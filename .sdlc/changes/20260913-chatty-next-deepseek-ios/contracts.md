# 原生 dsh 契约

本文件按本机安装包的生成声明和 JavaScript 实现编写。下方契约示例均为合成数据。2026-09-13 Build 已通过同源 HTTPS / WSS 的真实配对与文字会话；证据及范围见 build.md。安装包指纹见 `contracts/manifest.json`。

## 1. 配对与传输

1. 规范化输入为固定 HTTPS origin，包含有效端口。只允许根路径及配对 token，拒绝 userinfo、意外 fragment 与任意重定向来源。
2. 对该 origin 发 `GET /?token=<输入凭据>`；凭据仅在内存，日志与诊断不记录 query。
3. 读取返回 `Set-Cookie` 和清洁根路径重定向。配对阶段仅处理同 origin 的清洁 `/`；拒绝跨 origin Location，不把原 query 带入后续请求。
4. 将 cookie 元数据保存到独立 Keychain，清除输入 token；后续 Cookie 仅在 exact origin 对应的专用 URLSession 使用。
5. 当前 Tailscale Serve 后面的 dsh 返回 Cookie 未带 Secure 属性，因为上游为 loopback HTTP。原生端仍将凭据固定于 HTTPS / WSS 的 exact origin，不因 Cookie 属性放开 HTTP。Cookie 标准自身不按端口隔离，因此应用必须显式校验端口；不使用跨连接共享的默认 cookie jar。
6. RPC 路径为 `POST /api/<endpoint>`。上一轮计划中的“走 /api”描述的是通道前缀，实际原生请求需要 endpoint 后缀。
7. WebSocket 为 `wss://<origin-host>:<port>/api/remote.mux`；HTTP 与 WSS 使用同一连接凭据，WSS scheme 按映射校验。
8. 非配对 API 拒绝重定向；401 进入重新配对，403 显示来源不被服务接受，超时进入连接恢复，业务错误按 error.code 分类。

## 2. HTTP 请求与返回

路径：`POST /api/session/prompt`

```json
{
  "type": "client-request",
  "rpcId": "rpc-demo-1",
  "method": "session/prompt",
  "payload": {
    "args": {
      "request": {
        "sessionId": "session-demo-1",
        "requestId": "send-demo-1",
        "mode": "queue",
        "content": [{"type": "text", "text": "请解释测试目录中的说明文件。"}],
        "clientTimeZone": "Asia/Singapore"
      }
    }
  }
}
```

合成接受返回：

```json
{"type":"server-response","rpcId":"rpc-demo-1","result":{"ok":true,"value":{"accepted":true}}}
```

合成业务错误：

```json
{"type":"server-response","rpcId":"rpc-demo-1","result":{"ok":false,"error":{"code":"session/model-unavailable","message":"no adapter serves selected provider","details":{"provider":"demo","model":"demo"}}}}
```

- `rpcId` 关联这一次网络调用；`requestId` 关联用户这一次发送动作；`sessionId` 关联会话。三个 ID 不能混用。
- HTTP 200 仍可能携带 `result.ok:false`。`rpcId` 不匹配视为协议失败。
- `accepted:true` 只说明已接受。消息是否进入队列 / 持久历史需通过 rpcId 对应的 user source 或队列项验证。
- 已安装代码在队列和 `user/message` 中查重 requestId；检查后仍有异步附件解析。当前未证明所有并发与进程重启场景具有原子 exactly-once，客户端不承诺此性质。
- 本地发送事务：原子保存快照 → 本地回显并腾出输入框 → 串行 POST → 接受 / 未知 / 拒绝 → 事件对账 → 清理快照。
- 若原请求仍可能执行，超时后不自动再 POST。先恢复 follow / control；必要重试沿用同 requestId 和原始内容，新的用户明确发送使用新 ID。

## 3. 方法面

请求 payload 通常为 `{ "args": { "request": <下表> } }`，但 list 的参数名是 `_request`，无参方法是空 args。必须使用生成描述符的名字，不能全部套一个模板。

