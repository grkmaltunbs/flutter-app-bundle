#!/usr/bin/env bash
# Rebuilds the kit app after a change and puts it where it runs:
#   Mac   → ~/Applications/kit_app.app (relaunched if it was running)
#   Phone → ~/Desktop/kit_app.apk, and installed over USB when a phone is plugged in
# Usage: bash app/tool/ship.sh [mac|android|ios|ios-sim|all] [device-id]   (default: all)
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WHAT="${1:-all}"
cd "$HERE"
case "$WHAT" in
  mac|android|ios|ios-sim|all) ;;
  *) echo "Usage: bash app/tool/ship.sh [mac|android|ios|ios-sim|all] [device-id]" >&2; exit 2 ;;
esac

# iOS is explicit: `all` preserves the Mac + Android workflow. Never pick an
# arbitrary paired phone or simulator when several are available.
if [ "$WHAT" = ios ] || [ "$WHAT" = ios-sim ]; then
  DEVICES="$(mktemp)"
  flutter devices --machine >"$DEVICES"
  IOS_DEVICE="$(python3 - "$DEVICES" "$WHAT" "${2:-${IOS_DEVICE_ID:-}}" <<'PYDEVICE'
import json, sys
rows = json.load(open(sys.argv[1]))
simulator = sys.argv[2] == 'ios-sim'
requested = sys.argv[3]
rows = [r for r in rows if r.get('targetPlatform') == 'ios' and bool(r.get('emulator')) == simulator and r.get('isSupported', True)]
if requested:
    rows = [r for r in rows if r['id'] == requested]
if len(rows) != 1:
    print('Select one available iOS ' + ('simulator' if simulator else 'device') + ' by passing its ID from flutter devices (boot the simulator first).', file=sys.stderr)
    for r in rows:
        print(r['id'] + '  ' + r['name'], file=sys.stderr)
    sys.exit(2)
print(rows[0]['id'])
PYDEVICE
)" || { rm -f "$DEVICES"; exit 2; }
  rm -f "$DEVICES"
  if [ "$WHAT" = ios-sim ]; then
    echo "▸ iPhone simulator: building debug…"
    flutter build ios --simulator --debug
    xcrun simctl install "$IOS_DEVICE" "$HERE/build/ios/iphonesimulator/Runner.app"
    xcrun simctl launch "$IOS_DEVICE" dev.flutterkit.kitApp
    open -a Simulator
  else
    echo "▸ iPhone: building signed release…"
    flutter build ios --release
    flutter install --release -d "$IOS_DEVICE"
  fi
fi

if [ "$WHAT" = mac ] || [ "$WHAT" = all ]; then
  echo "▸ Mac: building release…"
  # A failed build must not ship the last good one.
  rm -rf "$HERE/build/macos/Build/Products/Release/kit_app.app"
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
  if pgrep -x kit_app >/dev/null; then
    WAS_RUNNING=1
    osascript -e 'tell application "kit_app" to quit' >/dev/null 2>&1 || true
    # The app says goodbye to the relay before it goes; an `open` while it
    # is still quitting lands on the dying instance and nothing relaunches.
    for _ in $(seq 1 40); do pgrep -x kit_app >/dev/null || break; sleep 0.5; done
    pgrep -x kit_app >/dev/null && { echo "▸ Mac: the running app would not quit — closing it"; pkill -x kit_app || true; sleep 1; }
  fi
  rm -rf "$DST" && cp -R "$SRC" "$DST"
  echo "▸ Mac: installed $DST"
  if [ "$WAS_RUNNING" = 1 ]; then (open "$DST" || { sleep 2; open "$DST"; } || echo "▸ Mac: could not relaunch — open \"$DST\" yourself"); echo "▸ Mac: relaunched — use Reattach on the Session tab if a session was running"; else echo "▸ Mac: open it from ~/Applications (or: open \"$DST\")"; fi
fi

if [ "$WHAT" = android ] || [ "$WHAT" = all ]; then
  echo "▸ Android: building arm64 release…"
  rm -f "$HERE/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk"
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
