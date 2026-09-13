# Evidence: 阶段 1 契约与受保护存储底座

- Change: `20260912-ios-deepseek-chat-alignment-impl`
- 阶段：1 / 8（见上游 `plan.md`）
- 日期：2026-09-12
- 状态：**已完成并验证**

## 1. 交付的行为（可观察）

### 1.1 历史会话所需字段已可解码

`GET /api/chat/sessions` 现在完整解码 `pinned / has_unread / unread_count /
last_message / created_at`。旧后端（不返回这些字段）不会让整页解码失败——
新字段全是可选，缺失即为 `nil`。

**例子**：`{"id":"s2","agent_id":"mika"}` 解出的会话 `pinned == nil`、`lastMessage == nil`，
而不是抛错。带 `last_message` 的会话可读出预览文本，历史列表因此能显示「最后一句」。

### 1.2 历史列表顺序确定

`ChatSessions.ordered(for:in:)`：置顶优先 → `updated_at` 降序 → **同时间戳保持服务端顺序**。
排序用原始下标做最终 tiebreak，因为 Swift 的 `sorted(by:)` 不稳定，而 fixture 与
Android 客户端都以服务端顺序为准。

**例子**：输入 `[a(09-01), b(09-05), c(置顶), d(09-05), e(archived), f(其他 agent)]`
→ 输出 `["c", "b", "d", "a"]`。

### 1.3 会话标题有确定的三级回退

`ChatSessions.displayTitle(_:firstUserMessage:limit:)`：服务端 `title`（去空白后非空）
→ 首条用户消息截断 20 字 → `新的对话`。

### 1.4 取消与队列优先的响应可解码

新增 `CancelTaskResponse` / `CancelledChatMessage` / `PrioritizeQueuedResponse` 与
`QueueCancelAction`，供阶段 2 的停止/队列实现使用。`restore_to_input` 由调用方读取而
**不猜测**——否则中止的消息可能被静默丢弃或在其它会话重复出现。

### 1.5 草稿按会话隔离（本阶段最重要的行为变化）

之前一个工作区（account/workspace/agent）只有**一份**草稿，切换会话会把未发送内容
带到另一个会话。现在：

- 每个会话一个受保护记录：`draft(account:workspace:agent:session:)`；
- 会话建立前用 `ProtectedStorage.pendingSessionKey`（`"new"`）占位，
  首条消息发出、服务端创建会话后用 `migrateDraft(from:to:)` 搬到真实会话 id；
- **迁移永不覆盖目标**，且先写目标再删来源，可安全重试（幂等）。

**例子**：会话 A 写「会话 A 的草稿」、会话 B 写「会话 B 的草稿」，两者独立可读；
查询未写过的会话 C 返回 `nil`（区别于「用户清空了草稿」）；换账号或换工作区读不到。

### 1.6 升级用户的既有草稿不丢

旧版本写在 agent 级键上的那一份草稿，通过 `adoptLegacyDraft(...)` 一次性采纳进用户
实际恢复的会话：

- 采纳一次后旧键清空，**重复调用返回 `nil`**（幂等）；
- 旧草稿**不会泄漏**到其它会话；
- 若目标会话已有记录，则**已有记录优先**，旧键同样清掉以免以后串味。

**例子**：升级后打开上次的会话 `s1`，输入框里仍是升级前那份未发送文字；
再打开 `s2`，输入框是空的。

### 1.7 旧版出站消息记录仍可解码

`OutgoingMessage` 新增 `sessionId`。旧记录没有这个键，解码后为 `nil`（迁移时归入
恢复的会话）；未指定会话的新记录也**不会**写出该键，因此记录仍可被旧版本读取。

## 2. 变更文件

| 文件 | 变更 |
| --- | --- |
| `ios/Packages/ChattyKit/Sources/ChattyCore/Contracts.swift` | 新增 `ChatPreview`；`ChatSession` 补 5 个字段；`ChatSessions` 新增 `ordered` / `displayTitle` / `newConversationTitle`；新增 `PrioritizeQueuedResponse`、`CancelledChatMessage`、`CancelTaskResponse`、`QueueCancelAction` |
| `ios/Packages/ChattyKit/Sources/ChattyCore/ProtectedStorage.swift` | 新增按会话分键的 `draft`/`saveDraft`/`removeDraft`/`migrateDraft`/`adoptLegacyDraft`；旧 agent 级 API 原样保留（旧键文件名不变，升级可读） |
| `ios/Packages/ChattyKit/Sources/ChattyCore/OutgoingMessage.swift` | 新增 `sessionId`（带默认值，向后兼容） |
| `ios/Packages/ChattyKit/Tests/ChattyCoreTests/ContractTests.swift` | +4 项：新字段解码与旧后端兼容、历史排序、标题回退、取消/优先响应 |
| `ios/Packages/ChattyKit/Tests/ChattyCoreTests/DraftScopeTests.swift` | 新增，6 项：会话隔离、账号/工作区隔离、`new`→会话迁移与幂等、迁移不覆盖、旧草稿只采纳一次且不泄漏、旧记录解码兼容 |

