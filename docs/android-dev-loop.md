# Android 开发闭环

2026-09-05 当前执行环境：Mac + USB Pixel 6 Pro（Android 16）。历史 Omarchy/AVD 记录保留在 v1；每次运行都重新检查当前设备，脚本默认选择唯一已授权的真机。

## 本轮工具

| 工具 | 版本 / 位置 |
|---|---|
| JDK | Homebrew OpenJDK 17 |
| Gradle | `android/gradlew`，8.7 |
| SDK | `.tools/android-sdk`，platform 35、build-tools 34.0.0 |
| Appium | `.tools/appium`，3.0.2 |
| UIAutomator2 | `.tools/appium-home`，5.0.0 |
| Appium 服务 | `127.0.0.1:4725`，与其他服务隔离 |

`source scripts/android-env.sh` 会配置本工程路径，可通过 `JAVA_HOME`、`ANDROID_HOME`、`ADB`、`GRADLE_USER_HOME` 覆盖。Linux 已安装 SDK 时设置 `ANDROID_HOME=$HOME/android-sdk`。

## 日常闭环

```bash
source scripts/android-env.sh
"$ADB" devices -l
android/gradlew -p android :app:assembleDebug test lint
scripts/dev-loop.sh android/app/build/outputs/apk/debug/app-debug.apk ai.chatty.app.debug ai.chatty.app.MainActivity
```

另一个终端启动 Appium：

```bash
source scripts/android-env.sh
appium --address 127.0.0.1 --port 4725
```

```bash
# 首次登录界面
scripts/appium-ui.sh "获取验证码"
# 可选：期望文本、点击文本、等待秒数、点击后的期望文本
scripts/appium-ui.sh "选择工作区" "某个工作区" 1 "工作区已连接"
```

- `dev-loop.sh` 检查授权、安装结果、进程存活、当前前台窗口和本次启动日志。
- `appium-ui.sh` 使用 W3C API，检查 HTTP 错误和真实元素，保证 session 释放。
- `ANDROID_SERIAL` 可显式选择设备；无授权或多台真机时脚本直接失败，避免连错设备。
- `PKG`、`ACT`、`APPIUM_URL` 可覆盖默认值。
- 证据自动写入 `.sdlc/changes/20260905-native-experience-without-multica-web-exits/evidence/device-runs/<时间戳>-.../`；`EVIDENCE_DIR` 可指定独立轮次目录，避免覆盖。
- 未获得用户授权时，不使用真实账号自动发送验证码或对话；合成服务用于异常测试。

## M2 登录异常闭环

启动 `python3 scripts/auth-fixture.py`（仅本机 8765），另一个终端执行：

```bash
source scripts/android-env.sh
"$ADB" reverse tcp:8765 tcp:8765
android/gradlew -p android -PchattyFixture=true :app:assembleDebug test lint
scripts/dev-loop.sh android/app/build/outputs/apk/debug/app-debug.apk ai.chatty.app.fixture ai.chatty.app.MainActivity
python3 scripts/auth-device-test.py
```

- 测试包名称 `Chatty Test`，包 ID `.fixture`；合成邮箱与 token 均无真实权限。
- 覆盖错误验证码、有效登录、选工作区、杀进程冷启动、503 保留凭据、恢复成功、401 清理。
- 通过 `run-as` 在内存中检查合成 token 不以明文保存在偏好文件，不写出偏好原文。
- 无 `chattyFixture` 属性时 Debug 使用真实 API；Release 始终使用 HTTPS 真实 API。
- 合成服务不证明真实 Multica 登录或 Mika 对话通过，EVAL 分开记录。

结束测试后恢复普通构建安装，并移除该测试端口映射：

```bash
android/gradlew -p android :app:assembleDebug test lint
scripts/dev-loop.sh android/app/build/outputs/apk/debug/app-debug.apk ai.chatty.app.debug ai.chatty.app.MainActivity
"$ADB" reverse --remove tcp:8765
```

## 本轮发现并修复

- 原脚本硬编码 `com.chatty.smoke`，现改为可配置的真实应用 ID。
- 原 UI 检查最后一次命中仍可能失败，现逐次精确判断。
- 原脚本仅警告应用不在前台，现直接失败。
- 原崩溃检查可能匹配其他应用，现限定本次启动和当前 PID。
- Mac 的 zsh 与 Bash 源文件路径语法不同，环境脚本分别处理。
- 不清空整台手机 logcat，不停止其他 Appium 服务。
