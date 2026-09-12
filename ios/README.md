# Chatty iOS

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
| 动态 | 全工作区事项的新进展 / 待处理、包含其他发起人、独立分页、按事项版本保存已读、应用内红点；两个列表支持多选 / 全选当前已加载页 / 退出，可批量已读，待处理页可批量验收完成或退回待办（`POST /api/issues/batch-update`），结果按成功 / 未生效 / 失败如实反馈并可按批重试；每一行还支持左滑 / 右滑逐行操作（新进展：标记已读 / 标为未读，只写本机指纹；待处理：验收完成 / 退回待办），动作定义与批量、VoiceOver 自定义动作及指针右键菜单共用一套，选择态下自动禁用 |
| 对话 | 项目选择、连续发送、文本/附件/项目快照、本机顺序提交与服务端队列、回执核对、双游标历史 |
| 实时与离线 | 前台 WebSocket auth 首帧、退避重连、REST 恢复、后台停止连接、跨工作区隔离、冷启动离线草稿 |
| 内容 | Markdown 标题/表格/引用/嵌套列表/任务列表/代码/链接、task_id 过程、失败说明、建议填草稿 |
| 附件 | 系统照片与文件选择、20 MB 限制、绑定回执校验、过期签名 URL 刷新、图片缩放、Quick Look、保存/分享 |
| 项目 | 全部发起人的事项、搜索/自定义状态/无项目筛选、50 条分页、精简详情、折叠目标与记录、revision + suppress_run 验收/状态修改 |
| 头像 → 设置 | 工作区 Sheet、Runtimes/Agents/Squads 原生列表与详情、退出清理 |

- `Chatty` / `ai.chatty.ios`：普通应用，不编译 `ios/Fixture`，不链接 `ChattyFixtureSupport`，无 ATS 例外。
- `ChattyFixture` / `ai.chatty.ios.fixture`：独立 bundle、Keychain service、受保护目录；允许本机测试网络。仅测试包开放 Documents 文件共享，便于通过系统 Files 选择合成样本；Library 内的受保护数据不在此目录。
- `ChattyCore`：DTO、APIClient、作用域/业务模型、受保护存储、Markdown AST。界面在 `ios/Chatty`。
- `scripts/generate-ios-project.py`：确定性生成 project、Info.plist 与共享 scheme。新增宿主 Swift 文件后运行；生成器是配置来源。
- `--p0-preview` 保留历史 P0 测试壳。`tests/device/ios/p0-navigation.ad` 和 `v1-*.ad` 对应旧导航；三页导航与动态批量处理的交互证据见 `v2-activity-batch*.ad`，动态逐行滑动操作见 `v2-activity-row-swipe.ad`，两者都对应 `.sdlc/changes/` 的记录。
- 动态页的行滑动依赖系统 `List` 行（`swipeActions` 在 `ScrollView` 行上不生效），因此两个列表用 `List` + `.listRowInsets` 承载原有行样式；空态 / 错误 / 加载提示在 `List` 之外，避免在列表行里塌陷。

Token 只保存在 Keychain。草稿与待发送消息共同保存在一个受保护、排除备份的原子记录中；每条待发送消息保留其文本、附件元数据和项目。动态已读指纹按账号/工作区隔离，退出清理。离线恢复元数据只保存账号/工作区/Agent 标识和凭据哈希，不保存 token。离线页不授予发送权限。服务端历史消息、项目和动态列表只在内存。临时附件 1 小时过期，关闭预览和退出时清理。外域下载不附加 Bearer 或工作区头；HTTP 重定向拒绝。HTML、SVG、Mermaid 等主动内容按文本阅读。任务过程中的常见凭据在呈现前隐藏。

发送会立即清空输入框。服务端支持队列时继续提交下一条；不支持时留在本机等待。冷启动或回到后台保留的队列需明确继续。超时/异常回执停止自动提交，核对后可确认已收到或明确重试；后者可能在原请求迟到时重复执行。每条 POST 前串行确认会话项目；后端目前没有逐条消息的原子项目参数，多端同时修改同一个会话项目的竞争仍需服务端后续支持。

