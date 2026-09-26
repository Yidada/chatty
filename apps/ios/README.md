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

## 当前状态：UI 原型

- 界面和交互按 v2 草图实现，所有数据都是演示数据，尚未连接 Runner。
- 发一条消息会播放一段模拟执行：工具调用 → 流式回复 → 请求审批 → 同意或拒绝 → 改动卡片。
- 核心状态在 `Chatty/Stores/AppStore.swift`，单元测试在 `ChattyTests/`。

## 本地运行

需要 Xcode 26 和 XcodeGen：

```bash
brew install xcodegen
cd apps/ios
xcodegen generate        # 生成 Chatty.xcodeproj（不提交到仓库）
open Chatty.xcodeproj
```

## 发布到 TestFlight（GitHub Actions）

流水线：`.github/workflows/ios.yml`，运行在 GitHub 托管的 `macos-26` 机器上。

| 触发方式 | 执行内容 |
| --- | --- |
| 推送到 `v3` 或向 `v3` 发 PR（改动了 `apps/ios`） | 生成工程、运行单元测试 |
| 推送 `ios-*` 标签，例如 `ios-0.3.0-1` | 单元测试 → 归档 → 上传 TestFlight |

一次性准备：

1. App Store Connect → 用户和访问 → 集成 → App Store Connect API，生成密钥，角色选 **Admin**（云端自动签名需要）。
2. 下载 `.p8` 文件，记下 Key ID 和 Issuer ID。
3. GitHub 仓库 → Settings → Secrets and variables → Actions，添加：
   - `ASC_KEY_ID`
   - `ASC_ISSUER_ID`
   - `ASC_KEY_P8`：`.p8` 文件的完整文本

发布一个版本：

```bash
git tag ios-0.3.0-1
git push origin ios-0.3.0-1
```

说明：

- App 记录沿用 `ai.chatty.ios`（Team `9247PC9936`），营销版本 `0.3.0`。
- 构建号取 UTC 时间 `yyMMddHHmm`，保证递增。
- Info.plist 已声明 `ITSAppUsesNonExemptEncryption = NO`，上传后不需要回答出口合规问卷。
- 上传后 App Store Connect 需要 5–30 分钟处理。内部测试组如果没有开启自动分发，需要在 TestFlight 页面手动把新构建加入测试组。
