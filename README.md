# Chatty

> 工作名，正式项目名待定。

Chatty 是一个 iOS 上的多 Harness Coding Agent 客户端。用户在手机上和 Coding Agent 对话、下达任务、审批操作。

- 交互参考 ChatGPT / DeepSeek iOS：以 Session 为单位，界面极简。
- 能力参考 OpenCode + Multica：底层 Harness（Claude Code、OpenCode、Codex、DSH）可以自由切换，Harness、Model、Context 三者独立配置。

## 架构一图

```
┌────────────┐  WebSocket + JSON   ┌──────────────────────────┐   ACP (stdio)   ┌──────────────┐
│  iOS App   │ ◀─── Tailscale ───▶ │  Runner (Node.js 22)     │ ◀─────────────▶ │ Harness 进程  │
│  薄客户端   │                     │  会话状态机 / SQLite /    │                 │ Claude Code  │
│  SwiftUI   │                     │  权限代理 / git worktree  │                 │ OpenCode ... │
└────────────┘                     └──────────────────────────┘                 └──────────────┘
```

## 仓库结构

| 路径 | 内容 |
| --- | --- |
| `apps/ios` | iOS App（Swift 6 + SwiftUI，iOS 17+） |
| `packages/runner` | Runner 服务（TypeScript + Node.js 22） |
| `packages/protocol` | iOS ↔ Runner 消息协议（JSON Schema）与代码生成 |
| `docs` | 架构文档、兼容矩阵、适配器说明 |
| `AGENTS.md` | 给 AI Agent 的开发规范 |

## 文档

- [docs/architecture.md](docs/architecture.md)：模块划分、消息协议草案、Session 状态机
- [docs/harness-adapters.md](docs/harness-adapters.md)：各 Harness 的 ACP 适配器查证结果
- [docs/compatibility-matrix.md](docs/compatibility-matrix.md)：Harness × Model 兼容矩阵初稿
- [docs/design/ios-mvp-sketch-v2.png](docs/design/ios-mvp-sketch-v2.png)：iOS 交互草图

## 获取代码

一律使用 SSH 地址 clone：

```bash
git clone git@github.com:Yidada/chatty.git
```

## 里程碑

1. **M1**：Runner + ACP，接通 Claude Code 和 OpenCode，能在命令行完成一轮对话。
2. **M2**：iOS App 完成配对、Session 列表、流式对话、权限审批。
3. **M3**：Agent 配置、Harness 切换、摘要迁移、git worktree 隔离。
4. **M4**：接入 Codex 和 DSH，支持多 Runner，接入 APNs。

当前状态：文档阶段，等待确认后开始 M1。
