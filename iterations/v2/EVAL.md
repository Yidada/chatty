# Chatty v2 · 实施期间验证记录

日期：2026-09-05。阶段：**Stage 4 Implementation，部分里程碑已验证**。这份记录不表示完整 V2 已进入或通过 Stage 5。

设备：USB Pixel 6 Pro，Android 16。执行机：Mac，当前 Codex 会话。真实包：`ai.chatty.app.debug`；合成测试包：`ai.chatty.app.fixture`。

## 本轮验收

| 项目 | 可复现命令 | 证据 | 结论 |
|---|---|---|---|
| M0 / CLE-68：真实任务链入库 | `rg -n 'CLE-' iterations/v2/ISSUES.md` | `ISSUES.md`，来源于 Multica CLE-57 的 11 个子 Issue | 本地工件完成；PR/远端合并未执行 |
| M1 / CLE-67：十模块工程与构建 | `source scripts/android-env.sh && android/gradlew -p android :app:assembleDebug test lint` | `evidence/m1-build-round2/build.log` | PASS；基线时尚无业务单测，后续 M2 增加实际测试 |
| M1：真机安装启动 | `scripts/dev-loop.sh android/app/build/outputs/apk/debug/app-debug.apk ai.chatty.app.debug ai.chatty.app.MainActivity` | `evidence/m1-launch-round3/launch.json`、`launch.png`、`logcat.txt` | PASS，进程与前台窗口核实 |
| M1：三轮页面切换 | `scripts/appium-ui.sh --shell-loop`（M1 版本；M2 后改为登录场景） | `evidence/m1-ui-round3/result.json`、`after-three-loops.png` | PASS，3 轮真实点击 |
| M2 / CLE-63：HTTP 与认证行为 | `android/gradlew -p android :core-auth:test :core-network:test` | `evidence/m2-final-checks/auth-tests.xml`、`network-tests.xml` | PASS，12 个独立测试，Debug/Release 均执行 |
| M2：最终构建与 lint | `android/gradlew -p android :app:assembleDebug test lint` | `evidence/m2-final-checks/build.log`、`lint.txt` | PASS；lint 无错误，固定依赖有新版本提示 |
| M2：合成账号登录 / 错误验证码 | `python3 scripts/auth-device-test.py`（先按 dev-loop 文档启动 fixture） | `evidence/m2-auth-ui-round6/result.json`、`invalid-code.png`、`connected.png` | PASS，手机运行，测试数据由本机服务提供 |
| M2：凭据加密 / 杀进程恢复 | 同上 | `evidence/m2-auth-ui-round6/result.json`、`cold-start-restored.png` | PASS，检查偏好字节不包含合成明文 token；冷启动重新请求工作区 |
| M2：503 保留登录 / 服务恢复 | 同上 | `evidence/m2-auth-ui-round6/server-503.png`、`recovered.png`、`fixture-calls.json` | PASS，错误期间杀进程重开仍可恢复 |
| M2：401 清凭据 | 同上 | `evidence/m2-auth-ui-round6/unauthorized-login.png`、`fixture-calls.json` | PASS，返回登录页并重启验证 |
| M2：真实 API 版本安装与登录页 | `scripts/appium-ui.sh '获取验证码'` | `evidence/m2-live-launch-final/launch.json`、`evidence/m2-live-login-ui/result.json`、`screen.png` | PASS，仅证明正式登录入口运行 |
| M2：真实账号登录并读取工作区 | 用户在手机输入验证码后，验证工作区并冷启动重取 | 待真实账号登录 | 待验证，合成测试不代替真实服务验收 |

## V2 总体验收仍未通过

| Intent 标准 | 当前状态 | 后续 Issue |
|---|---|---|
| 1. 与 Mika 真实对话 | 未实现 | CLE-62 / CLE-61 |
| 2. 语音转写可编辑发送 | 未实现 | CLE-64 |
| 3. 真实委派与状态卡变化 | 未实现 | CLE-59 |
| 4. 需要回复卡片 | 未实现；按已接受的平台近似方案 | CLE-60 |
| 5. Evidence 查看 | 未实现 | CLE-60 |
| 6. 对话与任务重启收敛 | 未实现；本轮只验证登录与工作区 | CLE-65 |
| 7. 真实 Agent 列表 | 未实现 | CLE-58 |
| 8. 全产品 Appium 端到端 | 未通过；M1/M2 子流程通过 | CLE-66 |
| 9. 日常使用认可 | 发布后评估 | 产品验收 |

## 证据边界

- 合成测试不调用 Multica，不调度 Mika，不伪造真实任务结果。
- 三轮页面切换记录属于 M1；M2 增加了登录入口，不能用旧截图说明当前账号已连接。
- 初期失败与修复见 `HARDENING.md`；旧截图与日志保留。
- 当前无发布、无 Git 推送、无远端合并；不将本地代码等同已上线。