**未触碰**：`ios/Chatty/*`、`ios/Fixture/*`、`macos/*`、导航（D5）、Xcode 工程文件。
本阶段没有新增宿主 Swift 文件，因此**不需要**重新生成 Xcode 工程。

## 3. 验证

| 检查 | 命令 | 结果 |
| --- | --- | --- |
| 包测试（基线） | `swift test --package-path ios/Packages/ChattyKit --scratch-path .tools/ios-swift-build` | 75 tests / 0 failures（改动前） |
| 包测试（改动后） | 同上 | **85 tests / 0 failures** |
| 宿主 iOS 编译 | `source scripts/ios-env.sh && xcodebuild -project ios/Chatty.xcodeproj -scheme Chatty -configuration Debug -destination "generic/platform=iOS" -derivedDataPath "$CHATTY_IOS_DERIVED_DATA" CODE_SIGNING_ALLOWED=NO build` | **BUILD SUCCEEDED** |

新增 10 项测试全部来自本阶段（`ContractTests` 9→13、新增 `DraftScopeTests` 6）。

## 4. 环境说明（会影响后续阶段的命令）

- 会话文件策略为 `workspace-write` 时，`swift test` 需要额外加 `--disable-sandbox`：
  SwiftPM 编译 manifest 会调用 `sandbox-exec`，而嵌套 `sandbox_apply` 被拒
  （`sandbox-exec: sandbox_apply: Operation not permitted`），manifest 编译失败，
  测试根本不会运行。策略为 `danger-full-access` 时**不需要**该参数。
  > 注意：用管道包住 `swift test` 时 shell 返回的是管道末端状态，必须用
  > `set -o pipefail` / `${PIPESTATUS[0]}` 才能看到真实退出码；本记录的所有数字都
  > 是在修正这一点之后取得的。
- 宿主 `xcodebuild` 需要把 DerivedData 放在仓库内（`$CHATTY_IOS_DERIVED_DATA`）；
  此外 SwiftPM 还要写 `~/Library/Caches/org.swift.swiftpm`，在受限文件策略下会被拒，
  表现为 `Could not resolve package dependencies`。重定向 `HOME` **无效**（Xcode 取真实
  home），受限策略下这一步只能通过放开文件策略完成。

## 5. 限制与未覆盖

- 本阶段**没有任何 UI 变化**，因此没有截图证据，也不需要 agent-device 剧本；
  宿主编译通过只证明接口兼容，不证明历史界面可用。
- 迁移逻辑只在 macOS 路径（posix 权限）下测过；iOS 的 `completeFileProtection`
  路径由既有 `SimulatorContractTests` 覆盖旧 API，**新 API 的文件保护属性尚未在
  模拟器上验证**——阶段 8 的宿主 XCTest 需要补一项。
- `ChatSession` 新增字段尚未在真实 Multica 后端验证（只验过 fixture 契约与解码）。
- 旧键文件名与旧 `saveDraft` API 保留是**有意**的兼容层，计划在阶段 8 或后续
  change 中评估移除时机；当前不产生行为影响。

---

# 阶段 2 / 3 / 5 / 6：模型层与聊天界面

- 日期：2026-09-12
- 状态：**已完成并验证**（阶段 4 富文本/公式与阶段 7 剧本扩展见 §9 未覆盖项）

## 6. 交付的行为（可观察）

### 6.1 会话模型（阶段 2，`ChatModel`）

- `sessions` 暴露全部非归档会话，置顶在前、`updated_at` 降序（`ChatSessions.ordered`）。
- `open(_:)` 切换会话：先落盘当前草稿记录，再清空时间线，最后载入目标会话自己的
  草稿、项目选择、附件与待发送队列。
- **出站队列按会话归属**：发送循环捕获当前会话代号，每个 `await` 之后比对；会话切换后，
  在途的发送结果不会写进新会话。
- **停止生成**：`stopCurrent()` → `POST /api/tasks/{id}/cancel`；服务端回执里的
  `restore_to_input` 决定是否把被取消的文本**追加**回输入框（不覆盖用户已输入内容）。
- **队列管理**：`sendQueuedNow`（优先，并取消被抢占的任务）、`editQueued` /
  `removeQueued`（带 `expected_status=queued&chat_session_id&queue_action`，409 时
  退化为普通 `cancel` 重试一次）、`clearQueued`（乐观移除 + `DELETE queued-tasks`）。
