# Chatty

Chatty 是 Multica 的原生客户端。用户通过 Mika 对话发起工作，通过动态和项目查看进展；身份、任务、Agent 与 Runtime 状态由 Multica 提供。

## 当前基线（2026-09-13）

日常开发使用 `main`。本地新版 Mika 对话与 iPad 侧栏移除已整合，回车发送来自 [PR #13](https://github.com/Yidada/chatty/pull/13)。开发状态与清理依据见 [本次对齐记录](docs/development-alignment-2026-09-13.md)。

| 平台 | 已进入主线的内容 | 尚未完成的部分 |
| --- | --- | --- |
| iOS / iPadOS | 登录、动态批量与滑动操作、Mika 历史/富文本/数学内容、停止和队列、回车发送、单栏 iPad 布局 | 最新整合源码尚未重新打包；中文输入法手动体验和硬件键盘仍有人工验收项 |
| Android | 登录、动态列表与已读指纹、Mika 连续发送、项目与验收反馈 | 动态批量操作和左右滑、语音输入、受控性能基线 |
| macOS | 原生 SwiftUI 客户端、动态/Mika/项目、共享 ChattyKit 核心 | 本轮未做 Mac 回归与重新分发 |
| Web | 独立 Sites 工作目录及 0.2.0 发布记录 | 本轮只整理本 Git 仓库，未重新发布 Web |

源码统一不代表四端功能或安装包相同。发布结果按 [发布流程](docs/releases/README.md)、[iOS TestFlight 记录](ios/TESTFLIGHT.md) 和各端证据分别核对。

## 开发入口

- [iOS](ios/README.md)：Xcode 工程、ChattyKit 与合成服务。
- [Android](android/README.md)：Gradle 构建、模块与设备验证。
- [macOS](macos/README.md)：共享核心、原生界面与公证打包。
- [设备测试](tests/device/README.md)：各平台回放与验证边界。
- [开发记录](.sdlc/README.md)：当前变更和历史证据索引。

```sh
# Apple 共享核心
swift test --package-path ios/Packages/ChattyKit --scratch-path .tools/ios-swift-build

# Android（仓库根目录）
source scripts/android-env.sh
android/gradlew -p android :app:assembleDebug test lint
```

## 分支与待办

- `main`：已整合的产品基线；本地与 `origin/main` 保持一致。
- `agent/mika/01a08d0a`：[PR #7](https://github.com/Yidada/chatty/pull/7)，性能测量插桩。它尚未进入主线，保留给 CLE-95 的受控 B0 采集；其本地分支与远端对应分支一致。
- CLE-99：Android 动态批量与滑动仍待实现，按代码事实跟踪。
- CLE-64：语音转写待办；CLE-70 / CLE-95：性能基线与预算仍待完成。

早期 Lark Context Layer 设想和已替代的迭代说明从当前入口移除，可通过 Git 历史查阅。历史 `.sdlc` 证据继续保留，完成的代码与过期计划分开阅读。
