# Specification

## 行为

- `canSend`：`pending.task_id == null || pending.supports_queue` 时才允许发送；其余条件（权限、Runtime、归档、草稿/附件、uncertain）不变。
- 运行中发送：服务端回执 `queued=true` 时，新任务进入 `pending.queued_tasks`，其用户消息从主消息流隐藏，仅在队列托盘显示。
- `canStop`：`pending.task_id != null` 时可用；停止后按 `cancelled_chat_message.restore_to_input` 回填内容与附件。
- 立即发送：`prioritize(task)` 后取消返回的 `active_task_id`，被取消内容回填输入框。
- 编辑/删除队列消息：`cancelTask(expected_status=queued, chat_session_id, queue_action=edit|remove)`；edit 回填，remove 不回填。若任务已被领取（409），退化为普通停止。
- 清空队列：`DELETE .../queued-tasks`，移除队列中所有消息。
- 回填策略：追加到现有草稿（空行分隔），附件按 id 去重。
- 事件收敛：`task:queued` 入队、`task:dispatch/running` 提升、终态移除，随后始终以 `pending` 查询为准。

## 边界

- 仅作用当前会话（`generation` 隔离）；其他会话事件忽略。
- 队列托盘「立即发送」仅在 head 状态为 `dispatched/running/waiting_local_directory` 时可用。
- 不改变发送结果不明（uncertain）的防重复语义。

## 验收映射

1. 运行中可发且入队 -> Controller 单测 + 合成真机 `queue`/`queue-replies`。
2. 不支持队列时禁用 -> Controller 单测。
3. 停止/编辑回填 -> Controller 单测。
4. 立即发送/删除/清空 -> Controller 单测。
5. 纯函数收敛 -> `ChatPendingTest`。
6. 协议 wire 名与 capability -> `ChatApiTest`。
7. 构建/单测/lint -> 见 evidence。
