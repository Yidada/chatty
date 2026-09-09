# iOS V1 完整开发

来源：用户已审阅 .sdlc/changes/20260905-complete-ios-v1-native-client-p1-through-p5/design-plan.md 和 HTML 方案，完成 P0 后明确说「没问题，全部执行开发完吧」。目标是离开电脑后能在 iPhone 登录同一 Multica 工作区，与 Mika 工作、查看过程和附件、处理项目进度。

范围：原方案 IOS-P1–P5，SwiftUI / iOS 26+，对话、项目、设置三 Tab。保持现有 Android 不变，复用已核实后端协议。普通 target 与 Fixture target 共用真实业务代码，配置和凭据隔离。只交付本地代码和开发构建，不包含 TestFlight/App Store/服务端部署。

验收：A01–A14 按原方案逐项记录开发、合成验证、模拟器和真机证据。尚未取得的账户、物理设备、具体真实发送授权属于外部验收依赖；不能用 fixture 替代，也不因此停止独立可完成的开发。
