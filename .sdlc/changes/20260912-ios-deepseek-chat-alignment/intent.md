# Intent: 重写 iOS 端 Mika 聊天体验，与 DeepSeek iOS App 完全对齐

- Author: Benjamin（用户指令）+ 规划会话
- Status: **规范已定稿**（U1/U2/U3 已确认；本轮仍不含产品代码，实施另行开 change）
- Stage: Plan
- Related: [iOS 动态与 Mika 连续发送](../20260910-ios-activity-mika-flow/intent.md)、
  [Android 对齐 iOS](../20260911-android-ios-alignment/intent.md)、
  [iOS 键盘工具栏移除](../20260912-ios-remove-chat-keyboard-toolbar/intent.md)、
  [iOS Mika 对话体验设计预览计划](../../../docs/ios-mika-design-plan.md)
- Last updated: 2026-09-12

## 1. 问题陈述

**谁受影响**：用 iPhone/iPad 上的 Chatty iOS 客户端与 Mika 交办的成员。他们同时还要在
「动态」里跟踪全工作区（含他人创建）的事项进展。

**今天失败在哪里**（均为代码事实，行号见 §5）：

1. **没有会话历史**。`ChatModel` 只能恢复「上次所在会话」（`ChatSessions.restored`
   → `latest`），`⌘N` 之外无法查看、切换、搜索、重命名任何历史会话。用户在 App 里
   找不回上周和 Mika 的对话。Android 端因此被明确要求「不新增会话列表」（见
   `20260911-android-ios-alignment/spec.md` 边界与 `review.md` residual scope）。
2. **首屏不是入口，是空态**。新会话只有 `ContentUnavailableView("和 Mika 开始工作")`，
   没有问候、没有建议、没有可发现的下一步；用户要自己猜「项目从哪选、附件怎么加」。
3. **生成中不可打断**。服务端已有 `POST /api/tasks/{id}/cancel`，Android 已实现
   停止生成 / 队列优先 / 删除队列 / 清空队列；iOS 只能等轮询结束，且队列只能整体
   「继续发送」，不能单条优先或移除。
4. **草稿按 Agent 单份存储**。`ProtectedStorage.draft(account:workspace:agent:)`
   一个工作区只有一份草稿；切换会话会让未发送内容跟随到另一个会话。Android 已按
   `workspace:session` 分键（`ChatController.draftKey()`）。
5. **思考过程与正文割裂**。过程是正文下方一个 `DisclosureGroup("执行过程")`，只有
   展开才按 `taskId` 拉取，没有「正在思考 / 已思考（用时 N 秒）」这种与消息绑定的
   可折叠过程块，长回答的默认视图因此要么只有一行摘要、要么正文被过程挤走。
6. **消息没有操作**。只有 `contextMenu { 复制文本 }`；没有重新生成、没有分享/导出、
   没有单条重试，失败消息只能靠顶部横幅理解。
7. **富文本不足以承载回答**。`MarkdownContent`/`RichDocument` 只解析块结构，
   LaTeX 公式会被降级成 `.literal` 纯文本；没有 DeepSeek 那种居中 display 公式。
8. **视觉语言与目标不一致**。`ChattyTheme` 是深绿强调色 + 灰绿背景；DeepSeek 是
   近白底 + 蓝紫（约 `#4D6BFE`）强调色 + 淡蓝紫用户气泡。用户明确要求对齐视觉语言。

**期望的可观察结果**：iPhone 上打开 Chatty，Mika 页是「首屏即可输入」的对话界面；
左上角能打开历史会话列表并切换、搜索、新建、删除；发一条消息后能看到
「正在思考」随时间推进、结束后自动折叠为「已思考（用时 N 秒）」并可展开；
生成中能停止；用户消息是右对齐淡蓝紫气泡、Mika 回答是全宽纯文本且公式正确渲染；
配色与 DeepSeek iOS 一致（近白底 + 蓝紫强调色），深浅色都成立。

**约束**：Mika 身份（`system_key == "mika"`）不可替换；项目上下文与逐条消息项目快照
必须保留；连续发送 / 本机顺序提交 / 服务端队列 / 回执核对 / 双游标历史 / 离线草稿
与受保护存储（ThisDeviceOnly、排除备份、`completeFileProtection`）语义不得回退；
动态红点与任务验收不属于本次范围但必须继续可用。

**成功示例**：用户从「动态」看到一条待验收事项，点「和 Mika 继续」进入 Mika 页，
首屏直接带上事项上下文；发送后先看到过程时间线，回答到达后过程折叠为一行
「已思考（用时 N 秒）」；此时点左上角历史，能看到今天这条会话标题（服务端生成），
切到上周会话后草稿各自独立；返回今天会话时输入框内容还在。

## 2. 本轮范围

**In scope（本轮交付物，不含产品代码）**

- `research.md`：DeepSeek iOS App（v2.5.x）聊天体验的深度调研报告，含一手截图证据、
  网络来源、置信度分级与「必须真机复核」清单。
