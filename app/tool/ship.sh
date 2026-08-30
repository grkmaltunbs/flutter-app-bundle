#!/usr/bin/env bash
# Rebuilds the kit app after a change and puts it where it runs:
#   Mac   → ~/Applications/kit_app.app (relaunched if it was running)
#   Phone → ~/Desktop/kit_app.apk, and installed over USB when a phone is plugged in
# Usage: bash app/tool/ship.sh [mac|android|all]   (default: all)
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WHAT="${1:-all}"
cd "$HERE"

if [ "$WHAT" = mac ] || [ "$WHAT" = all ]; then
  echo "▸ Mac: building release…"
  LOG="$(mktemp)"
  flutter build macos --release >"$LOG" 2>&1 || true
  grep -E "✓|error|Error" "$LOG" || true
  SRC="$HERE/build/macos/Build/Products/Release/kit_app.app"
  # A failed build says why: the last lines carry Gradle's or Xcode's reason.
  [ -d "$SRC" ] || { echo "Mac build failed:"; tail -25 "$LOG"; rm -f "$LOG"; exit 1; }
  rm -f "$LOG"
  DST="$HOME/Applications/kit_app.app"
  mkdir -p "$HOME/Applications"
  WAS_RUNNING=0
  if pgrep -x kit_app >/dev/null; then WAS_RUNNING=1; osascript -e 'tell application "kit_app" to quit' >/dev/null 2>&1 || true; sleep 2; fi
  rm -rf "$DST" && cp -R "$SRC" "$DST"
  echo "▸ Mac: installed $DST"
  if [ "$WAS_RUNNING" = 1 ]; then (open "$DST" || { sleep 2; open "$DST"; } || echo "▸ Mac: could not relaunch — open \"$DST\" yourself"); echo "▸ Mac: relaunched — use Reattach on the Session tab if a session was running"; else echo "▸ Mac: open it from ~/Applications (or: open \"$DST\")"; fi
fi

if [ "$WHAT" = android ] || [ "$WHAT" = all ]; then
  echo "▸ Android: building arm64 release…"
  LOG="$(mktemp)"
  flutter build apk --release --split-per-abi --target-platform android-arm64 >"$LOG" 2>&1 || true
  grep -E "✓|error|Error" "$LOG" || true
  APK="$HERE/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk"
  [ -f "$APK" ] || { echo "Android build failed:"; tail -25 "$LOG"; rm -f "$LOG"; exit 1; }
  rm -f "$LOG"
  cp "$APK" "$HOME/Desktop/kit_app.apk"
  echo "▸ Android: $HOME/Desktop/kit_app.apk ($(du -h "$APK" | cut -f1))"
  if command -v adb >/dev/null && adb devices 2>/dev/null | awk 'NR>1 && $2=="device"' | grep -q .; then
    adb install -r "$APK" && echo "▸ Android: installed on the connected phone"
  else
    echo "▸ Android: no phone on USB — send ~/Desktop/kit_app.apk to the phone and open it (same signature, installs over the old one)"
  fi
fi
