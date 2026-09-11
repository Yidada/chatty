# Stage A 实现与验证记录（CLE-89）

- 父任务：CLE-88「Chatty iOS：iPad / iPadOS 自适应实现」阶段 A「工程配置与自适应壳」。
- 设计依据：[spec.md](spec.md)、[plan.md](plan.md)（CLE-84 交付，PR #5）。
- 起点：`main` `7397e6b`（PR #5 已合入，含本目录设计文档）。
- 环境：Xcode 26.6 (17F113)、iOS 26.5 SDK、iPad Pro 13-inch (M5) 模拟器、iPhone 17 Pro 模拟器。

本文件只记录**已实测**的结果；未执行的项在 §5 明确列出。

## 1. 改动

| # | 项 | 文件 | 内容 |
| --- | --- | --- | --- |
| 1 | 设备族 | `scripts/generate-ios-project.py:36` | `TARGETED_DEVICE_FAMILY` `'1'` → `'1,2'`（三个 target 的 6 处配置） |
| 2 | 方向 | `scripts/generate-ios-project.py:56` | `UISupportedInterfaceOrientations` 补齐四方向，并新增 `UISupportedInterfaceOrientations~ipad`；`UIApplicationSupportsMultipleScenes` **保持 `False`**（多窗口属阶段 C） |
| 3 | 生成产物 | `ios/Chatty.xcodeproj/project.pbxproj`、`ios/Config/*-Info.plist` | 全部由 #1/#2 重新生成，未手改 pbxproj |
| 4 | 自适应壳 | `ios/Chatty/WorkspaceTabs.swift`、`ios/Fixture/FixtureRootView.swift` | `TabView` 增加 `.tabViewStyle(.sidebarAdaptable)` |
| 5 | 详情空态 | `ios/Chatty/ChatScreen.swift:51` | 空态条件由 `messages.isEmpty && agent != nil` 放宽为 `messages.isEmpty`：无 Mika 时给「当前工作区还没有可对话的 Mika」引导，不再出现空白栏 |
| 6 | 可读列宽 | `ios/Chatty/AppBootstrap.swift` | 登录页与离线草稿页加 `readableColumn()`（`maxWidth: 560` + 居中）；紧凑宽度下可用宽度本身小于 560，布局与改造前逐点一致 |

判定依据全部来自可用宽度与系统 size class，**没有引入 `userInterfaceIdiom` 分支**；全仓 `grep userInterfaceIdiom` 仍为空。

生成产物核对（安装后的包，非源码）：

```
UIDeviceFamily                     = [1, 2]
UISupportedInterfaceOrientations   = Portrait / PortraitUpsideDown / LandscapeLeft / LandscapeRight
```

## 2. 构建验证

```
xcodebuild -project ios/Chatty.xcodeproj -scheme Chatty -configuration Debug \
  -destination "generic/platform=iOS Simulator" -derivedDataPath .tools/dd \
  CODE_SIGNING_ALLOWED=NO build
→ ** BUILD SUCCEEDED **
```

`ChattyFixture`（含 `ios/Fixture`、`ChattyFixtureSupport`）在同一工程上对具体模拟器构建亦通过，用于下面的截图与 R1 实验。

## 3. 截图证据

| 档位 | 设备 / 尺寸 | 文件 | 观察 |
| --- | --- | --- | --- |
| 常规宽度（竖） | iPad Pro 13" / 1032 × 1376 pt | `evidence/stage-a/ipad-regular-01-activity.png` | 顶部 Tab 栏（`Toggle sidebar` + 动态/Mika/项目，y = 72.5），动态页自适应 |
| 常规宽度 + 展开侧栏 | 同上 | `evidence/stage-a/ipad-regular-02-sidebar.png` | 无障碍树出现 `collection`（动态/Mika/项目 三行）+ `Hide Sidebar`，主区仍保留动态详情 → 侧栏 + 详情，非空白 |
| 常规宽度 · Mika | 同上 | `evidence/stage-a/ipad-regular-03-mika.png` | 对话页在宽列下正常，composer 不裁切 |
| 常规宽度 · 项目 | 同上 | `evidence/stage-a/ipad-regular-04-projects.png` | 列表 + 搜索由系统自适应 |
| 常规宽度 · 无 Mika 空态 | 同上（fixture `deny_mika`） | `evidence/stage-a/ipad-regular-05-mika-empty-state.png` | 无障碍树出现「当前工作区还没有可对话的 Mika」「可在「设置 › Agents」查看工作区里的 Agent，或切换工作区。」→ **不是空白栏**（spec §7 R8） |
| 紧凑宽度 | iPhone 17 Pro / 402 × 874 pt | `evidence/stage-a/iphone-compact-01-activity.png`、`-02-mika.png`、`-03-projects.png` | 无障碍树为 `Tab Bar` + 底部按钮，与改造前一致（Tab 切换后画面差异 32.7% / 32.9%，确认三个页面各自渲染） |
| R1 窗口几何 | iPad Pro 13" / 635 × 1376 pt | `evidence/stage-a/r1-legacy-window-635pt.png` | 通用 App 覆盖安装后仍被 letterbox 到 635 pt 宽（见 §4）；该窗口下 AX 场景为 635 × 1376、底部 `Tab Bar`，紧凑壳可用 |

