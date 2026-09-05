# Chatty v2 · Stage 3 任务清单

日期：2026-09-05。来源：Multica 项目 Chatty，父任务 CLE-57。

用户本轮要求参考 V2 开发并在连接的 Android 手机上闭环调试。CLE-56 已在 Multica 验收；仓库 spec 的 Draft 标签滞后，按已验收规格执行。

## 2026-09-05 Chat 开发增量

- M3 对话核心已实现；23 个独立单测、构建和 lint 通过，Pixel 合成闭环两轮通过。
- M4 的 Chat WebSocket 与 M6 附件基础已接入。真实历史读取及 WebSocket 认证通过。
- 真实 Mika 新消息收发尚未执行；M3/M4 完整验收继续保持进行中。未将本地实现状态回写为外部任务 Done。
- 源码格式覆盖与差异见 [CHAT_SOURCE_PARITY.md](CHAT_SOURCE_PARITY.md)，证据见 [EVAL.md](EVAL.md)。

## 三 Tab 调整（用户本轮要求）

- 一级导航固定为“对话 / 项目 / 设置”。原独立 Agent / 动态页面安排由 [NAVIGATION.md](NAVIGATION.md) 覆盖。
- M3 页面收敛到 Mika 单对话；M5/M7 相关 Issue 进度与资源信息分别落到项目、设置。
- 项目页新增按 Project 读取、搜索、筛选、分页、详情和状态更新；设置页新增 Runtime / Agents / Squads 列表与对应管理入口。
- 当前构建、32 个独立单测和 Pixel 合成三 Tab 闭环通过。详细配置仍在 Multica 页面编辑，完整 V2 验收保持进行中。

## 执行规则

- 严格按阶段推进，同一仓库仅由当前 Codex 会话实现，不启动其他 Agent。
- 本轮执行位置为 Mac `/Users/benjamin/Workspace/chatty`；Pixel 6 Pro 已通过 USB 连接此 Mac。这是用户本轮设备指示覆盖旧 Omarchy 环境的位置变更。
- Multica 原负责人保留，实际执行者为当前 Codex 会话；任务更新使用 `--no-start` 避免启动并发实现。
- 后续任务保持 backlog，验收需要构建、测试、lint 和可复现真机证据。
- 普通回复用于需要人类输入的卡片；正式 Approval API 与真实推送仍是平台缺口。
- 此任务清单记录实施范围；实现验收和发布验收独立，未完成项保持未通过。

| 阶段 | Issue | 内容 | 原负责人 | 优先级 |
|---|---|---|---|---|
| 1 | CLE-68 | M0 — 生成 v2 ISSUES.md 并冻结 Android 执行计划 | 全能极客开发者 | high |
| 2 | CLE-67 | M1 — 初始化 Kotlin/Compose 多模块工程与质量基线 | Android 开发助手 | high |
| 3 | CLE-63 | M2 — 接入 Multica 鉴权、Token 安全存储与 workspace 选择 | Android 开发助手 | high |
| 4 | CLE-62 | M3 — 实现 Mika 对话核心、游标分页与发送状态 | Android 开发助手 | high |
| 5 | CLE-61 | M4 — 实现前台 WebSocket 与消息/任务实时收敛 | Android 开发助手 | high |
| 6 | CLE-59 | M5 — 实现 Task、Agent、Runtime 状态卡与陈旧性语义 | Android 开发助手 | high |
| 7 | CLE-60 | M6 — 实现附件 Evidence、Inbox 去重及“需要你回复”卡片 | Android 开发助手 | high |
| 8 | CLE-58 | M7 — 实现 Agent Fleet 列表与 Issue/Runtime/Agent Web 深链 | Android 开发助手 | medium |
| 9 | CLE-64 | M8 — 实现长按语音转写与可编辑发送 | Android 开发助手 | high |
| 10 | CLE-65 | M9 — 实现后台轮询、断线恢复与离线错误策略 | Android 开发助手 | high |
| 11 | CLE-66 | M10 — Pixel 6 Pro + Appium 全链路验收与 Stage 4 交付 | Android 开发助手 | high |

## CLE-68

