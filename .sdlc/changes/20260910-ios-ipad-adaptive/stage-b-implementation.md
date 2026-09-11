# Stage B 实现与验证记录（CLE-90）

- 父任务：CLE-88「Chatty iOS：iPad / iPadOS 自适应实现」阶段 B「输入与效率（快捷键 / 指针 / 拖放）」。
- 设计依据：[spec.md](spec.md) §6.1 键盘与菜单栏、§6.2 指针、§6.3 Apple Pencil、§5 逐屏表（图片预览 R4、项目关联入口 D4-4）、[plan.md](plan.md) Stage 2。
- 起点：`main` `7a71575`（A 阶段 PR #8 已合入）。
- 交付：PR [Yidada/chatty#9](https://github.com/Yidada/chatty/pull/9)（分支 `agent/ipad/01a08e81-b`，源提交 `87ff8f5`，标题带 CLE-90，未用 `Closes`）。
- 环境：Xcode 26.6 (17F113)、iOS 26.5 SDK、iPad Air 13-inch (M4) 模拟器（1024 × 1366 pt，regular）、iPhone 17e 模拟器（390 × 844 pt，compact）、`scripts/ios-fixture.py` 合成服务（端口 8766，独立实例）。

本文件只记录**已实测**的结果；未执行或无法在本环境执行的项在 §7 明确列出。

## 1. 改动

| # | 范围 | 文件 | 内容 |
| --- | --- | --- | --- |
| 1 | 菜单栏与快捷键 | `ios/Chatty/AppCommands.swift`（新增）、`ios/Chatty/ChattyApp.swift` | 新增 `AppCommandCenter`（场景级命令总线）+ `ChattyCommands`（`CommandGroup` / `CommandMenu`）；`WindowGroup` 挂 `.commands`，命令目标由当前可见界面注册 |
| 2 | 命令注册 | `ios/Chatty/WorkspaceTabs.swift` | Tab 切换、设置、刷新、新建会话、搜索聚焦、取消；离开壳时 `clearWorkspaceCommands()` |
| 3 | 发送命令 | `ios/Chatty/ChatScreen.swift` | 进入 Mika 时注册 `send` / `focusComposer` / `canSend`，离开时清除 |
| 4 | 新会话模型方法 | `ios/Packages/ChattyKit/Sources/ChattyCore/ChatModel.swift` | `startNewSession()` + `newSessionPending`：refresh 不得重新采纳旧会话，发送时才 `POST /api/chat/sessions` |
| 5 | 拖入附件 | `ChatScreen.swift`、`ChattyCore/AttachmentImport.swift`（新增） | composer `.dropDestination(for: DroppedAttachment.self)` + 目标高亮；`FileRepresentation(.item)` 与 `DataRepresentation(.image)` 双通道，统一走 `AttachmentImport` 校验 |
| 6 | 拖入/拖出模型接口 | `ChatModel.swift` | `upload(fileURL:)`、`upload(imported:)` |
| 7 | 指针 | `ActivityScreen.swift`、`ProjectsScreen.swift`、`AttachmentViews.swift`、`ChatScreen.swift` | 动态行 / 项目行 / 事项行 / 附件 / 图片 / 快捷操作加 `.hoverEffect`；共 6 处 |
| 8 | 右键与长按菜单 | `ActivityScreen.swift`、`ProjectsScreen.swift`、`AttachmentViews.swift`、`ChatScreen.swift` | 事项行：验收通过（`in_review`）、更改状态、复制链接；附件：分享…/打开；消息：复制文本 |
| 9 | 复制链接 | `ChattyCore/RichDocument.swift`、`ChattyCore/ProjectsModel.swift` | `NativeLink.issueLink(workspace:identifier:)`；`ProjectsModel.setStatus(_:for:)` 复用详情页同一受控更新路径 |
| 10 | 分享入口 | `AttachmentViews.swift` | `ShareSheet`（`UIActivityViewController`）用于 context menu 分享；图片预览加 `ShareLink`；文件预览保留既有 `ShareLink` |
| 11 | 拖出 | `AttachmentViews.swift` | 内联图片 `.draggable(Image)`；远程附件 `AttachmentExport`（`Transferable`，按需下载） |
| 12 | 呈现方式 | `AttachmentViews.swift`、`ChatScreen.swift` | 图片预览 `fullScreenCover` → `sheet`（全仓已无 `fullScreenCover`）；常规宽度项目关联入口 `Menu` → `.popover`，紧凑宽度保持 `Menu` |

判定依据仍全部来自 size class / 可用宽度，未引入 `userInterfaceIdiom` 分支（`grep -rn userInterfaceIdiom ios --include=*.swift` 只命中 `AppBootstrap.swift:187` 的说明性注释）。

## 2. 键盘快捷键与菜单栏

`ios/Chatty/AppCommands.swift` 的绑定（`grep -n keyboardShortcut ios/Chatty/*.swift` 共 9 条）：

| 快捷键 | 菜单项 | 动作路径 | 依据 |
| --- | --- | --- | --- |
| ⌘N | 新建 Mika 会话 | `WorkspaceTabs` → `ChatModel.startNewSession()` | spec §6.1 |
| ⌘↩ | 对话 › 发送 | `ChatScreen` → `ChatModel.send()`（与发送按钮同路径） | spec §6.1 |
| ⌘F | 对话 › 搜索事项 | 切到「项目」Tab + 让可见的 `IssuesScreen` 聚焦 `.searchable`（`.searchFocused`） | spec §6.1 |
| ⌘, | 设置… | `WorkspaceTabs` → 设置 Sheet | spec §6.1 |
| Esc | 对话 › 取消 | 关闭深链 Sheet / 设置（`.cancelAction`）；Sheet 本身系统默认响应 | spec §6.1 |
| ⌘1 / ⌘2 / ⌘3 | 视图 › 动态 / Mika / 项目 | `WorkspaceTabs.tab` 绑定 | spec §6.1 |
| ⌘R | 视图 › 刷新 | 当前 Tab 对应 `refresh` / `overview` | spec §6.1 |
| ⌘[ / ⌘] | — | `NavigationStack` 系统默认，无需补码 | spec §6.1 |

命令可见性：未登录、无工作区、无待发送草稿时对应菜单项为 disabled；命令闭包在界面离开时清空，不会指向失效模型。

**本环境限制（关键）**：iPadOS 26 的菜单栏按系统规则在常规宽度可用，但需要**硬件键盘 + 指针移到屏幕顶部（或按住 ⌘）**才会显示；本运行环境没有向模拟器注入键盘/指针事件的能力（`agent-device keyboard` 只支持 enter/return/dismiss，`osascript` 键注入被系统权限阻塞并超时）。因此**未取得菜单栏或 ⌘-HUD 的截图**，快捷键只做到「绑定与动作路径可核验」。手工 10 秒复现步骤：

1. Xcode 打开 `ios/Chatty.xcodeproj`，运行 `ChattyFixture` 到一台 iPad 模拟器，按 `scripts/ios-fixture.py` 登录（验证码 `123456`），选 `Loop Test Workspace`。
2. Simulator 菜单 `I/O › Keyboard › Connect Hardware Keyboard`（⌘⇧K）打开，保证连接硬件键盘。
3. 把指针移到屏幕最顶部（或按住 ⌘）→ 应用菜单栏出现，从左到右为 `对话`、`视图` 两组；每个菜单项右侧即为上表快捷键。
4. 逐条按下：⌘N 清空当前会话（顶部出现「已开始新的对话，发送后会创建会话。」）；⌘2 切到 Mika 后 ⌘↩ 发送草稿；⌘F 跳到项目 Tab 并聚焦搜索框；⌘, 打开设置；⌘R 刷新当前页；⌘1/2/3 切 Tab；Esc 关闭弹层。

## 3. 指针与右键 / 长按

- `.hoverEffect`：动态行（`ActivityScreen.swift`）、项目行与事项行（`ProjectsScreen.swift`）、附件与内联图片（`AttachmentViews.swift`）、消息快捷操作（`ChatScreen.swift`）。
- 事项行 context menu（动态与事项列表同一套）：`验收通过`（仅 `in_review`）、`更改状态`（来自状态目录）、`复制链接`。状态修改经 `ProjectsModel.setStatus(_:for:)` → `loadDetail` + `changeStatus`，与详情页完全同路径，仍受 revision / 409 保护。
- 附件 context menu：`分享…`、`打开`；消息 context menu：`复制文本`。
- 实测证据：`evidence/stage-b/ipad-11-issue-context-menu.png`（事项行菜单）、`ipad-09-context-menu.png`（附件菜单）。
- **复制链接实测**：长按动态第一行 → `复制链接` → `xcrun simctl pbpaste <udid>` 返回 `https://app.multica.ai/fixture/issues/LOOP-1`；同一 URL 经 `NativeLink.resolve` 判为 `.issue("LOOP-1")`（单元测试）。
- 触控板滚动与键盘焦点移动为系统默认行为，未改码；列入 D 阶段设备验收。

## 4. 拖放与 Share Sheet

**拖入 composer（实测，端到端）**

1. 让 Mika 会话里出现一张内联图片（合成服务：`POST http://127.0.0.1:8766/__control {"native":true}` 后重启 App）。
2. `agent-device gesture drag 'id="attachment.inlineImage"' 'id="chat.send"'`（源=内联图片，目标=composer 区域）。
3. 结果：composer 出现新附件 chip（`compose.remove.upload-1`），说明 `.dropDestination` 触发 → `AttachmentImport` 校验 → `POST /api/upload-file` → 附件进入输入区。

证据：`evidence/stage-b/ipad-12-drop-attachment.png`。

实现细节：

- `DroppedAttachment` 有两个 representation：`FileRepresentation(importedContentType: .item)`（Files / 其他 App 的文件 URL，保留真实文件名）与 `DataRepresentation(importedContentType: .image)`（只发布图像数据的 App，如 Photos）。
- 两条通道都走 `AttachmentImport.read(fileURL:)` / `.prepared(data:filename:contentType:)`，与 `fileImporter` 相同的 20 MB 上限与常规文件校验；拖入不会绕过选择器限制。
- 目标高亮：拖动悬停时 composer 出现 `松手即可添加附件` 虚线高亮（`isTargeted` 驱动，纯视觉、不参与命中）。
- 已知取舍：纯 Data 通道拿不到原文件名，落库名为 `image.png`（截图中 chip 显示 `PNG image.png`）；Files 的 File 通道保留原名。这是平台信息量差异，不是缺陷。

**拖出**

- 内联图片：`.draggable(Image(uiImage:))`，拖到 Files / 其他 App 得到图片内容。
- 远程附件：`AttachmentExport`（`Transferable`，`DataRepresentation(exportedContentType: .data)`），拖动时按需下载。**未做端到端实测**（见 §7）。

**Share Sheet（实测三处入口）**

| 入口 | 结果 | 证据 |
| --- | --- | --- |
| 附件预览 Sheet 的 `分享或保存文件` | 分享面板弹出 | `ipad-06-share-sheet.png` |
| 图片预览 Sheet 的 `分享或保存图片`（本次新增） | 分享面板弹出 | `ipad-08-image-share-sheet.png` |
| 附件长按 → `分享…`（本次新增，先下载再分享本地文件） | 分享面板弹出 | `ipad-10-context-share-sheet.png` |

## 5. 呈现方式（R4 / D4-4）

| 项 | 之前 | 现在 | 实测 |
| --- | --- | --- | --- |
| 内联图片预览 | `fullScreenCover` | `sheet` | 常规宽度为 580 × 650 pt 的 form sheet（x 222、y 353），标题「原生图片」+ 关闭 + 分享按钮；`ipad-07-image-preview-sheet.png` |
| 附件图片预览 | `fullScreenCover` | `sheet` | 同上路径 |
| 文件预览 | `sheet`（不变） | `sheet` | 580 × 650 form sheet；`ipad-05-attachment-sheet.png` |
| 项目关联入口 | `Menu` | 常规宽度 `.popover`，紧凑宽度 `Menu` | 常规：popover 280 × 165 pt，含项目列表与「刷新项目」，选中后 composer 标签变为 `Loop Project`（`ipad-03` / `ipad-04`）；紧凑：仍是系统菜单（`iphone-03-project-menu.png`） |

项目选择仍写 `ChatModel.selectProject` → `persistDraft`，服务端契约与持久化未变；两种宽度同一 selection 来源。

## 6. 构建与测试

```
# 1) App（iPhone + iPad 通用 target）
xcodebuild -project ios/Chatty.xcodeproj -scheme Chatty -configuration Debug \
  -destination "generic/platform=iOS Simulator" -derivedDataPath .tools/dd \
  CODE_SIGNING_ALLOWED=NO build
→ ** BUILD SUCCEEDED **

# 2) Fixture App（用于上面全部截图）
xcodebuild -project ios/Chatty.xcodeproj -scheme ChattyFixture -configuration Debug \
  -destination "platform=iOS Simulator,id=<iPad Air 13-inch M4>" -derivedDataPath .tools/dd \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- build
→ ** BUILD SUCCEEDED **

# 3) ChattyCore 包测试（SwiftPM）
swift test --package-path ios/Packages/ChattyKit --disable-sandbox
→ Executed 46 tests, with 0 failures（A 阶段 42；本次新增 4）

# 4) Simulator 宿主测试（ChattyFixtureTests）
xcodebuild -project ios/Chatty.xcodeproj -scheme ChattyFixture -destination "platform=iOS Simulator,id=<iPad Air 13-inch M4>" test
→ Executed 8 tests, with 1 test skipped and 0 failures（跳过项为模拟器不暴露文件保护属性的既有 skip）
```

新增测试：

- `testNewSessionDefersSessionCreationUntilTheNextSend`：⌘N 不建服务端会话；refresh 不重新采纳旧会话；下一次发送才创建。
- `testNewSessionIsRefusedWhileASendIsUnconfirmed`：发送中/待核对时拒绝新会话并给出提示。
- `testDroppedFileUsesTheSameValidationAndUploadPathAsThePicker`：拖入文件走同一上传路径；超限拖入在本地被拒绝。
- `testAttachmentImportLimitsAndSharedIssueLink`、`testAttachmentImportReadsDroppedFileURL`、`testSharedIssueLinkResolvesBackToTheNativeRoute`（App target）。

紧凑宽度回归：iPhone 17e（390 × 844）底部 `Tab Bar`（y 761–844）不变，composer 的 `chat.projectPicker` / `chat.attach` / `chat.send` 均为 44 pt 命中区，无横向裁切；截图 `iphone-01-activity.png`、`iphone-02-mika.png`、`iphone-03-project-menu.png`。

## 7. 未完成 / 本环境限制

1. **快捷键与菜单栏的真实按键未注入**：见 §2。绑定、菜单结构与动作路径已核验；实际按键、菜单栏/⌘-HUD 截图需要一台连接硬件键盘的真机或有人操作的模拟器（步骤见 §2）。这是本阶段唯一未闭环的验收项。
2. **附件拖出未实测**：`AttachmentExport` 已实现并随包编译，但把远程附件拖到 Files 的动作无法在本环境注入（需要真实指针拖拽）。内联图片拖出同理。
3. **指针 hover 反馈无法截图**：`.hoverEffect` 需要真实指针悬停；已按 spec §6.2 落点实现 6 处，纳入 D 阶段设备验收。
4. **Pencil Scribble**：v1 只保证系统在 `TextField` 上默认生效，未改码；Pencil 悬停与列表 hover 的共存属 D 阶段真机项。
