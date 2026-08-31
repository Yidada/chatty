# Chatty

> 一个以 Main Agent 管理人的注意力、以 Lark Context Layer 承载共享状态、以 Runtime Fleet 为执行网络的 AI-native 个人计算系统。

Chatty 希望提供一种真正属于个人的 AI 协作体验：像使用豆包一样自然地表达需求，通过与 Main Agent 的持续对话调度不同 Agent，并让这些 Agent 在分布于不同设备、权限和网络环境中的 Runtime 上可靠执行任务。

Chatty 参考 Multica 的 Runtime 与 Daemon 架构，也吸收豆包面向 AI 的交互体验。飞书的文档、多维表格、群聊、任务与日程共同构成 Context Layer；`larkcli` 是 Agent 对这层 Context 的读写接口。

## Why Chatty

现有产品分别解决了部分问题：

- 豆包拥有自然、低门槛、面向 AI 的日常交互体验，尤其适合手机端使用。
- ChatGPT 与 Codex 擅长呈现推理、工具调用、执行过程和最终产物。
- 飞书提供由文档、多维表格、群聊、任务与日程组成的 Context Layer，`larkcli` 让 Agent 可以读取和更新其中的共享状态。
- Buzz 让 Human 与 Agent 进入同一个通信空间。
- Multica 将分散在不同环境中的 Runtime 连接起来，并可靠调度本地 Agent Harness。

Chatty 将这些能力组织成一个以个人为中心的系统。用户无需持续守着 Terminal，也无需从 Project、Issue 或 Runtime 管理页面开始工作。任务可以从自然对话中产生，复杂状态沉淀到 Lark Context Layer，摘要、通知和关键 Gate 回到对话中。

## Core Principles

### 1. Chat is the primary interface

用户 90% 的时间直接与 Main Agent 对话。项目、任务、Agent、Harness、Runtime 和执行日志根据需要逐步展开。

对话承担低摩擦入口、注意力聚焦和关键 Gate：

- 普通交流显示为消息；
- 运行中的工作显示为任务状态卡；
- 高风险操作显示为审批卡；
- 文档、代码、表格、任务和日程以摘要、预览或可交互卡片进入对话。

### 2. Context Layer carries shared state

`Lark = Context Layer`。

复杂工作需要高信息密度、可扫描、可编辑、可执行的图形化载体。文档、多维表格、群聊、任务和日程将知识、数据、讨论、关系、责任、状态与时间外化为 Human 和 Agent 的实时共享 Context。

Context Layer 构成双方的共享外部记忆与持续工作状态。Human 可以浏览、筛选、比较和修改；Agent 可以读取 Schema、关系、参与者、任务和时间，并进行精确更新。Chatty 在对话中提供摘要、预览、操作入口和关键 Gate，完整状态保存在 Lark Context Layer。

### 3. Human and Agent are equal participants

Human 与 Agent 都是 IM 中的一级 `Participant`，共享相同的身份与协作模型。

两者都可以：

- 发送消息、创建 Thread、加入 Channel；
- @ 其他 Participant；
- 创建、接收、转派和完成任务；
- 主动发起对话和汇报进度；
- 拥有头像、Profile、Inbox、在线状态和权限；
- 作为消息作者、任务负责人和项目成员出现。

底层可以保留 `participant_type: human | agent`。Participant 层保持对等，差异由角色、权限与能力声明决定。

### 4. Main Agent is the attention interface

Main Agent 是用户默认交流的 Agent，也是用户与整个协作网络之间的 Attention Interface：

- 理解用户意图和长期偏好；
- 判断自己处理或委派给其他 Agent；
- 选择适合的 Agent；
- 聚合 Agent、WorkItem、Runtime 与 Context Layer 的状态；
- 过滤低价值更新并合并重复信息；
- 根据紧急度、影响和用户偏好排序；
- 将复杂进展压缩为可快速判断的摘要；
- 在 Gate 到来时提供上下文、选项、建议与风险；
- 保持连续、轻量、接近日常 IM 的交互体验。

