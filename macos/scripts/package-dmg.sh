#!/bin/bash
# Package an already-built, signed app. Preserves a stapled notarization ticket.
set -euo pipefail
macos_root="$(cd "$(dirname "$0")/.." && pwd)"
repo_root="$(cd "$macos_root/.." && pwd)"
app_path="${1:-$repo_root/.tools/macos-chatty/Chatty-0.1.0.xcarchive/Products/Applications/Chatty.app}"
: "${CHATTY_SIGN_IDENTITY:?Set your Developer ID signing identity locally}"
identity="$CHATTY_SIGN_IDENTITY"
test -d "$app_path/Contents"
codesign --verify --deep --strict "$app_path"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app_path/Contents/Info.plist")"
build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$app_path/Contents/Info.plist")"
mkdir -p "$macos_root/dist"
stage_dir="$(mktemp -d "${TMPDIR:-/tmp}/chatty-dmg.XXXXXX")"
trap 'rm -rf "$stage_dir"' EXIT
ditto "$app_path" "$stage_dir/Chatty.app"
ln -s /Applications "$stage_dir/Applications"
if xcrun stapler validate "$stage_dir/Chatty.app" >/dev/null 2>&1; then
  notarization='已通过 Apple 公证，并附带离线公证票据。'
else
  notarization='此本地验收包尚未附带 Apple 公证票据。Gatekeeper 可能阻止打开；请联系发布者提供公证版本，不要关闭系统安全保护。'
fi
cat > "$stage_dir/安装说明.txt" <<TEXT
Chatty for Mac $version ($build)

1. 将 Chatty.app 拖入 Applications。
2. 从“应用程序”打开 Chatty。
3. 使用 Multica 邮箱验证码登录，选择工作区。

系统要求：macOS 15 或更新版本。支持 Apple Silicon 与 Intel。
$notarization

快捷键：⌘1 动态，⌘2 Mika，⌘3 项目，⌘, 设置，⌘Return 发送。
动态中的红点是应用内提示。未发送队列在重新打开应用后需要“继续发送”。

验收：检查其他成员任务、连续三条消息及项目选择、设置返回后的草稿、附件预览。
TEXT
image_path="$macos_root/dist/Chatty-$version-universal.dmg"
if test -e "$image_path"; then
  echo "Refusing to overwrite existing DMG: $image_path" >&2
  exit 1
fi
hdiutil create -volname "Chatty $version" -srcfolder "$stage_dir" -format UDZO -ov "$image_path"
codesign --timestamp --sign "$identity" "$image_path"
codesign --verify --strict "$image_path"
hdiutil verify "$image_path"
(cd "$macos_root/dist" && shasum -a 256 "$(basename "$image_path")" > SHA256SUMS.txt)
echo "$image_path"
