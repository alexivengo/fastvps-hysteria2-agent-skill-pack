[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [Alias('Host')]
    [string]$ServerHost,

    [string]$Domain,

    [string]$Email,

    [switch]$SelfSigned,

    [int]$ListenPort = 0,

    [string]$User = 'root',

    [int]$Port = 22,

    [string]$SshKey,

    [string]$AuthPassword = '__AUTO__',

    [switch]$NoLocalSecrets,

    [string]$OutputDir = (Join-Path (Get-Location) 'artifacts/fastvps-hysteria2'),

    [switch]$SkipUpgrade
)

$ErrorActionPreference = 'Stop'

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Write-Output ("[{0}] {1}" -f $timestamp, $Message)
}

function Fail {
    param([string]$Message)
    throw $Message
}

function Require-Command {
    param([string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        Fail "Required command not found: $Name"
    }
}

function Require-File {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Fail "Required file not found: $Path"
    }
}

function Quote-BashArg {
    param([string]$Value)
    if ($null -eq $Value) {
        return "''"
    }
    return "'" + ($Value -replace "'", "'""'""'") + "'"
}

function Get-RemoteValue {
    param(
        [string[]]$Lines,
        [string]$Name
    )

    foreach ($line in $Lines) {
        if ($line -like "$Name=*") {
            return $line.Substring($Name.Length + 1)
        }
    }
    return ''
}

function Write-RedactedRemoteLines {
    param([string[]]$Lines)

    foreach ($line in $Lines) {
        if ($line -like 'HY2_AUTH_PASSWORD=*') {
            Write-Output 'HY2_AUTH_PASSWORD=[REDACTED]'
        } elseif ($line -like 'HY2_CERT_SHA256=*') {
            Write-Output 'HY2_CERT_SHA256=[REDACTED]'
        } else {
            Write-Output $line
        }
    }
}

$tlsMode = if ($SelfSigned) { 'self-signed' } else { 'acme' }

if ($ListenPort -ne 0 -and ($ListenPort -lt 1 -or $ListenPort -gt 65535)) {
    Fail "ListenPort must be between 1 and 65535"
}

if ($tlsMode -eq 'acme') {
    if (-not $Domain) {
        Fail "Domain is required in ACME mode"
    }
    if (-not $Email) {
        Fail "Email is required in ACME mode"
    }
    if ($ListenPort -ne 0 -and $ListenPort -ne 443) {
        Fail "ACME mode requires port 443"
    }
}

Require-Command 'ssh'

$scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$remoteScriptPath = Join-Path $scriptRoot 'remote_deploy_fastvps_hysteria2.sh'
Require-File $remoteScriptPath

$sshOptions = @(
    '-p', "$Port",
    '-o', 'BatchMode=yes',
    '-o', 'StrictHostKeyChecking=accept-new',
    '-o', 'ServerAliveInterval=30',
    '-o', 'ConnectTimeout=15'
)

if ($SshKey) {
    $sshOptions += @('-i', $SshKey)
}

$remote = "$User@$ServerHost"
$domainArg = if ($Domain) { $Domain } else { '_' }
$emailArg = if ($Email) { $Email } else { '_' }
$listenPortArg = if ($ListenPort -gt 0) { "$ListenPort" } else { '_' }
$skipUpgradeArg = if ($SkipUpgrade) { '1' } else { '0' }

