# Plan: iOS Mika 聊天体验对齐 DeepSeek iOS

- Change: `20260912-ios-deepseek-chat-alignment`
- 上游：`intent.md`（范围）、`spec.md`（规范）、`decisions.md`（已确认决策）
- 本轮状态：**计划阶段，不执行**。下面每个阶段都是后续实现 change 的工作项。
- 关键前提：`scripts/generate-ios-project.py` 是 Xcode 工程的唯一生成源
  （`ios/README.md:40`）。新增宿主 Swift 文件后必须重新生成工程并一起提交。

---

## 0. 阶段总览

| 阶段 | 目标 | 依赖 | 预估改动量 | 可独立验收 |
| --- | --- | --- | --- | --- |
| 1 | 契约与受保护存储底座 | — | 2 文件 + 测试 | 是（单测） |
| 2 | ChatModel 会话模型与停止/队列 | 1 | 1 文件（大）+ 测试 | 是（单测 + 合成服务） |
| 3 | 视觉令牌与主题 | — | 1 新文件 + `Theme.swift` | 是（单测 + 截图） |
| 4 | 富文本与公式 | — | 3 文件 + 测试 | 是（快照） |
| 5 | Mika 页重写（顶栏 / 欢迎态 / 时间线 / 过程块 / 输入区） | 2,3,4 | 2–3 文件 | 是（合成服务 + 截图） |
| 6 | 会话历史界面 | 2,3 | 1 新文件 + 3 文件接线 | 是（合成服务 + 截图） |
| 7 | 合成服务与验收剧本扩展 | 5,6 | 2 脚本 + 2 `.ad` | 是（回放） |
| 8 | 回归、无障碍与真机清单 | 5,6,7 | 文档 + 证据 | 是（全套命令） |

阶段 1–4 可以并行；5 依赖 2/3/4；6 只依赖 2/3，可与 5 并行。

---

## 阶段 1：契约与受保护存储底座

**目标**：把 V1 的 DTO 与草稿存储升级到能承载会话历史与按会话草稿，且升级不丢数据。

### 改动

1. `ios/Packages/ChattyKit/Sources/ChattyCore/Contracts.swift`
   - 新增 `ChatPreview`。
   - `ChatSession` 补 `pinned / hasUnread / unreadCount / lastMessage / createdAt`
     （服务端字段已存在：`scripts/chat-fixture.py:8-19`、`:218`）。
   - 新增 `QueuedChatTask.id` 已有；补 `PrioritizeQueuedResponse`、`CancelTaskResponse`、
     `CancelledChatMessage`（对齐 `android/core-model/.../ChatModels.kt:33-36`）。
   - `ChatSessions` 增加 `ordered(for:)`：置顶优先、`updatedAt` 降序，返回分组所需的排序
     （保留现有 `latest` / `restored` 语义不动）。
2. `ios/Packages/ChattyKit/Sources/ChattyCore/ProtectedStorage.swift`
   - `draft` / `saveDraft` 增加 `session:` 维度；旧键保留只读兼容。
   - 新增一次性迁移 `migrateDraft(...) -> DraftRecord?`：把旧 `agent` 级草稿归属到
     「最近一次会话」键，随后清空旧键；幂等（规范 §7.4）。
3. `ios/Packages/ChattyKit/Sources/ChattyCore/OutgoingMessage.swift`
   - 增加 `sessionId` 字段（`Codable` 容错：旧记录缺省为 `nil`，视为「无归属」，
     迁移时归入旧键会话）。

### 测试

- `ios/Packages/ChattyKit/Tests/ChattyCoreTests/ContractTests.swift`
  - 新字段解码（含缺省、`null`、未知字段）、`ordered(for:)` 排序与置顶分组。
- `ios/Tests/SimulatorContractTests.swift` 或新 `StorageMigrationTests`（宿主 XCTest，
  因为涉及 Keychain/文件保护）
  - 迁移正确、幂等、两会话互不串写、`uncertain` 与 `outbox` 归属正确。

### 验证

```sh
swift test --package-path ios/Packages/ChattyKit --scratch-path .tools/ios-swift-build
```

**退出条件**：新旧草稿格式都能读；迁移测试全绿；无 UI 改动。

---

## 阶段 2：ChatModel 会话模型、停止与队列

**目标**：模型层具备会话列表、切换、停止生成、队列单条操作，且不破坏连续发送与回执核对。

### 改动（`ChatModel.swift`）

