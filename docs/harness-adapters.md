# Harness 适配器调研

- 查证日期：2026-09-25
- 查证环境：Linux x64，Node.js 22.22.2，npm 10.9.7
- 查证方法：
  1. `npm view` 查询包名、版本、bin、依赖、废弃标记。
  2. 读取 ACP 官方 Registry 的条目（`github.com/agentclientprotocol/registry/<id>/agent.json`）。
  3. 本地实际启动每个适配器，发送 ACP `initialize` 和 `session/new`，记录真实返回。

> 所有版本号都会快速变化（Claude 适配器几乎每天发版）。M1 编码前以 `npm view` 的结果为准，并更新本文件。

## 1. 结论速览

| Harness | 接入方式 | 包 / 命令 | 查证版本 | 启动命令 | 许可 | 计划阶段 |
| --- | --- | --- | --- | --- | --- | --- |
| Claude Code | ACP 适配器，基于 Claude Agent SDK | `@agentclientprotocol/claude-agent-acp`（bin：`claude-agent-acp`） | 0.81.2 | `npx -y @agentclientprotocol/claude-agent-acp@0.81.2` | Registry 标注为 proprietary | M1 |
| OpenCode | CLI 原生子命令 | `opencode-ai`（bin：`opencode`） | 1.18.32 | `opencode acp --cwd <dir>` | MIT | M1 |
| Codex | ACP 适配器，包装 Codex App Server | `@agentclientprotocol/codex-acp`（bin：`codex-acp`） | 1.13.1 | `npx -y @agentclientprotocol/codex-acp@1.13.1` | Apache-2.0 | M4 |
| DSH | 官方预发布 ACP server | `@deepseek-ai/dsh-acp` | 0.0.1-rc.1 | 未验证 | 未确认 | M4（第一阶段只预留接口） |

ACP SDK：

| 项 | 值 |
| --- | --- |
| 包名 | `@agentclientprotocol/sdk` |
| 查证版本 | 1.5.0 |
| 协议版本 | `PROTOCOL_VERSION = 1`（稳定版） |
| ACP v2 | 草案，仅在 `@agentclientprotocol/sdk/experimental/v2` 暴露。本项目不使用 |
| peer 依赖 | `zod ^3.25.0 \|\| ^4.0.0` |
| 客户端 API 形态 | `acp.client({ name }).onRequest(...).connectWith(stream, async (ctx) => ...)`，传输层用 `acp.ndJsonStream(stdin, stdout)` |

## 2. 已废弃的包名（禁止使用）

网上很多教程仍在用旧包名。以下包都已在 npm 上标记 deprecated：

| 旧包名 | 最后版本 | 替代 |
| --- | --- | --- |
| `@zed-industries/agent-client-protocol` | 0.4.5 | `@agentclientprotocol/sdk` |
| `@zed-industries/claude-code-acp` | 0.16.2 | `@agentclientprotocol/claude-agent-acp` |
| `@zed-industries/claude-agent-acp` | 0.23.1 | `@agentclientprotocol/claude-agent-acp` |
| `@zed-industries/codex-acp` | 0.16.0 | `@agentclientprotocol/codex-acp` |

## 3. 握手实测结果

请求参数：`protocolVersion: 1`，客户端声明 `fs.readTextFile`、`fs.writeTextFile`、`terminal`。

### 3.1 `initialize` 返回的能力

| 能力 | Claude Code | OpenCode | Codex |
| --- | --- | --- | --- |
| protocolVersion | 1 | 1 | 1 |
| `loadSession` | ✅ | ✅ | ✅ |
| `sessionCapabilities.resume` | ✅ | ✅ | ✅ |
| `sessionCapabilities.list` | ✅ | ✅ | ✅ |
| `sessionCapabilities.fork` | ✅ | ✅ | ✅ |
| `sessionCapabilities.close` | ✅ | ✅ | ✅ |
| `sessionCapabilities.delete` | ✅ | ❌ | ✅ |
| `sessionCapabilities.additionalDirectories` | ✅ | ❌ | ✅ |
| 图片输入 | ✅ | ✅ | ✅ |
| embeddedContext | ✅ | ✅ | ✅ |
| MCP over HTTP | ✅ | ✅ | ✅ |
| MCP over SSE | ✅ | ✅ | ❌ |
| `authMethods` | 空数组。未登录时额外发送通知 `_auth/status_update`，内容为 `Not logged in` | `opencode-login`：提示在终端执行 `opencode auth login` | `api-key`（设置 `NO_BROWSER=1` 后隐藏 ChatGPT 浏览器登录） |