Main Agent 使用普通 Agent 数据模型。它的特殊性来自默认关系、协调职责与注意力托管职责。其他 Agent 仍可被直接打开并进行 DM 对话。

### 5. Agent aggregates Harness and Runtime

Harness 与 Runtime 是两个独立概念。

从执行角度看：

`AgentExecution = HarnessBinding + RuntimeBinding`

从产品角度看：

`Agent = Identity + HarnessProfile + RuntimeScope`

- **Identity**：名称、头像、角色、记忆、权限和关系；
- **HarnessProfile**：使用的 Agent 执行框架、模型和参数；
- **RuntimeScope**：允许调用的 Runtime 集合及路由策略。

### 6. Runtime is an environment and permission boundary

Runtime 是任何运行 Chatty Daemon 的执行端点。它可以位于 Mac、Windows PC、Linux Server、Cloud VM 或 Raspberry Pi，也可以存在于不同网络与账号环境中。

每个 Runtime 负责：

- 注册身份和环境信息；
- 持续上报在线状态与负载；
- 声明已安装的 Harness；
- 声明可用工具、目录、网络、设备和凭证；
- 接收任务并启动或恢复 Harness Session；
- 流式回传 reasoning、message、tool call、tool result 和异常；
- 在断线或进程重启后恢复任务状态。

Runtime 同时定义权限边界。凭证和本地能力保留在对应环境中，不会因为 Main Agent 可以调度多个 Runtime 而被合并。

### 7. Runtime Fleet is the execution network

Chatty 将用户可以调用的所有 Runtime 组织成一个持续在线的 Runtime Fleet。

典型示例：

| Runtime | Environment and capabilities |
| --- | --- |
| Work Mac | 公司网络、内部仓库、工作账号、`larkcli` |
| Home Mac mini | 个人文件、家庭设备、本地模型 |
| Cloud Server | 公网服务、定时任务、长时间运行 |
| Raspberry Pi | 家庭局域网、传感器、IoT 控制 |
| Windows PC | Windows 软件、GPU、特定开发环境 |

Agent 可以拥有一个或多个允许使用的 Runtime。每项任务在权限范围内选择具体执行端点。

## Concept Model

```mermaid
flowchart TD
    P[Participant] --> H[Human]
    P --> A[Agent]
    A --> X[Harness Profile]
    A --> R[Runtime Scope]
    R --> D[Daemon Endpoint]
```

### Context Layer

Context Layer 是 Human、Main Agent 与其他 Agent 共同读取和写入的实时共享状态：

`Context Layer = Knowledge + Data + Conversation + Work State + Time + Relationships`

Chatty 首期以 Lark 作为 Context Layer 的 Source of Truth。文档、多维表格、群聊、任务和日程分别承载不同维度的 Context，`larkcli` 向 Agent 提供读写接口。

### Harness

Harness 是执行 Agent 循环的框架，例如：

- Pi
- OpenCode
- Codex
- Claude Code

Harness 负责 Session、模型循环、工具调用和事件输出。同一种 Harness 可以安装在多个 Runtime 中，并因为环境、网络、目录和凭证不同而拥有不同的有效能力。

### Runtime

Runtime 是由 Daemon 暴露的可调度执行环境。Runtime 管理本地 Harness、文件系统、工具、网络、凭证和设备能力。

### Agent

Agent 是一级 Participant，也是 Harness 与 Runtime 的执行聚合。Agent 拥有稳定身份和长期关系，并在其 `RuntimeScope` 内选择执行环境。

### Daemon

Daemon 是 Runtime 与 Chatty Control Plane 之间的连接层，负责能力发现、任务领取、Session 生命周期、事件同步、心跳和恢复。

## Execution Flow

