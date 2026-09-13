# Spec: iOS Mika 聊天体验对齐 DeepSeek iOS

- Change: `20260912-ios-deepseek-chat-alignment`
- 状态：**已定稿**（U1 / U2 / U3 已由用户确认，见 §3.1 / §10 / §4.2；本轮不实现）
- 目标形态：DeepSeek iOS App v2.5.x（2026-09-12 中国区 v2.5.1）
- 一手证据：`ds/cn1..cn5.png`、`ds/us1..us5.png`（App Store 官方截图，1290×2796 @3x）
- 引用约定：`[截图]` = 本次读图确认；`[取样]` = 从截图像素取样得到，需真机复核；
  `[推断]` = 由截图结构推断；`[未知]` = 未证实，进入 §14 清单。

---

## 1. 对齐原则

1. **对齐可观察的体验，不对齐实现细节。** DeepSeek 的 token 级流式、模型选择、
   联网检索在 Multica 上没有对应能力；规范只对齐用户能看到、能操作的部分，并把
   无法对齐的部分显式记录（§13），不做假控件（`decisions.md` J1）。
2. **不牺牲 Chatty 的既有价值。** Mika 身份、项目上下文与逐条消息项目快照、
   连续发送与队列、回执核对（`uncertain`）、双游标历史、离线草稿、受保护存储、
   动态红点与任务验收全部保留（`decisions.md` J4）。
3. **状态与失败先于美观。** 每个新增控件都必须定义「加载 / 空 / 失败 / 无权限 /
   离线」下的样子，以及是否可撤销。
4. **诚实文案。** 不写系统做不到的承诺（例如「已搜索到 17 个网页」这类 Multica
   没有的字段，见 J2）。

---

## 2. 视觉令牌

### 2.1 取证与取值

| 令牌 | 浅色 | 深色 | 来源 |
| --- | --- | --- | --- |
| `background`（页面底） | `#FFFFFF` | `[未知]` | `[取样]` us3/us5 屏幕内空白区定点取样全部 `#FFFFFF` |
| `surface`（输入卡片 / 卡片底） | `#FFFFFF` | `[未知]` | `[取样]` 输入框区域 |
| `surfaceMuted`（顶栏圆形按钮、附件按钮） | `#F2F2F2` | `[未知]` | `[取样]` cn2 附件三按钮、us3 顶栏按钮底 |
| `accent`（品牌强调） | `#4D6BFE`（App 内待真机取色） | 候选 `#6799FE`（同源 Web token） | 官方站点 CSS token `--ds-color-brand: #4d6bfe` + `[取样]` 观测蓝 `#3864FC`–`#406CFC` 同族 |
| `bubbleUser`（用户气泡填充） | `#EDF3FE` | `[未知]` | `[取样]` us3 与 cn4 用户气泡一致 |
| `chipActiveFill`（激活 chip 底） | `#EDF3FE` | `[未知]` | `[取样]` us3 激活 chip 与气泡同色 |
| `chipInactiveBorder` | `#E5E5E5`（1px） | `[未知]` | `[推断]` 裁切放大确认「深度思考 / 智能搜索」为白底胶囊 + 浅描边 |
| `textPrimary` | `#0F0F0F` | `[未知]` | `[取样]` cn5 助手正文最深处 |
| `textSecondary`（过程块标题与正文、元信息） | `#7D7F85` | `[未知]` | `[取样]` us3 的 `Thinking` 标题、us3 思考正文、cn4 的 `已思考（用时 90 秒）` 三处一致 |
| `separator` | `#E8E8E8` | `[未知]` | `[取样]` |

**深色模式是本次最大的未知**：`ds/` 里 10 张全部为浅色。研究阶段拿到了 DeepSeek
**官网** CSS 的深色 token（`bg-page #0A0A0A`、`text-primary #FFF`、
`text-description hsla(0,0%,100%,.56)`、`surface hsla(0,0%,100%,.06)`、
`brand #6799FE`，见 `evidence/research/deepseek-design-tokens.css`），但那是 **Web** 的
设计系统——同一份 token 的浅色 `bg-page` 是 `#f9f8f8`，而 App 实测是纯 `#FFFFFF`，
证明两套值不能混用。

因此规则是：**深色令牌优先使用系统语义色**（`.systemBackground` / `secondarySystemBackground`
/ `.separator` / `.label` / `.secondaryLabel`）；只有在拿到真机深色截图后，才允许把
Web token 的候选值正式写入。**不要凭空编造或直接照搬 Web 的深色 hex。**

### 2.2 形状与尺寸