V1 范围不包含 APNs、语音转写、审批、其他 Agent 对话或远程 Runtime 控制。物理设备文件保护、VoiceOver 人工体验及真实账号业务闭环仍需对应验收，不能由合成服务测试替代。

## 验证

```sh
swift test --package-path ios/Packages/ChattyKit --scratch-path .tools/ios-swift-build
source scripts/ios-env.sh
xcodebuild -project ios/Chatty.xcodeproj -scheme ChattyFixture -configuration Debug \
  -destination "platform=iOS Simulator,id=$IOS_SIMULATOR_ID" \
  -derivedDataPath "$CHATTY_IOS_DERIVED_DATA" CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test
```

XCTest 与 UI 交互串行运行。当前核心回归有 72 项 Swift 测试，另有 iOS 宿主 XCTest 和 agent-device 原生交互证据。需求与实现见 [iOS 动态与 Mika 连续发送](../.sdlc/changes/20260910-ios-activity-mika-flow/evidence.md)，提交前的升级迁移检查见 [交付记录](../.sdlc/changes/20260910-ios-activity-mika-flow/release.md)。动态页批量处理（多选 / 批量已读 / 批量验收与退回）见 [iOS 动态批量处理](../.sdlc/changes/20260910-ios-activity-batch-actions/evidence.md)，逐行左滑 / 右滑动作见 [iOS 动态逐行滑动操作](../.sdlc/changes/20260911-ios-activity-row-swipe/evidence.md)。

以下为历史 V1 导航回放，保留用于追溯；其中设置 Tab、详情和计数选择器基于旧界面，不作为新版的验收命令。回放使用全新的测试服务，状态修改和消息计数有意保留到服务进程结束。

```sh
scripts/ios-v1-replay.sh
```

如果已结束的交互驱动仍占用设备，先 `agent-device session list` 确认没有活动会话，再 `agent-device daemon stop --clean`。套件会在没有活动交互会话时自动释放闲置运行器。原生 `.ad` 弹窗步骤使用 `wait stable`，不把 CLI 的 `--settle` 写入回放文件。回放保存了稳定语义选择器；录制器生成的动态 UIKit 层级不作为产品身份断言。

在 8765 端口空闲时，`python3 scripts/ios-check-redirect.py` 用真实本机 302 服务同时验证正式 `APIClient` 和历史 `FixtureClient`，要求重定向目标收到 0 次请求。不会停止他人占用的服务。

合成审计：`http://127.0.0.1:8765/__calls`，包含每个作用域的消息写入、逐条 Issue 状态写入（`issue_writes`）、批量写入（`batch_writes`）、逐条项目快照、上传元数据及 Socket 开关记录。`/__control` 可设置 `status`、`disconnect`、`send_mode`、`issue_conflict`、`catalog_status`、`deny_mika`；新增 `activity_scenario:true` 生成跨发起人和旧待处理事项，`send_mode:delayed` + `receipt_delay:20` 延迟回执，`bump_issue:i0` 模拟新进展。批量处理用 `batch_skip:["i0"]` 让服务端静默跳过指定事项（与真实 handler 的 `continue` 一致），`batch_status` 让整批返回错误码。通过 `X-Workspace-Slug` 和合成 token 指定作用域。测试服务与 Fixture 应用同时设置 `CHATTY_FIXTURE_PORT=8767` 可避开占用的 8765 端口；普通应用不读取此变量。写请求不会自动重试。

验收结果见 [进度](../.sdlc/changes/20260905-complete-ios-v1-native-client-p1-through-p5/progress.md)、[截图报告](../.sdlc/changes/20260905-complete-ios-v1-native-client-p1-through-p5/progress.html) 和 `.sdlc/changes/20260905-complete-ios-v1-native-client-p1-through-p5/`。本机构建和原始日志位于 `.tools/ios-v1/full-run/`。
