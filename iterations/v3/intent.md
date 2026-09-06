# Intent: Chatty v3 — 性能、缓存与稳定性升级

- **Author:** Mika
- **Status:** 1A–6A 已批准；Stage 2 基线准备中；B0/T 待验收
- **Stage:** 2 — Baseline harness & numeric budgets
- **Issue:** CLE-70（整体推进）/ CLE-73（本次基线准备）
- **Last updated:** 2026-09-06
- **Writable source:** `Yidada/chatty@e7e1c518daaabe65db2c74f7fae236cc955e6d8c`
- **Server reference (read-only):** `multica-ai/multica@7a438bd5b8bf39afd54259a7eb0971390e50a8ef`

## 1. Originator's intent

Chatty v3 不以增加业务功能为目标，而是让已经存在的 Android thin client 在日常移动网络、长会话和进程反复恢复中更快、更省、更可靠：

1. 打开应用和返回对话时更快到达可交互状态；
2. 长列表、消息更新和 Markdown/图片内容保持流畅；
3. 弱网或离线时能看到明确标记的最近快照，恢复后自动收敛到 Multica；
4. 不因轮询、重连、重复 Worker 或并发刷新制造请求风暴和耗电；
5. 不出现崩溃、ANR、永久 pending、重复发送或把客户端缓存变成第二真值。

v3 的核心原则是：

> **缓存用于更快地展示服务端快照，不用于替代 Multica 的身份、权限、任务或状态裁决。**

## 2. 用户场景与问题陈述

### 2.1 用户场景

- 通勤中从被系统回收的进程冷启动 Chatty，希望先看到上次对话并能判断其新旧，再等待网络刷新。
- 在 1,000 条以上的 Mika 会话中滚动、加载更早消息，并持续接收任务 trace、Markdown 与图片。
- 地铁弱网下进入项目或 Issue，能阅读已缓存内容；恢复网络后页面不闪回旧状态，也不重复提交修改。
- WebSocket 中断数分钟后恢复，客户端只有一个连接循环，使用抖动退避，并通过 REST 快照弥补遗漏事件。
- App 前后台切换、旋转、进程被杀、401/403/5xx 后，凭据、草稿、缓存和 pending 状态按各自边界恢复或清理。
- 连续运行 24 小时，内存、请求量、连接数和后台任务数量不持续上升。

### 2.2 当前问题

当前代码已经有基本的并发请求、取消、单次刷新合并、WebSocket 退避和发送结果不确定态保护，但缺少一套可复现的性能基线和持久化服务端快照：

- 首次对话初始化会并发读取 sessions、agents、me、members，随后再读 messages 与 pending，共 6 个 REST 请求；来源：`android/feature-chat/src/main/java/ai/chatty/feature/chat/ChatController.kt:46-60,143-155`。
- WebSocket 断开、存在 pending 或页面有错误时，前台每 5 秒触发一次完整 refresh；完整 refresh 会重复上述 4 个上下文请求与 2 个会话请求。按静态调用路径推导，上界为 `12 × 6 = 72` 次读请求/分钟前台客户端（实际值会受 refresh 合并与请求耗时影响，尚非网络实测）；来源：`android/feature-chat/src/main/java/ai/chatty/feature/chat/ChatController.kt:62-79,114-155`。
- 消息首屏有 50 条分页，但连续“加载更早”会把页面不断追加到同一个内存列表；trace map 也随当前会话读取增长。Generic Activity 单独限制为 30 条；来源：`ChatApi.kt:12-14`、`ChatController.kt:14-23,157-169,217`。
- 当前持久化只有 Keystore 支撑的 token/workspace、按账户与 workspace 隔离的草稿；sessions、messages、projects、issues、agents、task/pending 和附件元数据均只在内存，进程死亡后必须全量重取；来源：`EncryptedSessionStore.kt:9-25`、`ChatScreen.kt:63-78`。
- OkHttp 禁止连接失败自动重试，25 秒 call timeout，动态 App API 没有客户端缓存配置；这对写请求安全，但读请求也没有分层重试与 single-flight repository；来源：`MulticaApi.kt:36-42`。
- 基线 main 没有 Macrobenchmark、Baseline Profile、Room、通用缓存指标、WorkManager、崩溃/ANR 采集或长时间 soak runner。Stage 2 新增的测量工具单独记录，不代表产品优化已完成。`feature-inbox` 等模块仍为空边界。

## 3. 范围

### 3.1 In scope

