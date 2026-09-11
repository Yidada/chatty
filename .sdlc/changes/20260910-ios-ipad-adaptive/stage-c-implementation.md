# Stage C 实现与验证记录（CLE-91）

- 父任务：CLE-88「Chatty iOS：iPad / iPadOS 自适应实现」阶段 C「多窗口与场景恢复」。
- 设计依据：[spec.md](spec.md) §6.4 多任务与多窗口、§7 R3/R5；CLE-84 已确认的第 3 项「多窗口纳入首版，但独立为阶段 C，先技术验证再默认开启」。
- 起点：`main` `7a71575`（Stage A 已合入）。
- 环境：Xcode 26.6 (17F113)、iOS 26.5 SDK、iPad Pro 13-inch (M5) 模拟器（1032 × 1376 pt）、iPhone SE (3rd generation) 模拟器（375 × 667 pt，当前可用最窄档）、`scripts/ios-fixture.py` 合成服务（loopback `127.0.0.1:8767`）。

本文件只记录**已实测**的结果；未执行的项在 §7 明确列出。

## 1. 结论摘要

1. **多窗口默认开启**：`UIApplicationSupportsMultipleScenes = true`（生成脚本唯一来源）。技术验证见 §3，未发现窗口呈现回归。
2. **共享数据核心 + 每窗口视图状态**：登录态、轮询、WebSocket、发件箱在进程内只有一份；Tab、导航、滚动位置按窗口隔离。这是「无重复轮询/推送」的结构性保证（§4）。
3. **场景恢复**：窗口 Tab 与「上次所在会话」持久化，杀掉 App 重开回到原会话（§5）。
4. **与设计文档的一处偏离**：spec §6.4 写「每个 `WindowGroup` 场景持有自己的 `WorkspaceModel`」。实测与实现结论是**不能**每场景一份：`ChatModel` 的草稿/发件箱按 (账号, 工作区, Agent) 持久化，两个 `WorkspaceModel` 会各自加载同一份 outbox 并重复投递，同时各起一份轮询与 socket。因此实现改为「一个共享 core，窗口只订阅」，与 spec 同段的括号说明「或由 `SessionModel` 持有一份、窗口只订阅」一致（§4）。

## 2. 改动

| # | 项 | 文件 | 内容 |
| --- | --- | --- | --- |
| 1 | 多场景 | `scripts/generate-ios-project.py` | `UIApplicationSupportsMultipleScenes` `False` → `True`；两个 Info.plist 由脚本重新生成 |
| 2 | 共享 core | `ios/Chatty/AppCore.swift`（新） | `AppCore` 持有唯一的 `SessionModel`；`@State` 挂在 `App` 上（每进程一份），所有窗口渲染同一实例 |
| 3 | 多窗口入口 | `ios/Chatty/ChattyApp.swift` | `WindowGroup(id: "main", for: AppRoute.self)`；`AppRoute`（tab + 每次唯一 token）保证 `openWindow` 每次都开新窗口 |
| 4 | 每窗口状态 | `ios/Chatty/WorkspaceTabs.swift` | 「在新窗口打开」（Mika / 项目 工具栏）→ `openWindow(id:value:)`；Tab 按窗口持久化（§5） |
| 5 | 场景生命周期 | `ios/Chatty/SceneActivityMonitor.swift`（新）、`ios/Packages/ChattyKit/Sources/ChattyCore/SceneActivity.swift`（新） | 用「前台活跃场景集合」驱动共享 core 的 start/pause，替代 `.onDisappear { pause() }`（spec §7 R3）；停止前有 2 秒宽限，避免窗口切换瞬间误停 |
| 6 | 会话恢复 | `ChatModel.swift`、`Contracts.swift`、`ProtectedStorage.swift` | 记住/恢复上次会话（`ChatSessions.restored`），优先于「最近更新」；窗口 Tab 按窗口键持久化 |
| 7 | 多窗口可见性 | `ChatModel.setVisible` | 改为引用计数：一个窗口消失不再清掉其它窗口的已读状态 |
| 8 | 测试与夹具 | `ios/Packages/ChattyKit/Tests/ChattyCoreTests/SceneStateTests.swift`（新）、`scripts/ios-fixture.py` | 7 项新单测；夹具新增 `promote_session` 控制，用于制造「记住的会话 ≠ 最新的会话」场景 |
| 9 | 证据 | `evidence/stage-c/compact-320-class-composer-keyboard.png` | 紧凑宽度 composer 与键盘避让 |

判定依据仍全部来自 size class 与场景生命周期，**没有引入 `userInterfaceIdiom` 分支**。

## 3. `UIApplicationSupportsMultipleScenes` 技术验证

问题（spec §7 R1/R5）：开启多场景是否改变 iPadOS 26 上的窗口呈现（例如不再默认全屏）。

