# 设计决定

- R3：新客户端处理认证与敏感数据，即使复用共享核心仍按最高风险处理。
- 原生 SwiftUI + AppKit：与 iOS 共享业务模型，桌面独立布局与平台适配；不采用 WebView 壳。
- 共享包暂留 ios/Packages/ChattyKit：已声明 macOS 支持，避免给正在并行工作的移动端增加目录迁移。
- 单主窗口、宽屏侧栏、Cmd+Return 发送；保持队列语义，降低多窗口重复驱动风险。
- macOS 15+；优先 Apple Silicon 验收，Intel 编译和实机验证分别报告。
- 本地 DMG 交付；公证取决于现有 Apple 权限，签名、公证、安装启动与真实 API 集成分别举证。
