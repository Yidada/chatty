# Stage 3 收口：两处逐屏实现缺口修复（CLE-96）

- 父任务：CLE-88「Chatty iOS：iPad / iPadOS 自适应实现」Stage 3 收口。
- 设计依据：[spec.md](spec.md) §5 逐屏适配表「事项详情 = 改」「深链资源 Sheet = 改」。
- 背景：Stage D（CLE-92）在设备矩阵与无障碍实测执行前被取消；其静态逐屏核对指出这两条 spec 判为「改」的项在 A–C 中未兑现。本文件只补这两处实现缺口，不复跑 CLE-92 的矩阵。
- 起点：`origin/main` `21665f9`（A/B/C 合入点 `dca86e2`，其后为 macOS 客户端提交）。
- 环境：Xcode 26.6、iOS 26.5 SDK、iPad Pro 13-inch (M5) 模拟器（1032 × 1376 pt，regular）、iPhone 17 模拟器（402 × 874 pt，compact）、`scripts/ios-fixture.py` 合成服务（loopback）。

本文件只记录**已实测**的结果。

## 1. 改动

| # | 项 | 文件 | 内容 |
| --- | --- | --- | --- |
| 1 | 可读列宽 helper 复用 | `ios/Chatty/AppBootstrap.swift` | `readableColumn()` / `readableColumnWidth` 由 file-private 改为 internal，供登录、离线草稿、事项详情共用；实现（`frame(maxWidth: 560, alignment: .leading).frame(maxWidth: .infinity)`）不变 |
| 2 | 事项详情可读列宽 | `ios/Chatty/ProjectsScreen.swift` | `IssueScreen` 正文 `padding(24).frame(maxWidth: .infinity, alignment: .leading)` → `padding(24).readableColumn()` |
| 3 | 深链资源呈现 | `ios/Chatty/WorkspaceTabs.swift` | TabView 壳抽为 `tabShell`；新增 `LinkedScreenPresentation`：常规宽度 `.popover(item:attachmentAnchor: .point(.center))`，紧凑宽度原 `.sheet(item:)`；弹窗内容抽为 `linkedScreen(_:)` 供两种呈现共用；`NativeLink` 解析逻辑未动 |

选择说明：spec §5 对深链资源给出「`.popover` 或并入详情列」两个口径，本实现取 **popover**——它在不改动各 Tab 的 `NavigationStack` 结构、不引入第二套导航状态的前提下满足「常规宽度不再整屏铺满、保留工作区上下文」。深链没有可锚定的来源视图，因此把锚点显式钉在壳中心（`.point(.center)`）；默认的 `.rect(.bounds)` 会把弹窗挤到屏幕角落。

## 2. 证据

| 项 | 档位 | 结果 | 证据 |
| --- | --- | --- | --- |
| 事项详情可读列宽 | 常规 1032 × 1376 pt | 正文列 x=260、宽 512（= 560 − 48 padding）；标题/正文/整宽按钮同列，长正文换行后 509.5 × 328.5 pt（未拉满 984 pt） | `evidence/stage-3/regular-issue-detail-readable-column.png` |
| 事项详情可读列宽 | 紧凑 402 × 874 pt | x=24、整宽按钮宽 354（= 402 − 48）；与改造前逐点一致（可用宽度 < 560，helper 为恒等变换） | `evidence/stage-3/compact-issue-detail-readable-column.png` |
| 深链资源呈现 | 常规 1032 × 1376 pt | 首次呈现为居中的 popover：内容 x=516、433 × 476 pt（导航栏 433 × 54 + 正文 433 × 422），窗口四周仍是工作区；点 popover 外 (120, 1300) 即关闭并回到「事项」详情 → popover 语义（Sheet 不会因点击背景关闭） | `evidence/stage-3/regular-deeplink-popover.png` |
| 深链资源呈现 | 紧凑 402 × 874 pt | 仍为 Sheet：呈现宽度 402（整屏宽），y=62 起，内容 x=24、宽 354；与改造前同一条 `.sheet(item:)` 路径 | `evidence/stage-3/compact-deeplink-sheet.png` |

测法：合成服务 + `ChattyFixture` target（包含 `Chatty/` 全部真实屏幕，`CHATTY_FIXTURE` 配置指向 loopback），用 `agent-device` 读无障碍树每个节点的 `rect`，而非只看截图。为让深链可点，证据运行期用一次性包装脚本在合成数据的事项描述里加了两条 markdown 链接（`mention://issue/i1`、`mention://project/p1`）；该脚本写在 gitignore 的 `.tools/` 下，未入库。

常规宽度「改造前 984 pt」是按旧实现（padding 24 + `frame(maxWidth: .infinity)`）推算，未单独构建旧版实测；其余数字均为实测。

## 3. 构建与测试

```
xcodebuild -project ios/Chatty.xcodeproj -scheme Chatty -configuration Debug \
  -destination "generic/platform=iOS Simulator" -derivedDataPath .tools/dd CODE_SIGNING_ALLOWED=NO build
→ ** BUILD SUCCEEDED **

swift test --disable-sandbox --package-path ios/Packages/ChattyKit --scratch-path .tools/ios-swift-build
→ Executed 55 tests, with 0 failures

xcodebuild -project ios/Chatty.xcodeproj -scheme ChattyFixture -configuration Debug \
  -destination "platform=iOS Simulator,id=<iPad Pro 13-inch (M5)>" -derivedDataPath .tools/dd-fixture \
  PRODUCT_BUNDLE_IDENTIFIER=ai.chatty.ios.cle96 CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- build
→ ** BUILD SUCCEEDED **
```

## 4. 未执行 / 边界

- CLE-92 的设备矩阵（Split View 1/2、1/3、Slide Over、Stage Manager 自定义尺寸、iPhone Plus/Max 横屏 regular、iPad mini、遗留窄窗）、Dynamic Type、VoiceOver、命中区 ≥44 pt 审计、sheet/popover 与窗口边缘、深色模式与 R1 复验均**未执行**，按父任务口径登记为「已知未覆盖」，不属于本 Issue。
- 常规宽度的「改造前」列宽为推算值（§2）。
- 全部为模拟器验证，未上真机；未改签名、Bundle ID、版本号或 App Store Connect 资料。
- 本轮同时最多 boot 一台模拟器，用完即 `xcrun simctl shutdown`，未复现 CLE-92 的资源耗尽。
