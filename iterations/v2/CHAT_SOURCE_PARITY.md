# Android Chat 与 Multica 源码对齐

日期：2026-09-05。参考本机 Multica 提交 `1cc46b269`。本轮只读参考仓库，开发位于 Chatty。

> 当前页面安排以 [NAVIGATION.md](NAVIGATION.md) 为准：对话只保留 Mika，项目承担 Issue 进度，资源管理集中到设置。

## 本轮范围

实现 M3 对话核心，并接入支持该核心的 M4 Chat 实时事件与 M6 附件基础。完整 V2 仍未验收。

| Multica 源码契约 | Android 实现 | 验证 |
| --- | --- | --- |
| `packages/core/types/chat.ts` 会话、消息、游标、发送回执、pending | 明确 wire 字段，兼容缺失可选字段和 nullable 附件；发送使用服务端 message_id/task_id | API 单测、Pixel 合成与真实历史读取 |
| `packages/core/types/agent.ts`、`permissions/rules.ts` | system_key 定位 Mika；owner/public_to workspace/member 判断；private 无 admin 绕过 | 单测、Pixel 隐藏无调用权限 Agent |
| `chat-thread-list.tsx` | 本轮收敛为最近有效 Mika 会话；历史列表和多 Agent 切换入口已移除 | 单 Mika 入口真机验证 |
| `chat-message-list.tsx` | 用户靠右气泡、助手全文；任务 stable key；失败详情折叠、无回复提示、耗时、复制 | Pixel 两轮回复、失败、no_response、真实历史 |
| `task-transcript/build-timeline.ts`、`chat/lib/copy-text.ts` | seq 去重排序，连续 text/thinking 拼接；前言/过程/最终回复分段；凭据脱敏 | 单测、Pixel 工具过程 |
| `chat/lib/quick-actions.ts` | 隐藏尾部 quick-actions 协议，展示服务端动作；点击填入草稿 | 单测、Pixel |
| REST `messages/page` | limit=50、before_created_at + before_id；保留加载过的历史，含同时间戳边界 | API/Controller 单测、Pixel 加载最早消息 |
| REST `send` | 单飞；回执不明保留草稿并要求核对；接受成功后不因本地错误重新发送；校验 attachment_ids，未绑定附件保留并提示 | Controller 单测 |
| GET `/ws` | token 仅在 auth 首帧；auth_ack 后接受事件；15 秒认证超时；前台单连接；退避重连；无重放假设 | MockWebServer、Pixel socket 断开重连、真实 auth_ack |
| Chat/Task 事件 | 按当前 session/task 过滤；未知关联事件可折叠查看；最终事件 REST 收敛；pending/断线/失败时轮询修复 | Controller 单测、Pixel |
| `attachment.ts` 与 `api/client.ts` | SAF 选择、multipart file 上传（100 MB）；点击刷新 metadata；文本预览、图片、签名下载；同源代理下载走认证与 FileProvider | Pixel 文本预览；其他路径见限制 |
| `ui/markdown` | Markdown 标题、列表、引用、链接、代码、表格、删除线、任务列表；图片单独加载；禁用 file/javascript scheme | Pixel 格式样例、链接安全单测 |
| 本地数据边界 | 服务端会话/消息/任务仅内存；草稿 DataStore，按账号凭据摘要 + workspace + session/agent 隔离；显式打开的代理附件仅临时 cache | Pixel 草稿隔离/冷启动 |

## 明确差异与后续工作

- **交互内容**：按最新原生体验决策，HTML、Mermaid 当前保留文本/代码，已移除对应 Multica 网页入口。自定义富内容块、LaTeX、内嵌视频/音频、实体卡片、mention 解析尚未完整移植。
- **附件**：文本附件预览已真机通过；系统选择/上传单独验证。代理文件下载、签名地址过期、超大文件、图片错误态需要更广真机样本；图片不写磁盘缓存。显式代理附件的临时文件会在下一次下载时清理超过 1 小时的条目。
- **对话操作**：按最新用户要求，页面仅保留 Mika 单一对话。取消和排队消息管理尚未实现，执行中暂不开放再次发送。
- **入门引导**：隐藏 onboarding_kickoff，onboarding_opening 文本可见；专用 starter cards 尚未移植。
- **实时范围**：本轮仅完成 Chat 所需事件。M4 的 Issue/Agent/Runtime 跨页面失效、M5 状态映射等仍需后续阶段。
- **账号草稿键**：使用 token 的单向摘要隔离本机草稿；换发 token 后不会自动迁移旧草稿。
- **真实发送门禁**：真实历史和 WebSocket 已验证；向真实 Mika 发送新测试消息尚待用户对本轮明确消息内容的授权。合成服务成功不能替代这项验收。

## 开发入口

- `android/core-model/.../ChatModels.kt`：服务端资源结构。
- `android/core-network/.../ChatApi.kt`、`ChatSocket.kt`：REST 和 WebSocket。
- `android/feature-chat/.../ChatController.kt`：会话生命周期、分页、发送、事件收敛。
- `android/feature-chat/.../ChatPresentation.kt`：格式与权限规则。
- `android/feature-chat/.../ChatScreen.kt`：Compose 页面、Markdown、附件、草稿。
- `scripts/chat-fixture.py`、`scripts/chat-device-test.py`：隔离合成服务和 Pixel 闭环。