Multica ID：`01a06d29-09d6-7e03-942b-f63f1b5bfbdb`

## 目标

生成 Stage 3 仓库级 Artifact `iterations/v2/ISSUES.md`，把本父 Issue 下的全部 Multica 子 Issue、阶段、依赖、负责人、优先级、验收标准和验证命令固化到仓库，并将 README 当前指针更新为 Stage 3。

## 依赖

- PR #1 已合并。
- CLE-56 已完成。
- 本父 Issue 下 Stage 2–11 的实现子 Issue 已创建且保持 backlog。

## 工作要求

- 使用 `multica issue children <parent-id> --output json` 读取真实 Issue ID，不手写或猜测编号。
- `ISSUES.md` 必须说明：只提升当前阶段；后续阶段保持 backlog；同一仓库不并发实现。
- 明确记录两个平台缺口：无结构化 Approval API、无 FCM/APNs 推送；不得将近似方案描述为完整能力。
- 本任务只改文档，不开始 Android 功能实现。

## 验收标准

- `iterations/v2/ISSUES.md` 存在，且列出全部子 Issue 标识符和阶段。
- README Status 指向 Stage 3 和 `iterations/v2/ISSUES.md`。
- 文档与 `spec.md` §11–§14 一致。
- 创建包含本 Issue key 和 `Closes <本 Issue key>` 的可审查 PR。

## 验证命令

```bash
test -f iterations/v2/ISSUES.md
rg -n "Stage 3|ISSUES.md|CLE-" README.md iterations/v2/ISSUES.md
git diff --check
```

## CLE-67

Multica ID：`01a06d28-d228-7f04-bd2b-ef1ca59e268a`

## 目标

初始化 `android/` Kotlin + Jetpack Compose Material 3 多模块工程，建立后续功能共同依赖的构建、DI、测试和静态检查基线。

## 依赖

- Stage 1 的 `ISSUES.md` 已验收。

## 交付范围

- 创建 Gradle Wrapper，并冻结 applicationId、min/target SDK 与版本策略。
- 建立 `app`、`core-network`、`core-auth`、`core-model`、`feature-chat`、`feature-status`、`feature-approval`、`feature-inbox`、`feature-agents`、`feature-issue-link` 模块。
- 接入 Compose、Coroutines/Flow、Hilt、Retrofit/OkHttp 与 JSON 序列化方案。
- 提供可启动的空壳页面、基础主题、导航和测试骨架。
- 不接入真实 Multica 功能。

## 验收标准

- Debug APK 构建成功，单元测试和 lint 通过。
- APK 可通过现有 dev-loop 安装并启动，无启动崩溃。
- 模块依赖方向符合 Spec，不出现 feature 反向依赖或服务端实体本地数据库。

## 验证命令

```bash
cd android && ./gradlew :app:assembleDebug test lint
```

## CLE-63

Multica ID：`01a06d28-ccfe-733f-b514-72af274b67ca`

## 目标

实现 Multica 邮箱验证码登录、JWT 安全存储、401 处理和 workspace 选择，为所有后续 API 调用提供统一认证与作用域。

## 依赖

- M1 工程基础完成。

## 交付范围

- 两步邮箱验证码登录。
- Android Keystore 支撑的加密 Token 存储；退出仅清本地 Token，并明确 30 天不可吊销风险。
- 仅在真实 401 时清 Token；网络错误和 5xx 不强制退出。
- workspace 列表与上次 workspace 选择；统一注入 Bearer JWT 和 `X-Workspace-Slug`。
- 为 DTO 和失败响应建立类型化解析与测试。

## 验收标准

- 登录成功后重启 App 仍能恢复会话和 workspace。
- 401 会回到登录页；超时/5xx 不会误清凭据。
- Token 不进入日志、明文偏好、截图或仓库。

## 验证命令

```bash
cd android && ./gradlew :core-auth:test :core-network:test :app:assembleDebug lint
```

## CLE-62

Multica ID：`01a06d28-c76b-728e-b918-84330f217f77`

## 目标

实现打开即 Mika 的核心对话：会话定位、游标分页、消息发送、基于服务端 `task_id` 的 pending 状态和最终消息收敛。

## 依赖

