[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('codex', 'claude-code', 'opencode', 'gemini-cli', 'all')]
    [string]$Target
)

$ErrorActionPreference = 'Stop'

function Write-InstallLog {
    param([string]$Message)
    Write-Output ("[install] {0}" -f $Message)
}

function Require-Path {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Required path not found: $Path"
    }
}

function Copy-Tree {
    param(
        [string]$Source,
        [string]$Destination
    )

    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Destination) | Out-Null
    if (Test-Path -LiteralPath $Destination) {
        Remove-Item -Recurse -Force $Destination
    }
    Copy-Item -Recurse -Force $Source $Destination
}

function Copy-FileSafe {
    param(
        [string]$Source,
        [string]$Destination
    )

    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Destination) | Out-Null
    Copy-Item -Force $Source $Destination
}

$scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$repoRoot = Split-Path -Parent $scriptRoot
$skillSource = Join-Path $repoRoot 'fastvps-hysteria2-setup'
$claudeCommand = Join-Path $repoRoot 'integrations/claude-code/commands/fastvps-hysteria2.md'
$openCodeCommand = Join-Path $repoRoot 'integrations/opencode/command/fastvps-hysteria2.md'
$geminiCommand = Join-Path $repoRoot 'integrations/gemini-cli/commands/fastvps-hysteria2.toml'

Require-Path $skillSource
Require-Path $claudeCommand
Require-Path $openCodeCommand
Require-Path $geminiCommand

function Install-Codex {
    $destination = Join-Path $HOME '.codex/skills/fastvps-hysteria2-setup'
    Copy-Tree -Source $skillSource -Destination $destination
    Write-InstallLog "Codex skill installed to $destination"
}

function Install-ClaudeCode {
    $skillDestination = Join-Path $HOME '.claude/skills/fastvps-hysteria2-setup'
    $commandDestination = Join-Path $HOME '.claude/commands/fastvps-hysteria2.md'
    Copy-Tree -Source $skillSource -Destination $skillDestination
    Copy-FileSafe -Source $claudeCommand -Destination $commandDestination
    Write-InstallLog "Claude Code skill installed to $skillDestination"
    Write-InstallLog "Claude Code command installed to $commandDestination"
}

function Install-OpenCode {
    $skillDestination = Join-Path $HOME '.agents/skills/fastvps-hysteria2-setup'
    $commandDestination = Join-Path $HOME '.config/opencode/command/fastvps-hysteria2.md'
    Copy-Tree -Source $skillSource -Destination $skillDestination
    Copy-FileSafe -Source $openCodeCommand -Destination $commandDestination
    Write-InstallLog "OpenCode shared skill installed to $skillDestination"
    Write-InstallLog "OpenCode command installed to $commandDestination"
}

function Install-GeminiCli {
    $skillDestination = Join-Path $HOME '.agents/skills/fastvps-hysteria2-setup'
    $commandDestination = Join-Path $HOME '.gemini/commands/fastvps-hysteria2.toml'
    Copy-Tree -Source $skillSource -Destination $skillDestination
    Copy-FileSafe -Source $geminiCommand -Destination $commandDestination
    Write-InstallLog "Gemini CLI shared skill installed to $skillDestination"
    Write-InstallLog "Gemini CLI command installed to $commandDestination"
}

switch ($Target) {
    'codex' { Install-Codex }
    'claude-code' { Install-ClaudeCode }
    'opencode' { Install-OpenCode }
    'gemini-cli' { Install-GeminiCli }
    'all' {
        Install-Codex
        Install-ClaudeCode
        Install-OpenCode
        Install-GeminiCli
    }
}
