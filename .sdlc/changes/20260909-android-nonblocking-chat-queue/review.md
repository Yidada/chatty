# Review

- Reviewer: self-review（同一实现者自审，非独立审查）
- Verdict: approved for local delivery; device loop pending

## Findings

- `canSend` 仅在 `supports_queue` 或空闲时放开，运行中发送不会替换正在进行的任务；单飞只锁 POST。
- 队列收敛为纯函数（`ChatPending.kt`），与 Multica `pending.ts` 语义一致；事件先乐观收敛再 refresh 兜底。
- 停止/编辑/删除/清空均以服务端返回的 `cancelled_chat_message` 为准回填，409 退化为普通停止。
- 队列消息不出现在主消息流，避免与队列托盘重复。
- 新增接口路径、方法与 query 参数经 MockWebServer 单测锁定；capability 头只加在 `/api/` 认证请求上。
- 未改动服务端、身份、持久化协议；未引入 WebView 或新依赖。

## Residual scope

- 跨设备草稿列表 UI 未做；仅启用服务端能力与本地回填。
- 附件随队列消息的编辑回填已按 id 去重，但队列托盘未展示附件缩略图。
- 真机队列闭环未在本次会话执行。
