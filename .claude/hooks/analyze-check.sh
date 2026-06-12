#!/bin/bash
# Stop/SubagentStop hook — the checking half of the analyze gate.
# The per-edit hook (analyze-queue.sh) only collects edited .dart paths;
# this script runs ONE batched `dart analyze` per turn and blocks only
# on ERRORs in files edited this turn — warnings never block. Errors
# from pending codegen (@freezed/@injectable parts not generated yet)
# surface once here, at turn end, when running build_runner once is the
# correct batched response.

set -u

project_root="${CLAUDE_PROJECT_DIR:-$PWD}"
queue="$project_root/.claude/.analyze-queue"

# Nothing to check: no queued edits, not a Dart project, or no analyzer.
[[ -s "$queue" ]] || exit 0
[[ -f "$project_root/pubspec.yaml" ]] || exit 0
command -v dart >/dev/null 2>&1 || exit 0

# Dedupe the queue, keep only paths that still exist, and canonicalize
# them (the analyzer reports symlink-resolved paths, e.g. /private/tmp).
files="$(sort -u "$queue" | python3 -c '
import os, sys
for line in sys.stdin:
    p = line.rstrip("\n")
    if p and os.path.isfile(p):
        print(os.path.realpath(p))
' 2>/dev/null)"
if [[ -z "$files" ]]; then
  : > "$queue"
  exit 0
fi

# One analyzer run for the whole project. Machine format is
# pipe-separated: SEVERITY|TYPE|CODE|FILE|LINE|COL|LENGTH|MESSAGE.
output="$(dart analyze --format=machine "$project_root" 2>&1)"

# Keep only ERROR lines whose file is in the queued set.
# (Queued paths go through a temp file: BSD awk rejects newlines in -v.)
tmp_files="$(mktemp)"
printf '%s\n' "$files" > "$tmp_files"
errors="$(printf '%s\n' "$output" | awk -F'|' '
NR == FNR { queued[$0] = 1; next }
$1 == "ERROR" && ($4 in queued)
' "$tmp_files" -)"
rm -f "$tmp_files"

if [[ -n "$errors" ]]; then
  printf '%s\n' "$errors" >&2
  printf 'errors in files edited this turn — fix them (run build_runner first if generated parts are missing)\n' >&2
  exit 2
fi

: > "$queue"
exit 0
