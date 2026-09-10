# iOS 0.1.0 (2) TestFlight 交付

日期：2026-09-10。

代码已提交并推送到 `main`：`cb7a30a942017bab01f8ccec67b2d4332eccae1f`。用户完成 Xcode 登录后，生产构建 `0.1.0 (2)` 已于 2026-09-10 20:10（Asia/Singapore）通过 Organizer 上传 Apple，分发方式为 **TestFlight Internal Only**。

App Store Connect 网页仍需完成登录。Apple 处理结果、内测组分配和手机安装尚未核验，上传成功不代表已经可安装。

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

## 签名与上传证据

- `Chatty` / Release / generic iOS 归档成功，Team `9247PC9936`，归档路径 `.tools/ios-testflight/0.1.0-2/Chatty.xcarchive`。
- 归档版本、bundle、无 Fixture 标记和无 ATS 例外均核对通过；`codesign --verify --deep --strict` 在可访问系统证书链的环境下通过。
- CLI 导出报告 `No Accounts` 和缺少 distribution 证书；随后用已登录的 Xcode Organizer 完成上传。
- Organizer 上传完成页显示 `Chatty 0.1.0 (2) uploaded`；归档列表显示 `Uploaded to Apple`，Submission Status 为 `Today at 8:10 PM`，Build Number 为 `2`。
- [归档核对结果](evidence/release-0.1.0-2/archive-validation.json)与[上传状态记录](evidence/release-0.1.0-2/testflight-upload.json)记录了源码提交、版本与实际观察状态。

## 剩余发布步骤

1. 完成 App Store Connect 网页登录并检查构建 `2` 的处理状态。
2. 保存[中文测试说明](testflight-notes.zh-Hans.txt)。
3. 将构建加入现有 Benjamin Internal 内测组，核对可测试状态。
4. 手机安装与真实账号体验独立验证。

目前未更改内测成员或通知设置。
