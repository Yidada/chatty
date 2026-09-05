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

## 2026-09-05 M3 Chat / M4 Chat 实时切片

- **最终静态验证通过**：`assembleDebug test lint`。23 个独立测试（Auth 3、Network 12、ChatController 8），Debug/Release 均运行；lint 0 errors，依赖新版本提示保留。
- **Pixel 完整合成闭环通过两轮**：第一次验证收发/资源/状态；第二次加入无回复、错误详情和 503 恢复。每轮发送两条合成消息，服务端计数证明无重复 POST。
- **行为覆盖**：Markdown 表格、代码、任务列表；附件点击时刷新并预览文本；快捷操作填草稿；task_id 收敛；工具过程；socket 断开重连；跨会话草稿；冷启动；游标最早页；private Agent 过滤。
- **附件系统选择与上传通过**：仅选择本轮生成的 `chatty-loop-upload.txt`，上传后展示并可移除；结果见 `m3-chat-validation/attachment-upload.json`。
- **真实只读验证通过**：用户原登录恢复，真实工作区会话、Markdown、任务过程可读，WebSocket 已认证。真实内容截图只保存在本机 `/tmp`，不进入 Git。
- **真实发送未验收**：尚未取得本轮明确测试消息授权，没有向真实 Mika 发送新消息。M3/M4 不标记为完整 Done。
- **证据**：`evidence/m3-chat-validation/`；完整成功 UI 目录 `evidence/20260905-141208-612015-ui/`、`evidence/20260905-141627-717037-ui/`。首次脚本等待失败另保留，原因见 HARDENING。
- **覆盖边界**：见 `CHAT_SOURCE_PARITY.md`；完整 V2 gate 仍未通过。

## 2026-09-05 三 Tab 验收增量

- 一级导航：Mika 单对话 / 按 Project 管理 Issues / 设置。会话历史和其他 Agent 选择器已移除。
- 构建、lint 与 **32 个独立测试**通过（Network 15、Auth 3、Chat 9、Projects 5）。
- Pixel 三 Tab 闭环通过：项目服务端进度、自定义状态单次更新、搜索、状态筛选、50→55 条分页、空项目、未归属项目、Runtime / Agents / Squads 列表详情、三轮切换。
- 合成写入证据：恰好一次 Issue PUT，包含 `suppress_run=true` 与 `expected_revision=1`；三 Tab 用例没有发送 Chat 消息。
- 单 Mika 页回归通过：两轮合成收发、附件文本预览、任务过程、重连、跨 Tab 草稿、冷启动、历史分页、无回复、错误详情和 503 恢复。
- 证据：`evidence/three-tabs-validation/`、`evidence/20260905-144033-757160-ui/`、`evidence/20260905-144230-904782-ui/`。
- 本轮设置的原生范围是列表与详情；配置编辑和更完整 Issue 管理通过对应 Multica 页面打开。完整 V2 gate 保持未通过。

- 三 Tab 真实只读验证通过：项目进度正常显示，Runtime / Agents 列表正常，当前 Squads 返回空态，Mika 保持单一入口并连上真实 WebSocket。未修改真实 Issues。
- 真实项目内 Issue 列表另行只读验证通过；未触发状态修改。

## 2026-09-05 原生体验收敛

- 验证结果：35 项 JVM 测试、构建和 lint 通过。
- `evidence/native-tabs-loop/`：三 Tab、项目管理及资源详情，网页入口负向断言通过。
- `evidence/native-chat-loop/`：合成收发、草稿、重连、分页及错误恢复通过。
- `evidence/native-content-loop/` 保留首次测试滚动定位失败；修正测试后 `evidence/native-content-loop-2/` 原生链接、消息图片及附件图片预览通过。
- `evidence/native-validation/`：命令日志、测试汇总、真实包安装导航检查及无崩溃摘要。
- 完整说明见 `.sdlc/changes/20260905-native-experience-without-multica-web-exits/evidence.md`；本次是 local 交付，不表示 V2 全部完成。

## 2026-09-05 Android 视觉设计应用

- 参考与设计规则：`docs/android-visual-design.md`。
- 构建、Lint、35 项 JVM 测试通过。
- 项目/设置及聊天回归：`evidence/design-tabs-loop/`、`evidence/design-chat-loop/`。
- 明暗主题与字号验证：`evidence/design-visual-loop/`。
- 手工检查发现键盘上方留白偏大，已修正 Scaffold inset consumption；构建与测试通过。USB 重连后，`evidence/design-keyboard-loop/` 确认留白消除、合成消息收发与三 Tab 切换通过。
- 最终真实服务包已安装至 Pixel 6 Pro，Mika 与原生设置资源导航验证通过；当前进程无 AndroidRuntime FATAL。测试包和端口转发已清理，主题及字号已恢复。真实工作区无消息发送和 Issue 写入。
- 日志及边界：`evidence/design-refresh/`。本轮未新增 Multica 网页入口。
