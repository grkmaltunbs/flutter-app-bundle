#!/usr/bin/env bash
# flutter-kit in Codex, for one project: the agent profiles into
# .codex/agents/, CLAUDE.md as the instructions file, a word on the Dart
# MCP server. Idempotent — only what is missing is written.
# Usage: bash tool/codex/setup.sh <project dir>   (the $kit-codex-setup skill runs this)
set -euo pipefail
PLUGIN="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECT="${1:-$PWD}"
[ -d "$PROJECT" ] || { echo "no such folder: $PROJECT" >&2; exit 2; }

mkdir -p "$PROJECT/.codex/agents"
copied=0
for f in "$PLUGIN"/assets/agents/*.toml; do
  name="$(basename "$f")"
  if [ ! -f "$PROJECT/.codex/agents/$name" ]; then
    cp "$f" "$PROJECT/.codex/agents/$name"
    copied=$((copied + 1))
  fi
done
echo "▸ agents: $copied profile(s) copied into $PROJECT/.codex/agents/ ($(ls "$PROJECT/.codex/agents" | wc -l | tr -d ' ') there)"

CFG="$PROJECT/.codex/config.toml"
if [ -f "$CFG" ] && grep -q '^project_doc_fallback_filenames' "$CFG"; then
  echo "▸ config: project_doc_fallback_filenames already set in .codex/config.toml"
else
  { [ -f "$CFG" ] && [ -s "$CFG" ] && echo; echo '# flutter-kit: Codex reads the project rules from CLAUDE.md where it would read AGENTS.md.'; echo 'project_doc_fallback_filenames = ["CLAUDE.md"]'; } >> "$CFG"
  echo "▸ config: project_doc_fallback_filenames = [\"CLAUDE.md\"] written to .codex/config.toml"
fi

CODEX="$(command -v codex || true)"
[ -n "$CODEX" ] || [ ! -x /Applications/ChatGPT.app/Contents/Resources/codex ] || CODEX=/Applications/ChatGPT.app/Contents/Resources/codex
if [ -n "$CODEX" ]; then
  if "$CODEX" mcp list 2>/dev/null | grep -q '^dart\b\|"dart"\| dart '; then
    echo "▸ mcp: the Dart MCP server is configured for Codex"
  else
    echo "▸ mcp: not configured — add it with:  \"$CODEX\" mcp add dart -- dart mcp-server"
  fi
else
  echo "▸ mcp: codex not found on PATH or in the ChatGPT app — install Codex first"
fi
echo "▸ hooks: the plugin's hooks run in Codex only once you have trusted them (/hooks in the Codex TUI)."
