# Harness × Model 兼容矩阵（初稿）

- 数据文件：`packages/runner/config/harnesses.json`（以它为准，本文档只做说明）
- 查证日期：2026-09-25

## 1. 规则

1. 用户选择 Harness 后，iOS 只展示该 Harness 支持的模型。
2. iOS 不内置任何矩阵数据。矩阵由 Runner 通过 `harness.list` 下发。新增 Harness 或模型时 iOS 零改动。
3. 矩阵由两部分合并得到：
   - **静态推荐列表**：写在 `harnesses.json` 里，人工维护，决定默认展示哪些模型、显示什么名字。
   - **运行时发现**：Runner 启动 Harness 并创建会话后，从 ACP `configOptions`（`category = "model"`）读取实际可选值。
4. 合并策略：

| 情况 | 展示方式 |
| --- | --- |
| 静态列表有，运行时也有 | 正常展示，状态 `available` |
| 静态列表有，运行时没有 | 置灰，状态 `unavailable`，提示可能未登录或账号无权限 |
| 静态列表没有，运行时有 | 仅当该 Harness 配置了 `discover: true` 时，放在“更多模型”分组里 |
| 运行时发现尚未执行 | 按静态列表展示，状态 `unknown` |

5. 每个模型条目有两个 ID：
   - `nativeId`：传给 Harness 的原始值（写入 `session/set_config_option`）。
   - `modelRef`：跨 Harness 的规范名（例如 `anthropic/claude-sonnet-5`）。用于切换 Harness 时自动匹配“同一个模型”。可以为空。

## 2. 状态图例

| 标记 | 含义 |
| --- | --- |
| ✅ | 本次握手在 `configOptions` 中实际看到 |
| 🔑 | 实际看到，但依赖主机上配置了对应 Provider 或账号权限 |
| ❓ | 未实测，来自文档或推断，M1/M4 需要验证 |

## 3. 矩阵

### 3.1 Claude Code（`claude-code`）

| nativeId | 显示名 | modelRef | 状态 | 备注 |
| --- | --- | --- | --- | --- |
| `default` | 默认（推荐） | — | ✅ | 实测时指向 Sonnet |
| `sonnet` | Sonnet 5 | `anthropic/claude-sonnet-5` | ✅ | 静态默认项 |
| `opus` | Opus 5.5 | `anthropic/claude-opus-5.5` | ✅ | |
| `claude-fable-5-1` | Fable 5.1 | `anthropic/claude-fable-5.1` | ✅ | 实测描述为“需要 usage credits” |
| `haiku` | Haiku 4.5 | `anthropic/claude-haiku-4.5` | ✅ | |

说明：`sonnet`、`opus`、`haiku` 是别名，会随 Claude Code 版本指向新模型。显示名以运行时 `configOptions` 返回的 `name` 为准。

附加配置项：思考强度 `effort`（`default` / `low` / `medium` / `high` / `xhigh` / `max`）。MVP 不在界面上暴露，保持 `default`。

### 3.2 OpenCode（`opencode`）

`discover: true`。实测环境返回 197 个模型，完整列表取决于主机上 `opencode auth login` 配置的 Provider。静态推荐列表只放以下几项：

| nativeId | 显示名 | modelRef | 状态 | 备注 |
| --- | --- | --- | --- | --- |
| `opencode/big-pickle` | OpenCode Zen / Big Pickle | — | ✅ | 实测默认值，免费 |
| `github-copilot/claude-sonnet-5` | Claude Sonnet 5（Copilot） | `anthropic/claude-sonnet-5` | 🔑 | 需要 GitHub Copilot 登录 |
| `github-copilot/claude-opus-5` | Claude Opus 5（Copilot） | `anthropic/claude-opus-5` | 🔑 | 同上 |
| `github-copilot/gpt-5.5` | GPT-5.5（Copilot） | `openai/gpt-5.5` | 🔑 | 同上 |
| `amazon-bedrock/anthropic.claude-fable-5-1` | Claude Fable 5.1（Bedrock） | `anthropic/claude-fable-5.1` | 🔑 | 需要 AWS 凭据 |

M1 待办：在配置了 Anthropic 和 OpenAI 直连 Provider 的主机上重新实测，补充 `anthropic/*`、`openai/*` 的 nativeId。

### 3.3 Codex（`codex`，第二阶段）

| nativeId | 显示名 | modelRef | 状态 | 备注 |
| --- | --- | --- | --- | --- |
| （待实测） | — | — | ❓ | `session/new` 需要登录，本次未拿到模型列表。M4 登录后实测填写 |

### 3.4 DSH（`dsh`，第二阶段）

| nativeId | 显示名 | modelRef | 状态 | 备注 |
| --- | --- | --- | --- | --- |
| （待实测） | — | — | ❓ | DSH 内置 Provider 目录覆盖 Anthropic、OpenAI、Bedrock、Azure、Vertex，并支持自定义 Provider。M4 评估 `@deepseek-ai/dsh-acp` 后填写 |

## 4. 跨 Harness 的同模型对照

切换 Harness 时，Runner 用 `modelRef` 自动预选“同一个模型”。找不到时使用目标 Harness 的默认模型，并在界面提示。

| modelRef | Claude Code | OpenCode |
| --- | --- | --- |
| `anthropic/claude-sonnet-5` | `sonnet` | `github-copilot/claude-sonnet-5` 🔑 |
| `anthropic/claude-fable-5.1` | `claude-fable-5-1` | `amazon-bedrock/anthropic.claude-fable-5-1` 🔑 |
| `anthropic/claude-opus-5.5` | `opus` | ❓（直连 Provider 待实测） |
| `anthropic/claude-haiku-4.5` | `haiku` | ❓ |

## 5. 如何扩展

新增模型：在 `harnesses.json` 对应 Harness 的 `models` 数组里加一条，提 PR。

新增 Harness：在 `harnesses.json` 的 `harnesses` 数组里加一条（启动方式、模型选择方式、模型列表），再在 `packages/runner/src/harness/<harnessId>/` 下实现 Adapter（纯 ACP Harness 通常只需几十行，见 `docs/architecture.md` 第 4 节）。
