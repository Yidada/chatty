# iPad / iPadOS 自适应兼容体验设计规范

- Issue：[CLE-84](https://multica.ai) — Chatty iOS：iPad / iPadOS 自适应兼容体验设计
- 项目：Chatty（唯一可写仓库 `Yidada/chatty`）
- 基线提交：`2dd46ae`（main，2026-09-10 核对）
- 状态：设计交付，等待 Benjamin 验收；本变更不含产品代码

本文只做设计与拆分，不实现。文中的「实测」指本机模拟器可复现的观察，「推断」指依据 Apple 平台规则得出、尚未实测的结论，「待复核」指必须在实现阶段的真机矩阵中验证的项。

---

## 1. 现状核对（代码事实）

### 1.1 目标设备族、方向、最低系统版本

| 事实 | 证据 |
| --- | --- |
| 全部 target 仅 iPhone：`TARGETED_DEVICE_FAMILY = "1"` | `ios/Chatty.xcodeproj/project.pbxproj:242`、`:264`、`:421`、`:444`、`:533`、`:556`（Chatty / ChattyFixture / ChattyFixtureTests 共 5 处配置） |
| 平台仅 iPhone：`SUPPORTED_PLATFORMS = "iphoneos iphonesimulator"` | `project.pbxproj:243`、`:265`、`:422`、`:445`、`:534`、`:557` |
| 最低系统 iOS 26.0 | `project.pbxproj:245`、`:267`、`:424`、`:447`、`:536`、`:559`；`ios/Packages/ChattyKit/Package.swift:6` `platforms: [.iOS("26.0"), .macOS(.v15)]` |
| Info.plist 只声明竖屏，且未声明 iPad 方向键 | `ios/Config/Chatty-Info.plist`（`UISupportedInterfaceOrientations` = 仅 `UIInterfaceOrientationPortrait`）；`ios/Config/ChattyFixture-Info.plist` 同 |
| 未声明 `UIRequiresFullScreen` | 两个 Info.plist 均无该键；即当前只靠「仅 iPhone + 仅竖屏」避免分屏 |
| 不支持多场景：`UIApplicationSupportsMultipleScenes = false` | 两个 Info.plist 的 `UIApplicationSceneManifest` |
| 上述配置的**唯一生成源**是脚本，不是手改工程 | `scripts/generate-ios-project.py:36`（settings）与 `:56`（info 字典）；`ios/README.md` 明确「生成器是配置来源」。任何改动必须改脚本并重新生成，否则会被覆盖 |

**结论（已验证）**：当前是 iPhone-only、竖屏锁定、单场景工程。

### 1.2 iPad 上的当前实际表现（实测）

在 iPad Pro 13-inch (M5) / iPadOS 26.5 模拟器上安装 iPhone-only 的 `ChattyFixture`：

- 系统分配给该 bundle 的窗口为 **635 × 1376 pt**（屏幕为 1032 × 1376 pt），即按 iPhone 比例等比放大后居中（左右各留 199 pt），是 iPad 对 iPhone-only App 的兼容（letterbox 缩放）呈现。
- 截图证据：`evidence/00-before-ipad-iphone-only-compat.png`（2064 × 2752 px = 1032 × 1376 pt @2x；应用区经像素分析为 x=199、宽 635 pt）。
- 因此 D1 中「iPad 上当前是兼容模式缩放还是不可安装」的答案是：**可安装、以 iPhone 兼容模式缩放运行，不是原生 iPad 体验，也不能进入分屏/Slide Over 的自适应布局语义**。

### 1.3 导航结构与屏幕清单（代码事实）

| 层级 | 结构 | 位置 |
| --- | --- | --- |
| App 根 | 单一 `WindowGroup`，无 `Commands`（无菜单栏、无快捷键） | `ios/Chatty/ChattyApp.swift:5-14` |
| 会话根分支 | `restoring` / `WorkspaceTabs` / `OfflineDraftView` / `WorkspacePicker` / `LoginView` | `ios/Chatty/AppBootstrap.swift:51-57` |
| 主导航 | `TabView` 三 Tab：动态 / Mika / 项目；每个 Tab 内再包一层 `NavigationStack` | `ios/Chatty/WorkspaceTabs.swift:19-35` |
| 二级 | 动态 → 事项详情；项目 → 事项列表 → 事项详情（`NavigationLink` 推入同一 `NavigationStack`） | `ActivityScreen.swift:31-49`；`ProjectsScreen.swift:15-16`、`:58-59` |
| 模态 | 设置 Sheet（`WorkspaceTabs.swift:45-50`）、深链资源 Sheet（`:51-61`）、工作区切换 Sheet（`SettingsScreen.swift:35-47`）、附件 Quick Look Sheet（`AttachmentViews.swift:66`）、图片 `fullScreenCover`（`:37`、`:69`）、退出 `confirmationDialog`（`SettingsScreen.swift:48-51`）、两个 `alert`（`ChatScreen.swift:130-137`、`WorkspaceTabs.swift:62`） |
| 旧壳 | `ShellView`（对话/项目/设置三 Tab + 未连接空态）已不在导航路径上 | `ios/Chatty/ShellView.swift:8-28`（无调用方） |
| Fixture 壳 | `FixtureRootView` 三 Tab（对话/项目/设置，历史 P0 壳） | `ios/Fixture/FixtureRootView.swift:30-61` |

完整屏幕清单（实现时逐屏对照）：登录、离线草稿、工作区选择、动态（新进展/待处理）、事项详情、项目列表、事项列表、Mika 对话、设置、设置子页（Runtimes/Agents/Squads 列表与详情）、工作区切换、附件与图片预览、深链资源（事项/项目/附件）。

### 1.4 现存的尺寸假设

- **全仓没有任何 size class / idiom / 屏幕尺寸判断**：`horizontalSizeClass`、`verticalSizeClass`、`userInterfaceIdiom`、`UIScreen`、`UIDevice` 在 `ios/Chatty`、`ios/Fixture`、`ios/Packages` 内 grep 结果为空。这是本次改造最有利的起点：没有旧的宽度分支需要迁移。
- 唯一自适应构造是消息内快捷操作：`ChatScreen.swift:207` `ViewThatFits(in: .horizontal)`。
- 固定尺寸（均为图标/命中区，不随宽度变化，属于可接受集合）：`ActivityScreen.swift:36`（32×32 图标底）、`:38`（6×6 未读点）、`ProjectsScreen.swift:19`（38×38）、`WorkspaceTabs.swift:78`（32×32 头像）、`ChatScreen.swift:168`/`:175`（44×44 按钮）、`RichContentView.swift:82`（3pt 引用条）、`AttachmentViews.swift:24`（`maxHeight: 300` 图片）。
- 依赖竖屏/窄屏的布局假设：`ChatScreen.swift:71` `.defaultScrollAnchor(.bottom, for: .initialOffset)`、`:77-82` 滚动几何跟随底部、`:89-95` 右下悬浮「最新消息」、`AppBootstrap.swift:101` 登录页 `.padding(.top, 40)` 手写安全区。
- 无硬编码宽度上限：`ChatScreen.swift:42/49/192/212/290`、`ActivityScreen.swift:47/54`、`ProjectsScreen.swift:70/105/122/126/150` 全部是 `maxWidth: .infinity`，在 iPad 全屏下会被拉伸到整行——这是登录页与详情页需要处理的主要视觉问题。

### 1.5 与 CLE-78 的冲突面

核对结果（`multica issue runs`，2026-09-10）：**CLE-78 当前无分支、无 PR、无运行中的任务**，状态 `todo`，负责人同为 iPad 应用工程师。因此当前没有实际冲突，只有**预期的合并面**：

| 预期被 CLE-78 改动的文件 | 与本设计的重叠 | 合并顺序建议 |
| --- | --- | --- |
| `ChatScreen.swift:142-149` composer 的项目选择 `Menu` | 本设计要在常规宽度把它改成 popover / 侧栏选择器 | **CLE-78 先落**，本设计在其选择器组件之上加呈现方式分支 |
| `ChatModel.swift:218-221`、`:228-233`、`:180-183`（选择状态、持久化） | 本设计不改状态与持久化契约 | CLE-78 先落；本设计只读 |
| `WorkspaceTabs.swift`（若 CLE-78 增加「关联项目」入口/Sheet） | 本设计要在同一文件加 `.tabViewStyle(.sidebarAdaptable)` | CLE-78 先落，再改 TabView 修饰符（改动点不同，冲突极小） |
| `ChatScreen.swift` 屏幕内 sheet/popover 呈现 | `fullScreenCover` 图片预览的呈现方式调整 | 无顺序要求，但两个 Issue 不要同时改同一段修饰符链 |

**约定**：实现阶段（新 Issue）开工前必须重跑一次 `multica issue runs` 与分支检查；如 CLE-78 已合并，先 rebase 再动 `ChatScreen.swift`。

---

## 2. 设计基线（承接 Issue 已定默认）

| 编号 | 决策 | 本设计的细化 | 结论依据 |
| --- | --- | --- | --- |
| D1 | 一个通用 App：沿用 `Chatty` target 与 `ai.chatty.ios`，设备族扩为 iPhone + iPad；不新建 iPad App、不复制 UI | `TARGETED_DEVICE_FAMILY` 改 `1,2`（仅改脚本再生成）；`ChattyFixture` 同步，保证模拟器矩阵可测；不加 iPad 专属 target、不加 `~ipad` 启动图 | §1.1、§1.2；Issue 非目标 |
| D2 | 以 size class 驱动，不用 `userInterfaceIdiom` | 全仓目前零 size-class 引用（§1.4），新增分支统一用 `@Environment(\.horizontalSizeClass)`；禁止 `UIDevice.current.userInterfaceIdiom` 与硬编码宽度阈值 | §1.4 |
| D3 | 紧凑宽度零回归 | 现有紧凑布局原样保留；`.sidebarAdaptable` 在 compact 下仍是底部 Tab（实测，见 §3） | §4 实测 |
| D4 | 单一状态源：窗口尺寸/分屏/Stage Manager/旋转都不重建会话 | 现有状态均挂在 `WorkspaceModel`（`WorkspaceModel.swift:23-43`）上，随 `SessionRootView` 的 `.id(workspace.id)`（`AppBootstrap.swift:53`）只在切换工作区时重建——**旋转与窗口变化不会重建**，D4 天然成立。唯一风险是多场景下 `WorkspaceTabs.swift:72` `.onDisappear { model.pause() }` 会被误触发，见 §7 风险 R3 | `AppBootstrap.swift:53`、`WorkspaceTabs.swift:69-72` |

---

## 3. 宽度档位矩阵

单位 pt；`hSC` = horizontal size class。**实测**列为模拟器像素/无障碍树实测，**推断**列为平台规则推导，**待复核**列由实现 Issue 的设备验收补全。

| # | 档位 | 典型宽度 | hSC | `.sidebarAdaptable` 表现 | 设计响应 | 证据状态 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | iPhone 紧凑 竖 | 402（iPhone 17 实测 1206×2622 px @3x = 402 × 874 pt） | compact | 底部 Tab，双栏结构不出现 | 保持现状，零改动 | 实测（`evidence/04`、`06`） |
| 2 | iPhone 紧凑 横 | 874×402 | compact | 底部 Tab | 保持现状；键盘避让沿用 `safeAreaInset`（`ChatScreen.swift:105`） | 推断 |
| 3 | iPhone Plus/Max 横 | ~932×430 | **regular** | 会转为顶部 Tab / 可展开侧栏 | 不特判机型，接受与 Apple 自家 App 一致的侧栏；必须在真机复核排版不塌 | 待复核（R2） |
| 4 | iPad 全屏 竖 | 1032（实测） | regular | 顶部 Tab 栏 + 「Toggle sidebar」；展开后为 238 pt 侧栏列 | 竖屏默认顶部 Tab；详情列给出空态引导 | 实测（`evidence/02`、`03`） |
| 5 | iPad 全屏 横 | 1376 | regular | 侧栏常驻（238 pt）+ 详情 | 双栏主形态 | 推断（同 §4 的侧栏几何） |
| 6 | iPadOS 26 窗口（默认/遗留） | 635×1376（实测） | compact | 底部 Tab | 必须完整可用；不能假设 iPad 一定是常规宽度 | 实测（`evidence/01`、`05`） |
| 7 | Split View 1/2（13"） | ~678–688 | 以系统为准（13" 通常仍为 regular，小尺寸 iPad 为 compact） | 由 hSC 决定，两种都正确 | 不做宽度硬判断 | 待复核（R6） |
| 8 | Split View 1/3 | ~320–350 | compact | 底部 Tab | 与 iPhone 紧凑一致 | 待复核（R6） |
| 9 | Slide Over | ~320（可 320–375 拖拽） | compact | 底部 Tab | 与 iPhone 紧凑一致 | 待复核（R6） |
| 10 | Stage Manager 自定义 | 320–1376 连续 | 随宽度切换 | 由 hSC 决定 | 全程不硬编码列宽，用系统默认分割行为 | 待复核（R6） |
| 11 | iPad mini 竖 / 横 | 744 / 1133 | regular（竖屏贴近阈值） | 顶部 Tab / 侧栏 | 复核 744 pt 下顶部 Tab 是否换行 | 待复核 |

**待复核项的缺口与提供方**：第 3、5、6（横向）、7–11 行需要多窗口/分屏/Stage Manager 的真机或模拟器手势操作，本轮无法用 `xcrun simctl` 脚本化（`simctl` 无分屏/窗口缩放接口，`agent-device` 拒绝系统边缘手势）。由实现 Issue 的设备验收清单提供，验收人：iPad 应用工程师，复核对象：Benjamin。

---

## 4. 实验验证（已完成，实验代码已还原）

为验证 D2/D3 的结构结论，本轮做过一次**最小实验性改动**（已全部还原，diff 见 `evidence/experiment.diff`）：

1. `scripts/generate-ios-project.py:36`：`TARGETED_DEVICE_FAMILY` → `'1,2'`；
2. `scripts/generate-ios-project.py:56`：`UIApplicationSupportsMultipleScenes` → `True`，两个 Info.plist 增加四个方向与 `UISupportedInterfaceOrientations~ipad`；
3. `ios/Chatty/WorkspaceTabs.swift`：在 `TabView` 上增加 `.tabViewStyle(.sidebarAdaptable)`；
4. fixture-only（`#if CHATTY_FIXTURE`）尺寸档位探针：`--design-lab-regular` 强制 regular，用于在没有宽窗口时验证常规宽度分支。

实测结论：

| 观察 | 结果 | 证据 |
| --- | --- | --- |
| 635×1376 pt 窗口（compact） | 仍是**底部 Tab 栏**，交互与 iPhone 一致 → D3 成立，紧凑宽度零回归 | `evidence/01-ipad-compact-635pt-bottom-tabs.png` |
| 1032×1376 pt 全屏（regular，fresh bundle id） | 竖屏为**顶部 Tab 栏 + Toggle sidebar**；点击后出现 **238 pt 侧栏列**（cells x=26、宽 238、y=131.5/175.5，出现「Hide Sidebar」） | `evidence/02-ipad-fullscreen-regular-top-tabs.png`、`evidence/03-ipad-regular-sidebar-visible.png` |
| iPhone 17（compact） | 底部 Tab 栏，与改造前一致 | `evidence/04`、`06` |
| 窗口几何 | **iPadOS 26 按 bundle id 记忆窗口几何**：iPhone-only 版本留下的 635×1376 窗口，在改为通用 App 后仍被沿用；换一个全新 bundle id 重新安装后，窗口才恢复为全屏 1032×1376 | 见下 §7 R1 |

> 实验去留：`ChattyApp.swift` 的尺寸探针与 `.sidebarAdaptable` 均未合入。配置项与壳改造由 §8 的实现 Issue 按本文档正式落地。

---

## 5. 逐屏适配表

判定口径：**改** = 实现阶段需要动代码；**不改** = 布局已自适应，只需纳入验收；**理由**列说明为什么。

| 屏幕 | 位置 | 判定 | 理由与要求 | 影响文件 |
| --- | --- | --- | --- | --- |
| 登录 | `AppBootstrap.swift:62-108` | 改 | 内容列 `maxWidth: .infinity`（`:84`、`:93`），iPad 全屏下输入框会拉满 1032 pt。常规宽度需限制可读列宽（建议 `min(560, 可用宽度)`）并垂直居中；网格/背景保持 | `AppBootstrap.swift` |
| 离线草稿 | `AppBootstrap.swift:146-166` | 改 | 同登录页，`ScrollView` + 手写 `padding(24)`（`:161`）在宽屏下不可读 | `AppBootstrap.swift` |
| 工作区选择 | `AppBootstrap.swift:110-133` | 不改 | `List` 系统自适应；regular 下自动成为可读宽度的列表列 | — |
| 主导航壳 | `WorkspaceTabs.swift:19-35` | 改 | 增加 `.tabViewStyle(.sidebarAdaptable)`；保持三个 `Tab` 声明不变（`Tab(_:systemImage:value:)` 与 `sidebarAdaptable` 兼容，已实测） | `WorkspaceTabs.swift` |
| 壳的暂停语义 | `WorkspaceTabs.swift:69-72` | 改 | `.onDisappear { model.pause() }` 在多窗口/分屏切换时会误停轮询，需改为由 `scenePhase` + 场景维度判断（见 R3） | `WorkspaceTabs.swift` |
| 动态（新进展/待处理） | `ActivityScreen.swift` | 不改 | `ScrollView` + `LazyVStack`，宽度自适应；`padding(.horizontal, 24)`（`:17`、`:57`）在宽屏可接受 | — |
| 事项详情 | `ProjectsScreen.swift:93-188` | 改 | 正文 `padding(24)` + `maxWidth: .infinity`（`:150`）在 1032 pt 下每行过长；常规宽度限制正文可读列宽。`NavigationLink` 推入行为保持单栏 | `ProjectsScreen.swift` |
| 项目列表 / 事项列表 | `ProjectsScreen.swift:4-91` | 不改 | `List` + `searchable`（`:77`）系统自适应；`.searchable` 在 regular 下会进入导航栏搜索位，需纳入验收 | — |
| Mika 对话 | `ChatScreen.swift:20-181` | 改 | ① 详情列空态：`messages.isEmpty && agent != nil` 已有 `ContentUnavailableView`（`:51-53`），需确保在双栏未选会话时也给出引导而不是空白栏；② composer 在最小可用窗口（320 pt 宽、Stage Manager 最小尺寸）下保持可输入、可发送（`:164-178`）；③ 键盘避让沿用 `safeAreaInset(edge: .bottom)`（`:105`），需在 iPad 分屏 + 硬件键盘两种情况下复核 | `ChatScreen.swift` |
| 项目关联入口（与 CLE-78 共享） | `ChatScreen.swift:142-149` | 改 | 常规宽度用 `.popover`（锚定项目按钮）或侧栏选择器，不用全屏 Sheet；紧凑宽度保持现有 `Menu`。selection 状态与持久化（`ChatModel.swift:228-233`、`:180-183`）不变，服务端契约不变 | `ChatScreen.swift`（依赖 CLE-78 先落） |
| 设置 | `SettingsScreen.swift:9-53` | 不改（仅验收） | `List` + `sheet`（`:35`）在 regular 下系统自动呈现为 form sheet；需确认 form sheet 尺寸与「取消」按钮位置 | — |
| 设置子页（Runtimes/Agents/Squads） | `SettingsScreen.swift:55-125` | 不改 | `List` + `navigationDestination`（`:34`）自适应 | — |
| 附件 Quick Look | `AttachmentViews.swift:129-146` | 不改（仅验收） | `sheet` 在 regular 下自动变 form sheet；`ShareLink`（`:142`）保留 | — |
| 图片预览 | `AttachmentViews.swift:37`、`:69`、`:91-102` | 改 | `fullScreenCover` 在 iPad 上整屏铺满，观感突兀且丢失上下文；改为 `sheet`（regular 下为 form sheet）或限制最大尺寸 | `AttachmentViews.swift` |
| 深链资源 Sheet | `WorkspaceTabs.swift:51-61` | 改 | 常规宽度用 `.popover` 或把它并入详情列；紧凑宽度保持 Sheet。`OpenURLAction` 解析逻辑（`:36-44`）不变 | `WorkspaceTabs.swift` |
| 图片内联 | `AttachmentViews.swift:12-39` | 不改 | `scaledToFit` + `maxHeight: 300` 随列宽自适应 | — |
| 旧 `ShellView` | `ShellView.swift` | 不改 | 不在导航路径（无调用方）；建议实现阶段顺手删除，但不属于本设计范围 | — |
| Fixture 壳 | `Fixture/FixtureRootView.swift:30-61` | 改 | 与主壳同步加 `.sidebarAdaptable`，否则 fixture 矩阵截图与真实壳不一致 | `ios/Fixture/FixtureRootView.swift` |

---

## 6. 输入与效率映射表

### 6.1 键盘快捷键与菜单栏

当前 `ChattyApp.swift:5-14` 没有 `Commands`，需要新增 `CommandGroup` / `CommandMenu`。映射建议（⌘ = Command）：

| 快捷键 | 动作 | 实现位置 | 备注 |
| --- | --- | --- | --- |
| ⌘N | 新建 Mika 会话 | `App` 场景 `Commands`，经 `@FocusedValue` 下发到 `ChatModel` | 需先补一个「新建会话」的模型方法；当前 `ChatModel` 只有 `session` 单值（`ChatModel.swift:6`） |
| ⌘↩ | 发送当前草稿 | `ChatScreen` composer | 与软键盘「发送」按钮同路径（`ChatScreen.swift:173-177`） |
| ⌘F | 搜索事项 / 会话 | 事项列表 `searchable`（`ProjectsScreen.swift:77`）；对话内聚焦搜索 | 需避免与系统查找冲突，验收确认 |
| ⌘, | 打开设置 | 与头像按钮同路径（`WorkspaceTabs.swift:74-83`） | 标准约定 |
| Esc | 关闭 Sheet / 取消选择 | 模态与多选 | 系统默认对 Sheet 生效，需为 popover 补充 |
| ⌘1 / ⌘2 / ⌘3 | 切换 动态 / Mika / 项目 | `WorkspaceTabs` 的 `tab` 绑定（`:12`） | 侧栏形态下同样可用 |
| ⌘R | 刷新当前页 | 各页 `refreshable` 对应方法 | 与下拉刷新同路径 |
| ⌘[ / ⌘] | 返回 / 前进 | `NavigationStack` | 系统默认；仅在自定义 `NavigationPath` 时需补 |

不做：不做自定义主菜单（File/Edit/View…），只加有明确产品语义的命令组。

### 6.2 指针与触控板

| 能力 | 要求 | 落点 |
| --- | --- | --- |
| hover 反馈 | 动态行、项目行、附件行、消息内快捷操作需要 `.hoverEffect`（iPad 指针） | `ActivityScreen.swift:30-51`、`ProjectsScreen.swift:14-27`、`AttachmentViews.swift:41-70` |
| 右键 / 长按 context menu | 事项行：验收 / 状态变更 / 复制链接；附件：分享 / 打开；消息：复制文本 | 新增 `.contextMenu`；长按沿用系统 |
| 触控板滚动与键盘焦点 | 沿用系统；确认 `List` 与 `ScrollView` 在 iPad 上方向键可移动焦点 | 验收项（无需改码） |
| 拖拽（拖入） | composer 接受 Files / Photos / 其他 App 拖入作为附件，复用现有 `upload(data:filename:contentType:)`（`ChatModel.swift:210-217`）；目标区域为 composer（`ChatScreen.swift:139-180`），需给出 `.dropDestination` / `.dropDestination(for: URL.self)` 与视觉高亮 | `ChatScreen.swift` |
| 拖拽（拖出） | 消息内附件与图片可拖出到 Files / 其他 App | `AttachmentViews.swift` |

### 6.3 Apple Pencil

- v1 只保证 **Scribble 在输入框可用**（系统在 `TextField` 上默认生效，`ChatScreen.swift:170`、`AppBootstrap.swift:79`、`:88`），不做 PencilKit 手写、不做标注、不做悬停预览。
- 需要在验收中确认 Pencil 悬停（hover）不会破坏列表 hover 反馈。

### 6.4 多任务与多窗口

| 能力 | 设计 |
| --- | --- |
| Split View / Slide Over / Stage Manager | 不锁方向；`Info.plist` 补齐 iPhone 与 iPad 的四个方向；不设 `UIRequiresFullScreen`；布局全部由 hSC 决定 |
| 最小可用窗口 | 320 pt 宽时 composer 可用、发送按钮 44×44（`ChatScreen.swift:168/175`）、无横向裁切 |
| 多窗口 | 需要 `UIApplicationSupportsMultipleScenes = true` 并使用 `openWindow`；会话在新窗口打开。**注意**：该键会改变 iPadOS 26 上的窗口呈现（见 R1），需在实现阶段单独验证后再开 |
| 多窗口共享登录态 | 复用同一 Keychain 记录（`ProtectedStorage`/`KeychainVault`，`AppBootstrap.swift:39-41`）；每个 `WindowGroup` 场景持有自己的 `WorkspaceModel`（`WorkspaceModel.swift:23-43`） |
| 重复轮询 / 重复推送 | **必须避免**：目前轮询与 WebSocket 挂在 `ChatModel.start()`（`ChatModel.swift:92-106`）与 `ActivityModel.start()`，多场景会让每窗口各起一份。设计约束：轮询/连接改为场景级单例（或由 `SessionModel` 持有一份、窗口只订阅） |
| 场景恢复 | 重开 App / 恢复窗口后回到原会话与选择：现有恢复已覆盖工作区（`SessionModel.swift:81-83`）、草稿/队列/项目选择（`ChatModel.swift:65-85`）；需额外补「最后选中的 Tab 与滚动位置」 |

---

## 7. 风险与回滚

| 编号 | 风险 | 证据/影响 | 应对 |
| --- | --- | --- | --- |
| R1 | **iPadOS 26 按 bundle id 记忆窗口几何**：iPhone-only 时期留下的 635×1376 窗口，在升级为通用 App 后仍被沿用，用户看到的仍是窄窗 + 底部 Tab，而不是全屏双栏 | 实测：同一 iPad、同一 bundle `ai.chatty.ios.fixture`，改为通用 App 后窗口仍为 635×1376；换全新 bundle id 重新安装后才是 1032×1376 全屏 | ① 代码无法直接清除该记录，需在实现阶段做技术验证（`UIApplicationSupportsMultipleScenes` 变化或 `UIRequiresFullScreen` 是否触发重算）；② 无论能否重算，**紧凑宽度都必须完整可用**，因此本风险不阻塞设计；③ 若确认无法重算，写入升级说明：建议用户重装或手动全屏 |
| R2 | iPhone Plus/Max 横屏进入 regular，手机上出现侧栏 | 平台规则；`iPhone 17 Pro Max` 横屏 hSC = regular | 不特判 idiom（遵守 D2）；按 Apple 自家 App 的行为接受侧栏，并在真机复核竖排 Tab 不塌陷。若验收判定不可接受，备选：仅在 `verticalSizeClass == .regular`（iPad 全屏/分屏）时启用侧栏 |
| R3 | 多窗口 / 分屏切换触发 `.onDisappear`（`WorkspaceTabs.swift:72`），误停轮询与实时连接 | 代码事实 | 把 `pause()` 的触发条件从视图消失改为「场景不再活跃」（`scenePhase` + `UIApplication.shared.connectedScenes` 的活跃场景数），并补单元测试 |
| R4 | `fullScreenCover`（`AttachmentViews.swift:37`、`:69`）在 iPad 上整屏覆盖，观感与上下文丢失 | 代码事实 | 改为 `sheet`；regular 下系统给 form sheet，紧凑下仍是全屏 sheet，行为一致 |
| R5 | 启用 `UIApplicationSupportsMultipleScenes` 改变 iPadOS 26 的窗口呈现方式，可能让 App 不再默认全屏 | §4 实测的窗口行为 | 多窗口拆成独立实现步骤，先验证窗口行为再决定是否默认开启 |
| R6 | Split View / Slide Over / Stage Manager 的具体宽度与 size class 未实测 | §3 待复核行 | 实现 Issue 内建真机矩阵；若某档出现「regular 但列宽过窄」的排版问题，回退为单一顶部 Tab 栏（不启用侧栏） |
| R7 | 键盘快捷键与系统/输入法冲突（⌘F、⌘N） | 未验证 | 实现后做快捷键冲突检查；冲突项改为带修饰键的备选 |
| R8 | `ChatScreen` 详情空态与 `.sidebarAdaptable` 组合下出现空白详情栏 | Issue 设计要求「不出现空白栏」 | 空态必须是非空内容（引导文案 + 建议动作），纳入验收截图 |

**回滚方案**

- 本设计变更本身**只有文档**，回滚即回退文档提交。
- 实现阶段按 §8 拆成独立步骤，每步单独 PR、单独可回退：
  1. 工程配置（设备族/方向）回退 = 还原 `scripts/generate-ios-project.py` 并重新生成，App 立即回到 iPhone-only；
  2. 壳（`.tabViewStyle`）回退 = 删一行修饰符，布局回到底部 Tab；
  3. 逐屏改造回退 = 各屏独立提交；
  4. 多窗口回退 = 关闭 `UIApplicationSupportsMultipleScenes`。
- 回退后不应残留任何 iPad 专属代码路径（因为设计不引入平行 UI 代码，D1）。

---

## 8. 实施拆分建议

**单一前置**：CLE-78（Mika 图形化关联项目）先合并，再启动下面的实现 Issue；否则 `ChatScreen.swift` 的 composer 会被两个 Issue 同时改。

推荐拆成 **1 个父 Issue + 4 个阶段子 Issue**（`--parent` 同一父，`--stage` 分组，stage 1 用 `todo`，后续 `backlog` 待推进）：

| Stage | 子 Issue | 范围 | 依赖 | 验收要点 |
| --- | --- | --- | --- | --- |
| 1 | A：工程配置与自适应壳 | `generate-ios-project.py`（设备族 `1,2`、四方向、`UISupportedInterfaceOrientations~ipad`）；`WorkspaceTabs` / `FixtureRootView` 加 `.tabViewStyle(.sidebarAdaptable)`；登录与离线页可读列宽；详情空态引导 | CLE-78 已合并 | iPad 全屏竖/横、iPhone 竖/横截图；紧凑宽度与改造前逐像素一致（除系统 Tab 呈现）；R1 窗口几何技术验证结论 |
| 2 | B：输入与效率 | `Commands` + 快捷键表（§6.1）；hover / context menu；拖入拖出；图片预览改 `sheet`；项目关联入口改 popover | A | 快捷键全表可用且无冲突；拖放成功上传；popover 在两种宽度下 selection 一致 |
| 3 | C：多窗口与场景恢复 | `UIApplicationSupportsMultipleScenes`、`openWindow`、轮询/实时连接场景级去重、场景恢复补 Tab 与滚动位置 | A | 两窗口共享登录态；服务端审计证明无重复轮询/推送；重开回到原会话 |
| 4 | D：设备矩阵与无障碍验收 | §3 的第 3、5、7–11 行真机/模拟器复核；Dynamic Type 超大字号；VoiceOver；Pencil Scribble；命中区 ≥44pt | A、B、C | 矩阵逐行有截图或断言；超大字号下关键操作不被截断 |

**不拆的**：不做独立 iPad App、不做三栏、不做离线/同步协议改造、不做 PencilKit、不做 Android 对齐（Issue 非目标）。

---

## 9. 待 Benjamin 拍板（5 项）

1. **常规宽度默认呈现**：竖屏 iPad 是「顶部 Tab + 可展开侧栏」（`.sidebarAdaptable` 系统默认，已实测），还是要求进入即侧栏常驻？
   - 推荐：**跟随系统默认**（顶部 Tab + Toggle），横屏/宽窗自动侧栏。影响：竖屏首屏信息密度更高；侧栏常驻需自绘 `NavigationSplitView`，与 D1「不复制 UI」的成本更高。
2. **iPhone Plus/Max 横屏出现侧栏**：接受还是限制？
   - 推荐：**接受**（不特判 idiom，符合 D2，与 Apple 自家 App 一致）。备选：仅在 `verticalSizeClass == .regular` 时启用侧栏。影响：接受则手机横屏交互变化，需真机复核。
3. **多窗口（第 2 阶段）是否纳入首版**：`UIApplicationSupportsMultipleScenes` 会改变 iPadOS 26 的窗口呈现，且需要轮询/推送去重改造。
   - 推荐：**纳入但独立成阶段 C**，先做技术验证再默认开启。影响：不做则「会话在新窗口打开」不可用，其余设计不受影响。
4. **项目关联入口的常规宽度形态**（与 CLE-78 共享文件）：popover 还是并入详情列？
   - 推荐：**popover**（锚定 composer 的项目按钮），selection 与持久化不变。影响：并入详情列会与 D1「不做三栏」冲突。
5. **R1 窗口几何遗留的处理方式**：是否接受「升级后如仍是窄窗，由用户手动全屏/重装」？
   - 推荐：**接受 + 实现阶段先做重算技术验证**，并把结论写成升级说明。影响：若要求代码强制全屏，需要 `UIRequiresFullScreen = true`，而它会**禁用分屏**，与本次多任务目标直接冲突——因此不推荐。