- M2 鉴权与 workspace 基础完成。

## 交付范围

- 默认打开 Mika 对话，并支持必要的 per-agent 会话引用。
- 使用游标分页端点，禁止无界历史读取。
- 发送消息后用服务端返回的 `task_id` 锚定 pending UI。
- 显示最终完整消息；不得伪造 token 级流式输出。
- 明确空态、加载、重试、403/5xx 展示。

## 验收标准

- 可在真实 workspace 向 Mika 发送文本并收到最终回复。
- 分页、重复发送保护和进程重启后的服务端重取行为有测试。
- 本地不持久化服务器消息副本。

## 验证命令

```bash
cd android && ./gradlew :feature-chat:test :core-network:test :app:assembleDebug lint
```

## CLE-61

Multica ID：`01a06d28-c72e-77aa-9783-c42a43f20f1a`

## 目标

实现用户侧 `GET /ws` 前台实时层，正确处理认证、重连、消息/任务事件、执行轨迹以及断线后的 REST 收敛。

## 依赖

- M3 对话 REST 核心完成。

## 交付范围

- 单一 OkHttp WebSocket、auth/auth_ack、指数退避和生命周期管理。
- 处理 `chat:message`、`chat:done`、task/issue/agent/runtime 相关事件。
- thinking/tool_use/tool_result 作为可展开活动展示。
- 未知事件进入 Generic Activity，保留原始 payload 与 task/issue 关联。
- 重连后按所属 feature 精确失效和重取；不得假设有 missed-event replay。

## 验收标准

- 真实对话能从 queued/running 收敛到最终回复。
- 断网重连不产生重复 socket、重复消息或永久 pending。
- 未知事件不会导致崩溃或中断任务展示。

## 验证命令

```bash
cd android && ./gradlew :core-network:test :feature-chat:test :app:assembleDebug lint
```

## CLE-59

Multica ID：`01a06d28-c70a-7af3-9ef9-cf1263079727`

## 目标

实现 Task、Agent、Runtime 状态卡及渐进展开，忠实呈现 Multica 的持久状态、派生健康度、重试和陈旧性。

## 依赖

- M4 实时事件层完成。

## 交付范围

- 映射 task 的 queued/dispatched/running/waiting/completed/failed/cancelled。
- 映射 agent presence；按 Multica `derive-health` 阈值移植 runtime 健康度。
- 显示运行耗时、最后更新时间、attempt，避免把约 150 秒离线判定和 3 小时失败宽限描述成即时状态。
- 明确“等待原 Runtime”，不得暗示自动 failover。

## 验收标准

- 状态转换、recently_lost/long_offline 边界和 retry attempt 有确定性测试。
- 真实委派任务的卡片可随 WebSocket/REST 状态变化。

## 验证命令

```bash
cd android && ./gradlew :feature-status:test :core-model:test :app:assembleDebug lint
```

## CLE-60

Multica ID：`01a06d28-c70e-7e92-88c6-ebe1011cff19`

## 目标

实现附件 Evidence 展示、Inbox 去重以及基于现有三信号的“需要你回复”卡片，不虚构服务端 Approval/Decision 实体。

## 依赖

- M5 状态卡完成。

## 交付范围

- 渲染图片、链接、日志等普通 Attachment 为 Evidence UI 卡片。
- 使用持久 `markdown_url`，正确处理鉴权下载、相对 URL 和重复附件。
- Inbox 排除 archived、按 issue 去重并呈现 severity。
- 仅在 agent_blocked + issue blocked category + agent_activity inbox 三信号成立时显示“需要你回复”。
- 主操作打开预填上下文的回复 composer；不得显示伪造的批准/拒绝接口。

## 验收标准

- 附件去重、下载失败、未知类型和三信号真假组合均有测试。
- Appium 可点击 Evidence，并可从“需要你回复”卡进入 composer。

## 验证命令

```bash
cd android && ./gradlew :feature-inbox:test :feature-approval:test :feature-status:test :app:assembleDebug lint
```

## CLE-58

Multica ID：`01a06d28-c706-7198-bbea-6835be462633`

## 目标

实现真实 Agent Fleet 列表和 Issue/Runtime/Agent 的 HTTPS Web 深链入口。

