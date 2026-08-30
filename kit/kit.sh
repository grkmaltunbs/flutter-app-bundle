#!/usr/bin/env bash
# `kit` — runs the plan CLI against the current project.
#
# Compiles bin/kit.dart to a native binary on first use (and again whenever a
# source file is newer than the binary), so a command costs milliseconds
# instead of a Dart VM start. The binary lives in kit/.build/, which is
# gitignored. Falls back to `dart run` if compilation fails.
#
# Usage from a command: bash "${CLAUDE_PLUGIN_ROOT}/kit/kit.sh" next
set -euo pipefail

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${KIT_PROJECT_DIR:-$PWD}"
BIN="$KIT_DIR/.build/kit"

# `kit hook` fires on every tool call, in every project the plugin is installed
# in — including ones with no Flutter SDK on PATH. A hook that exits non-zero
# puts its stderr in front of the model, so the hook path stays silent.
if ! command -v dart >/dev/null 2>&1; then
  if [ "${1:-}" = hook ]; then exit 0; fi
  echo "kit: dart is not on PATH (it ships with the Flutter SDK)" >&2
  exit 2
fi

needs_build=0
if [ ! -x "$BIN" ]; then
  needs_build=1
else
  # Rebuild if any source is newer than the binary.
  if [ -n "$(find "$KIT_DIR/bin" "$KIT_DIR/lib" "$KIT_DIR/pubspec.yaml" -newer "$BIN" -print -quit 2>/dev/null)" ]; then
    needs_build=1
  fi
fi

if [ "$needs_build" = 1 ]; then
  mkdir -p "$KIT_DIR/.build"
  if [ ! -d "$KIT_DIR/.dart_tool" ]; then
    (cd "$KIT_DIR" && dart pub get >/dev/null)
  fi
  # Compile to a temp name and rename: hooks fire in parallel (a subagent's
  # tool call and the main session's), and two writers sharing one output path
  # would leave a half-written binary for the next one to exec.
  tmp="$BIN.$$"
  if (cd "$KIT_DIR" && dart compile exe bin/kit.dart -o "$tmp" >/dev/null 2>&1); then
    mv -f "$tmp" "$BIN"
  else
    rm -f "$tmp"
    # Compilation is an optimisation; never let it block a command.
    exec dart run "$KIT_DIR/bin/kit.dart" --project "$PROJECT_DIR" "$@"
  fi
fi

exec "$BIN" --project "$PROJECT_DIR" "$@"
