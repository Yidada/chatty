# @chatty/runner

Runner 是运行在 Mac / 开发机 / 云主机上的常驻进程。

职责：

- 通过 ACP 启动和管理 Harness 进程（Claude Code、OpenCode，后续 Codex、DSH）。
- 持有 Agent、Session、消息的唯一存储（SQLite）。
- 通过 WebSocket 向 iOS 推送会话事件，代理权限审批。
- 为每个 Session 管理独立的 git worktree，负责切换 Harness 时的摘要迁移。

目录规划、接口草案见 [`docs/architecture.md`](../../docs/architecture.md)。
Harness 列表与兼容矩阵见 [`config/harnesses.json`](config/harnesses.json)。

状态：M1 尚未开始编码。

注意：Runner 不能以 root 运行。
