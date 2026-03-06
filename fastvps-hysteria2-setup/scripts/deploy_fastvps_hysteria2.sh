#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  Self-signed mode:
    deploy_fastvps_hysteria2.sh --host HOST --self-signed [options]

  ACME mode:
    deploy_fastvps_hysteria2.sh --host HOST --domain DOMAIN --email EMAIL [options]

Required:
  --host HOST             VPS IP or hostname used for SSH and self-signed endpoint fallback

ACME mode required:
  --domain DOMAIN         FQDN for Hysteria2
  --email EMAIL           Email for Let's Encrypt ACME

Options:
  --self-signed           Use self-signed TLS instead of ACME
  --listen-port PORT      Override listen port; default is auto
  --user USER             SSH user (default: root)
  --port PORT             SSH port (default: 22)
  --ssh-key PATH          SSH private key path
  --auth-password PASS    Explicit auth password; otherwise reuse existing or generate
  --write-local-secrets   Explicitly write connection.env, URIs, and sing-box snippets locally
  --no-local-secrets      Deprecated compatibility alias; local secret writes are already disabled by default
  --output-dir DIR        Local artifact directory for explicit secret export
  --skip-upgrade          Skip apt upgrade
  --help                  Show this help
USAGE
}

log() { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }
err() { printf 'ERROR: %s\n' "$*" >&2; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REMOTE_SCRIPT_PATH="${SCRIPT_DIR}/remote_deploy_fastvps_hysteria2.sh"
ARTIFACT_LIB_PATH="${SCRIPT_DIR}/client_artifacts_fastvps_hysteria2.sh"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    err "Required command not found: $1"
    exit 1
  }
}

print_remote_output_redacted() {
  local output="$1"
  while IFS= read -r line; do
    case "$line" in
      HY2_AUTH_PASSWORD=*)
        printf 'HY2_AUTH_PASSWORD=[REDACTED]\n'
        ;;
      HY2_CERT_SHA256=*)
        printf 'HY2_CERT_SHA256=[REDACTED]\n'
        ;;
      *)
        printf '%s\n' "$line"
        ;;
    esac
  done <<< "$output"
}

extract_remote_value() {
  local output="$1"
  local key="$2"
  printf '%s\n' "$output" | awk -F= -v key="$key" '$1 == key { print substr($0, index($0, "=") + 1); exit }'
}

HOST=""
DOMAIN=""
EMAIL=""
TLS_MODE="acme"
LISTEN_PORT=""
SSH_USER="root"
SSH_PORT="22"
SSH_KEY=""
AUTH_PASSWORD="__AUTO__"
OUTPUT_DIR="$(pwd)/artifacts/fastvps-hysteria2"
SKIP_UPGRADE="0"
WRITE_LOCAL_SECRETS="0"
NO_LOCAL_SECRETS_COMPAT="0"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)
      HOST="${2:-}"
      shift 2
      ;;
    --domain)
      DOMAIN="${2:-}"
      shift 2
      ;;
    --email)
      EMAIL="${2:-}"
      shift 2
      ;;
    --self-signed)
      TLS_MODE="self-signed"
      shift
      ;;
    --listen-port)
      LISTEN_PORT="${2:-}"
      shift 2
      ;;
    --user)
      SSH_USER="${2:-}"
      shift 2
      ;;
    --port)
      SSH_PORT="${2:-}"
      shift 2
      ;;
    --ssh-key)
      SSH_KEY="${2:-}"
      shift 2
      ;;
    --auth-password)
      AUTH_PASSWORD="${2:-}"
      shift 2
      ;;
    --write-local-secrets)
      WRITE_LOCAL_SECRETS="1"
      shift
      ;;
    --no-local-secrets)
      NO_LOCAL_SECRETS_COMPAT="1"
      shift
      ;;
    --output-dir)
      OUTPUT_DIR="${2:-}"
      shift 2
      ;;
    --skip-upgrade)
      SKIP_UPGRADE="1"
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      err "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

if [[ "$WRITE_LOCAL_SECRETS" == "1" && "$NO_LOCAL_SECRETS_COMPAT" == "1" ]]; then
  err "--write-local-secrets conflicts with --no-local-secrets"
  exit 1
fi

[[ -n "$HOST" ]] || {
  err "--host is required"
  usage
  exit 1
}

if [[ -n "$LISTEN_PORT" ]]; then
  [[ "$LISTEN_PORT" =~ ^[0-9]+$ ]] || {
    err "--listen-port must be numeric"
    exit 1
  }
  (( LISTEN_PORT >= 1 && LISTEN_PORT <= 65535 )) || {
    err "--listen-port must be between 1 and 65535"
    exit 1
  }
fi