截图来源：`ChattyFixture` scheme + `scripts/ios-fixture.py` 合成服务（loopback `127.0.0.1:8767`，不接触生产数据）。常规宽度截图安装在一个**全新 bundle id**（`ai.chatty.ios.probe`）下，原因是 §4 的 R1 遗留窗口会持续把同一 bundle id 拉回紧凑宽度——这是复现「首装即全屏」的唯一手段，与 CLE-84 设计阶段的实验做法一致。

截图抓取方式：IOS 模拟器 AX 树上，`.sidebarAdaptable` 顶部 Tab 栏的按钮被标记 `covered` / `hittable=false`，`agent-device` 的 label 选择器会拒绝点击；常规宽度截图因此用 `snapshot --raw --json` 读到的元素矩形按下坐标，紧凑宽度（底部 Tab 栏）按钮可直接按 label 点击。

## 4. R1 窗口几何重算验证（实测）

问题（spec §7 R1）：iPadOS 26 按 bundle id 记忆窗口几何，iPhone-only 时期留下的 635 × 1376 pt 窄窗在改为通用 App 后是否仍被沿用，能否重算。

方法：每次改动后 `simctl launch` 同一 bundle，用截图像素分析测量应用窗口矩形（`ChattyTheme.background` 区域，@2x）。

| 实验 | bundle id | 操作 | 窗口 |
| --- | --- | --- | --- |
| 基线 | `ai.chatty.ios.fixture` | 安装 iPhone-only 构建（`7397e6b`） | **635 × 1376** |
| ① 升级为通用 App | 同上 | 直接覆盖安装通用构建 | **635 × 1376**（未重算） |
| ② 卸载 + 重装 | 同上 | `simctl uninstall` 后重装通用构建 | **635 × 1376**（未重算） |
| ③ `UIApplicationSupportsMultipleScenes = true` | `ai.chatty.ios.r1a` | 先 iPhone-only 建立窄窗，再覆盖安装通用 + 多场景构建 | **635 × 1376**（未重算） |
| ④ `UIRequiresFullScreen = true`（仅验证，不采用） | `ai.chatty.ios.r1b` | 先 iPhone-only 建立窄窗，再覆盖安装通用 + 全屏构建 | **1032 × 1376**（强制全屏） |
| ⑤ 对照：全新 bundle id | `ai.chatty.ios.probe` | 直接安装通用构建 | **1032 × 1376**（全屏，regular） |

机制（本机可复现的存储位置）：几何记录不在 App 容器内，而在**系统级 FrontBoard 存储**里：

```
~/Library/Developer/CoreSimulator/Devices/<UDID>/data/Library/FrontBoard/applicationState.db
  view kvs_debug where application_identifier='<bundle id>'
  key = SBApplicationLastWindowSizePerDisplayOrdinalKey
  value(plist) → { Width = 635, Height = 1376, ... }
```

因此：

1. **R1 成立且不是 App 能自愈的**：升级、卸载重装、开启多场景都不会重算；记录以 bundle id 为键存在系统库里，App 无法清除。
2. **唯一在代码层面能强制全屏的是 `UIRequiresFullScreen = true`**（实验 ④），但它会禁用分屏/Slide Over，与本次多任务目标直接冲突，因此**不采用**——与父任务待确认项 5 的结论一致。
3. 可用的用户侧路径仍是「手动全屏/调整窗口」或重装为不同 bundle id；本次未脚本化验证「用户手动全屏后记录是否被更新」（iPadOS 26 的窗口调整是系统手势，`agent-device` 拒绝系统边缘手势，`simctl` 无窗口几何接口）。
4. **取舍不变**：紧凑宽度必须完整可用，所以 R1 不阻塞本阶段。R1 记录存在时实测到的确是紧凑呈现（\u65e0\u969c\u788d\u6811\u573a\u666f 635 × 1376 + 底部 `Tab Bar`），但同一次会话后续又出现常规宽度呈现（顶部 Tab 栏），说明窗口几何在同一安装内也会被系统/用户改变；本阶段的「紧凑可用」结论主要由 iPhone 17 Pro 截图与既有紧凑布局支持。

## 5. 未执行 / 边界

- **横屏截图未取得**：`agent-device orientation landscape-left/right` 报告成功，iPhone 17 Pro 的 `Application.rect` 也变为 874 × 402（说明方向解锁在运行时生效），但模拟器截图始终输出 402 × 874 的竖屏帧，iPad 同样未产生实际旋转；`simctl` 无方向接口。方向解锁本身另有安装包 Info.plist 四方向与 `~ipad` 键为证。
- Split View 1/2、1/3、Slide Over、Stage Manager 自定义尺寸：仍按 spec §3 标注为「待复核」，属阶段 D 的设备矩阵。
- Dynamic Type、VoiceOver、Pencil Scribble、指针 hover/拖放：阶段 B / D。
- 多窗口（`UIApplicationSupportsMultipleScenes`、`openWindow`、轮询去重）：阶段 C，本阶段保持 `false`。
- 未修改签名、Bundle ID、版本号或 App Store Connect 资料；未上传 TestFlight。
- 未做真机验证（本阶段全部为模拟器）。
