#!/usr/bin/env bash
# dev-loop.sh - Install & launch an APK on a connected Android device/emulator.
# Usage: dev-loop.sh <app-debug.apk> <package> <activity> [activityExtraArgs...]
# Exit 0 on healthy launch; exit non-zero and prints logcat errors on failure.
set -euo pipefail

ADB="${ADB:-$HOME/android-sdk/platform-tools/adb}"

APK="${1:?usage: dev-loop.sh <apk> <package> <activity>}"
PKG="${2:?usage: dev-loop.sh <apk> <package> <activity>}"
ACT="${3:?usage: dev-loop.sh <apk> <package> <activity>}"

"$ADB" wait-for-device
"$ADB" install -r "$APK"
"$ADB" shell am force-stop "$PKG" || true
"$ADB" shell am start -n "$PKG/$ACT"

sleep 3
FOCUS=$("$ADB" shell dumpsys window 2>/dev/null | grep -m1 mCurrentFocus || true)
echo "focus: $FOCUS"

CRASH=$("$ADB" logcat -d -t 200 2>/dev/null | grep -E "FATAL EXCEPTION|AndroidRuntime.*$PKG" | tail -3 || true)
if [ -n "$CRASH" ]; then
  echo "CRASH detected:"
  echo "$CRASH"
  exit 1
fi
if [ -n "$FOCUS" ] && ! echo "$FOCUS" | grep -q "$PKG"; then
  echo "WARNING: app not in foreground: $FOCUS"
fi
echo "OK: $PKG healthy"