## 依赖

- M2 鉴权完成。
- M5 状态模型完成。

## 交付范围

- 使用最丰富的服务端 presence 端点展示 Agent 身份、状态和当前活动。
- 生成 workspace-scoped HTTPS URL，并通过 Android `ACTION_VIEW` 打开。
- 正确渲染消息内 `mention://` 引用，但不将其误作系统外部深链。
- 提供无权限、对象不存在和浏览器不可用的失败反馈。

## 验收标准

- Agent 列表与同 workspace 的 Multica CLI 查询结果一致。
- Issue、Runtime、Agent 链接均能打开正确 Web 页面。

## 验证命令

```bash
cd android && ./gradlew :feature-agents:test :feature-issue-link:test :app:assembleDebug lint
```

## CLE-64

Multica ID：`01a06d28-cd44-7d3b-9390-bc3954cb7a7c`

## 目标

实现 Android 长按语音转写、可编辑草稿和发送前隐私提示。

## 依赖

- M3 对话 composer 完成。

## 交付范围

- 首次长按时请求 `RECORD_AUDIO`，拒绝后可继续文字输入。
- 使用 Android `SpeechRecognizer`，优先离线模型。
- 回退在线识别时明确提示 Google 托管的隐私边界。
- 音频不上传 Multica；只有可编辑文本进入普通消息发送流程。
- 正确处理取消、超时、识别失败、旋转和生命周期中断。

## 验收标准

- 转写结果可编辑后发送；拒绝权限与识别失败不会丢失已有草稿。
- Appium/可复现实机步骤覆盖长按、编辑、发送。

## 验证命令

```bash
cd android && ./gradlew :feature-chat:test :app:assembleDebug lint
```

## CLE-65

Multica ID：`01a06d28-cf40-7105-80df-3608ebda074d`

## 目标

实现后台最终一致性、WorkManager 轮询、本地通知、前台恢复和统一离线/错误策略。

## 依赖

- M4 WebSocket 完成。
- M6 Inbox/需要回复完成。

## 交付范围

- 前台使用 WebSocket；后台使用 15–30 分钟 WorkManager 周期轮询 unread-summary 与活动任务。
- 对 action_required 且未见的条目发本地通知，并明确通知可能延迟。
- 前台恢复后统一重连并进行一次服务端重取，保证最终收敛。
- 401、403、超时、5xx、Doze、无网和重复 Worker 有明确行为。
- 不引入或声称 FCM/APNs 真推送。

## 验收标准

- 进程退后台、断网恢复和冷启动后状态与服务端一致。
- Worker 幂等，不重复通知，不误清 Token。

## 验证命令

```bash
cd android && ./gradlew :core-network:test :feature-inbox:test :app:assembleDebug lint
```

## CLE-66

Multica ID：`01a06d28-d0f8-79ce-88a8-0b50356350bc`

## 目标

在 Pixel 6 Pro 上完成 Chatty v2 Android V1 的构建、安装、启动和 Appium 全链路验证，并把成功标准 1–8 的真实证据提交到 `iterations/v2/evidence/`。

## 依赖

- M1–M9 全部完成并合并。

## 覆盖范围

- Mika 对话。
- 长按语音转写、编辑和发送。
- 真实委派任务及状态卡转换。
- “需要你回复”近似卡片。
- Evidence 附件查看。
- 杀进程/重启后的状态收敛。
- Agent Fleet 与真实状态。
- 完整 Appium 自动化执行。

## 验收标准

- Intent 成功标准 1–8 每项均有命令、结论和独立证据路径。
- 所有截图/日志写入 `iterations/v2/evidence/`，不覆盖旧证据。
- 失败项如实记录并转入后续 EVAL/HARDENING，不以口头 PASS 代替。
- 产出 Stage 4 实现交付摘要和进入 Stage 5 EVAL 的建议。

## 验证命令

```bash
cd android && ./gradlew :app:assembleDebug test lint
scripts/dev-loop.sh android/app/build/outputs/apk/debug/app-debug.apk <applicationId> <mainActivity>
scripts/appium-ui.sh "<expected Mika reply>" "<action text>"
```
