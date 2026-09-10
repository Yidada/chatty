# 实施与验收拆分

本文件只给出实现阶段的拆分与依赖顺序；设计依据见 [spec.md](spec.md)，本文不重复其内容。

## 前置

- [CLE-78](https://multica.ai)（Mika 图形化关联项目）必须先合并。理由：它预期改动 `ios/Chatty/ChatScreen.swift:142-149` 的 composer 项目选择器与 `ChatModel` 的选择/持久化路径，与本设计第 5、9 节的重叠面相同。
- 开工前重跑 `multica issue runs <CLE-78> --active` 与 `git branch -r`，确认没有并行改动同一文件。

## 阶段划分

一个父 Issue + 4 个阶段子 Issue（`--parent <父>`、`--stage <N>`；stage 1 用 `todo`，后续用 `backlog` 待推进）。

### Stage 1 — A：工程配置与自适应壳（阻塞其余阶段）

范围：

1. `scripts/generate-ios-project.py:36` 设备族 `1,2`；`:56` 补齐四个方向与 `UISupportedInterfaceOrientations~ipad`；重新生成工程与 Info.plist。
2. `ios/Chatty/WorkspaceTabs.swift` 与 `ios/Fixture/FixtureRootView.swift` 增加 `.tabViewStyle(.sidebarAdaptable)`。
3. 登录页与离线草稿页（`AppBootstrap.swift:62-108`、`:146-166`）在常规宽度限制可读列宽。
4. Mika 详情空态引导（不出现空白详情栏）。
5. R1 技术验证：确认改用通用 App 后，iPadOS 26 遗留的窄窗口几何能否被重置（试 `UIApplicationSupportsMultipleScenes` 变化、重装、`UIRequiresFullScreen`；注意 `UIRequiresFullScreen = true` 会禁用分屏，只作验证不作方案）。

验收：iPad 全屏竖/横与 iPhone 竖/横四张截图；紧凑宽度与改造前一致（除系统 Tab 呈现）；R1 给出明确结论。

### Stage 2 — B：输入与效率（依赖 A）

范围：`Commands` 与快捷键表（spec.md §6.1）；列表/附件/消息的 hover 与 context menu；composer 拖入、附件拖出；图片预览 `fullScreenCover` → `sheet`；项目关联入口常规宽度改 popover。

验收：快捷键全表可用且无冲突；拖放成功上传并出现在附件区；popover 在两种宽度下 selection 与持久化一致。

### Stage 3 — C：多窗口与场景恢复（依赖 A）

范围：`UIApplicationSupportsMultipleScenes`、`openWindow`；轮询与实时连接改为场景级单例，消除多窗口重复轮询/推送；场景恢复补最后 Tab 与滚动位置；修正 `WorkspaceTabs.swift:72` 在多场景下的 `pause()` 语义。

验收：两窗口共享登录态；服务端审计证明消息与轮询无重复；重开或恢复窗口回到原会话与选择。

### Stage 4 — D：设备矩阵与无障碍验收（依赖 A、B、C）

范围：spec.md §3 中标注「待复核」的第 3、5、7–11 行；Dynamic Type 超大字号；VoiceOver；Pencil Scribble；最小窗口下 composer 可用；命中区 ≥44 pt。

验收：矩阵逐行给出截图或断言；超大字号下关键操作不被截断；空态/错误态/弱网不被遗漏。

## 约束

- 不做独立 iPad App、不新建平行 UI 代码路径、不加 iPad 专属 target。
- 不做桌面级三栏、不做离线/同步协议改造、不做 PencilKit、不做 Android 对齐。
- 不擅自改 Bundle ID、签名、版本号或 App Store Connect 资料；TestFlight 上传需在实现阶段单独确认。
- 每个阶段单独 PR、单独可回退；回退后不应残留 iPad 专属代码路径。
