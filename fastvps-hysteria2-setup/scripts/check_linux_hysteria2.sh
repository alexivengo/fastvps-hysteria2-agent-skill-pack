#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  check_linux_hysteria2.sh --expected-ip IP [options]

Required:
  --expected-ip IP       Expected public IP of the VPS

Options:
  --with-speed           Run a simple HTTP download speed check
  --help                 Show this help
USAGE
}

err() { printf 'ERROR: %s\n' "$*" >&2; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    err "Required command not found: $1"
    exit 1
  }
}

EXPECTED_IP=""
WITH_SPEED="0"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --expected-ip)
      EXPECTED_IP="${2:-}"
      shift 2
      ;;
    --with-speed)
      WITH_SPEED="1"
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

[[ -n "$EXPECTED_IP" ]] || {
  err "--expected-ip is required"
  usage
  exit 1
}

[[ "$(uname -s)" == "Linux" ]] || {
  err "This script is for Linux only"
  exit 1
}

require_cmd ip
require_cmd curl
require_cmd dig

ROUTE_INFO="$(ip route get 1.1.1.1 2>/dev/null | head -n 1 || true)"
PUBLIC_IPV4="$(curl -4 -s https://api.ipify.org)"
PUBLIC_IPV6="$(curl -6 -s --max-time 8 https://api64.ipify.org 2>/dev/null || true)"
DEFAULT_IFACE="$(ip route show default | awk 'NR==1 {for (i=1;i<=NF;i++) if ($i=="dev") {print $(i+1); exit}}')"
ROUTE_IFACE="$(printf '%s\n' "$ROUTE_INFO" | awk '{for (i=1;i<=NF;i++) if ($i=="dev") {print $(i+1); exit}}')"
OPENDNS_IP="$(dig +short myip.opendns.com @resolver1.opendns.com | sed -n '1p')"
GOOGLE_IP="$(dig +short TXT o-o.myaddr.l.google.com @ns1.google.com | tr -d '"' | sed -n '1p')"

if command -v resolvectl >/dev/null 2>&1; then
  PRIMARY_RESOLVER="$(resolvectl dns 2>/dev/null | awk 'NR==1 {print $NF; exit}')"
else
  PRIMARY_RESOLVER="$(awk '/^nameserver /{print $2; exit}' /etc/resolv.conf 2>/dev/null || true)"
fi

FAIL="0"

printf 'default_interface=%s\n' "$DEFAULT_IFACE"
printf 'route_to_1_1_1_1=%s\n' "$ROUTE_IFACE"
printf 'route_info=%s\n' "$ROUTE_INFO"
printf 'public_ipv4=%s\n' "$PUBLIC_IPV4"
printf 'public_ipv6=%s\n' "${PUBLIC_IPV6:-none}"
printf 'primary_resolver=%s\n' "${PRIMARY_RESOLVER:-unknown}"
printf 'opendns_whoami=%s\n' "$OPENDNS_IP"
printf 'google_whoami=%s\n' "$GOOGLE_IP"

if [[ -z "$ROUTE_IFACE" ]]; then
  err "Could not determine route interface for 1.1.1.1"
  FAIL="1"
fi

if [[ "$PUBLIC_IPV4" != "$EXPECTED_IP" ]]; then
  err "Public IPv4 does not match expected VPS IP"
  FAIL="1"
fi

if [[ -n "$OPENDNS_IP" && "$OPENDNS_IP" != "$EXPECTED_IP" ]]; then
  err "OpenDNS whoami does not match expected VPS IP"
  FAIL="1"
fi

if [[ -n "$GOOGLE_IP" && "$GOOGLE_IP" != "$EXPECTED_IP" ]]; then
  err "Google DNS whoami does not match expected VPS IP"
  FAIL="1"
fi

if [[ "$WITH_SPEED" == "1" ]]; then
  curl -L --max-time 40 -o /dev/null -s -w 'download_bps=%{speed_download}\n' https://proof.ovh.net/files/100Mb.dat || true
fi

exit "$FAIL"
