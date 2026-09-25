# AGENTS.md

本文件是给 AI Coding Agent（以及人类贡献者）的开发规范。开始任何改动前先读完本文件和 `docs/architecture.md`。

## 1. 项目一句话

iOS 薄客户端 + 常驻 Runner + ACP 协议，让用户在手机上驱动多种 Coding Agent Harness。

## 2. 核心概念（所有代码必须遵守）

| 概念 | 含义 | 代码标识符 |
| --- | --- | --- |
| Harness | 执行引擎，即 Claude Code / Codex / OpenCode / DSH 等 CLI | `Harness`, `harnessId` |
| Model | 具体模型。每个 Harness 支持的模型不同，由兼容矩阵维护 | `Model`, `modelId` |
| Context | 工作目录（git 仓库）、AGENTS.md、Skills、MCP 配置 | `Context`, `contextId` |
| Agent | 一个命名组合 = Harness + Model + Context | `Agent`, `agentId` |
| Session | 一次对话，挂在 Agent 下面。对话记录由 Runner 持有 | `Session`, `sessionId` |

规则：

- 不要把 Harness、Model、Context 合并成一个字段或一个配置对象。
- Session 的对话记录以 Runner 的 SQLite 为准。Harness 自己的会话存储只作为“可恢复时的加速手段”。
- Harness 专属的逻辑只能出现在 `packages/runner/src/harness/<harnessId>/` 下。

## 3. 仓库结构

| 路径 | 内容 |
| --- | --- |
| `apps/ios` | iOS App：Swift 6 + SwiftUI，最低 iOS 17，Swift Concurrency |
| `packages/runner` | Runner：TypeScript + Node.js 22，官方 ACP TypeScript SDK |
| `packages/protocol` | iOS ↔ Runner 消息的 JSON Schema，以及生成的 Swift / TS 类型 |
| `docs` | 架构、兼容矩阵、适配器说明 |

## 4. 硬性约束

1. **SSH clone**：所有仓库一律使用 SSH 地址 clone，例如 `git@github.com:Yidada/chatty.git`。
2. **协议先行**：iOS ↔ Runner 协议的任何改动，必须先改 `packages/protocol/schema`，再重新生成两端类型。禁止手改生成文件。
3. **iOS 不含 Agent 逻辑**：iOS 只负责界面和状态展示。新增一个 Harness 时，iOS 端代码零改动。
4. **Adapter 统一**：新增 Harness 只需实现 `HarnessAdapter` 接口并在 `packages/runner/config/harnesses.json` 登记。
5. **测试**：Runner 核心逻辑（Adapter、会话状态机、摘要迁移）必须有单元测试。
6. **小 PR**：每个里程碑拆成小 PR。每个 PR 附带测试和一段中文说明（做了什么、为什么、怎么验证）。
7. **语言**：文档和注释用中文，代码标识符用英文。
8. **版本锁定**：ACP 适配器和 SDK 一律锁定精确版本。升级适配器需要单独 PR，并附带握手测试结果。
9. **运行身份**：Runner 不能以 root 运行（Claude Code 适配器在 root 下会拒绝启动，详见 `docs/harness-adapters.md`）。

## 5. 常用命令

> M1 开始编码后补全。以下为规划。

```bash
# 安装依赖（仓库根目录）
npm install

# 生成协议类型
npm run gen -w @chatty/protocol

# Runner
npm run test -w @chatty/runner
npm run dev  -w @chatty/runner

# iOS（在 apps/ios 下）
xcodebuild test -scheme Chatty -destination 'platform=iOS Simulator,name=iPhone 16'
```

## 6. 代码风格

- TypeScript：`strict: true`，ESM，禁止 `any`（确需时加注释说明原因）。
- Swift：Swift 6 语言模式，开启严格并发检查。视图状态用 `@Observable`，网络层用 `actor`。
- 不引入重型第三方框架。引入任何新依赖前，在 PR 说明里写清理由。

## 7. 第一阶段不做

- 多 Runner 管理
- DSH 和 Codex 接入（第二阶段）
- APNs 远程推送（MVP 只在 App 前台时显示通知）
- 看板、任务分派、多 Agent 协作
- 账号体系和云端同步