- Android 冷/热启动、首屏可交互时间、Compose 帧性能、内存峰值与泄漏趋势。
- REST 请求时延/数量、WebSocket 生命周期、前后台耗电代理指标。
- 会话、消息、Project/Issue、Agent/Runtime/Squad、task/pending、附件元数据和静态资源的分层缓存。
- 用户/workspace 隔离、失效、过期、淘汰、离线陈旧标识和重新同步。
- 读请求合并、取消、超时与有界退避；写请求的幂等/去重与不确定结果处理。
- 冷启动、旋转、进程回收、前后台切换、断网/弱网、401/403/5xx、WebSocket 断连和未来 Worker 重复调度。
- 单测、集成测试、Macrobenchmark、adb/Appium、故障注入与 24 小时 soak 证据链。
- 必要的可观测性：请求、缓存、重连、队列、内存与恢复指标；默认不记录凭据、正文或原始 tool trace。

### 3.2 Out of scope

- 新业务功能、iOS、生产发布和修改 Multica 服务端。
- 客户端生成新的服务端事实、在离线时修改任务真值，或以缓存掩盖 401/403/删除/权限变化。
- 在没有实测数据时宣称“提升 X%”、提前通过性能 Gate，或用 Debug 构建代替可 profile 的 Release 基线。
- 缓存附件二进制正文作为默认行为；用户明确下载/分享产生的文件遵循现有安全边界，另行管理。
- 以埋点上传消息正文、Issue 描述、附件名、token、workspace slug 或原始 trace。

## 4. 当前事实、实测与未知项

### 4.1 仓库与 PR 状态（2026-09-06 核对）

| 项目 | 证据 | 结论 |
| --- | --- | --- |
| Chatty 主分支 | `origin/main = e7e1c51`，任务分支检出后与其相同 | 这是 v3 基线；包含 2026-09-05 的登录、Chat、三 Tab、原生 UI 与导航连续性实现 |
| 已合并 PR | GitHub pull ref #1 的 head `96594fc` 可从 `origin/main` 到达，主分支含合并提交 `392ce19` | #1 已合并，属于 v2 spec/README 文档 |
| 未合并 PR | pull ref #2 head `f282942` 不可从 `origin/main` 到达，GitHub 仍发布 `refs/pull/2/merge`；其差异为旧版 v2 `ISSUES.md`/README | #2 仍未合并且已落后于 main 的 8 个实现提交；v3 不依赖、不修改其两份文档，Stage 2 已逐项复核，迁移/关闭证据见 `baseline/pr-audit.md` |
| Multica 参考 | `origin/main = 7a438bd5b` | API、分页、事件、权限和缓存语义均以此只读 revision 为证据；没有对该仓库写入 |

### 4.2 Stage 1 历史构建证据（不是本次 Stage 2 实测）

环境：macOS、OpenJDK 17.0.20、Android SDK `/Users/benjamin/Android/Sdk`，Chatty 基线 `e7e1c51`。

命令：

```bash
export ANDROID_HOME=/Users/benjamin/Android/Sdk
export JAVA_HOME=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home
source scripts/android-env.sh
android/gradlew -p android :app:assembleDebug test lint
```

结果（2026-09-06）：

- `BUILD SUCCESSFUL in 2m 26s`；本次首次下载 Gradle 8.7，772 个任务执行，因此只证明工程可构建，不作为用户性能预算。
- 92 个 JVM 测试通过，0 failure、0 error、0 skipped。
- lint 成功，生成的 12 个模块 XML 报告均无 `<issue>`。
- Debug APK 为 18,752,446 bytes。
- `adb devices -l` 无设备；没有可用 AVD。因此本轮没有冷/热启动、帧、PSS、网络、耗电、进程恢复或 24 小时 soak 数字。它们保持 **UNMEASURED**，不能据此宣称优化。

### 4.3 代码推导基线（不是运行时测量）

| 路径 | 当前行为 | v3 风险 |
| --- | --- | --- |
| 首次 Chat | 4 个上下文请求并发，随后 2 个会话请求 | 网络 RTT 至少两波；没有磁盘快照可先绘制 |
| Chat refresh | 同一 `refreshJob` 合并触发，但每轮仍读取 6 个 endpoint | 事件密集、pending 或断线时重复读取不相关能力数据 |
| WS reconnect | 1s、2s、4s、8s、16s、32s 封顶，加 0–299ms 抖动；认证成功清零 | 封顶时抖动窗口过窄，多客户端仍可能同步重连 |
| 发送 | 自动网络 retry 关闭；非 4xx 且 POST 结果未知时进入 uncertain，要求刷新核对 | 正确方向；需保存 operation id/本地发送状态，不能让缓存自动重发 |
| 历史 | cursor `(created_at,id)`，默认 50 条 | 服务端契约适合增量分页；客户端内存没有窗口上限 |
| 动态实体 | REST 快照 + WS invalidation/refresh | 没有 missed-event replay；进程恢复必须 REST 收敛 |

