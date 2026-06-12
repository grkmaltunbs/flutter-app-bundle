#!/bin/bash
# PostToolUse hook (matcher: Write|Edit) — enforces the bundle's
# "analyze must stay clean" rule deterministically: every time Claude
# writes or edits a .dart file, the file is immediately checked with
# `dart analyze`. On analysis errors the hook prints them to stderr and
# exits 2, which blocks the result and feeds the errors back to Claude
# so they get fixed right away instead of piling up.
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

# Only act on Dart files that actually exist on disk.
[[ "$file_path" == *.dart ]] || exit 0
[[ -f "$file_path" ]] || exit 0

# Only act inside a Dart/Flutter project (pubspec.yaml at the project root).
project_root="${CLAUDE_PROJECT_DIR:-$PWD}"
[[ -f "$project_root/pubspec.yaml" ]] || exit 0

# Only act when the dart CLI is on PATH.
command -v dart >/dev/null 2>&1 || exit 0

output="$(dart analyze "$file_path" 2>&1)"
status=$?

if [[ $status -ne 0 ]]; then
  printf '%s\n' "$output" >&2
  printf 'dart analyze reported issues in %s — fix them before continuing.\n' "$file_path" >&2
  exit 2
fi

exit 0