| 元素 | 规格 | 来源 |
| --- | --- | --- |
| 用户气泡圆角 | 约 **12–14pt**（实测上边缘直线段两端各切 ≈33px；现有实现的 18pt 偏圆） | `[取样]` 像素推断，待真机确认 |
| 用户气泡右外边距 | 约 17pt | `[取样]` 实测 52px / 屏宽 1024px = 5% |
| 用户气泡最大宽度 | ≈ **77% 屏宽**，随内容收缩（不是固定宽度） | `[取样]` cn5/us5 实测 |
| 输入卡片圆角 | ≥ 24pt（近胶囊）/ 卡片式 | `[截图]` cn2/us3 输入卡片为整体大圆角容器 |
| chip 圆角 | 全圆角（胶囊） | `[截图]` |
| chip 高度 | 约 34–36pt，命中区 ≥ 44pt | `[推断]` + Apple HIG 命中区要求 |
| 顶栏圆形按钮 | 约 36–40pt 视觉尺寸，命中区 ≥ 44pt | `[截图]` + HIG |
| 按钮命中区 | ≥ 44×44pt | 沿用现有代码约定（`ChatScreen.swift` 多处 44） |
| 正文排版 | 约 17pt，行距 ≈1.43 倍 | `[取样]` 实测行距 73px |
| 过程块排版 | 约 14–15pt（明显小于正文），行距 ≈1.43 倍 | `[取样]` 实测行距 62–63px |
| 正文最大宽度 | 无气泡、占满内容宽度；iPad 上限 700pt 左右可读行长 | `[推断]` + §10 |
| 块间距 | 助手正文 → 下一条用户气泡 ≈22pt；用户气泡 → 过程块/正文 ≈26–33pt | `[取样]` 与现有 `LazyVStack(spacing: 24)` 接近，建议保留 24 |

### 2.3 `ChattyTheme` 的落地形态

现 `Theme.swift` 只有 `background / accent / onAccent / surface` 四个令牌
（`Theme.swift:3-18`）。本规范要求扩展为：

```swift
enum ChattyTheme {
    // 语义层（视图只引用这些）
    static let background, surface, surfaceMuted, separator
    static let textPrimary, textSecondary
    static let accent, onAccent
    static let bubbleUser, bubbleUserText
    static let chipActiveFill, chipActiveText, chipInactiveBorder
    static let danger   // 失败态，沿用系统红
}
```

规则：全部用 `UIColor { traits in ... }` 动态颜色，深浅色在同一处定义，**禁止**视图层出现
字面 hex 或 `Color.gray` 之类的零散取值。

---

## 3. 信息架构

### 3.1 外壳（`WorkspaceTabs`）—— 已定稿：保留三 Tab

**决策（2026-09-12，用户确认）**：本期保留 `动态 / Mika / 项目` 三个 Tab，
**只重写 Mika 页**（下表方案 B）。导航结构不动。

DeepSeek 是单一聊天面 + 历史抽屉，那是因为它只做一件事；Chatty 的产品价值有一半在
「动态」里跟踪全工作区事项进展（含他人创建的工作）。把「入口收敛」和「聊天重写」放进
同一个 change，会把范围从「重写一个页面」放大成「重构导航 + 重写聊天」，风险和验证成本
翻倍，而且入口收敛本身是一个独立的产品决策。

| 方案 | 结构 | 结论 |
| --- | --- | --- |
| **B（已采用）** | 保留 `动态` / `Mika` / `项目` 三 Tab，只重写 Mika 页 | ✅ 本期执行。零导航回归，聊天体验的对齐不受入口形态影响 |
| A | `动态` / `Mika` 两 Tab，项目目录进历史抽屉与项目选择面板 | ⏸ 推迟。如需要，另开 change 评估项目可达性 |
| C | 单一 Mika 入口 + 历史抽屉 | ❌ 不采用。事项进展可达性下降，与已确认的产品价值冲突 |

> **对「完全对齐」的影响**：这是本期**唯一有意不对齐**的信息架构项。DeepSeek 的聊天体验
> 本体（首屏、消息呈现、过程块、停止与队列、历史抽屉）全部照 §4–§9 对齐，只有底部
> Tab 形态不同。已登记在 §13 不可对齐项。

### 3.2 Mika 页顶栏

顶栏必须同时容纳「对齐 DeepSeek 的两个按钮」和「Chatty 已有的入口」。取舍如下：

| 位置 | 内容 | 行为 |
| --- | --- | --- |
| 左 | 历史图标（两条不等长横线，非系统 `line.3.horizontal`） | 打开历史会话。DeepSeek 官方 FAQ 称作「历史对话侧边栏」，iPhone 上是**覆盖式抽屉**（非 push、非 Tab）。Chatty 在 compact 与 regular 都用覆盖式抽屉（§10），保持一套交互 |
| 中 | 会话标题：`session.title`；为空时用首条用户消息截断（约 20 字）；新会话显示「新的对话」 | `.principal` 位置。点击不动作（V1，服务端不支持重命名） |
| 右 1 | `+` 圆形按钮（气泡内加号造型，非纯 `plus`） | 新建会话（等价现有 `⌘N` / `startNewSession()`）；草稿与附件语义见 §7.4 |
| 右 2 | 头像按钮（`profile.open`，现有实现） | 打开设置 Sheet，**不改** |

**右侧收纳规则（避免顶栏拥挤）**：现有 `newWindowButton`（`window.open`）从 iPhone 顶栏
**移除**，只在 regular 宽度保留；`⌘N`、菜单栏命令与已有 `.ad` 剧本的选择器
（`window.open`）继续有效。理由：DeepSeek 顶栏只有两个按钮，我们的顶栏要保持同等清爽；
多窗口本来就是 iPad/桌面语义。