- `stopping` 暴露给界面，所有会发请求的控件在请求期间禁用，避免双击造成双写。
- `sessionTitle`：服务端标题 → 首条用户消息截断 20 字 → 「新的对话」。

**可观察例子**：发送后按钮变成「停止生成」；点它会调用 cancel 并把文本按
`restore_to_input` 追加回输入框；切到另一个会话时，上一个会话的排队消息不会跟过来。

### 6.2 按会话草稿补齐附件（阶段 2）

`DraftRecord` 增加 `attachments`，并新增 `isEmpty`。`isEmpty` 是必要的：离开一个会话时
会写下一份空记录，若把「记录存在」当成「用户在这里有内容」，升级用户的旧草稿就永远
无法被采纳（**这是本轮实际踩到并修掉的缺陷**）。

### 6.3 离线恢复跟随会话（阶段 2）

`DraftRecoveryScope` 增加 `sessionId`，离线草稿的读/写都落到用户当时所在会话的键上；
旧记录没有该字段，回退读旧键。

### 6.4 视觉令牌（阶段 3，`Theme.swift`）

`ChattyTheme` 从 4 个令牌扩到 13 个语义令牌（背景/表面/凹陷面/分隔线/主次文本/强调色/
用户气泡/激活 chip/描边/危险色），全部按 traits 定义深浅色。浅色取自已验证的
DeepSeek 取值（`#FFFFFF` 底、`#EDF3FE` 气泡、`#0F0F0F` 正文、`#7D7F85` 次要文本、
`#4D6BFE` 强调色）；**深色留在系统语义色**，因为一手素材全是浅色（见 `spec.md §2.1`）。

### 6.5 聊天界面（阶段 5，`ChatScreen.swift`）

- 顶栏：左＝历史（圆形浅灰底按钮）、中＝**会话标题**、右＝新建会话；头像仍由外壳提供，
  `window.open` 只在 regular 宽度保留（`spec.md §3.2`）。
- **欢迎态**替换原空态：居中 Mika 标识 + 「想从哪里开始？」+ 两条建议（点击填入输入框）。
- 用户消息＝右对齐 `#EDF3FE` 气泡（圆角 14）；助手回答＝**全宽纯文本、无气泡无头像**；
  文件附件在气泡上方渲染为带大小的卡片。
- **过程块**：运行中「正在思考 ⌄」展开并显示步骤（左侧 1px rail、`tool_use` 显示工具名、
  `thinking` 显示灰字），结束后自动折叠为「已思考（用时 N 秒）›」，可手动展开；
  超过 6 步只显示最近 6 步 + 总步数。`reduceMotion` 下不做滚动动画。
- 长按菜单：复制 / 分享 / 引用到输入框（引用是追加，不覆盖）。
- 队列区：每条排队消息带「优先 / 编辑 / 移除」，「清空」一次清完。
- iPad（regular）单栏并限宽 700pt。

**改动过程中的两处修正（都有截图前后对比）**：
1. 运行中的过程块原本不显示——收据行先到达，而我的条件要求「最后一条消息的 taskId 不等于
   当前任务」，收据行自身就带着该 taskId，条件恒假。改为「还没有属于该任务的助手消息时
   才单独显示」。
2. 运行中显示「暂时没有过程记录」——`loadTrace` 会把空数组写进 `traces`，于是
   「字典里没有条目」不再是「还在等」的判据。改为用 `isRunning` 判断并显示菊花。

### 6.6 会话历史（阶段 6，`ChatHistoryView.swift`）

全高 sheet：标题「历史对话」、关闭、新建；行为两行（标题 + 最后一条预览，`role == user`
时前缀「你：」），右侧时间（今天＝时刻、昨天＝「昨天」、本周＝星期、更早＝月/日），
当前会话打勾，`unread_count > 0` 显示蓝点；顶部 `搜索聊天内容` 本地过滤标题与预览；
下拉刷新。**行是纯选择行，没有长按菜单**（服务端不支持重命名/置顶/删除写入，D7）。

## 7. 验证

| 检查 | 命令 | 结果 |
| --- | --- | --- |
| 包测试 | `swift test --package-path ios/Packages/ChattyKit --scratch-path .tools/ios-swift-build` | **85 tests / 0 failures** |
| 宿主编译（Release，签名） | `xcodebuild -scheme Chatty -configuration Release -destination 'generic/platform=iOS' archive` | **BUILD SUCCEEDED / archive 生成** |
| 合成服务闭环 | `scripts/ios-fixture.py` + `agent-device replay tests/device/ios/v3-chat-alignment.ad` | **19 步全部通过**（18.8s） |

截图证据（`evidence/`）：

