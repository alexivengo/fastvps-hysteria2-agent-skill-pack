#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  install_skill.sh --target codex|claude-code|opencode|gemini-cli|all

Options:
  --target NAME   Installation target
  --help          Show this help
USAGE
}

err() { printf 'ERROR: %s\n' "$*" >&2; }
log() { printf '[install] %s\n' "$*"; }

copy_tree() {
  local src="$1"
  local dst="$2"
  mkdir -p "$(dirname "$dst")"
  if command -v rsync >/dev/null 2>&1; then
    mkdir -p "$dst"
    rsync -a --delete "$src"/ "$dst"/
  else
    rm -rf "$dst"
    mkdir -p "$(dirname "$dst")"
    cp -R "$src" "$dst"
  fi
}

copy_file() {
  local src="$1"
  local dst="$2"
  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILL_SRC="$REPO_ROOT/fastvps-hysteria2-setup"
CLAUDE_CMD_SRC="$REPO_ROOT/integrations/claude-code/commands/fastvps-hysteria2.md"
OPENCODE_CMD_SRC="$REPO_ROOT/integrations/opencode/command/fastvps-hysteria2.md"
GEMINI_CMD_SRC="$REPO_ROOT/integrations/gemini-cli/commands/fastvps-hysteria2.toml"

[[ -d "$SKILL_SRC" ]] || {
  err "Skill source not found: $SKILL_SRC"
  exit 1
}

install_codex() {
  local dst="$HOME/.codex/skills/fastvps-hysteria2-setup"
  copy_tree "$SKILL_SRC" "$dst"
  log "Codex skill installed to $dst"
}

install_claude_code() {
  local skill_dst="$HOME/.claude/skills/fastvps-hysteria2-setup"
  local cmd_dst="$HOME/.claude/commands/fastvps-hysteria2.md"
  copy_tree "$SKILL_SRC" "$skill_dst"
  copy_file "$CLAUDE_CMD_SRC" "$cmd_dst"
  log "Claude Code skill installed to $skill_dst"
  log "Claude Code command installed to $cmd_dst"
}

install_opencode() {
  local skill_dst="$HOME/.agents/skills/fastvps-hysteria2-setup"
  local cmd_dst="$HOME/.config/opencode/command/fastvps-hysteria2.md"
  copy_tree "$SKILL_SRC" "$skill_dst"
  copy_file "$OPENCODE_CMD_SRC" "$cmd_dst"
  log "OpenCode shared skill installed to $skill_dst"
  log "OpenCode command installed to $cmd_dst"
}

install_gemini_cli() {
  local skill_dst="$HOME/.agents/skills/fastvps-hysteria2-setup"
  local cmd_dst="$HOME/.gemini/commands/fastvps-hysteria2.toml"
  copy_tree "$SKILL_SRC" "$skill_dst"
  copy_file "$GEMINI_CMD_SRC" "$cmd_dst"
  log "Gemini CLI shared skill installed to $skill_dst"
  log "Gemini CLI command installed to $cmd_dst"
}

case "$TARGET" in
  codex)
    install_codex
    ;;
  claude-code)
    install_claude_code
    ;;
  opencode)
    install_opencode
    ;;
  gemini-cli)
    install_gemini_cli
    ;;
  all)
    install_codex
    install_claude_code
    install_opencode
    install_gemini_cli
    ;;
  *)
    err "Unsupported target: $TARGET"
    usage
    exit 1
    ;;
esac
