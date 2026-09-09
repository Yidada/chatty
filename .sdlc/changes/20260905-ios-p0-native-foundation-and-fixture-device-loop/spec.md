# P0 规格

## 用户可见行为
- ChattyFixture 清楚标识测试工作区。初始加载最新 50 条合成消息，按服务端项目计数显示项目，原生查看 Runtime/Agent/Squad 样本。
- 加载、空态、HTTP 错误和重试明确；重试只发 GET，不发消息或修改 Issue。
- 原生 TabView、各 Tab NavigationStack、系统字体及动态明暗主题。首版 P0 composer 为只读提示，不假装已经接入发送。
- Chatty 正常包显示尚未连接的壳页面；P1 才接登录。

## 结构与契约
- ios/Chatty.xcodeproj：Chatty、ChattyFixture、ChattyFixtureTests；iOS 26，独立 bundle IDs，Fixture 编译标志与 sources 分离。
- ios/Packages/ChattyKit：ChattyCore（Codable/纯逻辑/Markdown），ChattyFixtureSupport（固定 loopback 客户端，仅 Fixture 依赖）。
- 参考 Android ChatModels/WorkspaceModels、Multica 1cc46b269。必须覆盖 nullable 附件、缺失可选项、双游标、回执缺少 task_id、未知事件 payload。
- 固定 fixture URL http://127.0.0.1:8765，只使用仓库 synthetic-device-fixture-token；无可注入的真实凭据或任意远端 base URL。
- URLSession ephemeral；禁用重定向、系统凭据和 cookies。客户端只有 GET 接口，HTTP 失败不自动重试。
- Markdown 采用 swiftlang/swift-markdown 0.8.0 精确版本进行解析与原生视图技术验证。首版 P0 不执行 HTML/脚本，不打开消息链接；完整呈现验收仍属 P3。

## 失败和恢复
- 503/无服务 → 内容错误与手动重试；恢复服务后同页面重试成功。
- 异步取消正常返回，generation 丢弃旧刷新结果，避免重复 .task 请求。
- 主模型必填字段错误明确解码失败；未知枚举/事件保留为字符串/JSON，不能导致整个协议层崩溃。

## 验收到检查
- P0-1：Fixture Debug、Chatty Release 模拟器构建。
- P0-2：swift test 的 JSON、回执、分页、Markdown 与网络错误用例；ios-check-redirect.py 实际 HTTP 302 检查；iOS XCTest 契约冒烟。
- P0-3/P0-4：agent-device 在 iPhone 模拟器按稳定 ID 读取、切换与重放，截图验证。
- P0-5：合成服务 503 → 刷新显示错误 → 服务 200 → 重试恢复；请求记录无 send 或 Issue 写入。
- P0-6：构建 settings、Info.plist 与 binary 检查，正常包无 Fixture product/synthetic token/ATS 放宽。