| 新增/修改 | 说明 | 参考 |
| --- | --- | --- |
| `sessions: [ChatSession]` | `initialize()` / `refresh()` 时更新；不复用只读 `latest` | `Contracts.swift:52-61` |
| `open(_ session: ChatSession) async` | 切换会话：落盘当前草稿 → 清空时间线 → 载入目标会话消息与草稿 | `ChatController.kt:101-116` |
| `flushDraft()` | 切换前把当前草稿写到当前会话键 | 新增 |
| `stopCurrent() async` | `POST /api/tasks/{id}/cancel`；成功移除本地消息、`restore_to_input` 时合并回草稿、`refresh()` | `ChatController.kt:272-291` |
| `sendQueuedNow(_ taskId:) async` | `prioritize` → 对返回的 `active_task_id` 发 `cancel` | `ChatController.kt:292-316` |
| `editQueued(_:)` / `removeQueued(_:)` | `cancel?expected_status=queued&chat_session_id=..&queue_action=edit|remove`；409 退化为无参 `cancel` | `ChatController.kt:317-340` |
| `clearQueued() async` | 乐观移除 + `DELETE /api/chat/sessions/{id}/queued-tasks` | `ChatController.kt:341-354` |
| 出站队列按会话归属 | `flushOutbox()` 只处理 `item.sessionId == session?.id`；切换后不推进旧会话队列 | 新增（修补现有风险） |
| `mergeRestoredDraft(_:attachments:)` | 「已输入 + `\n\n` + 回填」，附件按 id 去重 | `ChatController.kt:356-362` |

- `startNewSession()`（`ChatModel.swift:98-112`）改为：先落盘当前会话草稿，再进入
  `session = nil` + `draftKey = "new"` 状态；草稿与附件保留在新会话输入框（与现有注释
  的语义一致），但**不再覆盖**旧会话草稿。
- 保留 `uncertain` 的全部现有语义（`ChatModel.swift:217-237`）；`stopCurrent` 与
  `uncertain` 互斥时给明确提示，不静默。

### 测试

- `ClientFlowTests.swift` 扩展（现有 42 项必须全部保持通过）
  - 会话切换：消息、pending、cursor、草稿、项目快照各自独立。
  - 停止：请求发出 → 消息移除 → 草稿回填不覆盖。
  - 队列：prioritize / edit / remove / clear 的请求形状与乐观更新回滚。
  - 409 退化路径。
  - 出站队列跨会话不串。

### 验证

```sh
swift test --package-path ios/Packages/ChattyKit --scratch-path .tools/ios-swift-build
```

**退出条件**：新流程单测全绿，现有 42 项无回归。

---

## 阶段 3：视觉令牌与主题

**目标**：把 `ChattyTheme` 从 4 个令牌扩到 `spec.md §2.3` 的完整语义集，深浅色集中定义。

### 改动

1. 新增 `ios/Chatty/ChatTheme.swift`（或直接把 `Theme.swift` 扩为完整实现）
   —— 令牌取值见 `spec.md §2.1`，**深色值在 U-DeepSeek 深色截图到位前使用系统语义色**
   （`systemBackground` / `secondarySystemBackground` / `separator` / `label` /
   `secondaryLabel`），不编造 hex。
2. `ios/Chatty/Theme.swift`：保留 `AppTab`，`ChattyTheme` 迁到新文件并保留同名 API，
   避免一次性大改所有调用点（可先并存再逐个替换）。
3. `scripts/generate-ios-project.py` 重新生成工程（新增宿主文件）。

### 测试

- 新增 `ChatThemeTests`（宿主 XCTest）：深浅色下关键文本/背景对比度 ≥ 4.5:1（正文）与
  ≥ 3:1（大字号/图形）；令牌在 `.light` / `.dark` trait 下解析成功。

```sh
source scripts/ios-env.sh
xcodebuild -project ios/Chatty.xcodeproj -scheme ChattyFixture -configuration Debug \
  -destination "platform=iOS Simulator,id=$IOS_SIMULATOR_ID" \
  -derivedDataPath "$CHATTY_IOS_DERIVED_DATA" CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test
```

**退出条件**：对比度单测通过；旧视图仍可编译。

---

## 阶段 4：富文本与公式

**目标**：回答正文达到 DeepSeek 的排版水平，公式不再被降级成纯文本。

### 改动

1. `ChattyCore/MarkdownContent.swift`：把 `text()` 的粗暴拼接改为保留结构；
   抽出公式定界符（`$...$`、`$$...$$`、`\(...\)`、`\[...\]`）为独立节点。
