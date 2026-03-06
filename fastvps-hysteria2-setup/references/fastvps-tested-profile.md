# FastVPS tested profile

## Baseline environment

- Provider: FastVPS
- OS: Ubuntu 24.04 LTS
- Init system: systemd
- Service account created by installer: `hysteria`
- Control panel stack may already include `nginx`, FastPanel, mail, and other listeners

## Working reference deployment

- Transport: Hysteria2 over QUIC
- TLS mode: self-signed
- Endpoint type: direct IP, no domain
- Auth mode: password
- Masquerade target: `https://news.ycombinator.com/`
- Full tunnel clients validated on macOS plus mobile/desktop clients

## Port behavior learned from production

- Do not assume `443` is free.
- On the tested FastVPS host, `nginx` occupied both `443/tcp` and `443/udp`.
- In self-signed mode, running Hysteria2 on `8443` worked without touching the existing web stack.
- In ACME mode, `443` must be available to Hysteria2 for TLS-ALPN verification. If FastPanel or `nginx` already owns it, either free the port or do not choose ACME on that host.

## Required filesystem permissions

- `/etc/hysteria`: `root:hysteria` with mode `750`
- `/etc/hysteria/config.yaml`: `hysteria:hysteria` with mode `640`
- `/etc/hysteria/server.key`: `hysteria:hysteria` with mode `600`
- `/etc/hysteria/server.crt`: `hysteria:hysteria` with mode `644`

If `/etc/hysteria` stays `root:root 700`, the service fails with:

```text
failed to read server config {"error": "open /etc/hysteria/config.yaml: permission denied"}
```

## Successful validation markers

- `systemctl is-active hysteria-server` returns `active`
- `journalctl -u hysteria-server` contains `server up and running`
- `ss -luntp` shows `hysteria` bound on the chosen UDP port
- BrowserLeaks `IP`, `DNS`, and `WebRTC` tests show the VPS IP and no WebRTC leak
- macOS route to `1.1.1.1` uses a `utun` interface
- DNS whoami checks resolve to the VPS public IP rather than the home ISP IP

## Performance note

The tested FastVPS host had 1 vCPU and was not CPU-bound during light personal use. Observed throughput on one MacBook session was much more constrained by network path than by server CPU. Treat those numbers as anecdotal, not as a guarantee for another region or ISP.

## Failure signatures

- `Permission denied (publickey,password)`: SSH key access is missing or the wrong login was used.
- `listen udp :443: bind: address already in use`: another service owns UDP `443`.
- Browser public IP equals the VPS IP but WebRTC shows the home IP: the tunnel is working, but browser WebRTC handling is incomplete.