顶栏背景：初始为 `background` 且无分割线；滚动后是否加毛玻璃与分割线 `[未知]`，
V1 采用滚动后 `.regularMaterial` + 1px `separator`（与 iOS 习惯一致，可回退为始终透明）。

两个顶栏按钮的造型：`[截图]` cn2/us2 显示二者都是**约 36–40pt 的圆形浅灰底按钮**
（`surfaceMuted` 底 + 深色图标），不是裸图标；命中区仍需 ≥ 44pt。

> 现有实现是 `.navigationTitle("Mika")`（`ChatScreen.swift:118`），与「标题＝会话名」
> 冲突，必须改为中心标题绑定会话。

### 3.3 入口的既有能力保留

- `和 Mika 继续`（`prepareIssueDiscussion`）仍切到 Mika 页并预填事项上下文草稿
  （`ChatModel.swift:276-286`）。
- 深链（`NativeLink`）、新窗口（`openWindow`）、菜单栏命令（`AppCommands`）语义不变；
  `⌘N` 继续映射为新建会话，并同步顶栏右侧按钮。

---

## 4. 会话历史

### 4.1 数据

服务端 `GET /api/chat/sessions` 已返回 `title / status / pinned / has_unread /
unread_count / last_message / created_at / updated_at / project_id`
（`scripts/chat-fixture.py:8-19`、`:218`）；iOS 侧 DTO 目前只解码
`id/agentId/title/status/updatedAt/projectId`（`Contracts.swift:43-50`），需补齐：

```swift
public struct ChatPreview { content, role, createdAt, failureReason }
public struct ChatSession {
    id, agentId, title?, status?, pinned?, hasUnread?, unreadCount?,
    lastMessage: ChatPreview?, createdAt?, updatedAt?, projectId?
}
```

### 4.2 列表规范

- 只显示 `agentId == mika.id && status != "archived"`；置顶（`pinned`）分组在最前，
  其余按 `updatedAt` 降序（复用 `ChatSessions` 的排序口径，`Contracts.swift:52-61`）。
- 行结构（两行）：
  - 第一行：标题（单行截断）+ 右侧时间（今天＝`HH:mm`，本周＝星期，更早＝`M月d日`）
  - 第二行：`last_message.content` 单行截断，前缀 `你：`（`role == "user"`）；
    `last_message.failureReason != nil` 时显示失败标记
  - 当前会话：标题用 `accent` 着色或行尾 `checkmark`（二选一，规范取 `checkmark`）
  - `unreadCount > 0`：标题后一个 `accent` 圆点（不显示数字，避免与动态红点计数混淆）
- 空态：说明性文案 + 「新建对话」按钮。
- **搜索**：DeepSeek iOS **有**历史搜索（官方版本记录 "Search your chat history" /
  「支持搜索历史对话」，2026-05 上线）。Multica 的 `GET /api/chat/sessions` 没有搜索参数，
  因此 **本地过滤标题与 `last_message.content` 是唯一可行实现**——这是实现限制，不是设计选择。
- **置顶（只读展示）**：若服务端返回 `pinned == true`，置顶会话排在列表最前
  （`Contracts.swift:52-61` 已有该排序口径）。**不提供置顶操作**（见下）。
- **下拉刷新抽屉**：官方 FAQ 也建议 App 端下拉刷新历史侧边栏；沿用 `.refreshable`。

#### 行操作：V1 **不做长按菜单**（U3 已定稿）

DeepSeek 的历史行操作是**长按**菜单（重命名 / 置顶 / 删除；官方 FAQ 逐字规定，无左滑、
无「…」三点菜单）。但 **Multica 服务端目前不支持写这些字段**：

| 操作 | 服务端现状 | 本期决定 |
| --- | --- | --- |
| 重命名 | `PATCH /api/chat/sessions/{id}` 只接受 `project_id`，不接受 `title`（`scripts/ios-fixture.py:211-221`；Android `ChatSessionUpdate` 同样只有 `project_id`） | **不提供**。标题继续由服务端生成 |
| 置顶 | 列表里有 `pinned` 字段但无写入接口 | **只读展示**，不提供操作 |
| 删除 | 合成服务与 Android API 均无 `DELETE /api/chat/sessions/{id}` | **不提供** |
| 归档 | 同上 | **不提供** |

**决策（2026-09-12，用户确认）**：按「不支持」保底。历史行是**纯选择行**——
点按即切换会话，**没有 `contextMenu`，没有滑动操作**。这与「不做假控件」原则一致
（`decisions.md` J1）：宁可少一个入口，也不给用户一个点了会失败的按钮。

> 后续：如果 Multica 补上这些接口，长按菜单按 DeepSeek 语义补齐即可（重命名 / 置顶 /
> 删除，删除必须二次确认且文案注明不可恢复）。届时只需给行加 `contextMenu`，不影响
> 本期结构。

### 4.3 切换语义

`open(session)` 必须（对齐 Android `ChatController.open`，`ChatController.kt:101-116`）：