if [[ "$TLS_MODE" == "acme" ]]; then
  [[ -n "$DOMAIN" ]] || {
    err "--domain is required in ACME mode"
    usage
    exit 1
  }
  [[ -n "$EMAIL" ]] || {
    err "--email is required in ACME mode"
    usage
    exit 1
  }
  if [[ -n "$LISTEN_PORT" && "$LISTEN_PORT" != "443" ]]; then
    err "ACME mode requires port 443"
    exit 1
  fi
fi

require_cmd ssh
require_cmd curl
require_cmd openssl
require_cmd python3
[[ -r "$REMOTE_SCRIPT_PATH" ]] || {
  err "Shared remote script not found: $REMOTE_SCRIPT_PATH"
  exit 1
}
[[ -r "$ARTIFACT_LIB_PATH" ]] || {
  err "Artifact helper not found: $ARTIFACT_LIB_PATH"
  exit 1
}
# shellcheck source=/dev/null
source "$ARTIFACT_LIB_PATH"

SSH_OPTS=(
  -p "$SSH_PORT"
  -o BatchMode=yes
  -o StrictHostKeyChecking=accept-new
  -o ServerAliveInterval=30
  -o ConnectTimeout=15
)

if [[ -n "$SSH_KEY" ]]; then
  SSH_OPTS+=( -i "$SSH_KEY" )
fi

REMOTE="${SSH_USER}@${HOST}"
DOMAIN_ARG="${DOMAIN:-_}"
EMAIL_ARG="${EMAIL:-_}"
LISTEN_PORT_ARG="${LISTEN_PORT:-_}"

log "Checking SSH access to $REMOTE"
ssh "${SSH_OPTS[@]}" "$REMOTE" 'echo "SSH OK: $(hostname)"'

if [[ "$TLS_MODE" == "acme" ]] && command -v dig >/dev/null 2>&1; then
  DNS_IPS="$(dig +short A "$DOMAIN" | tr '\n' ' ' | sed 's/[[:space:]]\+$//')"
  if [[ -n "$DNS_IPS" ]]; then
    log "DNS A for $DOMAIN: $DNS_IPS"
  else
    log "Warning: no A record found for $DOMAIN yet"
  fi
fi

log "Running remote deployment in $TLS_MODE mode"
REMOTE_OUTPUT="$(
  ssh "${SSH_OPTS[@]}" "$REMOTE" bash -s -- \
    "$TLS_MODE" \
    "$DOMAIN_ARG" \
    "$EMAIL_ARG" \
    "$AUTH_PASSWORD" \
    "$SKIP_UPGRADE" \
    "$HOST" \
    "$LISTEN_PORT_ARG" < "$REMOTE_SCRIPT_PATH"
)"

print_remote_output_redacted "$REMOTE_OUTPUT"

REMOTE_ENDPOINT="$(extract_remote_value "$REMOTE_OUTPUT" HY2_ENDPOINT)"
REMOTE_CERT_SHA256="$(extract_remote_value "$REMOTE_OUTPUT" HY2_CERT_SHA256)"
REMOTE_PORT="$(extract_remote_value "$REMOTE_OUTPUT" HY2_PORT)"
REMOTE_AUTH_PASSWORD="$(extract_remote_value "$REMOTE_OUTPUT" HY2_AUTH_PASSWORD)"

if [[ -z "$REMOTE_ENDPOINT" ]]; then
  if [[ "$TLS_MODE" == "acme" ]]; then
    REMOTE_ENDPOINT="$DOMAIN"
  else
    REMOTE_ENDPOINT="$HOST"
  fi
fi

if [[ -z "$REMOTE_PORT" ]]; then
  if [[ -n "$LISTEN_PORT" ]]; then
    REMOTE_PORT="$LISTEN_PORT"
  elif [[ "$TLS_MODE" == "acme" ]]; then
    REMOTE_PORT="443"
  else
    REMOTE_PORT="8443"
  fi
fi

[[ -n "$REMOTE_AUTH_PASSWORD" ]] || {
  err "Could not determine effective auth password from remote output"
  exit 1
}

if [[ "$NO_LOCAL_SECRETS_COMPAT" == "1" ]]; then
  log "Note: --no-local-secrets is now redundant because local secret writes are disabled by default"
fi

if [[ "$WRITE_LOCAL_SECRETS" != "1" ]]; then
  log "Local secret artifact generation is disabled by default"
  log "Run ${SCRIPT_DIR}/export-client-secrets.sh --host ${HOST} --output-dir ${OUTPUT_DIR} when you explicitly want local connection.env and client profiles"
  exit 0
fi

log "Creating local client artifacts in $OUTPUT_DIR"
write_hysteria2_local_artifacts \
  "$OUTPUT_DIR" \
  "$TLS_MODE" \
  "$REMOTE_ENDPOINT" \
  "$REMOTE_PORT" \
  "$REMOTE_AUTH_PASSWORD" \
  "$REMOTE_CERT_SHA256" \
  "$DOMAIN" \
  "$EMAIL"

log "Done. Keep $OUTPUT_DIR/server/connection.env private."