| Endpoint | args | 成功 value / 约束 |
| --- | --- | --- |
| `session/list` | `{_request:{cursor?}}` | `{items:[SessionSummary]}`；没有已声明 nextCursor |
| `session/create` | `{request:{sessionId?,cwd?,workspaceId?,agentPreset?}}` | `{sessionId,agentPreset?}`；cwd 与 workspaceId 互斥；重试复用客户端 sessionId |
| `session/search` | `{request:{query}}` | `{items:[{sessionId,snippet}],hasMore}`；上限 / 分页按服务契约，不造 nextCursor |
| `session/rename` | `{request:{sessionId,title}}` | `{title,seq}`；显示服务端规范化结果 |
| `session/prompt` | `{request:{sessionId,requestId,mode,content,clientTimeZone?}}` | `{accepted:true}`；content 至少一段非空文本或附件 |
| `session/cancel` | `{request:{sessionId}}` | `{accepted:true}`；实现调用 cancel with keepInbox:true；不自动重试 |
| `session/updateQueue` | `{request:{sessionId,itemId,action}}` | action 为 edit / remove / steer；仅操作仍待处理的队列项 |
| `session/follow` | `{request:{address,maxMessages?,assistantStream:true}}` | 下述 Snapshot / event / assistant-stream |
| `session/page` | `{request:{address,throughSeq,beforeSeq?,maxMessages?}}` | `{records,hasMore}`；throughSeq 来自对应 follow snapshot |
| `session/control` | `{}` | 当前进程 baseline，后续 queue / jobs / projection |
| `session/modelCatalog` | `{}` | provider / model / reasoning 能力目录 |
| `session/selectModel` | `{request:{sessionId,provider,model,reasoningEffort?}}` | `{selected}`；标准化选择作用于 next request，并尝试保存共享默认模型；与 prompt 不构成原子操作 |
| `session/fork` | `{request:{sessionId,atSeq?}}` | `{sessionId}`；不能直接视为原地重新生成 |

地址示例：`{"kind":"session","sessionId":"session-demo-1"}`。本期普通会话不把 subagent 地址当普通 sessionId。

### 3.1 两个选择器的协议

- `session/modelCatalog` 无参数（args `{}`），读取可路由提供方 / 模型、默认选择与 failures。无权限或全部失败时保持未就绪，不发明客户端模型列表。
- `workspace/follow` 无参数，使用同一多路 WSS 打开 endpoint。首帧 `{type:"baseline",value:{items,archivedSessionIds}}`，items 的每项为 `{workspaceId,path,title,sessionIds,createdAt,updatedAt}`。
- 后续帧支持 upsert / remove / order / archived。重连替换整个目录基线，旧代次不能覆盖新目录；没有 `workspace/list` 方法，不臆造 HTTP REST 地址。
- 选择现有 workspace，提交 `session/create` 的 request 带 workspaceId 与稳定 sessionId。workspaceId 与 cwd 互斥。已有 session 的 cwd 冲突会拒绝创建 / 采用，目录变更必须另用 sessionId。
- `session/workspace-attach-failed` 可能表示会话已创建。保留该 sessionId 并恢复状态，不能直接用新 ID 重发。不存在 workspace 时要求重选，不改用默认 cwd。
- `session/selectModel` 校验 provider / model / reasoningEffort，失败可为 `session/model-unavailable`；成功使用返回的 selected。源码调用 selectForNextRequest，再尝试 agentDefaultModel.saveSelection，保存默认失败可仅记日志而仍返回成功。
- 原生客户端串行 selectModel → 上传 / prompt，冻结本次发送意向。另一个客户端仍可能插入模型变更；当前请求体没有模型预期版本，不宣称跨客户端原子绑定。
- 工作区分组调整与会话执行 cwd 分开。`workspace/insertSessionBefore` 不作为迁移执行目录的命令。
- 已发现 `workspace/archiveSession`，归档分组与永久删除不同。此次只补充选择器契约，不扩大为 workspace 管理面板。

## 4. WSS 多路流

打开会话流的合成帧：

```json
{"type":"open","streamId":"follow-demo","endpoint":"session/follow","payload":{"args":{"request":{"address":{"kind":"session","sessionId":"session-demo-1"},"maxMessages":50,"assistantStream":true}}}}
```