## 5. Multica 契约边界（只读源码核对）

以下均来自 `multica-ai/multica@7a438bd5b`，是 v3 设计约束，不是 Chatty 自行定义的服务器行为：

1. `GET /api/chat/sessions/{id}/messages/page` 使用 `(before_created_at,before_id)` 游标，服务端取最新窗口、以两字段稳定打破同时间戳并返回 `has_more/next_cursor`；见 `server/internal/handler/chat.go:1207-1274` 与 `server/pkg/db/queries/chat.sql` 的 `ListChatMessagesPage`。
2. `POST /api/chat/sessions/{id}/messages` 在持久化前重查 session、Agent readiness 与调用权限，并通过 task service 原子创建 turn；成功后广播 `chat:message`，返回 message/task id 与服务器时间；见 `server/internal/handler/chat.go:832-1019`。
3. 当前 App API 的动态 chat/project/issue/agent endpoints 未提供可依赖的 ETag/304 契约。仓库中的 ETag 只出现在 daemon workspace 与 plugin issue 等其他 surface；不能向 Chatty 的 App API 擅自发送条件请求并假设有效。
4. 附件授权内容响应明确使用 `Cache-Control: no-store`；v3 不用 OkHttp HTTP cache 绕过这一服务端指令。静态 avatar/公开资源只有在其实际响应允许时才交给 Coil/HTTP cache。
5. 用户 WebSocket 用 query 中的 workspace slug 与连接后 auth frame 鉴权，成功返回 `auth_ack`；见 `server/internal/realtime/hub.go:778-868`。
6. 事件常量包括 issue/comment/agent/task/chat/project/status 等；未知事件必须保持前向兼容。`issue_status:changed` 的官方语义就是重新读取整个小目录，而不是合并事件内单行；见 `server/pkg/protocol/events.go:3-120`。
7. WebSocket 是变化提示，不是客户端持久真值，也没有为 Chatty 提供跨进程 missed-event replay；恢复与重连后必须以受权限保护的 REST 快照收敛。

## 6. 成功标准与预算冻结规则

### 6.1 为什么此时没有伪造数字

Stage 1 没有设备数据；Stage 2 已重新核对 Pixel 6 Pro 连通性并准备采集。具体环境、实测与缺项以 `baseline/README.md` 为准。生成 `B0` 原始报告后，由 Benjamin 接受具体数值预算。任何没有 `B0` 原始证据的百分比改善声明都无效。

### 6.2 预算符号

- `B0(metric,scenario)`：同一 commit、构建类型、设备、Android 版本和数据集下的基线分布。
- `M`：中位数；`P95/P99`：相应分位数；每轮保留原始 iteration，不只保留平均数。
- `noise`：同一基线连续两轮的差异区间；回归阈值不得小于测量噪声。
- `T(metric)`：Stage 2 在看到 B0 后冻结的数值门槛，记录绝对预算、相对 B0 目标和选择理由。

### 6.3 Gate 规则

- B0 未采集：该指标状态为 `UNMEASURED`，允许基线工具与采集，不得进入产品优化实现。
- B0 已采集但 T 未由评审冻结：状态为 `NO_BUDGET`，不得宣称优化完成。
- 每个性能指标必须同时满足冻结后的绝对预算与相对预算；稳定性正确性指标采用零容忍或下表的明确上限。
- 优化前后必须使用相同设备状态、数据集、网络 profile、构建 artifact 与采样数；否则只能作为探索数据。

## 7. 可重复测量计划

固定设备：USB Pixel 6 Pro、Android 16、60 Hz、充电 40–80%、关闭 battery saver/动画缩放变更，测试前静置至温度稳定。性能构建为 non-debug、profileable、R8 设置保持一致；fixture 与真实 workspace 分开报告。

固定数据集：

- `S0`：未登录/登录恢复；
- `S1`：1 个 Mika session、50 条消息、无附件；
- `S2`：20 个 sessions、1,000 条目标会话消息（20 页 × 50），其中 20% Markdown、10 张图片元数据、1 个 active pending task、200 条 trace；
- `S3`：50 projects、2,000 issues、100 agents/runtimes/squads 汇总实体；
- `S4`：弱网 fixture，可脚本化延迟、超时、401、403、429/Retry-After、500/503、断连与乱序事件。

