# Evidence: iPad 侧边栏移除

## 改动

| 文件 | 改动 |
| --- | --- |
| `ios/Chatty/WorkspaceTabs.swift` | `.tabViewStyle(.sidebarAdaptable)` → `.tabBarOnly` |
| `ios/Fixture/FixtureRootView.swift` | `.tabViewStyle(.sidebarAdaptable)` → `.tabBarOnly` |
| `scripts/generate-ios-project.py` | `CURRENT_PROJECT_VERSION` 10 → 11 |

## 验证

| 检查 | 命令 | 结果 |
| --- | --- | --- |
| 包测试 | `swift test --package-path ios/Packages/ChattyKit --scratch-path .tools/ios-swift-build` | 98 tests / 0 failures |
| iPad 单栏实测 | iPad Pro 11-inch (M5) 模拟器，`ChattyFixture`，登录 → 选择工作区 → 动态页 | 顶部 Tab 栏（动态 / Mika / 项目），**无侧边栏** |
| 截图 | `evidence/01-ipad-tabbar-no-sidebar.png` | 见下 |

## 说明

- 移除前的侧栏证据（旧 change）：`.tools/release-0.2.0/.sdlc/changes/20260910-ios-ipad-adaptive/evidence/03-ipad-regular-sidebar-visible.png`
- iPad 上 `.tabBarOnly` 呈现为顶部 Tab 栏，仍为单栏内容；iPhone 行为不变（底部 Tab 栏）。