服务端物理帧为 `item(streamId,value)`、`error(streamId,error)` 或 `end(streamId)`。关闭单个逻辑流发送 `{"type":"cancel","streamId":"follow-demo"}`，不取消正在运行的 Agent。

| 层次 | 字段 | 归并规则 |
| --- | --- | --- |
| follow snapshot | header、cursor、records、hasMore、projections、assistantStream? | 一个流 generation 的起点；验证版本与表面结构后发布 |
| durable event | type、seq、time、data、surfaceOp?、sourceEventSeqs?、ignorable? | 按持久序号对账；surfaceOp 可能替换旧范围，不能一律 append |
| assistant start | attemptId、revision、startedAfterSeq、turn、step | 建立一次临时尝试的身份和归并锚点 |
| assistant chunk | attemptId、revision、index、time、chunk | index 连续；检查完整性后解析文本 / reasoning / 工具分片 |
| assistant end | attemptId、revision、index、outcome | committed 指向最终事件类型与 seq；abandoned 撤销临时片段，不造最终成功消息 |
| control baseline | queues、jobs、projections | 每次重连整体替换进程状态；不能拿上次 baseline 推断现在已停止 |

重连与最终替换算法：

1. 每次连接分配 `connectionGeneration`，旧 generation 的任何回调都不能写新状态。
2. 先开 follow，取得 opening snapshot 和活跃 attempt baseline，再读与该 snapshot 对应的历史页；翻页不能跨不同切面拼接。
3. 活跃 baseline 包含 `nextIndex` 与 compact stream，先恢复它，再接收后续分片。
4. 最终 durable `assistant/message` / `assistant/attempt` 可能先到；仅当与正在跟随的 turn / step / attempt 对应时暂存，等待 end 所指 seq / index 合并。
5. 成功合并一次后，用稳定最终消息取代该 attempt 的临时呈现；同 turn 的其他重试内容按服务事件保留。
6. chunk 缺号、revision 缺口或 durable gap 触发重新打开 follow / 取得一致切面；不把未知中间内容补成空字符串。
7. 只在物理断线时退避重连（1、2、4…最多 30 秒，带抖动，为客户端初值）；鉴权 / 业务 / 必需 schema 错误立即进入对应状态。
8. app 后台停止前台网络订阅和录音；回到前台先恢复事实，再允许新发送。后台关闭流不等于取消 dsh 运行。

Compact stream 解码：持久数据包括 text-chunks、reasoning-chunks、tool-call-chunks 和 raw chunk，携带 time0、dt、block index。原生实现必须按锁定的 StreamChunk / assembler 结构重建 block，不能只拼所有 texts 并丢掉索引、替换和工具边界。

## 5. 附件

- 文件：`POST /api/session/uploadFileBinary?sessionId=<id>&name=<urlencoded>`，`Content-Type: application/octet-stream`，body 为原始字节。
- 返回 `{ok:true,value:{receiptId,file}}` 或 `{ok:false,error}`，采用独立的上传结果结构，不带 rpcId。
- prompt 文件段为 `{"type":"file","receiptId":"receipt-demo"}`；只在原会话 / Agent 使用。
- prompt 图片段为 `{"type":"image","mediaType":"image/jpeg","data":"<base64>","name":"photo.jpg"}`。限制来自实际模型 / imageLimits，不能从旧 Chatty 20 MB 限制推断 dsh 上限。
- 本地选择器保留可恢复来源文件；上传成功但 prompt 未确认时，不重复复用已被消费的收据。对账优先于重传。
- 图片能力被拒绝时展示具体原因；不把附件移除后自动发送一条缺材料的消息。

## 6. 工具授权

打开 `$events` 逻辑流，payload 为 `{args:{}}`。先收到 `{type:"ready",clientId,host}`，之后才处理该 generation 的事件。

- `approval/request` 通过 waterfall 帧传递，字段包括 eventId、agentId、request。
- 原生确认卡将 agentId 关联到当前 dsh 会话，并展示调用与 reason；没有相关调用细节时不虚构。
- 通过 `POST /api/$events/result` 返回 `payload.args = {clientId,eventId,outcome:{kind:"result",value:"allowed-once"}}`；拒绝使用 `"rejected"`。
- `type:"cancel"` 撤回对应卡片；回答提交后等待服务端 audit / 运行状态，而非立即画成执行成功。
- 断线保留“状态待恢复”，新 ready 后仅处理新 generation 对应的有效事件；不自动重放旧允许操作。
- 其他客户端可能先回答同一请求，服务端结果为最终事实。未识别的必需问答事件必须进入“需要处理”的可见状态。