| 指标 | 场景与步骤 | 采样/工具 | 通过阈值 |
| --- | --- | --- | --- |
| 冷启动 | S1，force-stop 后从 launcher 到首个可点击 composer；分别测无缓存/有缓存 | Macrobenchmark `StartupTimingMetric`，10 次，报告 M/P95 | Stage 2 冻结 `T_cold`；B0/T 缺一即失败 |
| 热启动 | S1，Activity 在后台 5 秒后恢复到可交互 | Macrobenchmark，20 次 | `T_warm`；同时不得重复创建 socket/controller |
| 首屏可用 | S2，进程被杀后先显示磁盘快照，再完成网络收敛 | 自定义 trace section + Appium 可见性时间戳，10 次 | `cached_content_visible <= T_cached` 且 `freshness_resolved <= T_fresh`；离线时 1 秒内显示明确 stale/empty 状态是产品硬门槛，最终值由 B0 复核 |
| 列表/消息帧 | S2，从最新滚至最旧、返回、持续注入 200 trace/消息更新 | Macrobenchmark `FrameTimingMetric` + Perfetto，10 次 | 冻结 P95/P99 与 missed-frame `T_frame`；任何单轮 ANR 为失败 |
| 内存峰值 | S2 全流程、图片打开/关闭、切换 20 sessions | `dumpsys meminfo` + heap dump/Memory Profiler，5 轮 | 峰值 `<= T_pss`；循环 30 次后回到稳态区间，无单调增长；确认泄漏对象为 0 |
| 网络时延/数量 | S1/S2/S3，冷启动、refresh、pending 5 分钟、WS 正常/断线 | fixture 请求日志 + OkHttp EventListener；各 10 次 | 每个场景冻结 request count 和 endpoint p50/p95；相同 cache key 并发只允许 1 个 in-flight read；空闲前台不得周期性全量读 |
| 缓存命中率 | S2 第二次启动/返回历史页/项目返回 | cache counters：memory/disk/network/miss/stale | 分实体冻结 `T_hit`；命中后仍必须按 TTL/事件触发 revalidate |
| 离线恢复 | S2 在线一次→force-stop→断网→打开→恢复网络 | Appium + fixture，10 次 | 离线显示带采集时间的快照或明确空态；联网后 `T_converge` 内与 REST 相同；0 条缓存写回服务端 |
| 崩溃/ANR | 六类验收路径 + 故障注入 | logcat、Android vitals 规则、JUnit/Appium | 0 crash、0 ANR、0 StrictMode 致命违规 |
| 重连 | S4 断开 1/5/30 分钟、DNS 失败、服务器重启、401 | fixture 连接日志，10 轮 | 同时最多 1 个 socket；每次断连只有 1 个重连计划；使用全抖动有界退避；0 重连风暴 |
| 后台耗电代理 | 前台 30 分钟、后台 2 小时、有/无 pending | Battery Historian/`dumpsys batterystats`、请求/唤醒次数 | 冻结 `T_wakeup/T_bg_req`；无业务变化时后台不得持续 5 秒轮询 |
| 24 小时稳定性 | S2 + 每分钟事件 + 每小时断网/恢复 + 进程回收 | soak runner、周期 meminfo/请求/连接/Worker 快照 | 0 crash/ANR/永久 pending/重复发送；内存、socket、Worker、请求速率无正向累积趋势 |

真机 B0 解锁条件：Pixel 6 Pro 以 `adb devices -l` 显示 `device`；固定 Android build；fixture 能生成 S0–S4；Macrobenchmark profileable artifact 可安装；记录电量/温度/刷新率。采集时点：Benjamin 接受本 Intent 后、任何 v3 优化代码合入前。

## 8. 缓存方案与决策

### 8.1 方案比较

| 选项 | 优点 | 限制 | 决策 |
| --- | --- | --- | --- |
| 仅 OkHttp Cache/条件请求 | 实现小，遵循 HTTP | 动态 App API 没有可依赖 validator/cache header；附件明确 no-store；无法表达实体 tombstone/revision | 只用于服务器明确允许的静态 GET，不承担业务缓存 |
| 仅内存 LRU | 快、进程内安全边界简单 | 进程死亡/离线无内容；长会话仍需窗口和容量 | 必须有，作为一级热点缓存 |
| DataStore 存实体 | 已有依赖，适合 key/value | 不适合分页、关系、事务、容量淘汰和 1,000+ 实体 | 只存偏好、草稿与小型 cache metadata，不存实体集合 |
| Room 实体快照 | 支持事务、分页、索引、tombstone、容量和迁移 | 新增依赖与 schema/migration 成本；仍需安全边界 | 选择为二级结构化快照，先用 fixture/benchmark 证明收益 |
| 仅每次 REST | 永远直接读真值 | 弱网/离线不可用，启动两波 RTT，重复请求高 | 保留为 revalidate/最终真值，不作为唯一展示路径 |

