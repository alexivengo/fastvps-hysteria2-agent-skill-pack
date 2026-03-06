#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  uninstall_skill.sh --target codex|claude-code|opencode|gemini-cli|non-codex|all

Options:
  --target NAME   Removal target
  --help          Show this help
USAGE
}

err() { printf 'ERROR: %s\n' "$*" >&2; }
log() { printf '[uninstall] %s\n' "$*"; }

delete_path() {
  local path="$1"
  if [[ -e "$path" ]]; then
    rm -rf "$path"
    log "Removed $path"
  else
    log "Skip missing $path"
  fi
}

TARGET=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      TARGET="${2:-}"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      err "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

[[ -n "$TARGET" ]] || {
  err "--target is required"
  usage
  exit 1
}

uninstall_codex() {
  delete_path "$HOME/.codex/skills/fastvps-hysteria2-setup"
}

uninstall_claude_code() {
  delete_path "$HOME/.claude/skills/fastvps-hysteria2-setup"
  delete_path "$HOME/.claude/commands/fastvps-hysteria2.md"
}

uninstall_opencode() {
  delete_path "$HOME/.agents/skills/fastvps-hysteria2-setup"
  delete_path "$HOME/.config/opencode/command/fastvps-hysteria2.md"
}

uninstall_gemini_cli() {
  delete_path "$HOME/.agents/skills/fastvps-hysteria2-setup"
  delete_path "$HOME/.gemini/commands/fastvps-hysteria2.toml"
}

case "$TARGET" in
  codex)
    uninstall_codex
    ;;
  claude-code)
    uninstall_claude_code
    ;;
  opencode)
    uninstall_opencode
    ;;
  gemini-cli)
    uninstall_gemini_cli
    ;;
  non-codex)
    uninstall_claude_code
    uninstall_opencode
    uninstall_gemini_cli
    ;;
  all)
    uninstall_codex
    uninstall_claude_code
    uninstall_opencode
    uninstall_gemini_cli
    ;;
  *)
    err "Unsupported target: $TARGET"
    usage
    exit 1
    ;;
esac
