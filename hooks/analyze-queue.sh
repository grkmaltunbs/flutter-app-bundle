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

# Extract the edited paths from the JSON payload: tool_input.file_path for
# Claude's Write/Edit; for Codex's apply_patch the paths named in the patch
# text ("*** Update File: path", "*** Add File: path").
paths="$(printf '%s' "$input" | python3 -c '
import json, re, sys
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)
ti = data.get("tool_input", {}) or {}
out = []
if isinstance(ti, dict):
    fp = ti.get("file_path", "")
    if fp:
        out.append(fp)
    for v in ti.values():
        if isinstance(v, str) and "*** " in v:
            out += re.findall(r"^\*\*\* (?:Update|Add) File: (.+)$", v, re.M)
elif isinstance(ti, str):
    out += re.findall(r"^\*\*\* (?:Update|Add) File: (.+)$", ti, re.M)
for p in out:
    print(p.strip())
' 2>/dev/null)" || exit 0

[[ -n "$paths" ]] || exit 0

project_root="${CLAUDE_PROJECT_DIR:-$PWD}"
mkdir -p "$project_root/.claude" 2>/dev/null
while IFS= read -r file_path; do
  # Only queue Dart files; a relative path in a patch is relative to the project.
  [[ "$file_path" == *.dart ]] || continue
  [[ "$file_path" == /* ]] || file_path="$project_root/$file_path"
  printf '%s\n' "$file_path" >> "$project_root/.claude/.analyze-queue" 2>/dev/null
done <<< "$paths"

exit 0