2. `ChattyCore/RichDocument.swift`：新增 `RichBlock.math(display: String)` 与
   `InlineRun.math(String)`。
3. `ios/Chatty/RichContentView.swift`：渲染公式（display 居中、行内随文）；
   代码块、表格、引用改用新令牌。

### 公式渲染方案（实现前二选一，需在开工时确认）

| 方案 | 做法 | 代价 |
| --- | --- | --- |
| A（推荐） | 用 `WKWebView` + 本地打包 KaTeX，公式区域按需渲染为静态高度块 | 引入 WebKit 依赖、内存与首屏成本；需处理深色与 Dynamic Type |
| B | 纯 Swift 排版（`AttributedString` + 自绘分数/上下标），只支持常见子集 | 无新依赖，但公式覆盖率低，遇到复杂公式仍有降级路径 |

无论哪种方案，**必须有降级路径**：渲染失败时显示原始 LaTeX 文本而不是空白。

### 测试

- 新增 `FormulaRenderingTests`：定界符解析（含转义、跨行、未闭合）。
- 快照样本加入 `scripts/ios-fixture.py` 的固定消息（已有 `rich` 样本，扩展公式段）。

**退出条件**：给定样本中行内与 display 公式都不再是纯文本；解析测试全绿。

---

## 阶段 5：Mika 页重写

**目标**：`ChatScreen` 按 `spec.md §3–§9` 重构，这是本轮最大的一块。

### 拆分（避免单个巨型 View）

| 文件 | 职责 |
| --- | --- |
| `ios/Chatty/ChatScreen.swift` | 组装：顶栏 + 时间线 + 输入区；保留既有 `.task` 命令注册与附件选择器 |
| `ios/Chatty/ChatWelcomeView.swift`（新） | 首屏欢迎态（§5） |
| `ios/Chatty/ChatProcessBlock.swift`（新） | 过程块状态机与步骤行（§6.3） |
| `ios/Chatty/ChatComposer.swift`（新） | 输入卡片、附件 chips、项目选择、发送/停止双态（§7） |
| `ios/Chatty/ChatMessageRow.swift`（新） | 用户气泡 / Mika 全宽 / 附件卡 / 元信息 / 长按菜单（§6） |

### 必须保留的既有行为

- `accessibilityIdentifier`：`chat.messages`、`chat.draft`、`chat.send`、`chat.older`、
  `chat.pending`、`chat.latest`、`chat.error`、`chat.notice`、`chat.attach`、
  `chat.projectPicker`、`chat.dropTarget`、`chat.resumeQueue`、`chat.uncertain`、
  `chat.acknowledge`、`compose.remove.<id>`、`message.<id>`、`chat.failure.<id>`、
  `trace.<taskId>`、`chat.suggestion`、`chat.outgoing.<id>`、`chat.projectPopover`。
  **新增**：`chat.history`、`chat.newSession`、`chat.title`、`chat.stop`、
  `history.list`、`history.row.<id>`、`history.search`、`chat.process`。
- 滚动跟随、`chat.latest` 悬浮按钮、`scrollDismissesKeyboard`、`defaultScrollAnchor(.bottom)`
  （`ChatScreen.swift:80-104`）。
- 拖放附件（`DroppedAttachment`）、`fileImporter`、`photosPicker`、附件校验。
- `.refreshable` 下拉刷新。
- 键盘工具栏保持移除状态（CLE-97）。

### 测试

- 既有 `.ad` 剧本 `tests/device/ios/v1-core.ad`、`v1-workspaces.ad` 必须仍通过
  （其中对 Mika 页的断言若因标题/Tab 变化失效，需要更新选择器并记录原因）。
- 新增截图证据：欢迎态、生成中（过程展开）、生成结束（过程折叠）、历史列表、
  深色模式（若 U-DeepSeek 截图到位）。

**退出条件**：合成服务下走通 `spec.md` A1/A4/A5/A7/A8/A10 的检查点。

---

## 阶段 6：会话历史界面

### 改动

1. 新增 `ios/Chatty/ChatHistoryView.swift`：列表 / 搜索 / 空态 / 当前会话标记 /
   未读圆点 / 切换与新建（§4.2）。
2. `WorkspaceTabs.swift`：Mika 页顶栏加历史与新建按钮；compact 用 sheet，
   regular 用侧栏或 popover（§3.2）。
3. `AppCommands.swift`：`⌘N` 继续映射新建会话；补「显示历史」命令与快捷键。
4. **导航不动**（U1 已定稿为三 Tab，`decisions.md` D5）：本阶段只给 Mika 页加顶栏按钮
   （历史左、新建右，`spec.md §3.2`），保持 `动态 / Mika / 项目` 与 Tab 状态恢复不变。
   `window.open` 仅在 regular 宽度保留。