- `spec.md`：对齐规范——视觉令牌、信息架构、逐屏规范、组件规范、逐字文案（zh-Hans
  + en）、状态机与失败行为、与现有 Chatty 能力的映射表和**不可对齐项**。
- `plan.md`：分阶段实施计划、涉及文件、测试与验证命令、风险与回滚。
- `decisions.md`：本轮已确认的范围决策与依据。

**Out of scope（明确排除，避免范围蔓延）**

- 逐字流式输出（token streaming）：Multica 服务端只提供 WebSocket `task:message`
  过程事件与最终消息，没有 SSE / token 增量通道。本轮以过程时间线 + 停止 + 队列
  能力实现「可观察上最接近」的体验，不承诺逐字流。
- 「深度思考」「智能搜索」开关：服务端没有对应请求参数，Mika 运行时自行决定是否思考
  与检索。**不做假开关**——在规范中给出诚实的替代呈现（只读状态标识或完全不显示）。
- Android / Web / macOS 端改动：会话历史与视觉语言会在 iOS 落地后再次造成跨端差异，
  Android 跟进另开 change（见 `decisions.md`）。
- 语音输入（「按住说话」）、图片理解、附件面板的「拍照/相册/文件」三段式之外的相机
  实时拍摄能力：依赖尚未确认的服务端与权限支持，本轮只在规范中标注差距。
- 发布、TestFlight、版本号与 App Store 资产更新。
- 真机验收（iPhone 物理设备、VoiceOver 人工体验）：计划中列出，但不在本轮执行。

## 3. 现有资产与依赖

| 资产 | 位置 | 与本次的关系 |
| --- | --- | --- |
| iOS 聊天界面 | `ios/Chatty/ChatScreen.swift`（367 行） | 主要重写对象 |
| iOS 聊天模型 | `ios/Packages/ChattyKit/Sources/ChattyCore/ChatModel.swift`（427 行） | 主要重写对象（会话切换、停止、队列、草稿分键） |
| 会话/消息契约 | `ChattyCore/Contracts.swift` | 需补 `pinned/has_unread/unread_count/last_message/created_at` |
| 草稿与受保护存储 | `ChattyCore/ProtectedStorage.swift` | `draft()` 需改为按会话分键（含迁移） |
| 主题令牌 | `ios/Chatty/Theme.swift`（22 行） | 需扩充为完整令牌集（深浅色 + 强调/气泡/描边） |
| 富文本渲染 | `ios/Chatty/RichContentView.swift` + `ChattyCore/RichDocument.swift` | 需补 LaTeX / 公式与代码块规范 |
| 实时连接 | `ChattyCore/RealtimeConnection.swift` | 已提供 `task:message` 过程事件，停止/队列复用 |
| 服务端能力基线 | `scripts/chat-fixture.py`：`POST /api/tasks/{id}/cancel`、`queued-tasks`（GET/DELETE）、`queued-tasks/{id}/prioritize`、`/api/chat/sessions` 带 `last_message/pinned/unread_count` | **iOS 尚未使用的现成能力**，本轮计划接入 |
| iOS 专用合成服务 | `scripts/ios-fixture.py` | 验收剧本需扩展历史/停止/队列场景 |
| 跨端参考实现 | `android/feature-chat/.../ChatController.kt`（`open/newChat/stopCurrent/sendQueuedNow/editQueued/removeQueued/clearQueued`） | 已有可直接对齐的行为语义与状态机 |
| 设备验收剧本 | `tests/device/ios/*.ad`、`scripts/ios-dev-loop.sh` | 新验收剧本的落点 |
| 核心测试 | `ios/Packages/ChattyKit/Tests/ChattyCoreTests/ClientFlowTests.swift`（42 项）等 | 契约与流程回归，需同步更新 |
| 一手设计证据 | `ds/cn1..cn5.png`、`ds/us1..us5.png`（1290×2796，App Store 官方截图） | 调研与规范的主要视觉依据 |
| 调研原始素材 | `.sdlc/changes/20260912-ios-deepseek-chat-alignment/evidence/research/`（19 个文件，含 810 行 UI 结构报告、948 行交互调研、450 条 App Store 评论、官方版本时间线、官方站点设计 token CSS） | `research.md` 每条断言的来源；provenance 见同目录 `README.md` |
| 既有设计预览 | `docs/ios-mika-design-plan.md` | 本轮的上游输入；其「待设计反馈确定」问题由本 spec 回答 |

## 4. 成功标准（可观察、可验证）

规范阶段（本轮）：

| 编号 | 标准 | 检查方式 |
| --- | --- | --- |
| P1 | 每条 DeepSeek 行为断言都有来源或截图标注，且区分「已证实 / 截图推断 / 未知」 | 通读 `research.md`，未知项全部进入「必须真机复核」清单 |
| P2 | 规范对每个 DeepSeek 模式都给出 Chatty 的落地方案或明确的「不可对齐」结论与理由 | `spec.md` 的映射表逐行可查，无「照搬」字样 |
| P3 | 计划的每一步都绑定具体文件、测试与验证命令 | `plan.md` 阶段表逐行可查 |

