---
name: fastvps-hysteria2-setup
description: Configure Hysteria2 on a FastVPS VPS, bootstrap SSH key access when the user only has panel/password access, deploy self-signed or Let's Encrypt TLS, export client URIs only on explicit request, handle common FastVPS port conflicts on 443, and verify server health plus IP/DNS/WebRTC leak posture on macOS, Linux, and Windows clients. Use when asked to set up, repair, migrate, or validate Hysteria2 or hy2 on FastVPS.
---

# FastVPS Hysteria2 Setup

## Overview

Use this skill to deploy and validate Hysteria2 on FastVPS Ubuntu hosts with a workflow that has already been tested end to end on a live FastVPS server. Prefer the bundled scripts over ad hoc shell sessions so another agent can reproduce the same result deterministically across Linux, macOS, and native Windows PowerShell operators.

Both deploy wrappers stream the same shared remote bash resource to the VPS. If deployment behavior needs to change, patch `scripts/remote_deploy_fastvps_hysteria2.sh` first. Local client artifact export is a separate step with its own shared remote reader, so change `scripts/remote_export_fastvps_hysteria2.sh` when the exported fields need to change.

## Workflow

1. Establish non-interactive SSH access first.
- Agents cannot type an interactive VPS password reliably. If the user only has a root password from the FastVPS panel, have them add the local public key with the one-liner in `## Bootstrap SSH Access`.

2. Inspect the server before choosing ports.
- Run `ss -luntp` and check whether `443/tcp` or `443/udp` is already occupied.
- Read `references/fastvps-tested-profile.md` before changing ports or permissions. FastVPS stacks often include `nginx`/FastPanel and may already use `443`, including QUIC on UDP.

3. Choose the deployment mode.
- `self-signed`: default for quick setup when the user has no domain. The deploy script reuses existing password and self-signed cert when possible and falls back from `443` to `8443` if `443` is busy.
- `acme`: use only when the user controls DNS for a domain pointing to the VPS and can keep `443` available for Hysteria2.

4. Run the bundled deploy script from the skill directory.
- Linux and macOS:

```bash
./scripts/deploy_fastvps_hysteria2.sh --host <vps-ip> --self-signed
```

ACME example:

```bash
./scripts/deploy_fastvps_hysteria2.sh \
  --host <vps-ip> \
  --domain <hy2.example.com> \
  --email <user@example.com>
```

- Windows PowerShell:

```powershell
./scripts/deploy_fastvps_hysteria2.ps1 -Host <vps-ip> -SelfSigned
```

ACME example:

```powershell
./scripts/deploy_fastvps_hysteria2.ps1 `
  -Host <vps-ip> `
  -Domain <hy2.example.com> `
  -Email <user@example.com>
```

5. Treat deploy as secure-by-default.
- Deploy wrappers do not write `connection.env`, URIs, or sing-box snippets to local disk unless the operator explicitly opts in with `--write-local-secrets` or `-WriteLocalSecrets`.
- The old `--no-local-secrets` and `-NoLocalSecrets` flags are only compatibility aliases now and should not be the primary path in new instructions.

6. Export client secrets only when the user explicitly wants local artifacts.
- Linux and macOS:

```bash
./scripts/export-client-secrets.sh --host <vps-ip>
```

- Windows PowerShell:

```powershell
./scripts/export-client-secrets.ps1 -Host <vps-ip>
```

- For self-signed mode the exported URI uses `insecure=1` together with `pinSHA256`, matching the tested reference setup.
- If the SSH host is not the same value the client should dial, pass `--client-endpoint` or `-ClientEndpoint`.

7. Validate the tunnel after the user imports the profile.
- macOS: run `scripts/check_macos_hysteria2.sh --expected-ip <vps-ip>`
- Linux: run `scripts/check_linux_hysteria2.sh --expected-ip <vps-ip>`
- Windows PowerShell: run `scripts/check_windows_hysteria2.ps1 -ExpectedIp <vps-ip>`
- Read `references/validation.md` for BrowserLeaks checks, DNS expectations, and throughput checks.

## Bootstrap SSH Access

FastVPS users often start with only panel access and a reset root password.

Use this panel path when the user cannot find the SSH password:
- `My services -> VPS/VDS -> server card -> Management -> Reset password`

Once the user has the password, add the local SSH public key.

Linux and macOS:

```bash
ssh root@<vps-ip> "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys" < ~/.ssh/id_ed25519.pub
```

Windows PowerShell:

```powershell
Get-Content $HOME\.ssh\id_ed25519.pub | ssh root@<vps-ip> "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
```

If the public key does not exist, generate it first.

Linux and macOS:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ''
```