1. 先把当前会话的草稿写入其键（`flushDraft()`）。
2. 切换 `session`，清空 `messages / pending / cursor / hasMore / traces / receiptRows`。
3. 加载会话的项目快照与消息首页（`syncMessages()`），重置 `followingBottom`。
4. 恢复目标会话自己的草稿与附件（§7.4）。
5. 已读：沿用 `markRead()`（`ChatModel.swift:185-192`），切换后即上报。

### 4.4 并发与竞态

- 切换会话期间若 `sending` 为真：**允许切换**，但发送循环按 `session.id` 归属结果；
  过期的回执不得写进新会话（现有 `syncMessages` 已有 `self.session?.id == session.id`
  守卫，`ChatModel.swift:164`，需在出站队列里补同样守卫）。
- 生成中的会话在列表里行尾显示一个小小的活动指示（避免用户以为卡死）。

---

## 5. 首屏欢迎态

取代现有 `ContentUnavailableView`（`ChatScreen.swift:56-62`）。

| 元素 | 规范 | 依据 |
| --- | --- | --- |
| 标识 | Mika 的身份符号（`sparkles`）居中，`accent` 着色，约 56pt | DeepSeek 用品牌 logo；Chatty 用 Mika 符号，不复制鲸鱼 |
| 问候 | **「想从哪里开始？」**（当前版本；**不带时段前缀**） | `[截图]` **2026-09-10 真机实拍**（鞭牛士/BiaNews 配图，已存 `evidence/research/empty-state-20260910-bianews.jpg`，本次已复核）。⚠️ App Store 商店截图里的「下午好，有什么可以帮到你？」是**滞后营销物料**，不要照抄——见下方说明 |
| 英文问候 | `[未知]`（商店截图为 "How can I help you?"，但中文已改版，英文是否同步改未知） | 列入 §14 复核清单 |
| 副文案 | 可省；若需要则「可以交办任务、追问进展，或从动态里继续未完成的事项。」 | 规范新增，保持诚实 |
| 建议 | `docs/ios-mika-design-plan.md` 的「两条轻量建议」：候选为「看看今天有哪些待处理」「汇总我负责项目的进度」；点击填入输入框（不直接发送） | 既有设计计划的待定项，规范给出定稿 |
| 输入区 | 首屏立即可输入，且输入区位置与有消息时一致（不因空态上移） | 目标「首屏可以直接输入」 |
| 附件面板 | 空态不默认展开；点 `+` 后展开为「照片 / 文件 / 拍照（若支持）」三段式 | `[截图]` cn2/us2 底部三按钮（Camera / Photo / Document）；`[截图]` us2 还显示最近照片缩略图横条带选择圈，Chatty 的 `photosPicker` 可在后续版本补这一段 |

**不做**：DeepSeek 的「深度思考 / 智能搜索」chip（J1）；不做模型选择器。

> **关于素材时效性（重要方法论结论）**：本项目的一手证据是 App Store 商店截图，
> 但商店截图是**营销物料，可能滞后于真机**。本次已经撞到一次：商店截图显示空态文案为
> 「下午好，有什么可以帮到你？」，而 2026-09-10 的真机实拍显示当前文案是
> **「想从哪里开始？」**（见 `evidence/research/empty-state-20260910-bianews.jpg`，
> 规格已按实拍更新）。
>
> 因此规范里所有 `[截图]` 标注的**文案类**结论都属于「营销物料级」置信度；
> 凡涉及**逐字文案**的实现，都要在真机截图到位后复核一遍。控件结构、布局、
> 颜色（如 `#EDF3FE` 气泡）在两套素材中一致，风险较低。

---

## 6. 消息时间线

### 6.1 用户消息

| 项 | 规范 |
| --- | --- |
| 对齐 | 右对齐；左侧留白 `minLength: 36`（沿用现有 `ChatScreen.swift:245`） |
| 容器 | `bubbleUser` 填充、`cornerRadius 18`、内边距 14（沿用现有几何，只换色） |
| 文本色 | `textPrimary`；`textSelection(.enabled)` |
| 附件卡片 | 位于气泡**上方**（`[截图]` cn5/us5）：白底圆角卡片 + `doc` 图标 + 文件名（截断）+ 副行 `大小`（如 `1.2MB`）；多于 3 个时折叠为「+N 个附件」 |
| 项目快照 | **保留**：气泡下方 `.caption` 显示 `· 项目名`（现有 `OutgoingRow` 语义），因为项目归属是 Chatty 的硬需求，不与 DeepSeek 冲突 |
| 排队态 | 气泡下方 `.caption` 显示「排队中 / 已提交 / 发送失败」等状态（现有 `OutgoingRow` 保留并改视觉） |

### 6.2 Mika 回答

- **全宽纯文本、无气泡、无头像**（`[截图]` us3/cn5 一致）。
- 正文块间距 14（沿用 `RichContentView` 现有）。
- 元信息行（`.caption`、`textSecondary`、正文下方）：耗时「用时 N 秒」；失败时用
  `ErrorNotice`（现有 `chat.failure.<id>` 标识保留）。
- `messageKind == "no_response"`：保留现有「本次执行没有返回文字回复。」的说明。

