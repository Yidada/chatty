# Chatty for Mac

四端发布与公证导出步骤见[统一发布流程](../docs/releases/README.md)。最新跨端交付状态见[0.2.0 发布记录](../docs/releases/0.2.0.json)。

原生 SwiftUI + AppKit 客户端，macOS 15+，支持 Apple Silicon 与 Intel。共享业务核心位于 `../ios/Packages/ChattyKit`，Mac 界面与构建独立放在本目录。

## 安装与验收

交付：[`dist/Chatty-0.1.0-universal.dmg`](dist/Chatty-0.1.0-universal.dmg)，版本 0.1.0 (1)。将 Chatty.app 拖入 Applications，打开后使用 Multica 邮箱验证码登录、选择工作区。

- Developer ID：[private signing identity]。应用已通过 Apple 公证并附带离线票据；DMG 已签名。
- 已验证镜像校验、挂载、复制安装、Gatekeeper 与正式应用启动。
- SHA-256 见 [`dist/SHA256SUMS.txt`](dist/SHA256SUMS.txt)。构建产物不纳入 Git。
- 首次登录独立于 iOS/Android；Mac 凭据、草稿、已读状态属于 `ai.chatty.macos`。
- 优先验收：动态中的其他成员任务与红点；Mika 项目选择和连续发送；设置返回及重开后的草稿；项目搜索和附件预览。
- 快捷键：⌘1 动态、⌘2 Mika、⌘3 项目、⌘, 设置、⌘Return 发送。Return 换行。
- 动态通知为应用内提示。冷启动未发送队列需要确认继续；未知回执需要先核对。

## 开发与打包

在仓库根目录运行：

```sh
python3 macos/scripts/generate-project.py
xcodebuild -project macos/Chatty.xcodeproj -scheme Chatty -configuration Debug -destination 'platform=macOS' -derivedDataPath .tools/macos-chatty/derived build
swift test --package-path ios/Packages/ChattyKit --scratch-path .tools/macos-chatty/swift-tests
bash macos/scripts/build.sh
```

归档默认输出 `.tools/macos-chatty/Chatty-0.1.0.xcarchive`。需要本机 Developer ID 证书及私钥；运行签名脚本前需在本地设置 `CHATTY_SIGN_IDENTITY` 和 `CHATTY_DEVELOPMENT_TEAM`，不要将个人证书身份写入仓库。版本号在工程生成器中维护；发布新版时同步归档文件名。

在 Xcode Organizer 打开归档，选择 Distribute App → Direct Distribution，等待 Ready to distribute，然后 Export Notarized App。导出到 `.tools/macos-chatty/Chatty.app` 后运行：

```sh
xcrun stapler validate .tools/macos-chatty/Chatty.app
bash macos/scripts/package-dmg.sh .tools/macos-chatty/Chatty.app
```

脚本拒绝覆盖已有同名 DMG。重新发布前保留旧产物并更新版本。直接传未公证归档会生成带明确限制说明的本地包；对外交付应使用公证后的导出应用。

## 合成验证

`ChattyFixture` scheme 使用独立 bundle `ai.chatty.macos.fixture`，默认连接 localhost:8767。启动 `scripts/ios-fixture.py` 时设置 `CHATTY_FIXTURE_PORT=8767`；测试验证码为 123456。正式 target 不包含 Fixture 配置和合成登录入口。

本轮为避免影响并行 Android 工作，使用 HEAD 中的 fixture 脚本副本，位于 `.tools/macos-chatty/fixture-server/`。测试证明 20 秒回执期间可排队、编辑；6 条发送顺序及项目快照准确。共享核心 43 项测试、Mac Debug/Fixture/Universal Release 和 iOS Simulator 编译通过。

真实账号端到端、Intel 实机、文件上传选择器及所有错误分支尚未完成桌面实测。完整边界见 [验收证据](../.sdlc/changes/20260911-macos-native-chatty-and-dmg-acceptance/evidence.md)。

## SDLC

[规格](../.sdlc/changes/20260911-macos-native-chatty-and-dmg-acceptance/spec.md) · [批准的计划](../.sdlc/changes/20260911-macos-native-chatty-and-dmg-acceptance/plan.md) · [风险](../.sdlc/changes/20260911-macos-native-chatty-and-dmg-acceptance/risk.md) · [回退](../.sdlc/changes/20260911-macos-native-chatty-and-dmg-acceptance/rollback.md)
