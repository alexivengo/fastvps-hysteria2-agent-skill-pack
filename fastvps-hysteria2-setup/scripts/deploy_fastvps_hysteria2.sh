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
  --host HOST           VPS IP or hostname

ACME mode required:
  --domain DOMAIN       FQDN for Hysteria2
  --email EMAIL         Email for Let's Encrypt ACME

Options:
  --self-signed         Use self-signed TLS instead of ACME
  --listen-port PORT    Override listen port; default is auto
  --user USER           SSH user (default: root)
  --port PORT           SSH port (default: 22)
  --ssh-key PATH        SSH private key path
  --auth-password PASS  Explicit auth password; otherwise reuse existing or generate
  --no-local-secrets    Do not write connection.env, URIs, or sing-box snippets to local disk
  --output-dir DIR      Local artifact directory (default: ./artifacts/fastvps-hysteria2)
  --skip-upgrade        Skip apt upgrade
  --help                Show this help
USAGE
}

log() { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }
err() { printf 'ERROR: %s\n' "$*" >&2; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REMOTE_SCRIPT_PATH="${SCRIPT_DIR}/remote_deploy_fastvps_hysteria2.sh"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    err "Required command not found: $1"
    exit 1
  }
}

url_encode() {
  local raw="$1"
  python3 - "$raw" <<'PY'
import sys, urllib.parse
print(urllib.parse.quote(sys.argv[1], safe=''))
PY
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
NO_LOCAL_SECRETS="0"

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
    --no-local-secrets)
      NO_LOCAL_SECRETS="1"
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

REMOTE_ENDPOINT="$(printf '%s\n' "$REMOTE_OUTPUT" | awk -F= '/^HY2_ENDPOINT=/{print $2; exit}')"
REMOTE_CERT_SHA256="$(printf '%s\n' "$REMOTE_OUTPUT" | awk -F= '/^HY2_CERT_SHA256=/{print $2; exit}')"
REMOTE_PORT="$(printf '%s\n' "$REMOTE_OUTPUT" | awk -F= '/^HY2_PORT=/{print $2; exit}')"
REMOTE_AUTH_PASSWORD="$(printf '%s\n' "$REMOTE_OUTPUT" | awk -F= '/^HY2_AUTH_PASSWORD=/{print $2; exit}')"

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

if [[ "$NO_LOCAL_SECRETS" == "1" ]]; then
  log "Local secret artifact generation skipped by --no-local-secrets"
  log "Re-run without --no-local-secrets when you explicitly want local connection.env and client profiles"
  exit 0
fi

log "Creating local client artifacts in $OUTPUT_DIR"
TS_UTC="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
ENC_AUTH="$(url_encode "$REMOTE_AUTH_PASSWORD")"

mkdir -p "$OUTPUT_DIR"

mkdir -p \
  "$OUTPUT_DIR/server" \
  "$OUTPUT_DIR/client/mobile" \
  "$OUTPUT_DIR/client/desktop" \
  "$OUTPUT_DIR/client/manual" \
  "$OUTPUT_DIR/client/sing-box"

if [[ "$TLS_MODE" == "self-signed" ]]; then
  [[ -n "$REMOTE_CERT_SHA256" ]] || {
    err "Could not determine certificate fingerprint from remote output"
    exit 1
  }
  PIN_ENC="$(url_encode "$REMOTE_CERT_SHA256")"
  BASE_URI="hysteria2://${ENC_AUTH}@${REMOTE_ENDPOINT}:${REMOTE_PORT}/?insecure=1&pinSHA256=${PIN_ENC}"
  TLS_SERVER_NAME=""
  TLS_INSECURE="true"
else
  BASE_URI="hysteria2://${ENC_AUTH}@${REMOTE_ENDPOINT}:${REMOTE_PORT}/?sni=${REMOTE_ENDPOINT}&insecure=0"
  TLS_SERVER_NAME="$REMOTE_ENDPOINT"
  TLS_INSECURE="false"
fi

printf 'TLS_MODE=%s\n' "$TLS_MODE" > "$OUTPUT_DIR/server/connection.env"
printf 'HY2_ENDPOINT=%s\n' "$REMOTE_ENDPOINT" >> "$OUTPUT_DIR/server/connection.env"
printf 'HY2_PORT=%s\n' "$REMOTE_PORT" >> "$OUTPUT_DIR/server/connection.env"
printf 'HY2_AUTH_PASSWORD=%s\n' "$REMOTE_AUTH_PASSWORD" >> "$OUTPUT_DIR/server/connection.env"
printf 'HY2_CERT_SHA256=%s\n' "${REMOTE_CERT_SHA256:-}" >> "$OUTPUT_DIR/server/connection.env"
printf 'HY2_DOMAIN=%s\n' "$DOMAIN" >> "$OUTPUT_DIR/server/connection.env"
printf 'ACME_EMAIL=%s\n' "$EMAIL" >> "$OUTPUT_DIR/server/connection.env"
printf 'DEPLOYED_AT_UTC=%s\n' "$TS_UTC" >> "$OUTPUT_DIR/server/connection.env"
chmod 600 "$OUTPUT_DIR/server/connection.env"

printf '%s#HY2-Mobile\n' "$BASE_URI" > "$OUTPUT_DIR/client/mobile/profile.txt"
printf '%s#HY2-Desktop\n' "$BASE_URI" > "$OUTPUT_DIR/client/desktop/profile.txt"
printf '%s#HY2-Manual\n' "$BASE_URI" > "$OUTPUT_DIR/client/manual/hysteria2-uri.txt"

cat > "$OUTPUT_DIR/client/sing-box/hy2-outbound-snippet.json" <<JSON
{
  "outbounds": [
    {
      "type": "hysteria2",
      "tag": "hy2-out",
      "server": "${REMOTE_ENDPOINT}",
      "server_port": ${REMOTE_PORT},
      "password": "${REMOTE_AUTH_PASSWORD}",
      "tls": {
        "enabled": true,
        "server_name": "${TLS_SERVER_NAME}",
        "insecure": ${TLS_INSECURE}
      }
    }
  ]
}
JSON

cat > "$OUTPUT_DIR/client/README.md" <<README
# Client artifacts

- \`mobile/profile.txt\`: URI for mobile clients.
- \`desktop/profile.txt\`: URI for desktop clients.
- \`manual/hysteria2-uri.txt\`: backup URI for manual import.
- \`sing-box/hy2-outbound-snippet.json\`: outbound snippet for sing-box.

TLS mode: ${TLS_MODE}
Endpoint: ${REMOTE_ENDPOINT}:${REMOTE_PORT}
README

log "Done. Keep $OUTPUT_DIR/server/connection.env private."