实施阶段（后续 change 执行时验收，本轮只登记）：

| 编号 | 标准 | 检查方式 |
| --- | --- | --- |
| A1 | 首屏直接可输入；左上角历史、右上角新建会话；无会话时显示问候与 Mika 标识 | 合成服务 + agent-device 截图 |
| A2 | 可列出、搜索、切换、新建会话；会话标题取自服务端 `title`，缺失时用首条用户消息截断。**重命名/置顶/删除取决于 U3**：服务端不支持时不显示对应菜单项，绝不做点了会失败的按钮 | iOS 合成服务断言 `/api/chat/sessions` 调用与页面快照 |
| A3 | 每个会话独立草稿：切换会话再返回，未发送文字与附件仍在原会话 | XCTest（ProtectedStorage 迁移 + ChatModel 流程） |
| A4 | 生成中显示「正在思考」并可展开过程时间线；点击停止调用 `POST /api/tasks/{id}/cancel` 且消息回到输入框 | 合成服务记录 `cancel` 调用；UI 快照 |
| A5 | 回答到达后过程自动折叠为「已思考（用时 N 秒）」，可展开；`reduceMotion` 下不播放动画 | UI 快照 + 无障碍断言 |
| A6 | 队列单条优先 / 移除 / 清空分别调用 `prioritize` / `DELETE queued-tasks` / 清空，回执与真实结果一致 | 合成服务 `__calls` |
| A7 | 用户消息右对齐淡蓝紫气泡，Mika 回答全宽无气泡；深浅色令牌均通过对比度检查 | 截图 + 令牌单测 |
| A8 | LaTeX 行内与 display 公式正确渲染，代码块带语言标签与复制按钮 | 固定样本快照测试 |
| A9 | 既有能力零回退：连续发送、项目快照、回执核对、离线草稿、受保护存储、动态红点 | 现有 72 项 Swift 测试全绿 + 既有 `.ad` 剧本 |
| A10 | 无假控件：界面不存在无服务端语义的开关 | 人工检查 + 记录在 `spec.md` 的「不可对齐项」 |

## 5. 代码事实索引（供实现阶段引用）

| 事实 | 证据 |
| --- | --- |
| 无会话历史入口，只恢复上次会话 | `ChatModel.swift:65-70`、`Contracts.swift:52-73`、`ProtectedStorage.swift:139-147` |
| `⌘N` 是唯一的新建会话方式 | `ChatModel.swift:98-112`、`AppCommands.swift:49` |
| 首屏是空态而非欢迎态 | `ChatScreen.swift:56-62` |
| 无停止生成；队列只能整体继续 | `ChatScreen.swift:37-43`、`ChatModel.swift:302-311` |
| 草稿按 Agent 单份 | `ProtectedStorage.swift:102-109`、`ChatModel.swift:208-211` |
| 过程与消息绑定但默认折叠为独立行 | `ChatScreen.swift:69-76`、`:282-301` |
| 消息操作只有复制文本 | `ChatScreen.swift:268-272` |
| 公式无渲染（降级为 literal） | `MarkdownContent.swift:27-42`、`RichContentView.swift:88` |
| 视觉令牌只有 3 个语义色 | `Theme.swift:3-18` |
| 服务端已支持停止 / 队列管理 | `scripts/chat-fixture.py:150-177` |
| 服务端会话已带 `pinned/has_unread/unread_count/last_message` | `scripts/chat-fixture.py:8-19`、`:218` |
| Android 已实现停止 / 优先 / 移除 / 清空 / 按会话草稿 | `android/feature-chat/.../ChatController.kt:101-124`、`:272-362` |

## 6. 未决问题

**已全部收敛（2026-09-12 规范定稿阶段，用户确认）**：

1. ~~是否保留「项目」Tab~~ → **保留三 Tab**，本期只重写 Mika 页；入口收敛推迟到独立
   change（`decisions.md` D5、`spec.md §3.1`）。
2. ~~历史会话的删除语义~~ → **按服务端不支持处理**：历史行是纯选择行，无长按菜单；
   `pinned` 字段只读排序（`decisions.md` D7、`spec.md §4.2`）。
3. ~~iPad 呈现~~ → **单栏定稿**，正文与输入限宽约 700pt 居中（`decisions.md` D6、`spec.md §10`）。

**唯一剩余**：

4. **真机复核（U4）**：DeepSeek 截图来自 App Store 营销物料，**已证实会滞后于真机**
   （空态文案已经从「下午好，有什么可以帮到你？」改为「想从哪里开始？」，
   `spec.md §5` 已按 2026-09-10 实拍改正）。仍缺的是 **App 内深色配色**（唯一
   阻塞令牌定稿的项，缺省走系统语义色）、逐字文案复核，以及历史行排版、回复的
   长按菜单项、停止按钮形态、键盘行为（逐项见 `spec.md §14`）。
