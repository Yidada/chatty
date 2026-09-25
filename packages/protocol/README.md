# @chatty/protocol

iOS ↔ Runner 消息协议的唯一事实来源。

## 规则

1. 任何协议改动，先改 `schema/` 下的 JSON Schema（draft 2020-12）。
2. 再运行代码生成，同时更新 Swift 和 TypeScript 类型。
3. 生成文件禁止手改。CI 会重新生成并检查 `git diff`。

## 规划

| 路径 | 内容 |
| --- | --- |
| `schema/envelope.json` | 信封：`req` / `res` / `event` / `notify` |
| `schema/requests/` | 每个请求的 params 与 result |
| `schema/events/` | 每种会话事件的 data |
| `schema/models/` | Agent、Session、Item 等实体 |
| `generated/ts/` | 生成的 TypeScript 类型 |
| `generated/swift/` | 生成的 Swift 类型（`Sendable` struct） |

代码生成工具：`quicktype`。协议草案见 [`docs/architecture.md`](../../docs/architecture.md) 第 6 节。

状态：M1-2 PR 中提交 Schema 初版。
