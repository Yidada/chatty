# Mac 版 Chatty：原生客户端与 DMG

## 用户目标
在仓库新建 macos/，实现与现有 iOS、Android 一致的业务功能与架构，交付可以安装验收的 DMG。来源：2026-09-11 用户明确要求全流程开发并调用 AI-Native SDLC。

## 可观察结果
- macOS 15+ 原生应用，Apple Silicon 优先，尽可能产出 arm64/x86_64 通用构建并实际核验架构。
- 动态 / Mika / 项目导航，右上角头像设置；使用真实 Multica API 的邮箱验证码登录。
- 全工作区事项、红点、详情与主要动作；连续发送消息时输入框可继续使用，每条消息保留项目快照。
- DMG 包含 Chatty.app 与 Applications 链接，附安装说明和 SHA-256；从镜像复制后能启动。

## 约束与边界
复用 ios/Packages/ChattyKit 中已支持 macOS 15 的 ChattyCore；保持 iOS/Android 已有行为和当前未提交工作。macOS 独立 bundle、Keychain service、应用数据目录。无新后端、无 APNs、无后台常驻代理、无自动更新系统。真实账号写操作由用户在验收中触发；自动测试使用隔离合成服务。

## 已验证背景
本机 arm64，Xcode 26.6 (17F113)。仓库已有 iOS SwiftUI、ChattyCore 的 macOS 平台声明；界面中的 UIKit、照片选择和导航栏 API 需要桌面适配。已有多个 Android/iOS 未提交修改，保持不动。没有现有 macOS 变更目录。

## 不确定项
现有 Developer ID 证书和公证账户是否可用尚未核验；DMG 的签名、公证和 Gatekeeper 结果分别记录。无法取得公证权限时交付本地验收包并明确限制，不声称已经公证。Intel 架构可以编译验证，本机无法验证 Intel 真机运行。