| 文件 | 展示 |
| --- | --- |
| `01-conversation.png` | 既有会话：顶栏会话标题、富文本、代码块、附件卡 |
| `02-welcome.png` | 欢迎态「想从哪里开始？」+ 两条建议 |
| `03-thinking.png` | 运行中：「正在思考 ⌄」展开 + 菊花；发送键变停止键 |
| `04-reply.png` | 回答到达：全宽正文、「用时 3.0 秒」、「已思考（用时 3 秒）›」折叠 |
| `05-history.png` | 历史抽屉：预览、未读蓝点、当前会话勾选、搜索框 |

## 8. 变更文件（阶段 2/3/5/6）

| 文件 | 变更 |
| --- | --- |
| `ChattyCore/ChatModel.swift` | 会话列表、`open`、`stopCurrent`、队列四项操作、按会话出站队列、`stopping`、`sessionTitle` |
| `ChattyCore/ProtectedStorage.swift` | `DraftRecord.attachments` / `isEmpty`；`adoptLegacyDraft` 允许替换空记录；`DraftRecoveryScope.sessionId` |
| `ChattyCore/SessionModel.swift` | 离线恢复按会话读写，旧记录回退 |
| `ChattyCore/APIClient.swift` | `write` 支持 query（队列取消需要） |
| `ios/Chatty/Theme.swift` | 完整语义令牌集（深浅色） |
| `ios/Chatty/ChatScreen.swift` | 重写：顶栏、欢迎态、消息行、过程块、队列区、输入区 |
| `ios/Chatty/ChatHistoryView.swift` | 新增：历史抽屉 |
| `ios/Chatty/WorkspaceTabs.swift` | `window.open` 仅在 regular 宽度显示 |
| `ios/Chatty.xcodeproj/project.pbxproj` | 生成器输出（新文件 + build 5） |
| `scripts/generate-ios-project.py` | `CURRENT_PROJECT_VERSION` 4 → 5 |
| `tests/device/ios/v3-chat-alignment.ad` | 新增：聊天对齐回放剧本 |
| `ChattyCoreTests/ClientFlowTests.swift` | 2 处断言改读按会话键（原读 agent 级键） |

## 9. 未覆盖 / 已知差距

- **阶段 4（公式渲染）已完成**，见 §10。
- **阶段 7 的模型语义已用单元测试固定**（见 §16），剧本覆盖到「清空」为止；
  队列单条「优先 / 编辑 / 移除」的**端到端 UI 断言仍不确定**——回放里三个动作都执行了、
  按钮也确实可达，但 `agent-device` 的 ref 在变更后会失效，我按 ref 点击时抓到的是
  过期元素，截图无法隔离出动作后的状态。因此改用单元测试验证语义（见 §16），
  UI 侧只声明"可达且已接线"，不声明"已验证"。
- 真机矩阵（键盘、长消息滚动、断网重试、后台恢复、深色模式）未执行。
- **无障碍字号下顶部栏遮挡内容**（本轮实测发现的真实缺陷，见 §17）——这是一条
  未修复的缺陷，因此 `spec.md §11` 的 Dynamic Type 条款**不能声明已满足**。
- `ChattyFixture` 之外未在真实 Multica 后端验证（新增字段与 cancel/queued-tasks 只在
  合成服务上验过）。

---

# 阶段 8（部分）：回归与无障碍

## 17. 宿主机测试与 Dynamic Type 实测

### 17.1 宿主 XCTest（此前从未在本会话跑过）

| 检查 | 命令 | 结果 |
| --- | --- | --- |
| 宿主 XCTest | `xcodebuild -scheme ChattyFixture -destination "platform=iOS Simulator,id=$IOS_SIMULATOR_ID" test` | **TEST SUCCEEDED**，9 项通过、1 项按设计跳过（模拟器不暴露文件保护，需真机） |

新增 `testConversationScopedDraftKeepsBackupExclusion`，补上了阶段 1 记录的缺口：
**按会话分键的记录、以及升级路径写出的记录，都带备份排除属性**（此前只在 macOS
文件布局上验过）。它同时断言采纳后旧键被清空。

### 17.2 Dynamic Type：逐档测出边界，只有最大那一档失败

`v3-chat-welcome.ad` 在五个无障碍档位逐一回放（每档 `uninstall` + `install` + 新 fixture）：

| 字号 | 欢迎态剧本 |
| --- | --- |
| `accessibility-medium` | ✅ 通过 |
| `accessibility-large` | ✅ 通过 |
| `accessibility-extra-large` | ✅ 通过 |
| `accessibility-extra-extra-large` | ✅ 通过 |
| `accessibility-extra-extra-extra-large` | ❌ **失败** |

标准档全部通过（见 `20-welcome-standard.png`、`16-dynamic-type-standard-xxxl.png`）。