### 6.3 过程块（本次最关键的改动）

取代现有正文下方独立的 `DisclosureGroup("执行过程")`（`ChatScreen.swift:69-76`、`:282-301`），
改为**与消息绑定的过程块**，视觉参考 `[截图]` us3。

**状态机**

| 状态 | 触发 | 呈现 | 默认展开 |
| --- | --- | --- | --- |
| `thinking`（进行中） | `pending.taskId != nil` 或该 `taskId` 仍在流式 | 标题「正在思考」+ **向下 chevron `⌄`**；过程按抵达顺序追加 | 展开 |
| `done`（完成） | 该 `taskId` 出现最终 assistant 消息，或 `pending.taskId` 变为空 | 标题「已思考（用时 N 秒）」+ **向右 chevron `›`** | **自动折叠** |
| `expanded`（用户手动展开） | 用户点开已折叠的块 | 同上，chevron 向下 | — |
| `unavailable` | 会话历史中的旧消息，服务端无 trace | 不显示过程块（不显示空块） | — |

chevron 方向与文案已用一手截图裁切放大确认（`research.md §3`）；**两个状态的标题
与正文都用 `textSecondary`（`#7D7F85`）**，不是主文本色——这一点曾有多种二手说法，
以实测为准。

自动折叠对齐 DeepSeek v2.5.1 release notes「支持思考过程自动折叠」，且
`reduceMotion` 为真时不做折叠动画（直接切换）。

**步骤行映射（`decisions.md` J2）**

Multica 的 `TaskTrace` 只有 `type / tool / content / input / output`（`Contracts.swift`；
样本见 `scripts/chat-fixture.py:40-51`），没有「网页数」字段。映射规则：

| trace | 呈现 |
| --- | --- |
| `type == "thinking"` | 圆点项目符号 + `content`（灰字，`textSecondary`） |
| `type == "tool_use"` | 左侧图标行：`tool` 名映射为可读标签（内置映射表 + 未知时显示原始 `tool`），右侧 `content`（若有） |
| `type == "text"` | 与最终消息重复时**不重复显示**（该 trace 就是回答正文） |
| 其他 | 归入「其他步骤」，不隐藏但也弱化 |

时间线左侧有一条 1px `separator` 竖线连接步骤图标（`[截图]` us3 的 rail 造型）。

**信息密度**：过程块默认最多展示最近 6 步 + 「展开全部 N 步」；避免长任务把正文顶走。

### 6.4 消息操作

| 动作 | 触发 | 行为 | 依据 |
| --- | --- | --- | --- |
| 复制文本 | 长按（contextMenu） | `UIPasteboard`（保留现有实现） | 已有 |
| 复制代码 | 代码块右上按钮 | 已有（`RichContentView.swift:57`） | 已有 |
| 分享 | 长按菜单 | `ShareLink` / `UIActivityViewController` 分享纯文本 | DeepSeek 有分享 `[未知]` 具体项；Chatty 补上 |
| 引用到输入框 | 长按菜单「引用这条」 | 在草稿前插入 `> ` 前缀引用块 | DeepSeek 的「引用」`[未知]`，但成本低且有用 |
| 重新生成 | 长按 Mika 回答 | **不自动重发**；仅提供「把上面的问题填回输入框」 | 服务端无 regenerate 接口，自动重发会造成重复执行（§13） |
| 删除消息 | — | 不做（服务端无接口） | §13 |

---

## 7. 输入区

### 7.1 结构（自下而上）

```
[ 附件 chips 横向滚动 ]            ← 仅当 attachments 非空
[ 项目选择行 ]                     ← 保留（Chatty 硬需求）
[ 输入卡片 ]
   ├ 多行 TextField（1...8 行自适应）
   └ 底部按钮行：  [附件 +]              [发送 ↑ / 停止 ■]
```

- 输入卡片：`surface` 填充、大圆角、`padding(8)`，外层 `.padding(.horizontal, 12)`
  （沿用现有几何，`ChatScreen.swift:172-187`，只改令牌与按钮语义）。
- 右侧按钮位是**上下文相关**的：`[截图]` us3 / cn4 / cn5 空输入时显示「附件 ⊕ + 语音 ◉」，
  cn2（附件面板展开）显示「关闭 ⊗ + 语音 ◉」，**看不到常驻的发送按钮**——说明 DeepSeek
  在无输入时不显示发送。Chatty 没有语音（§13），因此该位在 Chatty 的映射为：
  无输入＝禁用态发送按钮（保持现有可见性，避免按钮突然出现造成布局跳动）、
  有输入＝可发送、生成中＝停止。这一差异记录在案，不与 DeepSeek 逐帧一致。
- 占位文案：`和 Mika 说点什么…` **保留**。DeepSeek 是「发消息或按住说话」；Chatty 没有
  按住说话（§13），照搬会承诺做不到的事。
- 项目选择：compact 用 `Menu`、regular 用 `popover`（沿用现有
  `projectPickerMenu` / `projectPickerPopover`，`ChatScreen.swift:205-226`），但视觉降级为
  输入卡片上方一行 `.caption` 级控件，避免抢输入框视觉重心。