### 3.2 `session/new` 结果

| 项 | Claude Code | OpenCode | Codex |
| --- | --- | --- | --- |
| 无凭据时 | 用占位 API Key 可以创建成功（推断凭据在 prompt 阶段才校验） | 创建成功 | 返回错误 `-32000 Authentication required` |
| 模型选择 | `configOptions` 中 `id=model`，`category=model` | `configOptions` 中 `id=model`，`category=model` | 未实测（需要登录） |
| 模式 | `id=mode`：`default`（Manual）、`acceptEdits`、`plan`、`auto`、`bypassPermissions` | `id=mode`：`build`、`plan` | 环境变量 `INITIAL_AGENT_MODE`：`read-only`、`agent`、`agent-full-access` |
| 思考强度 | `id=effort`，`category=thought_level`：`default`、`low`、`medium`、`high`、`xhigh`、`max` | 无 | 文档称支持 reasoning effort，未实测 |

结论：三个 Harness 都通过 ACP 标准的 `configOptions` + `session/set_config_option` 切换模型和模式。Runner 统一走这条路径，不需要为每个 Harness 写专属的模型切换逻辑。

## 4. 各 Harness 细节

### 4.1 Claude Code

- **包**：`@agentclientprotocol/claude-agent-acp@0.81.2`
  - 依赖 `@anthropic-ai/claude-agent-sdk 0.3.280`、`@agentclientprotocol/sdk 1.5.0`、`zod 4.6.5`
  - `engines.node >= 22`
- **启动**：`npx -y @agentclientprotocol/claude-agent-acp@0.81.2`，或作为 Runner 的依赖安装后用 `node <bin 路径>` 启动。
- **认证**（在 Runner 所在主机上完成）：
  - 订阅账号：在主机上运行 `claude` 并登录。
  - API Key：环境变量 `ANTHROPIC_API_KEY`。
  - 云厂商：`CLAUDE_CODE_USE_BEDROCK` / `CLAUDE_CODE_USE_VERTEX`，以及 `ANTHROPIC_BASE_URL`。
- **有用的环境变量**：
  - `CLAUDE_CODE_EXECUTABLE`：指定使用哪个 `claude` 可执行文件。
  - `CLAUDE_CONFIG_DIR`：配置目录。
  - `ANTHROPIC_MODEL`：默认模型。
  - `CLAUDE_AGENT_LOGS`：适配器日志目录。
- **已知坑**：
  - 以 root 运行时，`session/new` 失败，报错 `--dangerously-skip-permissions cannot be used with root/sudo privileges`。**Runner 必须以普通用户运行。**
  - 发版极频繁（0.x 版本），必须锁定精确版本。
- **非标准扩展**（MVP 不依赖）：`_meta.claudeCode.promptQueueing`、steering、`_session/goal`、JetBrains AIR 能力（子 Agent 会话、文件改动报告等）。

### 4.2 OpenCode

- **包**：`opencode-ai@1.18.32`（bin 名为 `opencode`）。源码仓库已迁到 `github.com/anomalyco/opencode`。
- **启动**：`opencode acp`，可用参数：

| 参数 | 默认值 | 说明 |
| --- | --- | --- |
| `--cwd` | 进程当前目录 | 工作目录。Runner 必须显式传入 Session 的 worktree 路径 |
| `--port` | 0 | 内部 server 端口 |
| `--hostname` | 127.0.0.1 | 内部 server 监听地址 |
| `--pure` | false | 不加载外部插件 |
| `--log-level` | — | DEBUG / INFO / WARN / ERROR |
| `--print-logs` | false | 日志打到 stderr |

- **认证**：在主机上执行 `opencode auth login` 配置 Provider。
- **模型**：
  - 模型 ID 格式为 `provider/model`。
  - 可选列表取决于主机上配置了哪些 Provider。实测返回 197 个选项，默认值 `opencode/big-pickle`（OpenCode Zen 免费模型）。
  - 因此 OpenCode 的模型列表必须在运行时发现，静态矩阵只放推荐项。
- **Registry 分发方式**：按平台下载二进制压缩包（darwin-aarch64、darwin-x86_64、linux-aarch64、linux-x86_64 等），执行 `./opencode acp`。

### 4.3 Codex（第二阶段）

