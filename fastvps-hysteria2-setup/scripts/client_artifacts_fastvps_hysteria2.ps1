function Write-Hysteria2LocalArtifacts {
    param(
        [Parameter(Mandatory = $true)]
        [string]$OutputDir,

        [Parameter(Mandatory = $true)]
        [string]$TlsMode,

        [Parameter(Mandatory = $true)]
        [string]$Endpoint,

        [Parameter(Mandatory = $true)]
        [string]$Port,

        [Parameter(Mandatory = $true)]
        [string]$AuthPassword,

        [string]$CertSha256 = '',

        [string]$Domain = '',

        [string]$Email = ''
    )

    $baseDir = [System.IO.Path]::GetFullPath($OutputDir)
    $serverDir = Join-Path $baseDir 'server'
    $mobileDir = Join-Path $baseDir 'client/mobile'
    $desktopDir = Join-Path $baseDir 'client/desktop'
    $manualDir = Join-Path $baseDir 'client/manual'
    $singBoxDir = Join-Path $baseDir 'client/sing-box'

    foreach ($dir in @($serverDir, $mobileDir, $desktopDir, $manualDir, $singBoxDir)) {
        [void](New-Item -ItemType Directory -Path $dir -Force)
    }

    $timestamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    $encodedAuth = [Uri]::EscapeDataString($AuthPassword)

    if ($TlsMode -eq 'self-signed') {
        if (-not $CertSha256) {
            throw 'Certificate fingerprint is required in self-signed mode'
        }
        $encodedPin = [Uri]::EscapeDataString($CertSha256)
        $baseUri = "hysteria2://$encodedAuth@$Endpoint`:$Port/?insecure=1&pinSHA256=$encodedPin"
        $tlsServerName = ''
        $tlsInsecure = 'true'
    } else {
        $baseUri = "hysteria2://$encodedAuth@$Endpoint`:$Port/?sni=$Endpoint&insecure=0"
        $tlsServerName = $Endpoint
        $tlsInsecure = 'false'
    }

    $connectionEnv = @(
        "TLS_MODE=$TlsMode"
        "HY2_ENDPOINT=$Endpoint"
        "HY2_PORT=$Port"
        "HY2_AUTH_PASSWORD=$AuthPassword"
        "HY2_CERT_SHA256=$CertSha256"
        "HY2_DOMAIN=$Domain"
        "ACME_EMAIL=$Email"
        "DEPLOYED_AT_UTC=$timestamp"
    ) -join "`n"

    Set-Content -Path (Join-Path $serverDir 'connection.env') -Value ($connectionEnv + "`n") -Encoding utf8
    Set-Content -Path (Join-Path $mobileDir 'profile.txt') -Value ($baseUri + '#HY2-Mobile' + "`n") -Encoding utf8
    Set-Content -Path (Join-Path $desktopDir 'profile.txt') -Value ($baseUri + '#HY2-Desktop' + "`n") -Encoding utf8
    Set-Content -Path (Join-Path $manualDir 'hysteria2-uri.txt') -Value ($baseUri + '#HY2-Manual' + "`n") -Encoding utf8

    $singBoxPayload = [ordered]@{
        outbounds = @(
            [ordered]@{
                type = 'hysteria2'
                tag = 'hy2-out'
                server = $Endpoint
                server_port = [int]$Port
                password = $AuthPassword
                tls = [ordered]@{
                    enabled = $true
                    server_name = $tlsServerName
                    insecure = [System.Convert]::ToBoolean($tlsInsecure)
                }
            }
        )
    }

    $singBoxJson = $singBoxPayload | ConvertTo-Json -Depth 5
    Set-Content -Path (Join-Path $singBoxDir 'hy2-outbound-snippet.json') -Value ($singBoxJson + "`n") -Encoding utf8

    $clientReadme = @"
# Client artifacts

- `mobile/profile.txt`: URI for mobile clients.
- `desktop/profile.txt`: URI for desktop clients.
- `manual/hysteria2-uri.txt`: backup URI for manual import.
- `sing-box/hy2-outbound-snippet.json`: outbound snippet for sing-box.

TLS mode: $TlsMode
Endpoint: $Endpoint`:$Port
"@

    Set-Content -Path (Join-Path (Join-Path $baseDir 'client') 'README.md') -Value ($clientReadme.Trim() + "`n") -Encoding utf8
    return $baseDir
}