### 测试

- `SceneStateTests.swift` 扩展：窗口恢复时回到同一会话（已有 lastSession 语义）。
- 新增 `.ad` 剧本 `tests/device/ios/v3-chat-history.ad`：打开历史 → 切换会话 →
  返回 → 草稿仍在。

**退出条件**：A2/A3 检查点通过。

---

## 阶段 7：合成服务与验收剧本

**关键发现**：`scripts/ios-fixture.py` 以 `importlib` 加载并**继承** `scripts/chat-fixture.py`
的 API 类（`scripts/ios-fixture.py:18-27`、`:46`），因此
`POST /api/tasks/{id}/cancel`、`GET/DELETE /api/chat/sessions/{id}/queued-tasks`、
`queued-tasks/{id}/prioritize`、`/api/chat/sessions` 的 `last_message/pinned/unread_count`
**已经可用**。本阶段主要是补数据场景与剧本，不是重新实现协议。

### 改动

1. `scripts/ios-fixture.py`
   - 多会话样本：确保 `SESSIONS` 至少 3 个（含置顶、归档、未读）且各带不同的
     `last_message`；`__control` 增加会话相关开关（如 `session_switch`）。
   - 思考过程样本：`SLOW`/`slow` 场景下发 `thinking` → `tool_use` → `text` 多步
     `task:message`，用于验证过程块（`chat-fixture.py:40-51` 已有骨架，`finish()`）。
   - `cancel` 审计：`/__calls` 增加 `cancels` 数组（任务 id、query 参数），供验收断言。
2. `tests/device/ios/v3-chat-history.ad`、`tests/device/ios/v3-chat-stop-queue.ad`
   —— 稳定的语义选择器，不用录制器生成的 UIKit 层级（沿用 `ios/README.md:68` 的约定）。
3. `scripts/ios-v1-replay.sh` 是否需要接入新剧本：仅当新剧本替换旧流程时才改，
   否则保持旧回放可追溯。

### 验证

```sh
python3 -m py_compile scripts/ios-fixture.py scripts/chat-fixture.py
python3 scripts/ios-fixture.py &          # 或按 ios-dev-loop.sh fixture 的约定
scripts/ios-dev-loop.sh fixture
```

**退出条件**：`/__calls` 能证明 cancel / prioritize / DELETE queued-tasks 各被调用一次，
且时间线过程块出现「正在思考 → 已思考（用时 N 秒）」。

---

## 阶段 8：回归、无障碍与交付证据

1. 全量命令：

```sh
# 核心单测
swift test --package-path ios/Packages/ChattyKit --scratch-path .tools/ios-swift-build

# 宿主 UITest + XCTest（合成服务）
source scripts/ios-env.sh
xcodebuild -project ios/Chatty.xcodeproj -scheme ChattyFixture -configuration Debug \
  -destination "platform=iOS Simulator,id=$IOS_SIMULATOR_ID" \
  -derivedDataPath "$CHATTY_IOS_DERIVED_DATA" CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test

# 通用 iPhone 编译检查（不安装）
xcodebuild -project ios/Chatty.xcodeproj -scheme Chatty -configuration Debug \
  -destination "generic/platform=iOS" CODE_SIGNING_ALLOWED=NO build

# 重定向安全回归
python3 scripts/ios-check-redirect.py
```

2. 证据落盘：`.sdlc/changes/<实现 change>/evidence/` 下按运行分目录，保存
   `result.json`、页面快照 XML、截图与 `/__calls` 导出（沿用
   `.sdlc/archive/iterations/v2/evidence/*/` 的既有格式）。
3. 无障碍：VoiceOver 人工走查（欢迎态、历史、过程块、停止按钮）；Dynamic Type
   `XXXL` 截图；对比度单测已覆盖。
4. 真机矩阵（不在本轮）：iPhone 物理设备上的键盘、长消息滚动、连续发送、断网重试、
   后台恢复、深浅色；iPad 单栏/分栏复核。

---

## 文件清单

