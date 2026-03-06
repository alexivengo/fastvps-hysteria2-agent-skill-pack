#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  export-client-secrets.sh --host HOST [options]

Required:
  --host HOST              VPS IP or hostname used for SSH

Options:
  --client-endpoint HOST   Endpoint to write into client artifacts; defaults to --host for self-signed mode
  --user USER              SSH user (default: root)
  --port PORT              SSH port (default: 22)
  --ssh-key PATH           SSH private key path
  --output-dir DIR         Local artifact directory (default: ./artifacts/fastvps-hysteria2)
  --help                   Show this help
USAGE
}

log() { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }
err() { printf 'ERROR: %s\n' "$*" >&2; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REMOTE_SCRIPT_PATH="${SCRIPT_DIR}/remote_export_fastvps_hysteria2.sh"
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
CLIENT_ENDPOINT=""
SSH_USER="root"
SSH_PORT="22"
SSH_KEY=""
OUTPUT_DIR="$(pwd)/artifacts/fastvps-hysteria2"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)
      HOST="${2:-}"
      shift 2
      ;;
    --client-endpoint)
      CLIENT_ENDPOINT="${2:-}"
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
    --output-dir)
      OUTPUT_DIR="${2:-}"
      shift 2
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

require_cmd ssh
require_cmd python3
[[ -r "$REMOTE_SCRIPT_PATH" ]] || {
  err "Shared remote export script not found: $REMOTE_SCRIPT_PATH"
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
CLIENT_ENDPOINT_ARG="${CLIENT_ENDPOINT:-$HOST}"

log "Checking SSH access to $REMOTE"
ssh "${SSH_OPTS[@]}" "$REMOTE" 'echo "SSH OK: $(hostname)"'

log "Reading active Hysteria2 config from server"
REMOTE_OUTPUT="$(ssh "${SSH_OPTS[@]}" "$REMOTE" bash -s -- "$CLIENT_ENDPOINT_ARG" < "$REMOTE_SCRIPT_PATH")"
print_remote_output_redacted "$REMOTE_OUTPUT"

TLS_MODE="$(extract_remote_value "$REMOTE_OUTPUT" HY2_TLS_MODE)"
REMOTE_ENDPOINT="$(extract_remote_value "$REMOTE_OUTPUT" HY2_ENDPOINT)"
REMOTE_CERT_SHA256="$(extract_remote_value "$REMOTE_OUTPUT" HY2_CERT_SHA256)"
REMOTE_PORT="$(extract_remote_value "$REMOTE_OUTPUT" HY2_PORT)"
REMOTE_AUTH_PASSWORD="$(extract_remote_value "$REMOTE_OUTPUT" HY2_AUTH_PASSWORD)"
REMOTE_DOMAIN="$(extract_remote_value "$REMOTE_OUTPUT" HY2_DOMAIN)"
REMOTE_EMAIL="$(extract_remote_value "$REMOTE_OUTPUT" ACME_EMAIL)"

[[ -n "$TLS_MODE" ]] || {
  err "Could not determine TLS mode from remote config"
  exit 1
}
[[ -n "$REMOTE_ENDPOINT" ]] || {
  err "Could not determine endpoint from remote config"
  exit 1
}
[[ -n "$REMOTE_PORT" ]] || {
  err "Could not determine listen port from remote config"
  exit 1
}
[[ -n "$REMOTE_AUTH_PASSWORD" ]] || {
  err "Could not determine auth password from remote config"
  exit 1
}

log "Writing local client artifacts to $OUTPUT_DIR"
write_hysteria2_local_artifacts \
  "$OUTPUT_DIR" \
  "$TLS_MODE" \
  "$REMOTE_ENDPOINT" \
  "$REMOTE_PORT" \
  "$REMOTE_AUTH_PASSWORD" \
  "$REMOTE_CERT_SHA256" \
  "$REMOTE_DOMAIN" \
  "$REMOTE_EMAIL"

log "Done. Keep $OUTPUT_DIR/server/connection.env private."
