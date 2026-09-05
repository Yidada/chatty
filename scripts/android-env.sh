#!/usr/bin/env bash
# Source from any directory. All overrides are optional.
if [[ -n "${ZSH_VERSION:-}" ]]; then
  CHATTY_ENV_PATH="${(%):-%x}"
else
  CHATTY_ENV_PATH="${BASH_SOURCE[0]}"
fi
CHATTY_ROOT="$(cd "$(dirname "$CHATTY_ENV_PATH")/.." && pwd)"
export ANDROID_HOME="${ANDROID_HOME:-$CHATTY_ROOT/.tools/android-sdk}"
export ADB="${ADB:-$ANDROID_HOME/platform-tools/adb}"
if [[ ! -x "$ADB" ]]; then
  export ADB="$CHATTY_ROOT/.tools/platform-tools/adb"
fi
if [[ -z "${JAVA_HOME:-}" && -d /opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home ]]; then
  export JAVA_HOME=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home
fi
export GRADLE_USER_HOME="${GRADLE_USER_HOME:-$CHATTY_ROOT/.tools/gradle-home}"
export APPIUM_HOME="${APPIUM_HOME:-$CHATTY_ROOT/.tools/appium-home}"
export PATH="$ANDROID_HOME/platform-tools:$CHATTY_ROOT/.tools/appium/node_modules/.bin:$PATH"