**所以这不是"无障碍字号不可用"，而是"五档里最大的那一档不可用"**——
严重程度比第 4 轮的说法低得多。截图 `19-welcome-accessibility-xxxl.png` 显示：
提示文字「已开始新的对话，发送后会创建会话。」占满三行，第一颗建议按钮的上半部分
被顶出可见区域，标题「想从哪里开始？」完全不可见。

**复现命令**：

```sh
APP="$CHATTY_IOS_DERIVED_DATA/Build/Products/Debug-iphonesimulator/ChattyFixture.app"
for size in accessibility-medium accessibility-extra-extra-large accessibility-extra-extra-extra-large; do
  xcrun simctl ui "$IOS_SIMULATOR_ID" content_size $size
  xcrun simctl uninstall "$IOS_SIMULATOR_ID" ai.chatty.ios.fixture
  xcrun simctl install "$IOS_SIMULATOR_ID" "$APP"
  agent-device replay tests/device/ios/v3-chat-welcome.ad --platform ios \
    --udid "$IOS_SIMULATOR_ID" --session "wl-$size" --json
done
xcrun simctl ui "$IOS_SIMULATOR_ID" content_size large   # 复原
```

### 17.3 三次修复尝试都无效（因此**全部回退**，不留无效改动）

按"滚动位置"这条线索试了三个方案，**实测结果都没有变化**（最大档仍然失败）：

| 尝试 | 假设 | 结果 |
| --- | --- | --- |
| `defaultScrollAnchor` 空会话改 `.top` | 底部锚定把标题顶出视野 | 无效 |
| 同上 + `.id(conversationKey)` 强制重建 | `.initialOffset` 只求值一次，旧锚点被继承 | 无效 |
| `scrollRequest` 时对空会话 `scrollTo("chat.top")` | 新建对话时主动滚到顶 | 无效 |

**这三条负结果本身就是结论**：问题不在滚动锚点，而在**垂直空间预算**——
最大档下「fixture 横幅（仅测试包）+ 导航栏 + 三行提示文字」已经把高度吃掉，
欢迎态内容（图标 + 标题 + 两颗按钮）放不下，于是顶部被裁。

**未修**：真正的修法是给顶部横幅设高度上限，或让欢迎态在空间不足时压缩/滚动，
属于一次专门的外壳布局改动。**根因方向已有依据，但没有确定的修法**，
所以我没有把它算作已修，也没有留下实验代码。归档 7 与当前源码一致。

### 17.4 定位并修复：罪魁是"新建对话"提示条占掉了时间线的高度

第 17.3 节的三次失败说明问题不在滚动锚点。本轮做了一个**判别性实验**：
把「新建对话」的提示条临时去掉，再跑最大档的欢迎态剧本——**通过了**。
这就把范围钉死在提示条上，而不是欢迎态内容本身太高。

**根因**：最大档下提示文字「已开始新的对话，发送后会创建会话。」要占三行；
「fixture 横幅（仅测试包）+ 导航栏 + 这三行」把高度吃光，时间线只剩很少空间，
欢迎态内容放不下，标题被挤出可达区域。

**修法（已交付）**：欢迎态本身已经在说"这是新对话"，所以**新建对话时不再显示那条
冗余提示**：

```swift
if let notice = model.notice, !model.isStartingNewSession { … }
```

其他提示（包括「原对话已归档或删除，下次发送将创建新的 Mika 对话。」）**照常显示**——
它们出现在已有会话的状态下，与欢迎态互斥，不受影响。

**验证**（同一个二值剧本，`uninstall` + `install` 保证起点一致）：

| 字号 | 修前 | 修后 |
| --- | --- | --- |
| `accessibility-extra-extra-extra-large` | ❌ 失败 | ✅ **通过** |
| 标准档 | ✅ 通过 | ✅ 通过 |

截图 `21-welcome-accessibility-max-fixed.png`：最大档下「想从哪里开始？」与两颗建议按钮
完整可见。

**这是一次产品行为上的取舍，需要你确认是否接受**：代价是新对话时少了一句文字确认
（欢迎界面本身仍是反馈，VoiceOver 也能读到）。如果更希望保留那句提示，
替代方案是给顶部横幅设高度上限或让欢迎态在空间不足时压缩——那样改动会落到外壳布局上。
改动只有一行，回退成本很低。

---

## 18. 令牌对比度检查：顺手抓到一个深色模式真 bug

按 `spec.md §2.3`（正文 ≥ 4.5:1、图形/大字 ≥ 3:1）在宿主测试里加了两个对比度断言
（`testThemeBodyTextMeetsContrastInBothAppearances`、
`testThemeAccentPairingsMeetNonTextContrast`），把每个语义令牌对按浅色/深色两种
trait 解析后算 WCAG 对比度。

