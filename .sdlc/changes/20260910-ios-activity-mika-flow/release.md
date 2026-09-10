# iOS 0.1.0 (2) 代码交付

日期：2026-09-10。

用户授权继续提交、推送并准备 TestFlight，随后选择“先完成代码提交，稍后登录”。因此本次交付范围为代码、构建号和发布准备；Apple 登录后再进行签名归档、上传与内测组验证。

## 交付内容

- iOS 动态 / Mika / 项目导航、头像设置、全工作区任务进展、已读红点和待处理。
- Mika 项目选择、顺序提交、连续发送、失败恢复与受保护队列。
- 提交前补充旧版迁移：V1 未知发送结果保存在输入框中，新版会将其迁到待核对记录并清空输入，避免旧消息混入新请求；核对后只发送用户新写的内容。
- 生成器和生成的 Xcode 工程统一为 `0.1.0 (2)`。
- 共用 `scripts/chat-fixture.py` 的 FIFO 和能力标记是 iOS 合成测试依赖，一同提交。Android 的取消/优先级测试扩展及 Android 应用代码继续保留在原工作区。
- 源码、规划、验证截图和原始记录一同进入 `main`，通过 `origin` 的 SSH 地址推送。

## 提交前检查

- Swift：42 项通过，0 失败，含旧版迁移、相同文本独立消息、回执不确定时不自动重发。
- `Chatty` Release / generic iPhone：编译通过；bundle 为 `ai.chatty.ios`，版本 `0.1.0 (2)`。
- 发布隔离：普通包无 Fixture 配置变量、合成凭据、FixtureSupport 和 ATS 例外。
- 共用测试依赖：仅从准备提交的 fixture 文件运行独立 HTTP 测试，验证 A/B/C FIFO、p1/p2/null 项目快照，以及第一页以外的他人待处理事项。
- 初次原生 UI 和 iOS 宿主测试证据继续保留于 [验证记录](evidence.md)。

本次补充结果位于 `evidence/release-0.1.0-2/`。其中 `source-sha256.json` 使用准备提交的共用 fixture 内容计算哈希，避免把工作区尚未提交的 Android 扩展算入交付。

## Apple 登录后的步骤

1. 核对 App Store Connect 当前最大构建号；如果 `2` 已使用，先更新生成器再重新构建。
2. 使用 `Chatty` scheme、Team `9247PC9936` 和版本化 archive 路径归档。
3. 在 Organizer 选择 TestFlight Internal Only 上传；测试说明使用 [已准备文案](testflight-notes.zh-Hans.txt)。
4. 等待 Apple 处理完成，加入现有 Benjamin Internal 内测组，并核对该构建可测试。

当前未创建新的签名 archive，未上传 TestFlight，也未更改内测成员或通知设置。
