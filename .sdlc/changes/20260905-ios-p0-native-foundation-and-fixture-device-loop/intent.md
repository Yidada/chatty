# iOS P0：原生工程与合成设备闭环

用户在审阅 `.sdlc/changes/20260905-complete-ios-v1-native-client-p1-through-p5/design-plan.md` 和局域网 HTML 后说“good 下一步”，并显式调用 AI-Native SDLC。继续已提出的 IOS-P0，形成可以构建、启动、读取合成服务及重放的最小工程。

## 结果
- SwiftUI iPhone 应用实际运行，提供对话、项目、设置三入口。
- Chatty 与 ChattyFixture 分开编译，只有 Fixture 读取本机合成服务。
- 固化主要 DTO、未知/空值兼容与 Markdown 技术验证；建立可复用命令、测试和设备证据。

## 范围与边界
- iOS 26+、SwiftUI、Swift Package；本地交付。
- P0 只用合成数据，不接真实登录、Keychain、消息发送、Issue 写入或生产服务；这些仍按后续 P1/P2/P4 处理。
- 不修改现有 Android 行为，不创建外部 Issue，不推送或发布。
- iPhone 模拟器成功不代表物理 iPhone 或真实业务验收。

## 验收
P0-1 两个 scheme 构建；P0-2 契约与错误路径测试；P0-3 模拟器从 fixture 显示数据；P0-4 三 Tab 和 Markdown 示例重放；P0-5 服务失败可见且恢复；P0-6 正常包不包含 fixture 客户端和合成 token。