**第一次运行就失败了三条**，其中两条是**真 bug**：

| 断言 | 实测 | 性质 |
| --- | --- | --- |
| 深色 `textPrimary` / `background` | **1.00** | 🐞 **`background` 令牌漏了深色回退值**——深色模式下页面底色仍是白色，而 `textPrimary` 变成白色。白底白字，等于整页不可读 |
| 深色 `textSecondary` / `background` | 1.18 | 同上，由同一个漏配导致 |
| 浅色 `textSecondary` / `background` | 4.00 | ⚠️ 低于 AA 小字标准 4.5 |

**修法**：

1. `ChattyTheme.background` 补上 `darkFallback: .systemBackground`。**这是本轮最重要的
   修复**——深色模式此前基本不可用，而截图、剧本、单测都没覆盖到它。
2. `textSecondary` 的浅色值由实测的 `#7D7F85` 改为 `#6E7076`（4.88:1）。
   **这是一处有意偏离 DeepSeek 实测值的地方**：`#7D7F85` 只有 4.00:1，而它承载的是
   说明文字与过程块这类小字，规范 §2.3 自己要求 4.5:1。

深色模式修复后的实机效果见 `22-dark-mode-chat.png`：黑底、白字、深色代码块与输入卡片。

**这与前几轮的结论不冲突**：`research.md` 早已写明"深色配色无一手来源、不得凭编造"，
所以令牌走系统语义色；但**漏配回退**和"没有一手来源"是两回事——
前者是 bug，后者是信息缺口。对比度测试正好把前者逼了出来。

**教训**：我给 `surface`、`textPrimary` 等都传了 `darkFallback`，唯独 `background`
漏了。纯靠肉眼看浅色截图永远发现不了，只有把两种 trait 都断言一遍才会暴露。

### 18.1 补上深色模式的端到端回归（此前完全没有）

那个 bug 说明一件事：**深色模式此前没有任何端到端覆盖**——所有剧本都跑在浅色下。
本轮新增 `tests/device/ios/v3-chat-dark.ad`（21 步通过）：

| 截图 | 内容 |
| --- | --- |
| `23-dark-conversation.png` | 既有会话：深色底 + 富文本 + 代码块 + 附件卡 + 输入区 |
| `24-dark-welcome.png` | 欢迎态：黑底白字、强调色建议按钮、深色输入卡片与 Tab Bar |
| `25-dark-reply.png` | 发送后的用户气泡、过程块、回答 |
| `26-dark-history.png` | 历史抽屉：深色行、未读蓝点、当前会话勾选、搜索框 |

**这个剧本如果早存在，就会直接抓到白底白字。** 现在它是那条修复的回归保护。

复现：

```sh
xcrun simctl ui "$IOS_SIMULATOR_ID" appearance dark
xcrun simctl uninstall "$IOS_SIMULATOR_ID" ai.chatty.ios.fixture
xcrun simctl install "$IOS_SIMULATOR_ID" "$APP"
agent-device replay tests/device/ios/v3-chat-dark.ad --platform ios \
  --udid "$IOS_SIMULATOR_ID" --session chatty-v3-dark --json
xcrun simctl ui "$IOS_SIMULATOR_ID" appearance light   # 复原
```

---

## 19. 补齐 A2 的两条缺口：会话切换与历史搜索

复核验收标准时发现：**A2 写着"可列出、搜索、切换、新建会话"，但剧本只覆盖了"列出"和"新建"。**
切换和搜索写了实现、却没有任何端到端断言。新增 `tests/device/ios/v3-chat-history.ad`
（17 步通过）：

| 截图 | 断言 |
| --- | --- |
| `27-history-all.png` | 列表渲染；归档会话 `s3` 不出现 |
| `28-history-switched.png` | 点 `history.row.s1` 后**会话真的切换了**：顶栏标题变为「格式与资源验证」，正文出现 s1 的富文本内容（断言 `text="粗体与链接"` 通过） |
| `29-history-search.png` | 搜索「第二个」后列表只剩「第二个会话」一行——本地过滤生效 |

**过程中的两个小坑**（都记在剧本注释里，避免下次重踩）：

1. `fill` 不接受空字符串，所以不能用"清空搜索框"来恢复列表；改成**先切换、再搜索**的顺序。
2. 搜索框激活时导航栏的「关闭」按钮会被搜索 UI 取代，`history.close` 不可达——
   剧本因此不以"关闭抽屉"收尾。

这两条都是脚本层面的，不是产品缺陷。

**A2 现在四条（列出 / 搜索 / 切换 / 新建）都有断言。**

---

## 20. A5 的 `reduceMotion`：部分验证，其余如实说明

