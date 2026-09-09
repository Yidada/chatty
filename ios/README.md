# Chatty iOS V1

SwiftUI 原生 iPhone 客户端，iOS 26+ / Swift 6。普通应用连接 `https://api.multica.ai/`，已实现验证码登录、Mika 对话、附件、项目与协作资源。

## 运行

要求 Xcode 26+、iOS 26+ Simulator、Python 3。设备流程使用 `agent-device 0.20.10`。首次 SwiftPM 解析通过 SSH 获取锁定的 `swift-markdown 0.8.0`。

```sh
# 普通应用：使用自己的 Multica 邮箱登录
scripts/ios-dev-loop.sh app

# 合成测试：分别在两个终端运行
python3 scripts/ios-fixture.py
scripts/ios-dev-loop.sh fixture
```

合成测试邮箱可用 `ios@example.test`，验证码 `123456`。含 `other` 的邮箱进入第二个合成账号。每个账号各有两个独立工作区。测试服务只监听 Mac loopback，不接触 Multica 生产数据。

打开 `ios/Chatty.xcodeproj`，选择 `Chatty` 或 `ChattyFixture` scheme。固定模拟器可先设置 `IOS_SIMULATOR_ID`。需要连接物理 iPhone 时，选择自己的 Apple Development Team 和目标设备，再运行普通 `Chatty`；TestFlight 发布操作与证据见 [TESTFLIGHT.md](TESTFLIGHT.md)。

模拟器构建使用本地 ad-hoc 签名 `CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=-`，使 Keychain 在宿主应用里可用。`CODE_SIGNING_ALLOWED=NO` 仅用于不安装的通用 iPhone 编译检查。

## 实现与边界

| 入口 | 已实现行为 |
|---|---|
| 登录 | 邮箱验证码、Keychain ThisDeviceOnly、账号恢复、工作区选择、401 清理、503 保留凭据 |
| 对话 | 按 `system_key=mika` 和权限定位、最近有效会话、首次发送建会话、单次提交、回执核对、双游标历史 |
| 实时与离线 | 前台 WebSocket auth 首帧、退避重连、REST 恢复、后台停止连接、跨工作区隔离、冷启动离线草稿 |
| 内容 | Markdown 标题/表格/引用/嵌套列表/任务列表/代码/链接、task_id 过程、失败说明、建议填草稿 |
| 附件 | 系统照片与文件选择、20 MB 限制、绑定回执校验、过期签名 URL 刷新、图片缩放、Quick Look、保存/分享 |
| 项目 | 服务端总计、搜索/自定义状态/无项目筛选、50 条分页、详情、revision + suppress_run 状态修改 |
| 设置 | 工作区 Sheet、Runtimes/Agents/Squads 原生列表与详情、退出清理 |

- `Chatty` / `ai.chatty.ios`：普通应用，不编译 `ios/Fixture`，不链接 `ChattyFixtureSupport`，无 ATS 例外。
- `ChattyFixture` / `ai.chatty.ios.fixture`：独立 bundle、Keychain service、受保护目录；允许本机测试网络。仅测试包开放 Documents 文件共享，便于通过系统 Files 选择合成样本；Library 内的受保护数据不在此目录。
- `ChattyCore`：DTO、APIClient、作用域/业务模型、受保护存储、Markdown AST。界面在 `ios/Chatty`。
- `scripts/generate-ios-project.py`：确定性生成 project、Info.plist 与共享 scheme。新增宿主 Swift 文件后运行；生成器是配置来源。
- `--p0-preview` 保留历史 P0 测试壳；`flows/p0-navigation.ad` 是当时的证据，当前完整回归使用 `flows/v1-{core,resources,workspaces}.ad`。

Token 只保存在 Keychain。草稿、待确认标记和最近作用域保存在受保护、排除备份的目录；离线恢复元数据只保存账号/工作区/Agent 标识和凭据哈希，不保存 token。离线页不授予发送权限。消息与项目只在内存。临时附件 1 小时过期，关闭预览和退出时清理。外域下载不附加 Bearer 或工作区头；HTTP 重定向拒绝。HTML、SVG、Mermaid 等主动内容按文本阅读。任务过程中的常见凭据在呈现前隐藏。

V1 范围不包含 APNs、语音转写、审批、其他 Agent 对话或远程 Runtime 控制。物理设备文件保护、VoiceOver 人工体验及真实账号业务闭环仍需对应验收，不能由合成服务测试替代。

## 验证

```sh
swift test --package-path ios/Packages/ChattyKit --scratch-path .tools/ios-swift-build
source scripts/ios-env.sh
xcodebuild -project ios/Chatty.xcodeproj -scheme ChattyFixture -configuration Debug \
  -destination "platform=iOS Simulator,id=$IOS_SIMULATOR_ID" \
  -derivedDataPath "$CHATTY_IOS_DERIVED_DATA" CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test
```

XCTest 与 agent-device 串行运行。执行回放前确认测试应用已退出登录，并启动全新的 `scripts/ios-fixture.py`（状态修改和消息计数有意保留到服务进程结束）。

```sh
scripts/ios-v1-replay.sh
```

如果已结束的交互驱动仍占用设备，先 `agent-device session list` 确认没有活动会话，再 `agent-device daemon stop --clean`。套件会在没有活动交互会话时自动释放闲置运行器。原生 `.ad` 弹窗步骤使用 `wait stable`，不把 CLI 的 `--settle` 写入回放文件。回放保存了稳定语义选择器；录制器生成的动态 UIKit 层级不作为产品身份断言。

在 8765 端口空闲时，`python3 scripts/ios-check-redirect.py` 用真实本机 302 服务同时验证正式 `APIClient` 和历史 `FixtureClient`，要求重定向目标收到 0 次请求。不会停止他人占用的服务。

合成审计：`http://127.0.0.1:8765/__calls`，包含每个作用域的消息/Issue 写入、上传元数据及 Socket 开关记录。`/__control` 可设置 `status`、`disconnect`、`send_mode`、`issue_conflict`、`catalog_status`、`deny_mika`；通过 `X-Workspace-Slug` 和合成 token 指定作用域。写请求不会自动重试。

验收结果见 [进度](../iterations/ios-v1/progress.md)、[截图报告](../iterations/ios-v1/progress.html) 和 `.sdlc/changes/20260905-complete-ios-v1-native-client-p1-through-p5/`。本机构建和原始日志位于 `.tools/ios-v1/full-run/`。
