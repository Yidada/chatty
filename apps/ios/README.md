# iOS App

- Swift 6 + SwiftUI，最低 iOS 17
- Swift Concurrency（严格并发检查）
- 只使用系统框架：SwiftUI、SwiftData、AVFoundation、Network、Security

## 定位

薄客户端，只负责界面和状态展示，不执行任何 Agent 逻辑。
所有 Harness 差异由 Runner 抹平，iOS 只渲染统一的 Timeline Item。

## MVP 页面

| 界面 | 内容 |
| --- | --- |
| 会话页（主界面） | 打开即进入；流式对话、工具调用合并折叠、改动卡片 |
| 顶部标题 | 「Harness · Model ▾」+「仓库 · 分支」，点击弹出切换面板 |
| 底部审批面板 | 同意 / 拒绝，出现时暂时替代输入框 |
| 侧边抽屉 | 搜索、按仓库分组的 Session 列表、Runner 状态、设置入口 |
| 设置页 | Runner 配对（扫码）、Agent 管理 |

交互草图：[`docs/design/ios-mvp-sketch-v2.png`](../../docs/design/ios-mvp-sketch-v2.png)（源文件 `.excalidraw` 可在 excalidraw.com 打开）。

模块规划见 [`docs/architecture.md`](../../docs/architecture.md) 第 3.2 节。

状态：M2 开始创建 Xcode 工程。
