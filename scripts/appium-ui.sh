#!/usr/bin/env bash
# appium-ui.sh - Verify UI state against a live Appium session (UIAutomator2).
# Usage: appium-ui.sh [textToFind] [textToTap] [tapWaitSeconds]
#   textToFind:  element text that must be present (default: none - blank checks)
#   textToTap:   element text to tap (default: none - skip tap)
# Requires: Appium server on 127.0.0.1:4723 (start with ANDROID_HOME set).
set -euo pipefail

ADB="${ADB:-$HOME/android-sdk/platform-tools/adb}"
APPIUM_URL="${APPIUM_URL:-http://127.0.0.1:4723}"
PKG="com.chatty.smoke"
ACT=".MainActivity"
FIND="${1:-}"
TAP="${2:-}"
WAIT="${3:-1}"

SID=$(curl -s -X POST "$APPIUM_URL/session" -H 'Content-Type: application/json' -d "{
  \"capabilities\":{\"alwaysMatch\":{
    \"platformName\":\"Android\",
    \"appium:automationName\":\"UiAutomator2\",
    \"appium:appPackage\":\"$PKG\",
    \"appium:appActivity\":\"$ACT\",
    \"appium:newCommandTimeout\":120,
    \"appium:noReset\":true
  }}}" | python3 -c 'import sys,json; print(json.load(sys.stdin)["value"]["sessionId"])')
trap 'curl -s -X DELETE "$APPIUM_URL/session/$SID" > /dev/null' EXIT
echo "session: $SID"

if [ -n "$FIND" ]; then
  set +e
  for i in $(seq 1 10); do
    if curl -s "$APPIUM_URL/session/$SID/source" | grep -q "$FIND"; then
      echo "PASS: found '$FIND'"
      break
    fi
    sleep 1
  done
  set -e
  [ "$i" -lt 10 ] || { echo "FAIL: '$FIND' not visible"; exit 1; }
fi

if [ -n "$TAP" ]; then
  set +e
  for i in $(seq 1 5); do
    T=$(curl -s -X POST "$APPIUM_URL/session/$SID/element" -H 'Content-Type: application/json' \
      -d "{\"using\":\"xpath\",\"value\":\"//*[@text='$TAP']\"}")
    if echo "$T" | grep -q "element-6066-11e4-a52e-4f735466cecf"; then
      break
    fi
    sleep 1
  done
  set -e
  EID=$(echo "$T" | python3 -c 'import sys,json; print(json.load(sys.stdin)["value"]["element-6066-11e4-a52e-4f735466cecf"])')
  curl -s -X POST "$APPIUM_URL/session/$SID/element/$EID/click" > /dev/null
  echo "PASS: tapped '$TAP'"
  sleep "$WAIT"
fi

mkdir -p /tmp/opencode
curl -s "$APPIUM_URL/session/$SID/screenshot" | python3 -c 'import sys,json,base64; open("/tmp/opencode/ui-latest.png","wb").write(base64.b64decode(json.load(sys.stdin)["value"]))' || true
echo "DONE"
