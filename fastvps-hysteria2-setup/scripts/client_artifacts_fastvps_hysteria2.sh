#!/usr/bin/env bash

hy2_url_encode() {
  local raw="$1"
  python3 - "$raw" <<'PY'
import sys, urllib.parse
print(urllib.parse.quote(sys.argv[1], safe=''))
PY
}

write_hysteria2_local_artifacts() {
  local output_dir="$1"
  local tls_mode="$2"
  local endpoint="$3"
  local port="$4"
  local auth_password="$5"
  local cert_sha256="${6:-}"
  local domain="${7:-}"
  local email="${8:-}"

  local ts_utc enc_auth base_uri tls_server_name tls_insecure pin_enc
  ts_utc="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  enc_auth="$(hy2_url_encode "$auth_password")"

  mkdir -p \
    "$output_dir/server" \
    "$output_dir/client/mobile" \
    "$output_dir/client/desktop" \
    "$output_dir/client/manual" \
    "$output_dir/client/sing-box"

  if [[ "$tls_mode" == "self-signed" ]]; then
    [[ -n "$cert_sha256" ]] || {
      printf 'ERROR: certificate fingerprint is required in self-signed mode\n' >&2
      return 1
    }
    pin_enc="$(hy2_url_encode "$cert_sha256")"
    base_uri="hysteria2://${enc_auth}@${endpoint}:${port}/?insecure=1&pinSHA256=${pin_enc}"
    tls_server_name=""
    tls_insecure="true"
  else
    base_uri="hysteria2://${enc_auth}@${endpoint}:${port}/?sni=${endpoint}&insecure=0"
    tls_server_name="$endpoint"
    tls_insecure="false"
  fi

  printf 'TLS_MODE=%s\n' "$tls_mode" > "$output_dir/server/connection.env"
  printf 'HY2_ENDPOINT=%s\n' "$endpoint" >> "$output_dir/server/connection.env"
  printf 'HY2_PORT=%s\n' "$port" >> "$output_dir/server/connection.env"
  printf 'HY2_AUTH_PASSWORD=%s\n' "$auth_password" >> "$output_dir/server/connection.env"
  printf 'HY2_CERT_SHA256=%s\n' "$cert_sha256" >> "$output_dir/server/connection.env"
  printf 'HY2_DOMAIN=%s\n' "$domain" >> "$output_dir/server/connection.env"
  printf 'ACME_EMAIL=%s\n' "$email" >> "$output_dir/server/connection.env"
  printf 'DEPLOYED_AT_UTC=%s\n' "$ts_utc" >> "$output_dir/server/connection.env"
  chmod 600 "$output_dir/server/connection.env"

  printf '%s#HY2-Mobile\n' "$base_uri" > "$output_dir/client/mobile/profile.txt"
  printf '%s#HY2-Desktop\n' "$base_uri" > "$output_dir/client/desktop/profile.txt"
  printf '%s#HY2-Manual\n' "$base_uri" > "$output_dir/client/manual/hysteria2-uri.txt"

  python3 - "$endpoint" "$port" "$auth_password" "$tls_server_name" "$tls_insecure" > "$output_dir/client/sing-box/hy2-outbound-snippet.json" <<'PY'
import json
import sys

endpoint, port, password, server_name, insecure = sys.argv[1:]
payload = {
    "outbounds": [
        {
            "type": "hysteria2",
            "tag": "hy2-out",
            "server": endpoint,
            "server_port": int(port),
            "password": password,
            "tls": {
                "enabled": True,
                "server_name": server_name,
                "insecure": insecure == "true",
            },
        }
    ]
}
print(json.dumps(payload, indent=2))
PY

  cat > "$output_dir/client/README.md" <<README
# Client artifacts

- \`mobile/profile.txt\`: URI for mobile clients.
- \`desktop/profile.txt\`: URI for desktop clients.
- \`manual/hysteria2-uri.txt\`: backup URI for manual import.
- \`sing-box/hy2-outbound-snippet.json\`: outbound snippet for sing-box.

TLS mode: ${tls_mode}
Endpoint: ${endpoint}:${port}
README
}
