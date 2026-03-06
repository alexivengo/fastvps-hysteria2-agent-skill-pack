#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  check_macos_hysteria2.sh --expected-ip IP [options]

Required:
  --expected-ip IP       Expected public IP of the VPS

Options:
  --with-speed           Run networkQuality -s at the end
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

[[ "$(uname -s)" == "Darwin" ]] || {
  err "This script is for macOS only"
  exit 1
}

require_cmd route
require_cmd curl
require_cmd scutil
require_cmd dig

DEFAULT_ROUTE="$(route -n get default)"
TUNNEL_ROUTE="$(route -n get 1.1.1.1)"
DNS_STATE="$(scutil --dns)"
OPENDNS_RAW="$(dig +short myip.opendns.com @resolver1.opendns.com)"
GOOGLE_RAW="$(dig +short TXT o-o.myaddr.l.google.com @ns1.google.com | tr -d '"')"

DEFAULT_IFACE="$(printf '%s\n' "$DEFAULT_ROUTE" | awk '/interface:/{print $2}')"
TUNNEL_IFACE="$(printf '%s\n' "$TUNNEL_ROUTE" | awk '/interface:/{print $2}')"
PUBLIC_IPV4="$(curl -4 -s https://api.ipify.org)"
PUBLIC_IPV6="$(curl -6 -s --max-time 8 https://api64.ipify.org 2>/dev/null || true)"
PRIMARY_RESOLVER="$(printf '%s\n' "$DNS_STATE" | awk '/nameserver\[0\]/{print $3; exit}')"
OPENDNS_IP="$(printf '%s\n' "$OPENDNS_RAW" | sed -n '1p')"
GOOGLE_IP="$(printf '%s\n' "$GOOGLE_RAW" | sed -n '1p')"

FAIL="0"

printf 'default_interface=%s\n' "$DEFAULT_IFACE"
printf 'route_to_1_1_1_1=%s\n' "$TUNNEL_IFACE"
printf 'public_ipv4=%s\n' "$PUBLIC_IPV4"
printf 'public_ipv6=%s\n' "${PUBLIC_IPV6:-none}"
printf 'primary_resolver=%s\n' "$PRIMARY_RESOLVER"
printf 'opendns_whoami=%s\n' "$OPENDNS_IP"
printf 'google_whoami=%s\n' "$GOOGLE_IP"

if [[ "$TUNNEL_IFACE" != utun* ]]; then
  err "Route to 1.1.1.1 is not using a utun interface"
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
  if command -v networkQuality >/dev/null 2>&1; then
    networkQuality -s || true
  else
    err "networkQuality is not available on this macOS install"
  fi
fi

exit "$FAIL"
