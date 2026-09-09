# 实施计划

## 来源和授权
- 用户已审阅 iOS 方案后说“good 下一步”；授权本地实施下一个 IOS-P0 交付，以及构建和模拟器验证所需可逆操作。
- 源计划：.sdlc/changes/20260905-complete-ios-v1-native-client-p1-through-p5/design-plan.md §8 IOS-P0。当前 Git main 3c003f9；已有未跟踪 iOS 方案文件保留。
- R2：新增客户端工程、依赖和配置；全部使用合成数据。无真实认证或敏感数据处理，故本切片未触发 R3。后续真实认证切片单独分类。

## 顺序
1. 固化 R2 intent/spec/plan/decisions；进入 Build。
2. 新增 Swift Package、精确依赖锁与来自现有 fixture 的合成契约样本；实现纯解析、分页/回执验证和只读 fixture 客户端。
3. 新增 Xcode 工程、两 app targets 与 iOS 单测，SwiftUI 三 Tab 与基础 Markdown 渲染。
4. 新增 ios-env、ios-dev-loop 及 .ad 流程，隔离 DerivedData 与证据到 .tools。
5. 运行 Swift 单元测试、XcodeBuildMCP 模拟器构建/运行、iOS 测试、agent-device 稳定导航和失败恢复。
6. 构建普通 Release 模拟器包检查隔离；更新 ios/README 与 iOS progress；自审和 R2 证据后仅本地关闭本 P0 变更。

## 工具和命令
已验证 Xcode 26.6、Swift、iOS 26.5 iPhone 17 Pro 模拟器、agent-device 0.20.10 可用。XcodeBuildMCP 用于应用构建/启动/测试，agent-device 用于流程证据。无须重新确认启动模拟器，属于用户已授权的 P0 开发步骤。

待工程创建并实际验证：swift test --package-path ios/Packages/ChattyKit --scratch-path .tools/ios-swift-build；scripts/ios-dev-loop.sh；agent-device replay tests/device/ios/p0-navigation.ad --platform ios。

## 检查策略
只运行 P0 相关 Swift/iOS 检查，不对未改变的 Android 做无关构建。HTML 方案原样保留，进度另写 progress.md，LAN 预览保持可访问。