方法：全新 bundle id `ai.chatty.ios.mw`（避开 R1 按 bundle id 记忆的遗留几何）安装 `ChattyFixture`，用截图像素测量应用窗口矩形；再用系统日志计数 UIWindowScene 身份。

| 观察 | 结果 |
| --- | --- |
| 冷启动窗口 | 1032 × 1376 pt（全屏，与 Stage A 的 `multiScenes=false` 通用 App 首装一致）→ **开启多场景未改变默认呈现** |
| 按「在新窗口打开」 | 系统日志出现新的 `UIWindowScene` 身份（`ai.chatty.ios.mw-8FC03F8B…` 等），原场景交出 key window → `openWindow` 确实新建窗口 |
| 连续两次打开 | 场景身份计数继续增加（受控实验：按键前后 10 秒窗口内新增 1 个场景 id），说明每次都是新窗口而不是聚焦已有窗口 |
| 呈现 | iPadOS 26 把新窗口叠放在原窗口之上；`xcrun simctl` 无窗口几何/分屏接口，无法脚本化「并排平铺」的截图 |

**结论：默认值 `true`，不保留开关。** 依据：开启后默认呈现未变（无回归）；`openWindow` 可用且行为符合预期；多窗口是 CLE-84 已确认纳入首版的能力。后续若要再关闭：把 `scripts/generate-ios-project.py` 的该键改回 `False` 并重新生成工程即可（回退路径见 §8）。

## 4. 共享登录态与去重

结构（每进程各一份）：`SessionModel`（Keychain 令牌、工作区列表）→ `WorkspaceModel` → `ChatModel` / `ActivityModel`；窗口只持有视图状态。因此：

- `ChatModel.start()` 的轮询任务与 `RealtimeConnection` 每进程只有一份；
- 发件箱（outbox）只有一份，不存在两个窗口同时 flush 同一条消息；
- `markRead` 由 `markedMessage` 去重，多窗口不会重复提交已读。

实测（`scripts/ios-fixture.py` 的 `/__calls` 审计，同一夹具进程生命周期内）：

| 步骤 | 活跃 WebSocket | WebSocket open 事件 | 说明 |
| --- | --- | --- | --- |
| 启动（1 窗口） | 1 | 2（含一次重连） | 基线 |
| 再开 2 个窗口（共 3 窗口） | **1** | **2（无新增）** | 开窗口不再新建连接 |
| 3 窗口空闲 30 秒 | 1 | — | `/api/chat/sessions` +0（socket 在线时按事件刷新）、`/api/issues` +2（单条 30 秒轮询） |

> 修复过程中实测到：最初用 `.onDisappear` / 即时场景数变化驱动，窗口切换瞬间会出现「无前台活跃场景」，导致 socket 断开重连（开 2 个窗口 = 新增 2 次 open）。§2 的第 5 项（2 秒宽限）修复后，上表显示新增窗口 **0** 次连接。

复现步骤：

```sh
# 1. 合成服务（独立端口，避免与其它会话占用的 8765 冲突）
CHATTY_FIXTURE_PORT=8767 python3 scripts/ios-fixture.py
# 2. 构建安装具备多场景的 fixture（bundle id 用一个全新值，避开 R1 遗留窗口几何）
xcodebuild -project ios/Chatty.xcodeproj -scheme ChattyFixture -configuration Debug \
  -destination "platform=iOS Simulator,id=<iPad UDID>" -derivedDataPath .tools/dd-fixture \
  PRODUCT_BUNDLE_IDENTIFIER=ai.chatty.ios.mw CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- build
xcrun simctl install <iPad UDID> .tools/dd-fixture/Build/Products/Debug-iphonesimulator/ChattyFixture.app
SIMCTL_CHILD_CHATTY_FIXTURE_PORT=8767 xcrun simctl launch <iPad UDID> ai.chatty.ios.mw
# 3. 登录（合成邮箱 ios@example.test / 验证码 123456）后，在 Mika 或 项目 工具栏按「在新窗口打开」两次
# 4. 读审计：active_sockets 应始终为 1，且第 3 步不再产生新的 ws open 事件
curl -s http://127.0.0.1:8767/__calls
```

## 5. 场景恢复（实测）

「回到原会话与选择」由两处持久化兑现：窗口 Tab 按窗口键（`route.token`，首窗口用 `default`）保存在受保护目录；上次会话 id 按 (账号, 工作区, Agent) 保存。

判别实验（用 `promote_session` 制造「记住的会话 ≠ 最新的会话」）：

| 步骤 | 观察 |
| --- | --- |
| 全新安装，`s1` 为最近更新 | 进入 Mika，显示 `s1` 的 63 条历史消息 |
| 把 `s2`（无消息）提升为最近更新，然后杀掉 App 重开 | **仍显示 `s1` 的 63 条历史消息**，Tab 回到 Mika；若按「最近更新」选择会落到 `s2` 的空态 |
| 停在「项目」Tab，杀掉 App 重开 | 回到「项目」Tab |

