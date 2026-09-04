# Android 开发闭环 (Dev Loop)

> 目标：Android 开发助手在本机 (omarchy) 上运行「构建 → 安装 → 启动 → UI 验证 → 修复」闭环，
> 用 adb + Appium (UIAutomator2) 在 **Pixel 6 Pro 真机**（USB）上循环调试。
> 真机断开时可回退到模拟器 AVD `chatty35`（KVM 硬件加速可用）。

## 环境（已就绪）

| 工具 | 位置 |
| --- | --- |
| JDK 21 (Temurin, mise) | `~/.local/share/mise/installs/java/temurin-21*`, shim 在 PATH |
| Gradle 8.7 (mise) | 同上 |
| Android SDK | `$ANDROID_HOME = ~/android-sdk`（platform-tools, platforms;android-35, build-tools;35.0.0, emulator） |
| adb | `$ANDROID_HOME/platform-tools/adb` |
| Appium 3.7 + uiautomator2 8.5.2 | `appium` (npm -g), server 需带 `ANDROID_HOME` 启动 |
| 模拟器 AVD | `chatty35` (android-35 google_apis x86_64, 系统镜像已装) |
| 真机 | Pixel 6 Pro (`adb devices` 显示 `device` 即 USB 已授权) |

环境变量已写入 `~/.bashrc`（`ANDROID_HOME`, `ANDROID_AVD_HOME`, PATH）。

## 五步闭环

```bash
# 0. 基础设施（后台）
appium --port 4723 --log-level info &     # 必须与 ANDROID_HOME 同环境启动

# 1. 构建
gradle :app:assembleDebug                  # 或 .gradlew assembleDebug (项目内 wrapper 优先)

# 2. 安装 + 启动（含崩溃检查）
scripts/dev-loop.sh app/build/outputs/apk/debug/app-debug.apk com.chatty.smoke .MainActivity

# 3. UI 验证（Appium session，可查文本、可点击元素，自动截图）
appium --port 4723 &                      # 若未在运行
scripts/appium-ui.sh "CHATTY SMOKE OK" "TAP ME" 1

# 4. 看崩溃/错误
adb logcat -d -t 300 | grep -E "FATAL EXCEPTION|$aPKG"

# 5. 修复 → 回到 1
```

## 命令速查

```bash
export PATH=$PWD/../android-sdk/platform-tools:$PATH   # 或在 .bashrc 中已配置
adb devices                 # 设备在线状态
adb install -r <apk>        # 覆盖安装
adb shell am start -n <pkg>/<act>   # 启动应用
adb shell am force-stop <pkg>       # 停止应用
adb shell input text 'hello'        # 注入输入
adb shell input swipe 540 1200 540 400 300  # 滑动
adb logcat -d -t 300 -s <pkg>      # 只看本应用日志
adb exec-out screencap -p > /tmp/opencode/scr.png   # 截图

# 模拟器（仅当无真机时）
emulator -avd chatty35 -no-window -no-audio -no-boot-anim -gpu swiftshader_indirect -no-snapshot &
```

## Appium 使用要点

- 服务器必须以 `ANDROID_HOME` 环境变量启动，否则 session 报 `Neither ANDROID_HOME nor ANDROID_SDK_ROOT...`
- 先杀旧 server 再启动：`pkill -f appium; sleep 2; appium --port 4723 &`
- 原生 Appium 3 路径是 `/session`（无 `/wd/hub` 前缀）
- uiautomator2 不支持 `text` locate strategy；用 XPath：`//*[@text='TAP ME']`
- 元素响应 key 为 W3C `element-6066-11e4-a52e-4f735466cecf`
- 会话必备 caps：`platformName=Android, appium:automationName=UiAutomator2, appium:appPackage, appium:appActivity, appium:noReset=true`
- 首次 session 会自动在设备上安装 `appium-uiautomator2-server`，耐心等待几秒

## 已验收

2026-09-04：Pixel 6 Pro 真机完成闭环冒烟（3 次循环识别 UI → 点击 → 验证计数状态变化，全 PASS）。