- **包**：`@agentclientprotocol/codex-acp@1.13.1`，内置依赖 `@openai/codex ^0.156.1`。
- **启动**：`npx -y @agentclientprotocol/codex-acp@1.13.1`。需要换 Codex 可执行文件时设置 `CODEX_PATH`。
- **认证**：
  - ChatGPT 浏览器登录。远程主机上应设置 `NO_BROWSER=1` 隐藏此方式。
  - API Key：`CODEX_API_KEY`（优先）或 `OPENAI_API_KEY`。
  - 自定义 OpenAI 兼容网关（客户端需声明能力）。
- **其他环境变量**：`CODEX_CONFIG`（合并进会话配置的 JSON）、`MODEL_PROVIDER`、`INITIAL_AGENT_MODE`、`APP_SERVER_LOGS`。
- **待验证**：主机上 `codex login` 后的凭据能否被适配器复用。

### 4.4 DSH（DeepSeek Harness，第二阶段）

需求文档写的是“DSH 暂无 ACP 支持”。查证结果与此略有出入：

- DSH 官方已经发布了**预发布版** ACP server：
  - `@deepseek-ai/dsh-acp@0.0.1-rc.1`，描述为 “Automation-only Agent Client Protocol server for driving DeepSeek Harness agents over JSON-RPC stdio”，2026-09-24 更新。
  - `@deepseek-ai/dsh-acp-app@0.1.2-alpha.2`，描述为 “The dsh ACP profile bundle”。
- DSH CLI 本体：`@deepseek-ai/dsh`，latest 为 `0.1.5-rc.3`，bin 为 `dsh`。
- DSH **尚未**进入 ACP 官方 Registry。
- 所有相关包都处在 rc / alpha 阶段，接口随时可能变化。

建议：

1. 第一阶段维持原计划，只预留 Adapter 接口，不实现。
2. M4 开工时，先评估 `@deepseek-ai/dsh-acp` 是否稳定。如果稳定，DSH 可以直接复用通用 ACP Adapter，工作量会远小于自研适配。

### 4.5 附带发现

ACP Registry 还收录了 Gemini CLI（`@google/gemini-cli`，查证版本 0.61.0）。这说明 Registry 可以作为后续新增 Harness 的来源，Runner 的 Harness 配置格式应该和 Registry 的 `distribution` 字段保持兼容（见 `docs/architecture.md` 第 4 节）。

## 5. 对 Runner 设计的影响

| 发现 | 设计决定 |
| --- | --- |
| 三个 Harness 都用 `configOptions` 暴露模型和模式 | 模型切换统一走 `session/set_config_option`，Adapter 只需声明 option id |
| OpenCode 的模型列表依赖主机配置 | 兼容矩阵 = 静态推荐列表 + 运行时发现结果，两者合并后下发给 iOS |
| 三个 Harness 都支持 `loadSession` / `resume` | Runner 重启后优先恢复 Harness 会话。恢复失败时退回“摘要重建”路径，与切换 Harness 复用同一套逻辑 |
| 认证状态各不相同 | Runner 在 `harness.list` 里上报每个 Harness 的安装状态和登录状态。MVP 阶段登录操作在主机终端完成 |
| Claude 适配器拒绝以 root 运行 | Runner 启动时检测 `uid === 0` 并直接报错退出 |
| 适配器发版极快 | 版本锁定在 `packages/runner/config/harnesses.json`，升级走单独 PR |
| `npx` 冷启动慢，且每次可能访问网络 | Claude 和 Codex 适配器作为 Runner 的 npm 依赖安装，Runner 用 `node <bin>` 直接启动。OpenCode 使用主机上已安装的 `opencode`，路径可配置 |

## 6. 复现方法

```bash
# 查询版本
npm view @agentclientprotocol/claude-agent-acp version
npm view @agentclientprotocol/codex-acp version
npm view opencode-ai version
npm view @agentclientprotocol/sdk version

# 查看 Registry 条目
curl -sS https://raw.githubusercontent.com/agentclientprotocol/registry/main/claude-acp/agent.json
curl -sS https://raw.githubusercontent.com/agentclientprotocol/registry/main/codex-acp/agent.json
curl -sS https://raw.githubusercontent.com/agentclientprotocol/registry/main/opencode/agent.json
```

握手脚本会在 M1 作为 `packages/runner/scripts/acp-probe.ts` 提交，并作为适配器升级 PR 的必跑检查。
