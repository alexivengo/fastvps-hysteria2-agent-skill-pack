#!/usr/bin/env bash
set -euo pipefail

CLIENT_ENDPOINT="${1:-_}"

if [[ "$EUID" -eq 0 ]]; then
  SUDO=""
elif command -v sudo >/dev/null 2>&1; then
  SUDO="sudo"
else
  echo "ERROR: root or sudo is required on remote host" >&2
  exit 1
fi

run() {
  if [[ -n "$SUDO" ]]; then
    "$SUDO" "$@"
  else
    "$@"
  fi
}

CONFIG_PATH="/etc/hysteria/config.yaml"
run test -f "$CONFIG_PATH" || {
  echo "ERROR: $CONFIG_PATH not found" >&2
  exit 1
}

read_cfg() {
  run awk "$1" "$CONFIG_PATH"
}

listen_port() {
  read_cfg '
    /^listen:/ {
      gsub(":", "", $2)
      print $2
      exit
    }
  '
}

password_value() {
  read_cfg '
    /^auth:/ { in_auth=1; next }
    in_auth && $1 == "password:" { print $2; exit }
    in_auth && /^[^[:space:]]/ { exit }
  '
}

acme_domain() {
  read_cfg '
    /^acme:/ { in_acme=1; next }
    in_acme && $1 == "-" { print $2; exit }
    in_acme && /^[^[:space:]]/ { exit }
  '
}

acme_email() {
  read_cfg '
    /^acme:/ { in_acme=1; next }
    in_acme && $1 == "email:" { print $2; exit }
    in_acme && /^[^[:space:]]/ { exit }
  '
}

cert_path() {
  read_cfg '
    /^tls:/ { in_tls=1; next }
    in_tls && $1 == "cert:" { print $2; exit }
    in_tls && /^[^[:space:]]/ { exit }
  '
}

TLS_MODE="self-signed"
ENDPOINT="$CLIENT_ENDPOINT"
DOMAIN=""
EMAIL=""
CERT_SHA256=""

if run grep -q '^acme:' "$CONFIG_PATH"; then
  TLS_MODE="acme"
  DOMAIN="$(acme_domain || true)"
  EMAIL="$(acme_email || true)"
  [[ -n "$DOMAIN" ]] || {
    echo "ERROR: acme domain not found in $CONFIG_PATH" >&2
    exit 1
  }
  ENDPOINT="$DOMAIN"
else
  [[ -n "$ENDPOINT" && "$ENDPOINT" != "_" ]] || ENDPOINT="$(run hostname -f 2>/dev/null || run hostname)"
  CERT_PATH="$(cert_path || true)"
  [[ -n "$CERT_PATH" ]] || CERT_PATH="/etc/hysteria/server.crt"
  run test -f "$CERT_PATH" || {
    echo "ERROR: certificate not found at $CERT_PATH" >&2
    exit 1
  }
  CERT_SHA256="$(run openssl x509 -in "$CERT_PATH" -noout -fingerprint -sha256 | awk -F= '{print $2}')"
fi

PORT="$(listen_port || true)"
PASSWORD="$(password_value || true)"

[[ -n "$PORT" ]] || {
  echo "ERROR: listen port not found in $CONFIG_PATH" >&2
  exit 1
}
[[ -n "$PASSWORD" ]] || {
  echo "ERROR: auth password not found in $CONFIG_PATH" >&2
  exit 1
}

echo "HY2_TLS_MODE=${TLS_MODE}"
echo "HY2_ENDPOINT=${ENDPOINT}"
echo "HY2_PORT=${PORT}"
echo "HY2_AUTH_PASSWORD=${PASSWORD}"
echo "HY2_CERT_SHA256=${CERT_SHA256}"
echo "HY2_DOMAIN=${DOMAIN}"
echo "ACME_EMAIL=${EMAIL}"