### 8.2 选定架构

读取路径：

`Compose → Repository → memory LRU → Room snapshot → REST → transactional cache write → StateFlow`

更新路径：

`WebSocket event → scoped invalidation/tombstone → single-flight REST revalidate → newer snapshot wins`

关键不变量：

- cache key 至少包含稳定的 `user_id + workspace_id + entity_type + entity_id/page_cursor`；显示名、slug 和 token hash 不能充当身份主键。
- App 首次尚未通过 `/api/me` 确认用户时，不展示任何前一账户业务快照。
- UI 必须携带 `freshness = fresh | refreshing | stale | offline | unauthorized | deleted` 和 `fetched_at`；不能把陈旧数据伪装成实时状态。
- `revision` 可用时采用 revision；否则用 endpoint 快照时间与服务器 `updated_at`。较旧网络响应不得覆盖较新事件/响应。
- 写操作只在服务器成功响应后更新权威快照；可有视觉 optimistic row，但必须标注 `local_pending`，且绝不能成为 task/issue 的本地真值。
- WS 只触发 invalidation；恢复连接的 `auth_ack` 后执行一次分层收敛，不为每个遗漏事件重放盲目刷新。

### 8.3 缓存矩阵（初始预算，Stage 2 以 B0/B1 校准）

TTL 表示“何时必须 revalidate”，不是数据自动正确的保证；容量达到上限时先删已过期，再按 LRU，任何清理都不能删除草稿或凭据。

| 数据 | L1 内存 | L2 磁盘 | TTL / 容量 / 淘汰 | 刷新与失效 | 离线与安全 |
| --- | --- | --- | --- | --- | --- |
| 消息 | 当前 session 最近 200 条；其他 session 最近 50 条 | Room，最近 30 个 session，每 workspace 最多 10,000 条或 50 MiB，先到者为准 | fresh 30 秒；7 天未访问可淘汰；按 session 分页 LRU | `chat:message/done/cancel_finalized`、手动刷新、auth_ack；session 删除立即 tombstone | 显示 stale 时间；不缓存原始 tool input/output 中可能的秘密；正文位于 app-private credential-encrypted storage，禁备份 |
| 会话 | 最近 100 个 | Room，最多 1,000/workspace | fresh 60 秒；30 天未访问淘汰 | `chat:session_*`、权限/Agent 变化、手动刷新 | 离线可读；无权限或删除立即隐藏 |
| Project/Issue | 当前列表 + detail，LRU 500 | Room，projects 500、issues 5,000/workspace | 列表 2 分钟、detail 30 秒；30 天未访问淘汰 | project/issue/status/property/label/comment 相关事件按 key 失效；delete tombstone；状态目录事件全量重读 | 离线只读并标 stale；不允许离线状态写入队列 |
| Agent/Runtime/Squad | 当前 workspace 各 200 | Room，各 1,000/workspace | 60 秒；7 天未访问淘汰 | agent/runtime/squad/member/permission 事件、401/403、workspace switch | 离线仅显示“上次看到”，不得称“在线” |
| Task/pending | active session 全部；settled 最近 100 | Room 仅最小状态与关联 id，1,000/workspace | active 5 秒；settled 1 小时；7 天淘汰 | 所有 `task:*`、chat done、auth_ack；REST pending 为空时清 active | 离线 pending 显示“最后已知”，不能触发/恢复本地任务 |
| 附件元数据 | 当前页面 100 | Room，10,000/workspace | 15 分钟；30 天未访问淘汰 | attachment/message/issue 删除、403、workspace switch | 只存 id/type/size/受权 URL 元数据；二进制遵循 `no-store`，不默认持久化 |
| Avatar/明确静态资源 | Coil memory cache | Coil disk cache，仅尊重响应 header | 合计 100 MiB，HTTP/Coil LRU | URL/validator 改变、登出/账户切换清隔离分区 | 不缓存 Authorization 响应，除非服务端明确允许 private caching |
| 草稿/偏好 | 当前值 | DataStore | 草稿按 account/workspace/session；总量 1 MiB，30 天未访问清理 | 发送成功删；登出提供清理；账户删除必清 | 不含 token；迁移现有 token-hash key，避免孤儿草稿无限增长 |