```mermaid
flowchart TD
    U[Human] --> M[Main Agent]
    M --> A[Target Agent]
    A --> B[Harness + Runtime Binding]
    B --> D[Runtime Daemon]
    D --> E[Session Events and Artifacts]
    E --> M
```

典型链路：

1. Human 向 Main Agent 发送文字、语音转写、图片或文件；
2. Main Agent 理解意图并决定直接处理或委派；
3. 系统选择目标 Agent；
4. 目标 Agent 解析 Harness Profile 与允许的 Runtime；
5. 任务发送到对应 Runtime Daemon；
6. Daemon 启动或恢复本地 Harness Session；
7. 执行事件持续回传，并映射为 Chatty 消息或状态卡；
8. Main Agent 汇总结果，并在需要时请求用户决策。

## AI-native Interaction

Chatty 的整体交互以豆包式 AI 对话体验为主要参考。

### Main composer

- 打开应用后直接进入 Main Agent；
- 输入框默认支持文字；
- 长按输入框开始语音转文字；
- 转写结果进入文本输入框，可以继续补充和编辑；
- 语音承担输入方式，最终内容以可搜索、可编辑的文字消息进入上下文。

### Progressive disclosure

日常对话保持简洁。任务卡只展示最重要的信息，例如：

> 磁盘管家 · Codex · Home Mac mini · Running

用户点击后再查看 Agent、Harness、Runtime、执行日志、产物和历史状态。Lark Context 对象可以在对话中显示为摘要、预览或可交互卡片，并继续在飞书中编辑。

## Lark Context Layer

`Lark = Context Layer`

飞书通过不同对象保存持续变化的共享 Context：

| Context dimension | Lark primitive |
| --- | --- |
| Knowledge | 文档 |
| Structured data and relationships | 多维表格 |
| Conversation and participants | 群聊与 Thread |
| Ownership and work state | 任务 |
| Time and commitments | 日程 |

`larkcli = Context Read / Write Interface`。它让 Agent 可以在权限允许的 Runtime 上搜索、读取、创建、更新和连接这些 Context 对象。

输入链路：

`Voice / Chat → Main Agent → Read Context`

执行链路：

`Main Agent → Target Agent → Harness + Runtime → Read / Write Context via larkcli`

回流链路：

`Context Change / Artifact → Main Agent → Summary / Card / Gate → Human`

`larkcli` 安装并认证在具体 Runtime 上，例如 Work Mac。飞书凭证保留在该 Runtime 的权限边界内，Agent 只有在自身权限与 `RuntimeScope` 同时允许时才能使用相关能力。

Chatty 提供低摩擦交流和注意力管理；Lark Context Layer 提供高信息密度、持续更新、可编辑和可执行的共享状态。

## Initial Product Scope

第一阶段聚焦：

- 单个 Human；
- 一个默认 Main Agent；
- 多个可直接对话和被委派的 Agent；
- Harness 与 Runtime 独立配置；
- 多 Runtime 注册、心跳、能力发现和任务调度；
- 豆包式文字与长按语音转写交互；
- 对话内的任务状态、审批和结果展示；
- 通过 Runtime 中的 `larkcli` 读写 Lark Context 对象，并在对话中呈现摘要、预览和操作卡片。

Human 与 Agent 的统一 Participant 模型从第一天建立。多人邀请、群聊与组织协作可以在这一模型上逐步开放。

## Product Statement

> Chatty is a personal AI-native IM where humans and agents are equal participants, a Main Agent stewards human attention, Lark provides the shared context layer, and a fleet of permission-scoped runtimes executes work through interchangeable agent harnesses.

Chatty 让用户通过一次自然对话表达意图，在 Lark Context Layer 中沉淀共享状态，并调动分布在所有设备、环境和权限边界中的个人计算能力。

## Status

Chatty is currently in **Stage 1 — Plan** of the AI-native SDLC.

- Current artifact: [`intent.md`](./intent.md)
- Intent status: Draft — awaiting product-owner acceptance
- Next artifact after acceptance: `spec.md`

