# Chatty Android

Kotlin / Compose Android 客户端。所有服务端事实来自 Multica，当前主线已包含登录、动态列表、Mika 连续发送、项目与验收反馈；动态批量操作和左右滑仍待 CLE-99 完成。

## 构建

```bash
# 从仓库根目录运行，macOS zsh 与 Linux bash 均可
source scripts/android-env.sh
android/gradlew -p android :app:assembleDebug test lint
scripts/dev-loop.sh android/app/build/outputs/apk/debug/app-debug.apk ai.chatty.app.debug ai.chatty.app.MainActivity
```

- JDK 17；Gradle Wrapper 8.7；AGP 8.6.1；Kotlin 1.9.25；Compose compiler 1.5.15。
- `compileSdk/targetSdk = 35`，`minSdk = 26`；已在 Android 16 的 Pixel 6 Pro 上验证。
- Debug 包：`ai.chatty.app.debug`，Release 包：`ai.chatty.app`。
- 当前源码版本为 `0.2.0`（versionCode 2）；功能缺口见 [开发对齐记录](../docs/development-alignment-2026-09-13.md)。
- SDK 通过 `ANDROID_HOME` / `android/local.properties` 指定，默认 `.tools/android-sdk`；JDK 使用现有 Homebrew OpenJDK 17。
- Gradle 依赖缓存位于 `.tools/gradle-home`。本地 SDK、缓存、APK 不提交 Git。

版本兼容依据：[AGP 8.6](https://developer.android.com/build/releases/agp-8-6-0-release-notes)、[Compose/Kotlin 映射](https://developer.android.com/jetpack/androidx/releases/compose-kotlin)。固定版本复现现有 V2 工具链，不进行无关升级。

## 模块

| 模块 | 职责 |
|---|---|
| app | Compose 页面、Hilt 装配、界面状态 |
| core-model | 按 Multica 源码定义的序列化 DTO |
| core-network | Retrofit、OkHttp、认证头与 401 处理 |
| core-auth | Keystore 加密存储、登录与工作区 |
| feature-chat | Mika 对话、连续发送、队列与 Runtime 绑定刷新；语音待办 |
| feature-status | 状态与附件功能边界，后续 M5/M6 |
| feature-approval | 需要回复的近似卡片，后续 M6 |
| feature-inbox | 动态列表、待关注、分页与本机已读指纹；批量和滑动待办 |
| feature-agents | Agent Fleet，后续 M7 |
| feature-issue-link | 预留模块；当前项目与事项使用原生入口 |

仅 app 依赖所有 feature，feature 不反向依赖 app 或彼此。`feature-workspace` 承担项目、事项、资源与设置；空模块不代表对应功能已交付。

## 登录边界

- 默认连接 `https://api.multica.ai/`，不复用或导入 CLI 凭据。
- 邮箱验证码直接由用户在手机输入；验证码不存储、不进入状态恢复和日志。
- JWT 与上次 workspace slug 保存在 Keystore 支撑的加密 SharedPreferences。
- 禁用云备份、ADB 备份和设备迁移中的应用数据。
- 仅带当前凭据的 API 请求收到 401 时清 token；403、503、断网保留凭据。
- 禁止自动网络重试与跨站跳转，防止重复发送和凭据泄露。
- 注销清本机凭据与工作区选择，服务端 token 生命周期仍由 Multica 管理。
- 工作区列表仅保存在内存，冷启动从服务端重新读取。

## 合成登录真机验证

详见 [`../docs/android-dev-loop.md`](../docs/android-dev-loop.md)。测试包 `ai.chatty.app.fixture` 与真实登录包隔离，测试服务只绑定本机，不访问 Multica。
