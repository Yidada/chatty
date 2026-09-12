# Plan

1. `core-model`：新增 `PrioritizeQueuedResponse`、`CancelTaskResponse`、`CancelledChatMessage`；复用 `QueuedTask`。
2. `core-network`：新增 prioritize / clearQueued / cancelTask 接口；`SessionInterceptor` 对 `/api/` 请求加 `X-Client-Capabilities: chat-draft-restore-v1`。
3. `feature-chat`：新建 `ChatPending.kt`，移植 Multica `packages/core/chat/pending.ts` 的 enqueue/promote/remove/prioritize/hide 纯函数。
4. `ChatController`：放开运行中发送；新增 stopCurrent / sendQueuedNow / editQueued / removeQueued / clearQueued；事件乐观收敛 + refresh 兜底。
5. `ChatScreen`：队列托盘、隐藏队列消息、停止按钮。
6. 测试：`ChatPendingTest`、扩展 `ChatControllerTest`、`ChatApiTest`；扩展 `scripts/chat-fixture.py`（queued/supports_queue/prioritize/clear/cancel/slow）与 `chat-device-test.py`。
7. 验证：`source scripts/android-env.sh && cd android && ./gradlew testDebugUnitTest assembleDebug lintDebug`；真机队列闭环待设备可用时执行。
8. 记录 evidence/review/decisions；本次不自动提交或推送。