### 7.2 发送 / 停止 双态按钮

| 条件 | 图标 | 动作 |
| --- | --- | --- |
| `canSend`（有文本或附件、非生成中） | `arrow.up` | `send()` |
| 生成中（`pending.taskId != nil`）且输入为空 | `stop.fill` | `stopCurrent()` |
| 生成中且输入非空 | `arrow.up` | 继续排队发送（现有队列语义，`supportsQueue`） |

- 按钮底色：可发送时 `accent`；禁用时 `surfaceMuted` + `textSecondary`。
- 停止按钮必须有 `.accessibilityLabel("停止生成")`，且点击后按钮立即变为「停止中」
  禁用态，收到结果后恢复（对齐 Android `stopCurrent` 的 `sending` 守卫）。
- **失败/超时不静默**：停止请求失败时保留顶部错误提示，并 `refresh()` 收敛真实状态
  （对齐 `ChatController.kt:287-288`）。

### 7.3 停止与队列操作的精确语义

对齐 Android 已验证语义（`ChatController.kt:272-362`），iOS 逐条实现：

| 操作 | 请求 | 成功后 | 失败 |
| --- | --- | --- | --- |
| 停止当前生成 | `POST /api/tasks/{id}/cancel` | 移除该条待回执消息；`cancelled_chat_message.restore_to_input == true` 时把内容合并回草稿（**追加不覆盖**）；`refresh()` | 顶部错误 + `refresh()` |
| 队列单条优先 | `POST /api/chat/sessions/{sid}/queued-tasks/{tid}/prioritize`，再对返回的 `active_task_id` 发 `cancel` | 同上移除被抢占的消息并回填草稿 | 失败 + `refresh()` |
| 队列单条编辑 | `POST /api/tasks/{tid}/cancel?expected_status=queued&chat_session_id={sid}&queue_action=edit` | 内容合并回草稿 | 409 时退化为无参数的 `cancel` 重试一次（任务已被领取） |
| 队列单条移除 | 同上，`queue_action=remove` | 仅移除，不回填 | 同上 |
| 清空队列 | `DELETE /api/chat/sessions/{sid}/queued-tasks` | 乐观移除队列消息后 `refresh()` | 失败 + `refresh()` |

草稿合并规则（`ChatController.kt:356-362`）：`已输入内容 + "\n\n" + 回填内容`，
附件按 `id` 去重追加。**任何队列编辑都不丢弃用户已输入内容。**

### 7.4 草稿按会话分键（必须改造）

现状：`ProtectedStorage.draft(account:workspace:agent:)`（`ProtectedStorage.swift:102-109`）
→ 一个 Agent 一份草稿。目标：按 `account/workspace/agent/session` 分键，新会话用
`session = "new"` 占位键。

迁移（`decisions.md` J6）：

1. 新增 `draft(account:workspace:agent:session:)` 与 `saveDraft(..., session:)`。
2. 首次进入某会话、新键不存在时，**仅当**旧键属于「最近一次会话」或会话还没建立时，
   把旧键内容作为该会话的初始草稿读出，然后写入新键并清空旧键；其余情况下旧键内容
   归属「最近一次会话」。
3. 迁移必须幂等：迁移后旧键置空，重复执行不产生副作用。
4. `DraftRecord` 结构不变（`text / uncertain / projectId / projectSelectionSet / outbox`），
   但 `outbox` 必须只包含当前会话的待发送消息；切换会话时不得把另一会话的 outbox 带过去。
5. 单测覆盖：迁移、幂等、两个会话互不串写、切换后回填。

---

## 8. 富文本与公式

| 能力 | 现状 | 目标 |
| --- | --- | --- |
| 标题 / 段落 / 列表 / 引用 / 表格 / 代码 | 已实现（`RichContentView`） | 视觉换成新令牌；代码块加语言标签 + 复制（已有） |
| 行内代码 | 已实现 | 背景改 `surfaceMuted` |
| **LaTeX 行内与 display 公式** | **降级为 `.literal` 纯文本**（`MarkdownContent.swift:39-41`、`RichContentView.swift:88`） | `[截图]` us3/cn4 确认 DeepSeek 渲染公式：display 居中、行内斜体衬线。需引入公式渲染（`ios/Packages/ChattyKit` 已有 `swift-markdown` 依赖；公式需新增解析与渲染方案，见 `plan.md` 阶段 4 的两个候选） |
| 图片 | 已实现（`InlineImageView`） | 视觉对齐，圆角与最大高度沿用 |
| 链接 | 已实现（`NativeLink` 内链解析） | 不变 |

公式至少要处理：`$...$` 与 `$$...$$`、`\(...\)`、`\[...\]` 四种定界符，以及
`MarkdownContent` 当前把整段当 `text()` 拼接导致公式内容被吞的问题。

---

## 9. 状态、失败与离线

沿用现有语义，只改呈现：

