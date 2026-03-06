#!/usr/bin/env bash
set -euo pipefail

TLS_MODE="$1"
HY2_DOMAIN="$2"
ACME_EMAIL="$3"
HY2_AUTH_PASSWORD="$4"
SKIP_UPGRADE="$5"
HY2_HOST="$6"
HY2_LISTEN_PORT="$7"

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

existing_listen_port() {
  [[ -f /etc/hysteria/config.yaml ]] || return 1
  awk '
    /^listen:/ {
      gsub(":", "", $2)
      print $2
      exit
    }
  ' /etc/hysteria/config.yaml
}

existing_password() {
  [[ -f /etc/hysteria/config.yaml ]] || return 1
  awk '
    /^auth:/ { in_auth=1; next }
    in_auth && $1 == "password:" { print $2; exit }
    in_auth && /^[^[:space:]]/ { exit }
  ' /etc/hysteria/config.yaml
}

port_lines() {
  local port="$1"
  run ss -luntp | awk -v port="$port" '$5 ~ ":" port "$" || $5 ~ "\\]:" port "$"'
}

port_busy_by_other() {
  local port="$1"
  local lines
  lines="$(port_lines "$port" || true)"
  [[ -n "$lines" ]] || return 1
  if echo "$lines" | grep -vq 'hysteria'; then
    return 0
  fi
  return 1
}

pick_port() {
  local requested="$1"
  local current_port=""
  local effective=""

  current_port="$(existing_listen_port || true)"
  if [[ "$requested" != "_" && -n "$requested" ]]; then
    effective="$requested"
  elif [[ -n "$current_port" ]]; then
    effective="$current_port"
  else
    effective="443"
  fi

  if port_busy_by_other "$effective"; then
    if [[ "$TLS_MODE" == "self-signed" && "$effective" == "443" ]]; then
      if port_busy_by_other "8443"; then
        echo "ERROR: both 443 and 8443 are occupied by other services" >&2
        exit 1
      fi
      effective="8443"
      echo "INFO: 443 is occupied; using 8443 instead" >&2
    else
      echo "ERROR: port $effective is already occupied by another service" >&2
      exit 1
    fi
  fi

  echo "$effective"
}

pick_password() {
  if [[ "$HY2_AUTH_PASSWORD" != "__AUTO__" ]]; then
    echo "$HY2_AUTH_PASSWORD"
    return
  fi

  local existing=""
  existing="$(existing_password || true)"
  if [[ -n "$existing" ]]; then
    echo "$existing"
    return
  fi

  openssl rand -base64 24 | tr -d '\n'
}

ensure_self_signed_cert() {
  local cert_cn="$1"
  local cert_san="$2"

  run install -d -m 750 -o root -g hysteria /etc/hysteria

  if [[ -f /etc/hysteria/server.crt && -f /etc/hysteria/server.key ]]; then
    run chown hysteria:hysteria /etc/hysteria/server.crt /etc/hysteria/server.key
    run chmod 644 /etc/hysteria/server.crt
    run chmod 600 /etc/hysteria/server.key
    return
  fi

  run openssl req -x509 -nodes -newkey rsa:2048 -days 3650 \
    -keyout /etc/hysteria/server.key \
    -out /etc/hysteria/server.crt \
    -subj "/CN=${cert_cn}" \
    -addext "subjectAltName = ${cert_san}"

  run chown hysteria:hysteria /etc/hysteria/server.crt /etc/hysteria/server.key
  run chmod 644 /etc/hysteria/server.crt
  run chmod 600 /etc/hysteria/server.key
}

echo "== Preflight =="
run uname -a
run lsb_release -a || true
run timedatectl || true
run ss -luntp || true

echo "== System update =="
run apt-get update
if [[ "$SKIP_UPGRADE" != "1" ]]; then
  run env DEBIAN_FRONTEND=noninteractive apt-get -y upgrade
fi
run env DEBIAN_FRONTEND=noninteractive apt-get install -y curl ca-certificates jq openssl ufw dnsutils

echo "== Install Hysteria2 =="
TMP_INSTALLER="$(mktemp)"
curl -fsSL https://get.hy2.sh/ -o "$TMP_INSTALLER"
run bash "$TMP_INSTALLER"
rm -f "$TMP_INSTALLER"

[[ -x /usr/local/bin/hysteria ]] || {
  echo "ERROR: /usr/local/bin/hysteria not found after install" >&2
  exit 1
}

EFFECTIVE_PORT="$(pick_port "$HY2_LISTEN_PORT")"
EFFECTIVE_PASSWORD="$(pick_password)"

echo "== Firewall (UFW) =="
run ufw allow OpenSSH || true
run ufw allow "${EFFECTIVE_PORT}/tcp"
run ufw allow "${EFFECTIVE_PORT}/udp"
run ufw --force enable
run ufw status verbose || true

echo "== Write server config =="
TMP_CFG="$(mktemp)"
if [[ "$TLS_MODE" == "self-signed" ]]; then
  if [[ "$HY2_HOST" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    CERT_CN="$HY2_HOST"
    CERT_SAN="IP:${HY2_HOST}"
  else
    CERT_CN="$HY2_HOST"
    CERT_SAN="DNS:${HY2_HOST}"
  fi

  ensure_self_signed_cert "$CERT_CN" "$CERT_SAN"

  cat > "$TMP_CFG" <<CFG
listen: :${EFFECTIVE_PORT}

tls:
  cert: /etc/hysteria/server.crt
  key: /etc/hysteria/server.key

auth:
  type: password
  password: ${EFFECTIVE_PASSWORD}

masquerade:
  type: proxy
  proxy:
    url: https://news.ycombinator.com/
    rewriteHost: true
CFG
else
  run install -d -m 750 -o root -g hysteria /etc/hysteria

  cat > "$TMP_CFG" <<CFG
listen: :443

acme:
  domains:
    - ${HY2_DOMAIN}
  email: ${ACME_EMAIL}
  ca: letsencrypt
  type: tls

auth:
  type: password
  password: ${EFFECTIVE_PASSWORD}

masquerade:
  type: proxy
  proxy:
    url: https://news.ycombinator.com/
    rewriteHost: true
CFG
fi

run install -D -m 640 "$TMP_CFG" /etc/hysteria/config.yaml
rm -f "$TMP_CFG"
run chown hysteria:hysteria /etc/hysteria/config.yaml
run chown root:hysteria /etc/hysteria
run chmod 750 /etc/hysteria

run systemctl daemon-reload
run systemctl enable --now hysteria-server.service

sleep 3

echo "== Validation =="
run systemctl is-active hysteria-server.service
run systemctl status hysteria-server.service --no-pager || true
run ss -luntp | grep ":${EFFECTIVE_PORT}" || true
run journalctl -u hysteria-server.service -n 120 --no-pager || true

echo "== Result =="
if [[ "$TLS_MODE" == "self-signed" ]]; then
  CERT_SHA256="$(run openssl x509 -in /etc/hysteria/server.crt -noout -fingerprint -sha256 | awk -F= '{print $2}')"
  echo "HY2_ENDPOINT=${HY2_HOST}"
  echo "HY2_CERT_SHA256=${CERT_SHA256}"
else
  echo "HY2_ENDPOINT=${HY2_DOMAIN}"
fi
echo "HY2_PORT=${EFFECTIVE_PORT}"
echo "HY2_AUTH_PASSWORD=${EFFECTIVE_PASSWORD}"