A5 的措辞是「回答到达后过程自动折叠…；`reduceMotion` 下不播放动画」。

**先说结论：能验的部分验了，验不了的部分说清楚。**

1. **过程块的折叠本身没有任何动画**——它是 `if expanded { … }` 的条件渲染，
   不是 `withAnimation` 包裹的转场。所以"`reduceMotion` 下不播放动画"对过程块是
   由构造保证的，不存在需要开关的动画。
2. **聊天界面里唯一的动画是「新消息到达时滚到底部」**，它在代码里被显式门控：

   ```swift
   if reduceMotion { proxy.scrollTo("chat.bottom", anchor: .bottom) }
   else { withAnimation(.easeOut(duration: 0.2)) { … } }
   ```

   全仓 `reduceMotion` 只出现在这一处（`ChatScreen.swift`），可以用
   `grep -n reduceMotion ios/Chatty/*.swift` 复核。
3. **功能冒烟：在 Reduce Motion 打开的情况下，欢迎态剧本仍然通过**（`success: true`）。

**没能验证的**：动画"消失"本身。截图是静态的，看不出有没有动画；
`xcrun simctl ui` 也不提供 reduce-motion 开关（只有 appearance / increase_contrast /
content_size），我是通过改模拟器偏好实现的：

```sh
xcrun simctl spawn "$IOS_SIMULATOR_ID" defaults write com.apple.Accessibility ReduceMotionEnabled -bool YES
# …跑剧本…
xcrun simctl spawn "$IOS_SIMULATOR_ID" defaults write com.apple.Accessibility ReduceMotionEnabled -bool NO
```

要真正断言"没有动画"，需要录屏逐帧比对或 XCUITest 的动画观测——都不在本轮工具范围内。
**所以 A5 记作"折叠与门控已复核 + 打开开关后功能正常"，不记作"动画行为已验证"。**

---

# 阶段 7（补充）：队列语义的确定性验证

## 16. 队列三条动作的语义

截图无法可靠隔离"点击之后"的状态，所以在 `ClientFlowTests` 里补了三条断言，
用 FlowRig 的服务器记录请求、并复刻真实 fixture 的取消回执（含 `restore_to_input`）：

| 测试 | 固定的行为 |
| --- | --- |
| `testEditingAQueuedMessageRestoresItsTextAlongsideTheDraft` | 编辑发出 `expected_status=queued` + `queue_action=edit` + `chat_session_id`；**排队消息的文本追加回输入框，且不丢弃用户已输入的内容**；队列变空 |
| `testRemovingAQueuedMessageDropsItsTextInsteadOfRestoringIt` | 移除发出 `queue_action=remove`，**不把文本倒回输入框**（草稿原样保留） |
| `testPrioritizingAQueuedMessageCancelsTheActiveTaskAndReturnsItsText` | 优先调用 `prioritize`，随后**用同一个 cancel 接口取消被顶掉的运行中任务**，并把**那个**任务的文本还给用户；被提升的消息继续执行、不回输入框 |

第三条测试第一次是**失败**的：我原本断言"输入框里出现排队消息的文本"，实际语义是
"被顶掉的**运行中**任务的文本回到输入框"。是我的期望写错了，不是实现错了——
修正断言后通过。这一条正好说明为什么值得写测试而不是看截图：截图里两个文本都可能出现，
分不清是哪一个。

`FlowRig` 为此扩了三处：`queuedTasks`（服务器上报的排队项）、`cancels`（记录每次取消及其
query）、`prioritized`，以及 `activeContent`（让 cancel 能像真实 fixture 一样把运行中
任务的文本交回来）。

**测试总数 95 → 98，全绿。**

---

# 阶段 7（补充）：停止生成与队列

## 13. 交付的验证

| 检查 | 命令 | 结果 |
| --- | --- | --- |
| 停止 + 队列闭环 | `agent-device replay tests/device/ios/v3-chat-stop-queue.ad` | **27 步通过**（26.9s），4 张截图 |

截图证据：

| 文件 | 展示 |
| --- | --- |
| `07-stop-available.png` | 运行中：发送键已替换为黑色停止键 |
| `08-stopped.png` | 点停止后：消息被移除、会话回到欢迎态、**被取消的文本回到输入框**（`restore_to_input`），发送键恢复为可用 |
| `09-queue.png` | 「排队中 1 条」+ 清空；排队消息带「优先 / 编辑 / 移除」 |
| `10-queue-cleared.png` | 清空后队列区消失；过程块显示真实工具步骤（`• 检查格式与上下文`、`fixture_check` + 输入 JSON），左侧有 1px rail |

`08-stopped.png` 是 A4 的直接证据：停止不只是"没反应"，而是**按服务端回执把文本还给了用户**。

