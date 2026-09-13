# Intent: 去掉 iPad 侧边栏（单栏对齐）

- Author: 实施会话
- Status: 完成（0.2.0 (11) 已上传 TestFlight 内测组）
- Stage: Build + Release
- 上游决策：`../20260912-ios-deepseek-chat-alignment/decisions.md` D6 与 `spec.md §10`

## 目标

按 D6「iPad 与 iPhone 同样走单栏，不做侧栏」，移除 `WorkspaceTabs` 在 iPad 常规宽度下由
`.tabViewStyle(.sidebarAdaptable)` 产生的侧边栏，改为 `.tabBarOnly`，让 iPad 与 iPhone
保持同一套单栏 Tab 外壳。

## 范围

- `ios/Chatty/WorkspaceTabs.swift`：`.sidebarAdaptable` → `.tabBarOnly`
- `ios/Fixture/FixtureRootView.swift`：同上（夹具与生产一致）
- 不改 Tab 数量、深链、多窗口与历史抽屉语义（D5 / D7 不变）