Write-Log "Checking SSH access to $remote"
$sshCheck = & ssh @sshOptions $remote 'echo "SSH OK: $(hostname)"' 2>&1
if ($LASTEXITCODE -ne 0) {
    $sshText = ($sshCheck | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
    Fail "SSH preflight failed: $sshText"
}
$sshCheck | ForEach-Object { $_.ToString() }

if ($tlsMode -eq 'acme') {
    try {
        $addresses = [System.Net.Dns]::GetHostAddresses($Domain) |
            Where-Object { $_.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork } |
            ForEach-Object { $_.IPAddressToString }
        if ($addresses) {
            Write-Log ("DNS A for {0}: {1}" -f $Domain, ($addresses -join ' '))
        } else {
            Write-Log ("Warning: no IPv4 A record found for {0} yet" -f $Domain)
        }
    } catch {
        Write-Log ("Warning: DNS lookup failed for {0}: {1}" -f $Domain, $_.Exception.Message)
    }
}

$remoteCommand = "bash -s -- {0} {1} {2} {3} {4} {5} {6}" -f `
    (Quote-BashArg $tlsMode), `
    (Quote-BashArg $domainArg), `
    (Quote-BashArg $emailArg), `
    (Quote-BashArg $AuthPassword), `
    (Quote-BashArg $skipUpgradeArg), `
    (Quote-BashArg $ServerHost), `
    (Quote-BashArg $listenPortArg)

Write-Log "Running remote deployment in $tlsMode mode"
$remoteScript = [System.IO.File]::ReadAllText($remoteScriptPath)
$remoteOutput = $remoteScript | & ssh @sshOptions $remote $remoteCommand 2>&1
$remoteExit = $LASTEXITCODE
$remoteLines = @($remoteOutput | ForEach-Object { $_.ToString() })
Write-RedactedRemoteLines -Lines $remoteLines

if ($remoteExit -ne 0) {
    Fail "Remote deployment failed"
}

$remoteEndpoint = Get-RemoteValue -Lines $remoteLines -Name 'HY2_ENDPOINT'
$remoteCertSha256 = Get-RemoteValue -Lines $remoteLines -Name 'HY2_CERT_SHA256'
$remotePort = Get-RemoteValue -Lines $remoteLines -Name 'HY2_PORT'
$remoteAuthPassword = Get-RemoteValue -Lines $remoteLines -Name 'HY2_AUTH_PASSWORD'

if (-not $remoteEndpoint) {
    if ($tlsMode -eq 'acme') {
        $remoteEndpoint = $Domain
    } else {
        $remoteEndpoint = $ServerHost
    }
}

if (-not $remotePort) {
    if ($ListenPort -gt 0) {
        $remotePort = "$ListenPort"
    } elseif ($tlsMode -eq 'acme') {
        $remotePort = '443'
    } else {
        $remotePort = '8443'
    }
}

if (-not $remoteAuthPassword) {
    Fail 'Could not determine effective auth password from remote output'
}

if ($NoLocalSecrets) {
    Write-Log 'Local secret artifact generation skipped by -NoLocalSecrets'
    Write-Log 'Re-run without -NoLocalSecrets when you explicitly want local connection.env and client profiles'
    exit 0
}

$baseDir = [System.IO.Path]::GetFullPath($OutputDir)
$serverDir = Join-Path $baseDir 'server'
$mobileDir = Join-Path $baseDir 'client/mobile'
$desktopDir = Join-Path $baseDir 'client/desktop'
$manualDir = Join-Path $baseDir 'client/manual'
$singBoxDir = Join-Path $baseDir 'client/sing-box'

foreach ($dir in @($serverDir, $mobileDir, $desktopDir, $manualDir, $singBoxDir)) {
    [void](New-Item -ItemType Directory -Path $dir -Force)
}

Write-Log "Creating local client artifacts in $baseDir"
$timestamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
$encodedAuth = [Uri]::EscapeDataString($remoteAuthPassword)

if ($tlsMode -eq 'self-signed') {
    if (-not $remoteCertSha256) {
        Fail 'Could not determine certificate fingerprint from remote output'
    }
    $encodedPin = [Uri]::EscapeDataString($remoteCertSha256)
    $baseUri = "hysteria2://$encodedAuth@$remoteEndpoint`:$remotePort/?insecure=1&pinSHA256=$encodedPin"
    $tlsServerName = ''
    $tlsInsecure = 'true'
} else {
    $baseUri = "hysteria2://$encodedAuth@$remoteEndpoint`:$remotePort/?sni=$remoteEndpoint&insecure=0"
    $tlsServerName = $remoteEndpoint
    $tlsInsecure = 'false'
}

$connectionEnv = @(
    "TLS_MODE=$tlsMode"
    "HY2_ENDPOINT=$remoteEndpoint"
    "HY2_PORT=$remotePort"
    "HY2_AUTH_PASSWORD=$remoteAuthPassword"
    "HY2_CERT_SHA256=$remoteCertSha256"
    "HY2_DOMAIN=$Domain"
    "ACME_EMAIL=$Email"
    "DEPLOYED_AT_UTC=$timestamp"
) -join "`n"

Set-Content -Path (Join-Path $serverDir 'connection.env') -Value ($connectionEnv + "`n") -Encoding utf8
Set-Content -Path (Join-Path $mobileDir 'profile.txt') -Value ($baseUri + '#HY2-Mobile' + "`n") -Encoding utf8
Set-Content -Path (Join-Path $desktopDir 'profile.txt') -Value ($baseUri + '#HY2-Desktop' + "`n") -Encoding utf8
Set-Content -Path (Join-Path $manualDir 'hysteria2-uri.txt') -Value ($baseUri + '#HY2-Manual' + "`n") -Encoding utf8

$singBoxJson = @"
{
  "outbounds": [
    {
      "type": "hysteria2",
      "tag": "hy2-out",
      "server": "$remoteEndpoint",
      "server_port": $remotePort,
      "password": "$remoteAuthPassword",
      "tls": {
        "enabled": true,
        "server_name": "$tlsServerName",
        "insecure": $tlsInsecure
      }
    }
  ]
}
"@

Set-Content -Path (Join-Path $singBoxDir 'hy2-outbound-snippet.json') -Value ($singBoxJson.Trim() + "`n") -Encoding utf8

$clientReadme = @"
# Client artifacts

- `mobile/profile.txt`: URI for mobile clients.
- `desktop/profile.txt`: URI for desktop clients.
- `manual/hysteria2-uri.txt`: backup URI for manual import.
- `sing-box/hy2-outbound-snippet.json`: outbound snippet for sing-box.

TLS mode: $tlsMode
Endpoint: $remoteEndpoint`:$remotePort
"@

Set-Content -Path (Join-Path (Join-Path $baseDir 'client') 'README.md') -Value ($clientReadme.Trim() + "`n") -Encoding utf8

Write-Log "Done. Keep $serverDir/connection.env private."