## 14. 本轮修掉的两个问题

1. **合成服务的 `slow` 开关一直没生效**。`ios-fixture.py` 的 `/__control` 会在委托给
   `chat-fixture` 之前把请求体读掉，父处理器只看到空 body，于是 `SLOW` 永远保持 False，
   任务 3 秒就结束——这正是"排不上队"的根因。已在 iOS fixture 里直接设置 `module.SLOW`。
   > 验证方式：让 fixture 直接收两次并发发送，确认服务端返回 `queued: true` 且
   > `queued_tasks` 有内容（服务端本来就对），再用 `/pending-task` 在 4 秒后仍为
   > `running` 证明 slow 生效。
2. **队列行内的按钮对无障碍不可达**。在 `ChatQueueList` 容器上打
   `accessibilityIdentifier("chat.queue")` 会把整棵子树折叠成一个元素，导致
   「优先 / 编辑 / 移除 / 清空」既不能被设备测试选中，**VoiceOver 也读不到**。
   已移除容器标识，四个子按钮各自带标识。
   > 这是"为了写测试而加标识"反而暴露出的真实无障碍缺陷——`spec.md §11` 要求
   > 每个新控件都可单独聚焦。

## 15. 剧本的可复现前置条件

`v3-chat-stop-queue.ad` 依赖一个确定性的起始状态，命令序列已写进剧本头部注释：
重启 fixture → `{"slow":true}` → `uninstall` + `install`（清容器但保留 Keychain 登录）
→ replay。**不执行 uninstall 就会失败**：应用会记住上次的工作区并直接进入对话页，
剧本里的工作区选择步骤匹配不到。这一条是本轮反复踩到后才定下来的。

---

# 阶段 4：公式渲染

## 10. 交付的行为

采用**纯 Swift 排版子集**（`plan.md` 阶段 4 的候选 B），不引入 WebKit：

- 新增 `ChattyCore/MathText.swift`：LaTeX → Unicode 转换 + 分隔符规范化。
- `InlineRun.math` 与 `RichBlock.math` 两个新形态；`RichDocument.parse` 里
  `$…$`、`\(…\)` 成为行内公式，整段 `$$…$$`、`\[…\]` 成为居中 display 公式。
- `RichContentView` 用衬线斜体渲染行内公式、居中衬线渲染 display 公式，
  并带 `markdown.math` 无障碍标识。

覆盖范围：希腊字母、`\times \cdot \pm \le \ge \ne \approx \infty \sum \int`
等运算符、上下标（Unicode 上标/下标）、`\frac`、`\sqrt`、`\text`。

**三条设计原则**（都是踩出来的）：

1. **不丢内容**：无法识别的命令原样保留。`\unknowncmd{x}` 会显示出来，而不是消失。
2. **不改变数学含义**：`\frac{a+b}{2}` 渲染为 `(a+b)/2`。最初的实现输出 `a+b/2`——
   优先级被静默改错，比不渲染更糟。多操作数自动加括号。
3. **不可转换的上标不能塌陷**：`x^{ab}` 输出 `x^(ab)`。原来的 `x^{ab}` 会在收尾的
   去括号步骤里变成 `x^ab`，含义被改变。

**`\[…\]` 与 `\(…\)` 必须在 Markdown 解析前规范化**：`swift-markdown` 把 `\[` 当作
转义标点、还原成裸方括号，所以 LaTeX 定界符根本活不到块构建阶段。
`MathText.normalizeDelimiters` 先把它改写成 `$$` / `$`，这是这两种写法能工作的唯一原因。

## 11. 验证

| 检查 | 命令 | 结果 |
| --- | --- | --- |
| 包测试 | `swift test --package-path ios/Packages/ChattyKit --scratch-path .tools/ios-swift-build` | **95 tests / 0 failures**（+10 项公式测试） |
| 合成服务闭环 | `agent-device replay tests/device/ios/v3-chat-math.ad` | 12 步通过 |
| 视觉 | `evidence/06-math.png` | 行内 `a`、`b`、`α ≤ β`、`x₁ ≠ x₂`；居中 `c² = a² + b²` 与 `(a+b)/2 ≥ √(ab)` |

`scripts/ios-fixture.py` 新增 `math_sample` 控制开关，注入一条同时含三种定界符的回答，
用于上述截图与回归。

## 12. 已知限制

- 复杂公式（矩阵、多行对齐、大型运算符上下限、真正堆叠的分数）会退化为线性文本。
  这是选择候选 B 的代价，`spec.md §8` 的降级路径要求（失败时显示原文而不是空白）已满足。
- 没有 WebKit/KaTeX 的高保真度；若后续要求像素级对齐 DeepSeek 的公式排版，
  需要切到候选 A 并重新评估首屏成本。
