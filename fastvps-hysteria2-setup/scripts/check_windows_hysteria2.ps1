[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ExpectedIp,

    [switch]$WithSpeed
)

$ErrorActionPreference = 'Stop'

function Write-CheckError {
    param([string]$Message)
    Write-Error $Message
}

if (-not $IsWindows) {
    Write-CheckError "This script is for Windows PowerShell or PowerShell on Windows only"
    exit 1
}

$route = Test-NetConnection -ComputerName 1.1.1.1 -DiagnoseRouting -WarningAction SilentlyContinue
$publicIpv4 = (curl.exe -4 -s https://api.ipify.org).Trim()
$publicIpv6 = (curl.exe -6 -s --max-time 8 https://api64.ipify.org 2>$null).Trim()
$dnsServers = Get-DnsClientServerAddress -AddressFamily IPv4 |
    Where-Object { $_.ServerAddresses.Count -gt 0 } |
    Select-Object -ExpandProperty ServerAddresses -Unique
$openDnsIp = ''
$googleIp = ''

try {
    $openDnsIp = (Resolve-DnsName -Name myip.opendns.com -Server resolver1.opendns.com -Type A -ErrorAction Stop |
        Select-Object -First 1 -ExpandProperty IPAddress).Trim()
} catch {
}

try {
    $googleIp = ((Resolve-DnsName -Name o-o.myaddr.l.google.com -Server ns1.google.com -Type TXT -ErrorAction Stop |
        Select-Object -First 1 -ExpandProperty Strings) -join '').Trim()
} catch {
}

$fail = $false

$interfaceAlias = $route.SelectedNetRoute.InterfaceAlias
$sourceAddress = $route.SelectedSourceAddress

Write-Output ("route_interface={0}" -f $interfaceAlias)
Write-Output ("route_source={0}" -f $sourceAddress)
Write-Output ("public_ipv4={0}" -f $publicIpv4)
Write-Output ("public_ipv6={0}" -f ($(if ($publicIpv6) { $publicIpv6 } else { 'none' })))
Write-Output ("dns_servers={0}" -f ($dnsServers -join ','))
Write-Output ("opendns_whoami={0}" -f $openDnsIp)
Write-Output ("google_whoami={0}" -f $googleIp)

if (-not $interfaceAlias) {
    Write-CheckError "Could not determine route interface for 1.1.1.1"
    $fail = $true
}

if ($publicIpv4 -ne $ExpectedIp) {
    Write-CheckError "Public IPv4 does not match expected VPS IP"
    $fail = $true
}

if ($openDnsIp -and $openDnsIp -ne $ExpectedIp) {
    Write-CheckError "OpenDNS whoami does not match expected VPS IP"
    $fail = $true
}

if ($googleIp -and $googleIp -ne $ExpectedIp) {
    Write-CheckError "Google DNS whoami does not match expected VPS IP"
    $fail = $true
}

if ($WithSpeed) {
    try {
        $response = curl.exe -L --max-time 40 -o NUL -s -w "download_bps=%{speed_download}" https://proof.ovh.net/files/100Mb.dat
        Write-Output $response
    } catch {
        Write-Warning "Speed check failed: $($_.Exception.Message)"
    }
}

if ($fail) {
    exit 1
}
