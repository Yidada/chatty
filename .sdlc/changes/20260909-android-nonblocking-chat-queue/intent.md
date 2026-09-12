# Intent — Android 无阻塞对话（像人沟通）

- Change id: `20260909-android-nonblocking-chat-queue`
- Risk: R2（客户端交互行为变更，无数据迁移、无协议破坏）
- Date: 2026-09-09

## 问题

Mika 处理任务期间 `ChatState.canSend` 因 `pending.task_id != null` 直接禁用发送（`android/feature-chat/.../ChatController.kt`），用户必须等回复结束才能继续表达，违背「像人沟通」的体验目标。`.sdlc/archive/iterations/v2/CHAT_SOURCE_PARITY.md` 也记录了「取消和排队消息管理尚未实现，执行中暂不开放再次发送」。

## 目标

- 运行中仍可发送，后续消息按 FIFO 排队。
- 可停止当前任务、把内容回到输入框。
- 队列在输入框上方可见，可立即发送（打断当前）、编辑、删除、清空。
- 不重复发送、不丢草稿；重连后队列从服务端恢复。

## 依据

Multica 服务端（本机 `1cc46b269`）已具备完整能力：`queued`/`supports_queue` 回执、`GET /pending-task` 的 `queued_tasks`、`prioritize`、`DELETE queued-tasks`、`POST /api/tasks/{id}/cancel?queue_action=`，以及 `X-Client-Capabilities: chat-draft-restore-v1`。本次只接客户端，不改服务端。

## 非目标

- 不改 Multica 协议、身份、数据模型。
- 不新增 WebView/网页兜底。
- 跨设备草稿列表 UI（仅启用服务端能力 + 本地回填）。