| 状态 | 呈现 |
| --- | --- |
| 加载首页 | 时间线中央 `ProgressView("读取对话…")` |
| 加载更早 | 顶部「加载更早消息」按钮 + 保持滚动锚点（沿用 `ChatScreen.swift:48-55`） |
| 断网 | 顶部一条轻量提示条（新），不遮输入；草稿仍可编辑 |
| `uncertain`（发送结果待确认） | 保留现有橙色区块与「刷新核对 / 核对结果」对话框（`ChatScreen.swift:29-36`、`:146-152`），文案与语义不变 |
| 队列 held | 保留「未发送的消息已保留 + 继续发送」 |
| 失败消息 | `ErrorNotice` + 长按菜单「重新填回输入框」 |
| 离线冷启动 | `OfflineDraftView` 语义不变；不授予发送权限 |
| 会话被归档/删除 | 保留现有 notice「原对话已归档或删除，下次发送将创建新的 Mika 对话。」 |

**新增**：会话切换、停止、队列操作都必须有「进行中」禁用态，避免重复点击造成双请求。

---

## 10. 自适应（iPhone / iPad）—— 已定稿：都走单栏

- **iPhone**：单栏，顶部栏 + 时间线 + 底部输入（本次主要目标）。
- **iPad（已定稿，U2）**：`[截图]` 官方 iPad 截图显示 DeepSeek 在 iPad 上使用与 iPhone
  **完全相同**的单栏布局（同一个左上角历史图标 + 右上角新建，没有分栏）。
  因此 Mika 页在 regular 宽度下**保持单栏**：历史仍是覆盖式抽屉（§3.2），
  正文与输入卡片**限宽约 700pt 居中**，避免长行难读。
- **理由与可逆性**：三 Tab 外壳下（§3.1）新增一个 `NavigationSplitView` 侧栏会同时改动
  Tab 内导航结构与 iPad 布局，属于本期的额外风险；而「限宽单栏」是纯增量改动，
  将来要加分栏是**追加**而不是返工。
- 既有 iPad 约束（popover 承载深链、可读列宽 420pt 最小 popover、`window.open`）
  不得回退；`window.open` 仅在 regular 宽度保留（§3.2）。

---

## 11. 无障碍与本地化

- 所有新控件 ≥ 44pt 命中区；历史行、chip、停止按钮、过程块标题均有
  `accessibilityLabel`；过程块用 `.accessibilityElement(children: .contain)` 并提供
  「过程，N 步，已折叠/已展开」的状态描述。
- Dynamic Type：时间线与输入卡片在 `XXXL` 下不截断标题、不遮挡输入。
- VoiceOver：会话切换后焦点落到顶部标题；发送/停止切换时播报状态变化。
- 文案：中文为主，英文串要同步（DeepSeek 英文版文案 `[截图]` us3/us5 已确认：
  `Thinking` / `Thought for 52 seconds ›` / `Found 17 web pages` / `Type a message or hold to speak`）。
  Chatty 现有代码大量硬编码中文，本轮不改本地化架构，只保证新增文案集中在一个
  `ChatCopy`/`DisplayText` 命名空间里，便于以后抽取。

---

## 12. DeepSeek → Chatty 映射表

| # | DeepSeek 模式（依据） | Chatty 落地 | 差距性质 |
| --- | --- | --- | --- |
| 1 | 左上历史图标 / 右上新建（`[截图]` cn3/us3） | §3.2 顶栏 | 直接对齐 |
| 2 | 顶部居中会话标题（`[截图]`） | 绑定 `session.title`，空时截断首条用户消息 | 直接对齐 |
| 3 | 问候语 + logo 空态（`[截图]` cn2） | §5 欢迎态（Mika 符号代替鲸鱼） | 品牌替换 |
| 4 | 用户右对齐淡蓝紫气泡（`[取样]` #EDF3FE） | §6.1 | 直接对齐 |
| 5 | 回答全宽纯文本、无头像（`[截图]`） | §6.2 | 直接对齐 |
| 6 | 「正在思考」→「已思考（用时 N 秒）」自动折叠（`[截图]` cn4 + v2.5.1 release notes） | §6.3 状态机 | 语义对齐，数据源换成 `TaskTrace` |
| 7 | 过程步骤行 + favicon 药丸（`[截图]` us3） | 步骤行 + 工具标签，**无 favicon/网页数** | 数据不支持（J2） |
| 8 | 输入卡片 + 胶囊 chip 行（`[截图]`） | §7.1 输入卡片；**无 chip** | 数据不支持（J1） |
| 9 | 附件卡「拍照/相册/文件」（`[截图]` cn2） | 「照片 / 文件」；拍照需权限与确认 | 部分对齐 |
| 10 | 文件卡（doc 图标 + 名称 + 大小）（`[截图]` cn5） | §6.1 附件卡 | 直接对齐 |
| 11 | LaTeX 公式渲染（`[截图]` cn4/us3） | §8 新增 | 需新增渲染能力 |
| 12 | 停止生成（服务端 `POST /api/tasks/{id}/cancel`） | §7.2 / §7.3 | 能力已有，iOS 未接 |
| 13 | 队列优先 / 清空（服务端 `queued-tasks`） | §7.3 | 能力已有，iOS 未接 |
| 14 | 会话历史列表与切换（`[截图]` 入口 + 服务端字段） | §4 | 能力已有，iOS 未接 |
| 15 | 逐字流式输出 | **不对齐** | 服务端无 token 流（§13） |
| 16 | 深度思考 / 智能搜索开关 | **不对齐** | 服务端无参数（§13） |
| 17 | 语音「按住说话」 | **不对齐** | 无转写服务（§13） |
| 18 | 图片理解 / 视觉模式 | **不对齐** | 本轮范围外（§13） |
| 19 | 重新生成 / 编辑重发 | **部分**：只回填输入框 | 无接口，避免重复执行 |
| 20 | 模型选择（快速/专家/识图） | **不对齐** | Mika 单 Agent 模型由服务端决定 |
| 21 | 历史是左上角唤出的**侧边栏抽屉**，可下拉刷新（官方 FAQ 原文） | §3.2 / §4 | 直接对齐（compact 覆盖式抽屉） |
| 22 | 历史行操作是**长按**菜单：重命名 / 置顶 / 删除（官方 FAQ；无左滑、无「…」三点菜单） | §4.2 **本期不做行操作**（服务端不支持写 `title`/`pinned`/删除）；置顶仅只读排序 | 暂不对齐，服务端补齐后可按原语义加上 |
| 23 | 历史**搜索**（2026-05 上线，官方版本记录） | §4.2 本地过滤 | 实现限制（服务端无搜索参数） |
| 24 | 生成中「打断并发送」，输入不被禁用/排队（Web 端 diff 证据，iOS 未验证） | §7.2 保留 Chatty 队列语义 | **差异保留**，不为了对齐丢队列 |
| 25 | 分享：长按**模型回复**或回复下方「分享」按钮（官方 FAQ） | §6.4 长按菜单「分享」 | 直接对齐 |
| 26 | 未公告的次数配额（重新生成/编辑/提问/回答上限） | **不对齐** | 不引入任何次数配额 |

