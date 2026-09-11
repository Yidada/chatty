#!/bin/bash
set -euo pipefail
macos_root="$(cd "$(dirname "$0")/.." && pwd)"
repo_root="$(cd "$macos_root/.." && pwd)"
: "${CHATTY_DEVELOPMENT_TEAM:?Set your Apple Developer team ID locally}"
: "${CHATTY_SIGN_IDENTITY:?Set your Developer ID signing identity locally}"
python3 "$macos_root/scripts/generate-project.py"
xcodebuild -project "$macos_root/Chatty.xcodeproj" -scheme Chatty -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$repo_root/.tools/macos-chatty/release-derived" \
  -archivePath "$repo_root/.tools/macos-chatty/Chatty-0.1.0.xcarchive" \
  ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO DEVELOPMENT_TEAM="$CHATTY_DEVELOPMENT_TEAM" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$CHATTY_SIGN_IDENTITY" archive
