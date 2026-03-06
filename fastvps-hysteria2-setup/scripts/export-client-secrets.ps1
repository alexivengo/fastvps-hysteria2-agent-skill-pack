[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [Alias('Host')]
    [string]$ServerHost,

    [string]$ClientEndpoint,

    [string]$User = 'root',

    [int]$Port = 22,

    [string]$SshKey,

    [string]$OutputDir = (Join-Path (Get-Location) 'artifacts/fastvps-hysteria2')
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
    $replacement = "'" + '"' + "'" + '"' + "'"
    return "'" + ($Value -replace "'", $replacement) + "'"
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

Require-Command 'ssh'

$scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$remoteScriptPath = Join-Path $scriptRoot 'remote_export_fastvps_hysteria2.sh'
$artifactModulePath = Join-Path $scriptRoot 'client_artifacts_fastvps_hysteria2.ps1'
Require-File $remoteScriptPath
Require-File $artifactModulePath
. $artifactModulePath

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
$clientEndpointArg = if ($ClientEndpoint) { $ClientEndpoint } else { $ServerHost }
$remoteCommand = "bash -s -- {0}" -f (Quote-BashArg $clientEndpointArg)

Write-Log "Checking SSH access to $remote"
$sshCheck = & ssh @sshOptions $remote 'echo "SSH OK: $(hostname)"' 2>&1
if ($LASTEXITCODE -ne 0) {
    $sshText = ($sshCheck | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
    Fail "SSH preflight failed: $sshText"
}
$sshCheck | ForEach-Object { $_.ToString() }

Write-Log 'Reading active Hysteria2 config from server'
$remoteScript = [System.IO.File]::ReadAllText($remoteScriptPath)
$remoteOutput = $remoteScript | & ssh @sshOptions $remote $remoteCommand 2>&1
$remoteExit = $LASTEXITCODE
$remoteLines = @($remoteOutput | ForEach-Object { $_.ToString() })
Write-RedactedRemoteLines -Lines $remoteLines

if ($remoteExit -ne 0) {
    Fail 'Remote export failed'
}

$tlsMode = Get-RemoteValue -Lines $remoteLines -Name 'HY2_TLS_MODE'
$remoteEndpoint = Get-RemoteValue -Lines $remoteLines -Name 'HY2_ENDPOINT'
$remoteCertSha256 = Get-RemoteValue -Lines $remoteLines -Name 'HY2_CERT_SHA256'
$remotePort = Get-RemoteValue -Lines $remoteLines -Name 'HY2_PORT'
$remoteAuthPassword = Get-RemoteValue -Lines $remoteLines -Name 'HY2_AUTH_PASSWORD'
$remoteDomain = Get-RemoteValue -Lines $remoteLines -Name 'HY2_DOMAIN'
$remoteEmail = Get-RemoteValue -Lines $remoteLines -Name 'ACME_EMAIL'

if (-not $tlsMode) {
    Fail 'Could not determine TLS mode from remote config'
}
if (-not $remoteEndpoint) {
    Fail 'Could not determine endpoint from remote config'
}
if (-not $remotePort) {
    Fail 'Could not determine listen port from remote config'
}
if (-not $remoteAuthPassword) {
    Fail 'Could not determine auth password from remote config'
}

Write-Log "Writing local client artifacts in $OutputDir"
$baseDir = Write-Hysteria2LocalArtifacts `
    -OutputDir $OutputDir `
    -TlsMode $tlsMode `
    -Endpoint $remoteEndpoint `
    -Port $remotePort `
    -AuthPassword $remoteAuthPassword `
    -CertSha256 $remoteCertSha256 `
    -Domain $remoteDomain `
    -Email $remoteEmail

Write-Log "Done. Keep $(Join-Path $baseDir 'server/connection.env') private."
