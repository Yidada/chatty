# Chatty Android · 导航连续性预览版

本版提供 Android 原生导航连续性，适合当前 Pixel 开发测试。

## 更新

- 切换对话、项目、设置 Tab 后，保留详情、搜索、筛选、分页和阅读位置。
- Issue、Runtime、Agent、Squad 使用完整详情页，支持顶部返回和系统逐级返回。
- 工作区切换使用可取消的底部面板，确认切换后隔离旧工作区状态。

## 安装包

- Android APK：`chatty-android-v0.2.0-android.20260905.apk`
- 包名：`ai.chatty.app.debug`；应用版本：`0.2.0-dev`；最低 Android 8.0。
- 本包连接真实 Multica 服务；使用已有登录，不包含账户凭据。
- 随包提供 SHA256 校验文件与上一版本 APK，便于手动回退。

## 已知问题

**NAV-TEST-01（P2）尚未修复。** Mika 在服务端新绑定 Runtime 后，设置页能看到绑定，对话页仍可能提示未绑定并禁用发送。返回 Tab 和手动刷新无效，重启应用后恢复。该问题已通过 JVM 测试和 Pixel 复现。

## 验证

- 构建、Lint、原有 41 项 JVM 测试通过。
- 导航、聊天、项目、深色及大字号真机回归已有通过证据。
- 补充的 4 项边界测试中 3 项通过、1 项失败；失败项即上述 Runtime 同步问题。
- 本次为开发预览版；完整 V2 产品验收尚未完成。

## 回退

上一版本 `chatty-previous-debug.apk` 与本包签名、包名及 versionCode 一致，可通过 `adb install -r chatty-previous-debug.apk` 覆盖安装。回退后重启应用并检查登录和三 Tab 导航。APK 回退不会撤销已经发生的服务端消息或 Issue 更新；本轮未执行回退演练。
