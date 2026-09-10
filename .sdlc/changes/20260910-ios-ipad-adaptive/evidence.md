# 验证记录

- 核对基线：`Yidada/chatty` main `2dd46ae`（2026-09-10）。
- 环境：Xcode 26.6 (17F113)、iOS 26.5 SDK、iPad Pro 13-inch (M5) 模拟器、iPhone 17 模拟器。
- 结论：设计规范已完成；实验验证已完成并**已全部还原**；本变更只提交文档与截图。

## 现状核对

| 检查 | 命令/位置 | 结果 |
| --- | --- | --- |
| 设备族 | `grep -n "TARGETED_DEVICE_FAMILY" ios/Chatty.xcodeproj/project.pbxproj` | 5 处配置均为 `"1"`（仅 iPhone）：`:242`、`:264`、`:421`、`:444`、`:533`、`:556` |
| 方向与场景 | `ios/Config/Chatty-Info.plist`、`ChattyFixture-Info.plist` | 仅 `UIInterfaceOrientationPortrait`；无 `UISupportedInterfaceOrientations~ipad`；`UIApplicationSupportsMultipleScenes = false`；无 `UIRequiresFullScreen` |
| 配置生成源 | `scripts/generate-ios-project.py:36`、`:56` | 设备族与 Info.plist 由脚本生成，手改工程会被覆盖 |
| 最低系统 | `project.pbxproj:245` 等；`ios/Packages/ChattyKit/Package.swift:6` | `IPHONEOS_DEPLOYMENT_TARGET = 26.0` |
| 导航结构 | `ChattyApp.swift:5-14`、`AppBootstrap.swift:51-57`、`WorkspaceTabs.swift:19-35` | 单 `WindowGroup`、无 `Commands`；根分支 5 态；主导航三 Tab（动态/Mika/项目），各 Tab 内一层 `NavigationStack` |
| 尺寸假设 | `grep -rn "horizontalSizeClass\|verticalSizeClass\|userInterfaceIdiom\|UIScreen\|UIDevice" ios/` | 结果为空：全仓没有任何宽度分支或设备判断 |
| 唯一自适应构造 | `ChatScreen.swift:207` | `ViewThatFits(in: .horizontal)` |
| CLE-78 冲突面 | `multica issue runs 01a0812c-… --active`；`git branch -r` | 无运行中任务、无分支、无 PR（状态 `todo`）；仅存在预期合并面 |

## iPad 上的当前表现（改造前）

| 检查 | 结果 | 证据 |
| --- | --- | --- |
| iPhone-only 包在 iPad Pro 13" 上可安装 | 是，系统以 iPhone 兼容模式等比缩放运行 | `evidence/00-before-ipad-iphone-only-compat.png` |
| 窗口几何 | 屏幕 1032 × 1376 pt；应用窗口 635 × 1376 pt，水平居中（x = 199） | 截图像素分析（2064 × 2752 px @2x），应用区经饱和度分割得到 |

## 实验验证（最小实验性改动，已还原）

实验内容（diff 全文见 `evidence/experiment.diff`）：

1. `scripts/generate-ios-project.py:36` `TARGETED_DEVICE_FAMILY` → `'1,2'`；
2. `scripts/generate-ios-project.py:56` `UIApplicationSupportsMultipleScenes` → `True`，两个 Info.plist 补齐四个方向与 `UISupportedInterfaceOrientations~ipad`；
3. `ios/Chatty/WorkspaceTabs.swift` 增加 `.tabViewStyle(.sidebarAdaptable)`；
4. `#if CHATTY_FIXTURE` 下的尺寸档位探针 `--design-lab-regular`（强制 regular，用于无宽窗口时验证常规宽度分支）。