初始容量是实现约束候选，不是已经验证的最优值。Stage 2 必须用 S2/S3 测量数据库大小、查询耗时和 PSS 后确认或下调；超过容量时客户端仍可从服务端重新获取。

### 8.4 失效规则

| 事件/动作 | 必须行为 |
| --- | --- |
| 登出 | 关闭 socket、取消 scope/Worker、清 L1；删除当前 user 的业务快照、静态授权缓存和 token；草稿按用户选择保留或清理，但登录页永不展示业务缓存 |
| 切换 workspace | 先停止旧 workspace socket/请求，再切 key；清旧 L1，磁盘保留在隔离分区；新 workspace 在身份确认前不读取旧分区 |
| 401 | 只处理与当前 token 对应的响应；关闭连接、清 token 与当前账户业务 cache，进入登录；不得继续显示受保护快照 |
| 403 | 不清 token；立即隐藏/失效对应资源及其子缓存，刷新能力/成员目录；不从旧 cache 绕过权限 |
| 权限/成员/Agent 变化 | 使 sessions、agents 和相关详情失效；revalidate 前禁用发送/写操作 |
| 服务端删除 | 先写 tombstone、从 UI/L1 移除，再异步清子记录；较旧响应不能复活实体 |
| 网络恢复/auth_ack | 每个 active key 只发一次 single-flight revalidate；先关键首屏，后后台列表 |
| App 进程恢复 | 先确认 user/workspace，再显示带 freshness 的 Room 快照；并行 revalidate，不串行阻塞所有页面 |

## 9. 稳定性设计

### 9.1 网络与并发

- GET：repository 按 cache key single-flight；失败重试使用 capped exponential **full jitter**，尊重 `Retry-After`，仅重试 timeout、连接失败、429 和可恢复 5xx；401/403/404 不自动重试。
- POST/PUT：默认不自动重试。每次本地写有 operation id 和状态 `not_sent/sending/accepted/uncertain/failed`；只有服务端 endpoint 明确支持 idempotency key 时才复用同一 key。
- Chat send 保留现有 uncertain 保护：网络结果不确定时先拉消息/pending 核对，用户明确确认后才能重发。
- 取消：workspace/session 切换会取消旧 generation 请求；晚到结果在 user/workspace/generation/revision 四个门槛后才能写 cache。
- 超时分层：connect/read/call 分开配置并记录 endpoint，不用一个 25 秒 call timeout 掩盖 DNS、TLS 和服务器等待来源。

### 9.2 WebSocket

- 每个已认证 workspace 最多一个 socket owner；STARTED/STOPPED 只启动/停止同一个状态机。
- 退避采用 1 秒起步、32 秒封顶的 full jitter；稳定连接达到观察窗口或收到 auth_ack 后清 attempt。
- 断线只安排一个 timer；网络不可用时等待系统网络回调，不忙循环。
- auth_ack 后一次 prioritized reconciliation；事件只失效相关 key，burst 在 100–300ms 窗口合并。
- 401/auth_error 立即停止重连并走登录失效；403/资源删除按失效矩阵处理。

### 9.3 Worker 与后台

当前 main 没有 WorkManager。若 v2 或 v3 后续引入后台同步：

- 使用稳定的 unique work name（包含 user/workspace hash），`ExistingPeriodicWorkPolicy.UPDATE` 或等价单例策略；登录、切 workspace、进程恢复不得叠加 Worker。
- Worker 输入不含 token/正文；运行时从安全存储读取当前凭据并二次确认 workspace。
- 约束网络、电量与退避；前台 WS 正常时不同时做高频后台 poll。
- 登出/401 必须 cancel unique work；24 小时 soak 中同一 user/workspace 的 enqueued/running 实例上限为 1。

### 9.4 内存与渲染

- 消息采用分页窗口与稳定 key；超出 L1 窗口的页留在 Room，需要时回读，不让一次会话无限增长。
- Markdown 转换、trace redaction 与图片尺寸解析移出主线程并按 message id 缓存结果；内容/revision 改变才重算。
- 图片请求限定尺寸、并发与占位；页面离开取消未需要请求。
- 使用 immutable UI model、批量合并 event burst，避免整页无关重组。
- LeakCanary 可只用于 debug/测试；是否引入由 Stage 2 依赖审查决定，生产包不带分析依赖。

## 10. 故障与恢复验收矩阵

