[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('codex', 'claude-code', 'opencode', 'gemini-cli', 'non-codex', 'all')]
    [string]$Target
)

$ErrorActionPreference = 'Stop'

function Write-UninstallLog {
    param([string]$Message)
    Write-Output ("[uninstall] {0}" -f $Message)
}

function Remove-PathSafe {
    param([string]$Path)
    if (Test-Path -LiteralPath $Path) {
        Remove-Item -Recurse -Force $Path
        Write-UninstallLog "Removed $Path"
    } else {
        Write-UninstallLog "Skip missing $Path"
    }
}

function Uninstall-Codex {
    Remove-PathSafe (Join-Path $HOME '.codex/skills/fastvps-hysteria2-setup')
}

function Uninstall-ClaudeCode {
    Remove-PathSafe (Join-Path $HOME '.claude/skills/fastvps-hysteria2-setup')
    Remove-PathSafe (Join-Path $HOME '.claude/commands/fastvps-hysteria2.md')
}

function Uninstall-OpenCode {
    Remove-PathSafe (Join-Path $HOME '.agents/skills/fastvps-hysteria2-setup')
    Remove-PathSafe (Join-Path $HOME '.config/opencode/command/fastvps-hysteria2.md')
}

function Uninstall-GeminiCli {
    Remove-PathSafe (Join-Path $HOME '.agents/skills/fastvps-hysteria2-setup')
    Remove-PathSafe (Join-Path $HOME '.gemini/commands/fastvps-hysteria2.toml')
}

switch ($Target) {
    'codex' { Uninstall-Codex }
    'claude-code' { Uninstall-ClaudeCode }
    'opencode' { Uninstall-OpenCode }
    'gemini-cli' { Uninstall-GeminiCli }
    'non-codex' {
        Uninstall-ClaudeCode
        Uninstall-OpenCode
        Uninstall-GeminiCli
    }
    'all' {
        Uninstall-Codex
        Uninstall-ClaudeCode
        Uninstall-OpenCode
        Uninstall-GeminiCli
    }
}
