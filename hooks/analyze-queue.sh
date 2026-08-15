#!/bin/bash
# PostToolUse hook (matcher: Write|Edit) — the collecting half of the
# analyze gate. Per-edit it ONLY records the edited .dart path to a
# queue file; it never runs the analyzer and never blocks (always exit
# 0). The Stop/SubagentStop hook (analyze-check.sh) runs one batched
# check per turn, so mid-implementation states — warnings, or
# @freezed/@injectable files whose .g.dart/.freezed.dart parts aren't
# generated yet — never interrupt the work in progress.
# Dependency-free beyond bash + python3 (for parsing the hook JSON).

set -u

# Read the hook payload from stdin exactly once.
input="$(cat)"

# Extract tool_input.file_path from the JSON payload.
file_path="$(printf '%s' "$input" | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)
print(data.get("tool_input", {}).get("file_path", ""))
' 2>/dev/null)" || exit 0

# Only queue Dart files.
[[ "$file_path" == *.dart ]] || exit 0

project_root="${CLAUDE_PROJECT_DIR:-$PWD}"
mkdir -p "$project_root/.claude" 2>/dev/null
printf '%s\n' "$file_path" >> "$project_root/.claude/.analyze-queue" 2>/dev/null

exit 0