| 故障 | 预期行为 | 证据 |
| --- | --- | --- |
| 冷启动/进程被杀 | 身份确认后先呈现 scoped stale snapshot，再收敛；无旧账户闪现 | Macrobenchmark + Appium + fixture log |
| 旋转/配置变化 | controller/socket/请求不重复；草稿、选择和滚动位置保持 | Appium + connection/request count |
| 前后台切换 | STOPPED 停止前台 socket；恢复只有一个连接与一轮 revalidate | Appium + fixture connection log |
| 断网/弱网/timeout | 快照带 stale/offline；读请求有界退避；写入 uncertain 不重复 | Toxiproxy/fixture + Appium |
| 401 | 当前 credential 才能触发清理；缓存不再显示；回登录 | fixture + cache inspection |
| 403 | 凭据保留，资源隐藏/刷新权限，不重试 | fixture + Appium |
| 5xx/429 | GET 有界重试并尊重 Retry-After；write 不盲重试 | MockWebServer/fixture request log |
| WS 断连 | 单 socket、单 timer、full jitter；恢复后 REST 收敛 | fixture timestamps |
| 删除/乱序 | tombstone 优先，旧响应不能复活；高 revision 胜出 | repository 单测/集成测试 |
| 永久 pending | task terminal/chat done/pending REST 为空均可清；超时只提示核对，不伪造 terminal | fixture + controller test |
| Worker 重复 | 同 key 最多一个；登出取消 | WorkManager test + `dumpsys jobscheduler` |
| 24 小时 | 0 crash/ANR/duplicate send；内存/请求/socket/Worker 无累积 | soak report + raw time series |

## 11. 可观测性

只记录结构化、低敏感度指标：

- 启动：process start、first frame、cached content visible、freshness resolved。
- HTTP：endpoint template、method、status class、DNS/connect/TLS/TTFB/total、bytes、retry count、single-flight wait；不记录 URL query、header/token 或 body。
- Cache：entity、memory/disk/network/miss、fresh/stale、age bucket、eviction reason、database bytes。
- WS：connect attempt、authenticated duration、disconnect reason class、backoff、event type、coalesced invalidation count。
- Stability：crash/ANR、OOM、pending age bucket、active socket count、unique Worker count。

本地 fixture 原始日志与 benchmark JSON 作为 PR evidence；生产遥测若未来需要，必须另行经过隐私与保留期评审，不由本 Intent 自动授权。

## 12. 最小有价值交付（MVV）

v3 的最小有价值交付不是“一次大重写”，而是可验证的四步闭环：

1. 建立 Macrobenchmark/fixture/指标采集并冻结 B0/T；
2. 把 Chat refresh 拆成按 key single-flight 的 repository，消除 pending/断线时不相关的 6 请求全刷；
3. 为会话、消息与 active task 增加隔离的 memory + Room stale-while-revalidate，完成进程死亡/离线收敛；
4. 用 Pixel 6 Pro + adb + Appium 通过冷启动、滚动、弱网、重连、进程恢复和 24 小时 soak，再决定是否扩展到 Project/Issue/Agent 与静态资源缓存。

如果第 2 步已达到预算且 Room 对启动/离线收益不成立，可在 Stage 2 decision 中缩减第 3 步；不得因文档先选 Room 就跳过 benchmark 证据。

## 13. 后续阶段拆分建议

Benjamin 已于 2026-09-06 批准 1A–6A，CLE-73 执行 Stage 2；真实 B0 与数值预算验收前不启动 Stage 3 及之后的产品优化。按依赖串行推进：

1. **Stage 2 — Baseline harness & numeric budgets**：fixture S0–S4、Macrobenchmark、Perfetto、网络/cache 指标；接入 Pixel 后冻结 B0/T。
2. **Stage 3 — Repository contracts**：user/workspace key、freshness、single-flight、revision/tombstone、写操作状态机及单测。
3. **Stage 4 — Chat hot path**：精确 invalidation、full-jitter WS、pending refresh 降载、消息窗口化。
4. **Stage 5 — Disk snapshot**：Room schema/migration/容量/清理；先 chat/task，再按证据扩展 project/issue/agent。
5. **Stage 6 — Rendering & memory**：Markdown/trace/image 主线程与对象生命周期优化、Baseline Profile（若 B0 证明需要）。
6. **Stage 7 — Recovery & background**：401/403/5xx、网络恢复、进程回收；仅在需求存在时加入 unique WorkManager。
7. **Stage 8 — Full verification**：adb/Appium 六类场景、24 小时 soak、回归预算与最终 EVAL/HARDENING。

每个实现 PR 只覆盖一个可测边界，必须带优化前后相同场景的原始证据；不把多项改动合在一起后猜测收益来源。

## 14. 风险与回滚