### 6.1 运行中提问

`user-questions/request` 同样通过 waterfall 传递。request.questions 中每项包含 `id、question、detail?、header?、options?、multiSelect?、intent?`；选项包含 label 和可选 description。

- 原生 UI 显示问题正文和可展开 detail，单选 / 多选规则来自 multiSelect；允许按协议提交 custom 文本。
- 用户提交后，`$events/result` 的 outcome.value 为 `{"answers":[{"id":"q-demo","selected":["选项标签"],"custom":"可选补充"}]}`。
- `intent.kind:"plan-review"` 的 approve 字段指定哪个标签表示批准，不根据第一个选项或按钮颜色推断。
- 同一批问题按 id 收集后提交；撤回 / 断线遵循和授权相同的 generation 校验，不代用户填写答案。

## 7. 开发时必须补充的契约样本

需要真实或按已安装校验器生成的脱敏样本：创建 / 列表 / 搜索、文本与推理交错、分块代码、工具调用 / 授权、完成前断线、cancel 保留 queue、文件 receipt 失效、user-questions request/result。

这些样本未取得前，阅读原型和静态 JSON 只能验证设计一致性，不能证明 N1 已通过。

## 8. 语音提交复用文本事务（D20）

- 输入：同一 recordingId 的有效松手意图 + 非空稳定识别结果。ASR 的临时 / final 回调单独不构成发送。
- 固定 connectionId、connectionGeneration、原 conversationKey、草稿修订和模型 / workspace 意向。每次录音最多消费一次发送意图，再分配稳定 requestId，进入第 2 节的文本发送事务。
- 取消、来电、后台、切会话、失去指针或权限尚未完成时的松手，都不能在迟到 final 后自动发送。已取消 recordingId 的回调全部失效。
- 识别为空不创建 session 或 requestId。结果非空且首次发送时，按原 workspace 建立会话，按第 3.1 节选择模型，再提交普通 text content。
- 发送接受情况不明时只恢复和对账；不得由重复 final 重新创建 ID、重建会话或重复 POST。
- 此为客户端契约设计，没有新增 dsh 语音端点，没有验证当前服务接收真实录音。原生引擎与 Tailscale 对话仍需 N1 / N2。

## 9. Chatty 自动审核（D22）

- `commands/execute` args：`{"agentId":"<session-id>","line":"/chatty-review","submittedAttachments":[]}`。这是现有 dsh 人类命令接口，命令不送入对话模型。
- 发送链为创建 / 采用会话 → 选择模型 → 自动审核启用回执 → 附件与 prompt。要求 `result.kind=success` 且 `result.text=chatty-next:approve-for-me-v1`；不把未知回执解释为成功。
- 服务端 `/chatty-review` 幂等写入 `chatty/approval-mode`，将本会话设为 `workspace-write` 基线。只有带此标记的会话进入审核器；其他会话委托原应答链。
- 审核使用 `approval/asked` 的单次 id、`tool/call` 或 `tool/ptc-dispatch-start` 的精确参数以及 `source.kind=user` 的消息。工具结果与插件消息不能提供授权。缺失记录、附件内容未知或输入超过 96 KB 时交给人工判断。
- 审核调用使用现有 `deepseek-official/deepseek-flash`、high 思考、无工具、4096 token 上限及 30 秒超时。仅接受完整 stop 与严格 JSON；允许必须同时满足 `authorized=true` 和 low / medium 风险。
- `chatty/approval-review` 保存开始 / 完成、approvalId、callId、输入摘要哈希、模型路由和结论，属于 log-only 事件。原生客户端消费其序号，工具过程不会因此自动展开。
- 单次审批去重；取消后不授予权限。用户输入或调用事实变化会使审核失效。断线不会让客户端自动回复 `allowed-once`。已有、已转交人工的审批不会被安装过程自动重放。
- `user-questions/request` 保持人工回答。自动审核不填写产品选择、计划确认或其他问题。