Windows PowerShell:

```powershell
ssh-keygen -t ed25519 -f "$HOME\.ssh\id_ed25519" -N ''
```

After that, confirm non-interactive access.

Any platform:

```bash
ssh -o BatchMode=yes root@<vps-ip> 'echo ok'
```

## Deployment Rules

- Do not assume the VPS is clean just because the user says it is. FastVPS images may ship with FastPanel, `nginx`, mail services, or other listeners.
- Do not rotate an existing password or self-signed cert unless the user explicitly wants new client credentials. The deploy script preserves them by default.
- Prefer the default deploy path without local secret writes. Only use `--write-local-secrets` or `-WriteLocalSecrets` when the user explicitly wants credentials materialized on disk immediately.
- Prefer `export-client-secrets` as the normal path for creating `connection.env`, URI files, and sing-box snippets after the server is already up.
- Do not use ACME mode unless the user has a domain and `443` can remain on Hysteria2. With `type: tls`, port `443` is operationally required.
- Keep `/etc/hysteria` readable by the `hysteria` service user. The tested working permission model is in `references/fastvps-tested-profile.md`.

## Troubleshooting

- `Permission denied (publickey,password)`:
  The agent does not have non-interactive SSH access yet. Bootstrap SSH key auth first.
- Windows operator environment has no OpenSSH client:
  Install the built-in OpenSSH Client feature first; the Windows deploy and validation scripts depend on `ssh.exe`.
- `failed to read server config: permission denied`:
  Directory or file permissions under `/etc/hysteria` are wrong. Apply the ownership and modes from the reference profile.
- `listen udp :443: bind: address already in use`:
  Another service is already using UDP `443`. In self-signed mode keep Hysteria2 on `8443`. In ACME mode resolve the conflict before continuing.
- Browser shows the VPS IP but WebRTC leaks the home public IP:
  The tunnel is up, but browser-level WebRTC protection is incomplete. Use the manual browser checks in `references/validation.md`.

## Resources

- `scripts/deploy_fastvps_hysteria2.sh`: deterministic FastVPS deployer with secure-by-default local behavior.
- `scripts/deploy_fastvps_hysteria2.ps1`: native PowerShell deployer for Windows operators with the same secure-by-default behavior.
- `scripts/export-client-secrets.sh`: explicit local export of `connection.env`, URI files, and sing-box snippets on Unix operators.
- `scripts/export-client-secrets.ps1`: explicit local export of client secrets on Windows operators.
- `scripts/remote_deploy_fastvps_hysteria2.sh`: shared server-side deployment logic consumed by both wrappers.
- `scripts/remote_export_fastvps_hysteria2.sh`: shared server-side reader for current Hysteria2 settings.
- `scripts/client_artifacts_fastvps_hysteria2.sh`: local artifact writer for bash operators.
- `scripts/client_artifacts_fastvps_hysteria2.ps1`: local artifact writer for PowerShell operators.
- `scripts/check_macos_hysteria2.sh`: post-connect CLI checks for route, public IP, DNS, and optional speed.
- `scripts/check_linux_hysteria2.sh`: post-connect CLI checks for Linux clients.
- `scripts/check_windows_hysteria2.ps1`: post-connect CLI checks for Windows PowerShell clients.
- `references/fastvps-tested-profile.md`: reference profile and failure signatures from the tested live setup.
- `references/validation.md`: server-side, macOS, Linux, Windows, BrowserLeaks, and throughput validation steps.