- **缓存 schema 错误或迁移崩溃：** 所有磁盘快照可丢弃并从服务端重建；迁移失败只能删除业务 cache，不能删除凭据/草稿。回滚到 no-disk-cache 路径必须保留。
- **权限泄漏：** user/workspace key、身份确认前不展示、401/403 清理是 release blocker；任何跨 workspace 命中都立即停止发布。
- **陈旧状态误导：** 在线/运行中/权限状态必须显示 freshness；离线快照不得提供会改变服务端状态的按钮。
- **数据库增加启动成本：** 首屏只读小窗口并异步清理；若 B1 比 B0 更慢且离线收益不达标，回滚 Room rollout。
- **重连/重试放大流量：** fixture 先验证 request/connection 上限，再接真实 API；通过 feature flag 或 repository fallback 快速关闭新策略。
- **v2 继续变化：** v3 Stage 2 开始前 rebase 最新 main，并重新核对未合并 PR；不与 v2 未完成路径并发改写。

## 15. Benjamin 已批准的决策（2026-09-06）

以下 1A–6A 已明确批准，无需重复询问；仅具体数值预算仍需实测后验收。

1. **1A：先基线后优化。** 现在开展 fixture、测量工具、脚本和 B0；真实 B0 与预算冻结后才启动产品优化。
2. **2A：初始存储安全边界。** app-private credential-encrypted storage + 禁备份，账户/workspace 隔离、身份确认、登出/401/403 清理；首版不额外要求数据库级加密，机制仍需实现验证。403 清对应资源，不清有效凭据。
3. **3A：离线只读。** 显示缓存时间和离线标识；允许本地草稿，恢复网络后由用户发送；不提供离线发送、Issue 状态变更或任务队列。
4. **4A：完整消息正文缓存。** 最近最多 30 个会话，每 workspace 最多 10,000 条或 50 MiB，先到上限即淘汰；7 天未访问可淘汰，**不是硬性 7 天到期删除**。这些是已接受的初始候选，仍用真机数据库大小、查询耗时和 PSS 校准，必要时下调。附件二进制不默认持久化，敏感原始 tool trace 不纳入普通正文缓存。
5. **5A：停止无变化高频后台轮询。** 无真实业务变化时不做 5 秒 polling；返回前台刷新；必要后台同步受系统约束，接受延迟；即时推送不纳入本轮。
6. **6A：条件处理旧 PR #2。** 核对最新状态和独有内容，先迁移有价值遗漏再关闭过时 PR；该操作已授权。逐项证据见 `baseline/pr-audit.md`。

## 16. Stage 1 验收清单

- [x] 核对 Chatty 最新 main、已合并提交与未合并 PR，并明确 v2 当前可测路径。
- [x] 以 Multica 当前 main 只读核对消息分页、发送、权限、WS 与事件/HTTP 缓存语义。
- [x] 区分真实构建基线、静态调用路径推导和未测真机指标。
- [x] 为启动、帧、内存、网络、缓存、离线、崩溃/ANR、重连、后台与 24 小时运行定义设备、数据集、步骤、采样和 Gate。
- [x] 给出消息、会话、Agent/Issue/Task、附件元数据和静态资源的层级、TTL、容量、淘汰、失效、离线与安全矩阵。
- [x] 覆盖冷启动、滚动/消息渲染、弱网、断线重连、进程恢复与 24 小时 soak 六类可执行验证。
- [x] 给出 MVV、阶段拆分、风险、回滚和需要 Benjamin 决策的项目。
- [x] Benjamin 接受 1A–6A 方向，授权 Stage 2 准备与采集。
- [ ] 真实 B0 与具体数值预算 T 验收；在此之前不启动产品优化。

## 17. References

- `android/feature-chat/src/main/java/ai/chatty/feature/chat/ChatController.kt`
- `android/feature-chat/src/main/java/ai/chatty/feature/chat/ChatScreen.kt`
- `android/core-network/src/main/java/ai/chatty/core/network/MulticaApi.kt`
- `android/core-network/src/main/java/ai/chatty/core/network/ChatApi.kt`
- `android/core-auth/src/main/java/ai/chatty/core/auth/EncryptedSessionStore.kt`
- `iterations/v2/intent.md`
- `iterations/v2/spec.md`
- `iterations/v2/EVAL.md`
- `docs/android-dev-loop.md`
- Multica read-only: `server/internal/handler/chat.go`
- Multica read-only: `server/internal/realtime/hub.go`
- Multica read-only: `server/pkg/db/queries/chat.sql`
- Multica read-only: `server/pkg/protocol/events.go`