第二行说明恢复的是**上次所在会话**而不是「最新会话」；第三行说明 Tab 按窗口恢复。`@SceneStorage` 在本机实测不足以覆盖这条（强杀后不保留，且被恢复的窗口会用它最初打开时的路由重设 Tab），因此改为显式持久化，理由写在 `WorkspaceTabs.swift` 的注释里。

## 6. 多任务基础与紧凑宽度

| 项 | 结论 | 证据 |
| --- | --- | --- |
| 方向 | 已由 Stage A 放开四方向，本阶段未再改动 | 安装包 Info.plist 四方向 + `UISupportedInterfaceOrientations~ipad` |
| 不设 `UIRequiresFullScreen` | 保持不设置（设置它会禁用分屏） | `scripts/generate-ios-project.py` |
| 紧凑宽度 composer 可用 | 375 × 667 pt（当前可用的最窄模拟器档）下：附件按钮 44 × 44 @ x=20、输入框 227 pt 宽 @ x=74、发送 44 × 44 @ x=311（右边缘 355 < 375），无横向裁切 | `evidence/stage-c/compact-320-class-composer-keyboard.png` |
| 键盘避让 | 聚焦输入框后 composer 底边 y=295、键盘顶边 y=451 → 完整可见，未被键盘遮挡 | 同上 |
| 紧凑宽度导航 | 底部 Tab 栏（动态 / Mika / 项目），与 Stage A 基线一致 | 同一次会话的无障碍树 |

`xcrun simctl create` 无法创建 iPhone SE (1st generation)（iOS 26 不支持该机型），`simctl` 也没有窗口缩放/分屏接口，因此 320 pt 档（Stage Manager 最小宽度）仍未实测——与 spec §3 的第 7–11 行一起留给阶段 D 的设备矩阵。

## 7. 构建与测试

```
swift test --disable-sandbox --package-path ios/Packages/ChattyKit --scratch-path .tools/ios-swift-build
→ Executed 50 tests, with 0 failures   （改造前 42 + SceneStateTests 新增 8）

xcodebuild -project ios/Chatty.xcodeproj -scheme Chatty -configuration Debug \
  -destination "generic/platform=iOS Simulator" -derivedDataPath .tools/dd CODE_SIGNING_ALLOWED=NO build
→ ** BUILD SUCCEEDED **

xcodebuild -project ios/Chatty.xcodeproj -scheme ChattyFixture -configuration Debug \
  -destination "platform=iOS Simulator,id=<iPad UDID>" -derivedDataPath .tools/dd-fixture \
  PRODUCT_BUNDLE_IDENTIFIER=ai.chatty.ios.mw CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- build
→ ** BUILD SUCCEEDED **
```

新增单测（`SceneStateTests`）：场景集合变化 → start / keep / pause 的转换（含「两窗口中关掉一个仍继续运行」）；记住的会话优先于「最近更新」、失效时回退；会话记忆按账号/工作区分区且随退出清理；每个窗口的 Tab 互不覆盖。

> 说明：本机沙箱禁止 SwiftPM/Xcode 申请自己的嵌套 sandbox（`sandbox-exec: sandbox_apply: Operation not permitted`），上述构建与测试在放开该限制后执行；命令本身与仓库文档一致（`--disable-sandbox` 只用于包测试）。

## 8. 回滚

1. 关闭多窗口：`scripts/generate-ios-project.py` 的 `UIApplicationSupportsMultipleScenes` 改回 `False` 并重新生成工程；`openWindow` 入口随之失效，其余改动不受影响。
2. 恢复每窗口状态：`WorkspaceTabs` 去掉场景持久化与 `openWindow` 按钮即可回到「单窗口 Tab」。
3. 恢复会话记忆：`ChatModel` 去掉 `ChatSessions.restored` 分支即回到「总是选择最近更新的会话」。
4. 场景生命周期：把 `SceneActivityMonitor` 换回 `scenePhase` + `onDisappear` 即回到 Stage A 行为（注意会重新引入窗口切换重连）。

回退后不残留 iPad 专属代码路径（本阶段未引入平行 UI）。

## 9. 未执行 / 边界

- **并排平铺截图未取得**：`simctl` 无窗口几何/分屏接口，`agent-device` 不支持系统级窗口拖拽；多窗口证据为系统日志中的场景身份 + 审计中的连接数，而不是「两窗口并排」截图。
- Split View 1/2、1/3、Slide Over、Stage Manager 自定义尺寸：与 spec §3 一致，留给阶段 D。
- 320 pt 档未实测（§6）。
- 真机未验证，全部为模拟器。
- 未修改签名、Bundle ID、版本号或 App Store Connect 资料；未上传 TestFlight。
- 未改 `.sdlc`/`spec.md` 的设计结论；本阶段与 spec §6.4 的一处偏离已在 §1 第 4 条记录。
