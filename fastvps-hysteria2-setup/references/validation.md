# Validation workflow

## Server-side checks

Run these on the VPS after deployment:

```bash
systemctl is-active hysteria-server
systemctl status hysteria-server --no-pager
ss -luntp | grep hysteria
journalctl -u hysteria-server -n 80 --no-pager
```

Expected outcome:

- Service status is `active`
- Logs contain `server up and running`
- The chosen UDP port is bound by `hysteria`

## macOS CLI checks

Run the bundled script:

```bash
./scripts/check_macos_hysteria2.sh --expected-ip <vps-ip> --with-speed
```

Expected outcome:

- Route to `1.1.1.1` uses a `utun` interface
- Public IPv4 equals the VPS IP
- OpenDNS and Google DNS whoami also return the VPS IP

## Linux CLI checks

Run the bundled script:

```bash
./scripts/check_linux_hysteria2.sh --expected-ip <vps-ip> --with-speed
```

Expected outcome:

- `ip route get 1.1.1.1` resolves through the VPN interface
- Public IPv4 equals the VPS IP
- OpenDNS and Google DNS whoami also return the VPS IP

## Windows PowerShell CLI checks

Run the bundled script from PowerShell:

```powershell
./scripts/check_windows_hysteria2.ps1 -ExpectedIp <vps-ip> -WithSpeed
```

Expected outcome:

- `Test-NetConnection -DiagnoseRouting` resolves a route/interface without errors
- Public IPv4 equals the VPS IP
- OpenDNS and Google DNS whoami also return the VPS IP

## Browser checks

Open:

- `https://browserleaks.com/ip`
- `https://browserleaks.com/dns`
- `https://browserleaks.com/webrtc`

Expected outcome:

- `IP`: public IP equals the VPS
- `DNS`: DNS servers are not the home ISP; FastVPS upstream or Cloudflare is acceptable
- `WebRTC`: status is `No Leak`; local private IP is acceptable, public home IP is not

## Route and DNS spot checks

Useful direct commands on macOS:

```bash
route -n get 1.1.1.1
curl -4 -s https://api.ipify.org
scutil --dns | sed -n '1,120p'
dig +short myip.opendns.com @resolver1.opendns.com
dig +short TXT o-o.myaddr.l.google.com @ns1.google.com
```

Useful direct commands on Linux:

```bash
ip route get 1.1.1.1
curl -4 -s https://api.ipify.org
resolvectl dns || cat /etc/resolv.conf
dig +short myip.opendns.com @resolver1.opendns.com
dig +short TXT o-o.myaddr.l.google.com @ns1.google.com
```

Useful direct commands on Windows PowerShell:

```powershell
Test-NetConnection 1.1.1.1 -DiagnoseRouting
curl.exe -4 -s https://api.ipify.org
Get-DnsClientServerAddress -AddressFamily IPv4
Resolve-DnsName myip.opendns.com -Server resolver1.opendns.com -Type A
Resolve-DnsName o-o.myaddr.l.google.com -Server ns1.google.com -Type TXT
```

## Throughput checks

Use `networkQuality -s` on macOS for a quick uplink/downlink snapshot. On Linux and Windows, or for a common fallback across all platforms, use a test file:

```bash
curl -L --max-time 40 -o /dev/null -s -w 'download_bps=%{speed_download}\n' https://proof.ovh.net/files/100Mb.dat
```

Interpretation:

- Low throughput does not automatically implicate Hysteria2.
- Compare with VPN disabled before blaming the server.
- If the VPS load is low and `hysteria` CPU is low, the bottleneck is usually the client network path or routing.