---

## 13. 不可对齐项（必须写进交付说明）

1. **逐字流式**。现有传输是 WebSocket `task:message`（过程事件）+ 最终消息，没有 token
   增量。用户看到的将是一段段过程步骤 + 完整回答一次到达。若要真正逐字，需服务端新增
   SSE/WS token 通道——本 change 明确排除（`decisions.md` D4）。
2. **思考/搜索开关**。没有请求参数，做开关即假控件（J1）。
3. **网页检索与引用**。Mika 运行时的工具调用可能包含检索，但 Multica 没有 citation
   数据结构，无法呈现 DeepSeek 那样的引用角标与来源列表。
4. **语音输入与图片理解**：见映射表 17/18。
5. **重新生成**：没有 regenerate 接口；自动重发会造成重复执行和重复计费/重复副作用。
6. **会话重命名 / 置顶 / 删除**：服务端没有写入接口（U3 已定稿，§4.2）。本期历史行是
   纯选择行，没有长按菜单。
7. **底部 Tab Bar**：DeepSeek 是单入口 + 历史抽屉；Chatty 保留
   `动态 / Mika / 项目` 三 Tab（U1 已定稿，§3.1）。这是本期唯一有意保留的**信息架构**
   差异——理由是产品价值而非技术限制。聊天面本体的对齐不受影响。
8. **深色配色**：缺少一手深色截图（§14）。

---

## 14. 未知项与真机复核清单

| # | 未知 | 复核方式 |
| --- | --- | --- |
| 1 | **App 内**深色完整配色（背景 / 气泡 / chip / 文本 / 分隔线） | 真机深色截图各一张（空态 + 对话 + 历史）；在此之前用系统语义色 |
| 2 | 品牌蓝在 **App 内**的精确值（当前按官方 Web token `#4D6BFE` 实施） | 真机取色 |
| 3 | 历史列表的具体行结构（是否显示预览、时间格式、置顶分组样式） | 真机截图（抽屉打开态） |
| 4 | **回复**的长按菜单完整项（复制 / 重新生成 / 点赞点踩 / 选择文本） | 真机长按截图 |
| 5 | 停止按钮的形态与位置（已知存在，且支持「继续」） | 真机生成中截图 |
| 6 | 滚动到底部按钮的形态 | 真机长对话截图 |
| 7 | 自动折叠的精确触发时机与折叠动画 | 真机录屏 |
| 8 | 会话标题的生成规则（服务端生成 vs 客户端截断） | 观察新会话标题出现时机 |
| 9 | 键盘行为（是否 `scrollDismissesKeyboard`、输入卡片是否上移） | 真机录屏 |
| 10 | `error` / `empty` / `offline` 下 DeepSeek 的呈现 | 真机断网截图 |

**已在调研中收敛、不再是未知**：iPad 单栏（官方 iPad 截图使用与 iPhone 相同的左上角菜单
图标，判定为单栏 + 抽屉）；历史是否有搜索（有，2.1.1 起）；历史行是否支持左滑（没有，
官方只描述长按）；停止生成是否存在（存在，且有「继续」）。

上述 1–10 不影响主体实现（除 #1 会决定深色令牌），可以并行推进；规范中的
`[未知]` 项在实现前必须收敛或显式降级为「沿用系统语义色」。