| 文件 | 类型 | 阶段 |
| --- | --- | --- |
| `ios/Packages/ChattyKit/Sources/ChattyCore/Contracts.swift` | 修改 | 1 |
| `ios/Packages/ChattyKit/Sources/ChattyCore/ProtectedStorage.swift` | 修改 | 1 |
| `ios/Packages/ChattyKit/Sources/ChattyCore/OutgoingMessage.swift` | 修改 | 1 |
| `ios/Packages/ChattyKit/Sources/ChattyCore/ChatModel.swift` | 修改 | 2 |
| `ios/Packages/ChattyKit/Sources/ChattyCore/MarkdownContent.swift` | 修改 | 4 |
| `ios/Packages/ChattyKit/Sources/ChattyCore/RichDocument.swift` | 修改 | 4 |
| `ios/Chatty/Theme.swift` / `ios/Chatty/ChatTheme.swift` | 修改/新增 | 3 |
| `ios/Chatty/ChatScreen.swift` | 重写 | 5 |
| `ios/Chatty/ChatWelcomeView.swift` | 新增 | 5 |
| `ios/Chatty/ChatProcessBlock.swift` | 新增 | 5 |
| `ios/Chatty/ChatComposer.swift` | 新增 | 5 |
| `ios/Chatty/ChatMessageRow.swift` | 新增 | 5 |
| `ios/Chatty/ChatHistoryView.swift` | 新增 | 6 |
| `ios/Chatty/RichContentView.swift` | 修改 | 4/5 |
| `ios/Chatty/WorkspaceTabs.swift` | 修改 | 6 |
| `ios/Chatty/AppCommands.swift` | 修改 | 6 |
| `ios/Chatty.xcodeproj/project.pbxproj` | 由生成器改写 | 3/5/6 |
| `scripts/generate-ios-project.py` | 可能修改 | 3/5/6 |
| `scripts/ios-fixture.py` | 修改 | 7 |
| `tests/device/ios/v3-chat-history.ad`、`v3-chat-stop-queue.ad` | 新增 | 7 |
| `ios/Packages/ChattyKit/Tests/ChattyCoreTests/*` | 修改/新增 | 1/2/4 |
| `ios/Tests/SimulatorContractTests.swift` 或新测试文件 | 修改/新增 | 1/3 |

> 注意：工作区当前已有未提交的 `ios/Chatty.xcodeproj/project.pbxproj`、
> `scripts/generate-ios-project.py` 与 `.gitignore` 改动。实施前先确认它们的归属，
> 避免把无关改动混进本次提交（`docs/sdlc-workflow.md` 第 5 条）。

---

## 风险与回滚

| 风险 | 影响 | 缓解 |
| --- | --- | --- |
| `ChatScreen.swift` 一次重写过大，回归面广 | 高 | 阶段 5 拆成 5 个文件、按 checkpoint 分批提交；每批跑一次 `.ad` 核心剧本 |
| 草稿迁移写坏用户数据 | 高 | 迁移只读旧键 + 写新键 + 最后清旧键；幂等；先用 `ChattyFixture` 的两账号工作区验证 |
| 出站队列跨会话污染 | 高 | 阶段 2 先加 `sessionId` 归属与单测，再动 UI |
| 公式方案引入 WebKit 后拖慢首屏 | 中 | 方案 A 只在存在公式时才创建 WebView；保留方案 B 作为降级 |
| 会话历史让 Android 再次脱齐 | 中 | 已确认 D3：另开 Android change；在本 change 的 `evidence.md`/交付说明里登记 |
| 深色配色无一手来源 | 中 | 先用系统语义色；拿到真机截图再替换令牌，视图零改动 |
| 视觉改动导致既有 `.ad` 选择器失效 | 中 | 保持 `accessibilityIdentifier` 不变（§阶段 5 清单） |
| 停止/队列接口在真实后端行为与合成服务不一致 | 中 | 合成服务与 Android 已验证契约同源（`chat-fixture.py`）；真机验证时优先核对 `cancelled_chat_message` 字段 |

**回滚**：本次为设计阶段，无代码可回滚。实施阶段的每个阶段都是独立可提交单元；
若阶段 5 出问题，可只回滚 UI 文件而保留阶段 1–2 的模型与存储能力（向后兼容）。

---

## 后续（本 change 之外）

1. **Android 重新对齐**：会话历史、按会话草稿、过程块自动折叠、新令牌。
   依据 `decisions.md` D3。
2. **服务端依赖**：会话删除/归档（U3）、token 流式通道、思考/搜索参数（若产品要开关）。
3. **跨端**：macOS 端是从 iOS 移植的（`macos/Chatty/*`），会话历史与令牌需要同步评估。
4. **`docs/ios-mika-design-plan.md` 的收编**：本轮 spec 已覆盖其「可观察验收标准」，
   实施完成后应把该文档标记为已被本 change 取代，避免两份规范并存。
