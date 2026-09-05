# Chatty v2 · 实施期缺陷记录

此文件在 Stage 4 记录失败与修复。完整 EVAL 尚未全绿，未进入 Stage 6 正式加固验收。

| 优先级 | 发现 | 复现 | 修复与证据 | 状态 |
|---|---|---|---|---|
| P2 | Android 26 不支持主题 `windowLightNavigationBar` | `android/gradlew -p android lint`，初始主题 | 移除不兼容属性；`evidence/m1-build-round1/build.log` → `m1-build-round2/build.log` | 已修复 |
| P2 | macOS zsh 下 Bash 路径变量为空，工具缓存路径落到父目录 | 在 zsh `source scripts/android-env.sh` 检查 CHATTY_ROOT | 分别处理 zsh/Bash 来源路径，二者均验证指向本仓库 | 已修复 |
| P2 | adb shell 的带空格日期参数被拆开 | 初版 `scripts/dev-loop.sh` | 把日期命令作为完整远端 shell 参数；`evidence/m1-launch-round3/launch.json` | 已修复 |
| P2 | Appium 默认服务环境与项目驱动不一致 | 原 4723 服务建立 session 返回 500 | 项目专用 4725 + APPIUM_HOME；`evidence/m1-ui-round3/result.json` | 已修复 |
| P2 | Compose 测试标签需实验 API 声明 | M2 第一轮构建 | 显式 OptIn；`evidence/m2-build-round1/build.log` | 已修复 |
| P2 | debug network security 域缺少 includeSubdomains | M2 第二轮 lint | 明确 false，仅开放 loopback；`evidence/m2-build-round2/build.log` → `m2-final-checks/lint.txt` | 已修复 |
| P2 | 本地 fixture HTTP/1.0 连接关闭与分块 POST 处理不完整，验证码路径出现 IOException | `python3 scripts/auth-device-test.py`，fixture 初始实现 | 支持 HTTP/1.1 与 chunked；`evidence/m2-auth-ui-round3/failure.png` 至 round5 保留，round6 全通过 | 已修复，问题位于测试服务 |
| P2 | 状态栏在设备深色设置下图标对比度不足 | M1 启动截图 | 为浅色应用显式设置浅色状态栏样式，当前登录截图可读 | 已修复 |

下一里程碑继续按 `ISSUES.md` 的 M3–M10 执行，功能开发不混入缺陷清单。