| 检查 | 命令 | 结果 | 证据 |
| --- | --- | --- | --- |
| Fixture 构建 | `xcodebuild -project ios/Chatty.xcodeproj -scheme ChattyFixture -configuration Debug -destination "generic/platform=iOS Simulator" build` | BUILD SUCCEEDED | `.tools/ios-derived-data` |
| 应用运行（iPad，635 × 1376 窗口） | `xcrun simctl launch <iPad-UDID> ai.chatty.ios.fixture` + `agent-device` | 仍为**底部 Tab 栏**（`tab-bar` 节点），交互与 iPhone 一致 → D3 成立 | `evidence/01-ipad-compact-635pt-bottom-tabs.png` |
| 应用运行（iPad 全屏，fresh bundle） | 以 `PRODUCT_BUNDLE_IDENTIFIER=ai.chatty.ios.probe` 重新构建安装 | 窗口 = 全屏 **1032 × 1376 pt**（regular） | 无障碍树 `Application.rect` |
| `.sidebarAdaptable` 在 regular 竖屏 | 同上 | 顶部 Tab 栏（`Toggle sidebar` + 动态/Mika/项目，y = 72.5） | `evidence/02-ipad-fullscreen-regular-top-tabs.png` |
| 展开侧栏 | 触发 Toggle sidebar | 出现 **238 pt 侧栏列**：cells x = 26、宽 238、y = 131.5 / 175.5，导航栏出现 `Hide Sidebar` | `evidence/03-ipad-regular-sidebar-visible.png` |
| iPhone 基线 | iPhone 17，同一构建 | 底部 Tab 栏，与改造前一致 | `evidence/04-iphone-compact-activity.png`、`evidence/06-iphone-compact-mika-chat.png` |
| iPad 紧凑宽度下的对话页 | 635 × 1376 窗口 | composer 与项目选择器可用，无横向裁切 | `evidence/05-ipad-compact-mika-chat.png` |

**实验去留**：`WorkspaceTabs.swift` 的 `.tabViewStyle(.sidebarAdaptable)`、`ChattyApp.swift` 的尺寸探针、以及工程配置改动均**未合入**。工作区恢复为与 `2dd46ae` 一致（`git status` 仅显示本变更目录）。正式落地由 [plan.md](plan.md) 的阶段 A 承担。

## 关键实测发现

1. **iPadOS 26 按 bundle id 记忆窗口几何。** 同一 iPad、同一 bundle `ai.chatty.ios.fixture`：iPhone-only 时期留下的 635 × 1376 窗口，在改为通用 App 后仍被沿用（重启模拟器、卸载重装均未清除）；换成全新 bundle id 重新安装后才恢复为 1032 × 1376 全屏。⇒ 升级用户可能停留在窄窗 + 底部 Tab，因此紧凑宽度必须完整可用。详见 spec.md 风险 R1。
2. **regular 竖屏的 `.sidebarAdaptable` 是「顶部 Tab + 可展开侧栏」而不是「常驻侧栏」。** 这与 spec.md 第 9 节待拍板项 1 直接相关。
3. **窗口模式是 iPadOS 26 的一等形态。** 需要一个宽度约 635 pt、hSC = compact 的窗口档位纳入设计矩阵（spec.md §3 第 6 行）。

## 未执行 / 明确边界

- Split View 1/2、1/3、Slide Over、Stage Manager 自定义尺寸、iPhone Pro Max 横屏：本轮未实测。`xcrun simctl` 无分屏/窗口缩放接口，`agent-device` 拒绝系统边缘手势（返回 `Move the gesture away from the edge`），无法脚本化。这些档位在 spec.md §3 标注为「待复核（R6）」，由实现 Issue 的设备验收矩阵补全，负责人：iPad 应用工程师。
- 未做 Dynamic Type 超大字号、VoiceOver 人工体验、Pencil Scribble 验收；属实现 Issue 的阶段 D。
- 未做真机验证（本轮全部为模拟器）。
- 未修改任何签名、Bundle ID、版本号或 App Store Connect 资源；未上传 TestFlight。
