# Intent: Chatty

- **Author:** Benjamin Zhang
- **Status:** Draft — awaiting product-owner acceptance
- **Stage:** 1 of 6 — Plan
- **Last updated:** 2026-08-31
- **Source of truth:** This file and its Git history

## Originator's intent

我长期、深度使用豆包、飞书、Buzz、Multica、ChatGPT 和 Codex。它们分别解决了表达、工作能力、Agent 协作、跨环境执行和 AI 过程展示的一部分问题，但这些能力仍然分散，缺少一个真正属于我、符合我日常习惯的统一入口。

我最深的产品体验判断是：

> **Buzz + Multica + 豆包式长按语音输入，是一个非常好的组合。**

Chatty 希望把这个组合变成完整产品：

> **用户开口表达意图，Main Agent 在 AI-native IM 中组织协作，Agent 在合适的 Runtime 上持续完成工作。**

可以将它压缩为一条核心链路：

> **Voice → Conversation → Execution**

## Problem

今天，从一个自然产生的想法到可靠执行，中间存在四类断裂。

### 1. Expression is separate from execution

手机上的 AI 产品已经可以让用户轻松说出需求。豆包的长按输入框、实时语音转文字和可编辑文本体验尤其自然，但表达结束后，任务通常停留在单个 AI 会话中，无法可靠调度其他 Agent、设备和权限环境。

### 2. Human attention needs a default focus

Buzz 已经把 Human 与 Agent 放进同一个通信空间，Agent 拥有身份、消息和活动记录。这种团队协作空间本身成立，Chatty 也完整保留团队协作。

当多个 Human、Agent 和 WorkItem 同时活跃时，人的注意力会成为整个系统最稀缺的资源。Chatty 需要一个与用户保持默认关系的 Main Agent，持续聚合、过滤、排序和压缩团队信息，只把需要人类判断的事项带到用户面前。

### 3. Execution environments are fragmented

用户可调用的能力分散在不同设备、网络、目录、账号与权限中：

- Work Mac 拥有公司网络、内部仓库、工作账号和 `larkcli`；
- Home Mac mini 拥有个人文件、家庭设备和本地开发环境；
- Cloud Server 适合公网服务、定时任务和长时间运行；
- Raspberry Pi 连接家庭局域网、传感器和 IoT；
- Windows PC 可能拥有 GPU、Windows 软件或特定工具。

Multica 最重要的价值，是通过 Daemon 将这些环境组织成可发现、可调度、可持续执行的 Runtime Fleet。

### 4. Work tools and AI conversation live in different products

飞书通过 `larkcli` 可以调度消息、文档、任务、日程等完整工作能力，这是 Chatty 需要的能力入口。飞书的日常 AI 对话体验和 Agent 一级形态仍有明显空位。

## Proposed outcome

构建一个属于个人的 AI-native IM：

- 用户打开 App 后直接进入 Main Agent；
- 用户通过文字、长按语音转文字、图片或文件表达意图；
- Main Agent 理解上下文，自己处理或委派给其他 Agent；
- Agent 在权限允许的 Runtime 上调用合适的 Harness；
- 任务离开 App 后继续执行，可暂停、恢复和跨 Session 延续；
- 进度、询问、审批、证据与结果回到原始对话；
- Runtime 保留各自的文件、网络、工具、设备、账号和凭证边界；
- 飞书等外部系统通过 Runtime 上的工具进入 Chatty。

最终用户感受到的是一次自然对话，后台可以完成 Agent 选择、Runtime 路由、Harness Session、持续执行、Artifact 生成和 Approval Gate。

## Target user

### Initial user

第一阶段只服务一个深度使用 AI 与多台设备的个人用户：项目发起者本人。

这个用户同时具有：

- 工作与生活两类高频请求；
- 多台持续在线或间歇在线的计算设备；
- Codex、Claude Code、OpenCode、Pi 等多个 Agent Harness；
- 不同环境中的独立权限与凭证；
- 随时产生、希望立即捕获的想法；
- 通过手机发起任务，并在后台持续执行的需求。

### Future users

在核心闭环得到验证后，Chatty 可以逐步支持家人、朋友和同事加入。数据模型从第一天支持多个 Human，V1 交互仍聚焦“一个 Human + 多个 Agent”。

## Product thesis

> **Chatty turns spoken intent into persistent work across your agents and runtimes.**

中文表达：

> **开口说一句，让工作在你的所有 Agent 和 Runtime 中持续发生。**

所有产品选择都应强化至少一项能力：

1. 更容易表达意图；
2. 更清楚地与 Agent 协作；
3. 更可靠地跨 Runtime 执行；
4. 更安全地控制权限；
5. 更自然地将结果带回对话。

## Core experience

一个代表性的完整流程：

1. 用户长按输入框说：“让家里 Mac mini 上的开发 Agent 看一下 Chatty，按照 intent 生成第一版技术方案。”
2. 语音实时转成文字，并允许用户编辑后发送。
3. Main Agent 结合长期上下文理解意图。
4. Main Agent 创建持续运行的 WorkItem，并委派给开发 Agent。
5. 开发 Agent 选择 Codex Harness 与 Home Mac mini Runtime。
6. Runtime Daemon 启动或恢复 Harness Session。
7. 用户离开 App，任务继续运行。
8. 原对话中显示轻量状态：
   - 已委派给开发 Agent；
   - Codex · Home Mac mini · Running；
   - 已生成 `spec.md` · 等待确认。
9. 用户在需要判断时通过消息或 Approval Card 继续推进。
10. 完成状态附带 Artifact、测试、日志、截图或链接等 Evidence。

## Core concept decisions

### Participant

Human 与 Agent 都是 IM 中的一级 `Participant`，共享消息、Thread、Channel、Inbox、Profile、在线状态、任务与权限模型。

`participant_type: human | agent` 用于表达类型差异。产品层级与协作能力保持对等，具体差异来自角色、权限与能力声明。

### Agent

Agent 是稳定身份与执行能力的聚合：

`Agent = Identity + HarnessProfile + RuntimeScope`

- **Identity:** 名称、头像、角色、记忆、权限和长期关系；
- **HarnessProfile:** 允许使用的 Harness、模型与参数；
- **RuntimeScope:** 允许调用的 Runtime 集合与路由策略。

每次具体执行解析为：

`AgentExecution = HarnessBinding + RuntimeBinding`

### Harness

Harness 是运行 Agent 循环的执行框架，例如：

- Pi
- OpenCode
- Codex
- Claude Code

Harness 负责 Session、模型循环、工具调用和事件输出。Harness 与 Runtime 必须作为独立概念建模。

### Runtime

Runtime 是任何运行 Chatty Daemon 的执行端点。它同时代表：

- 一个计算环境；
- 一个文件与网络环境；
- 一组本地工具和设备能力；
- 一组凭证和权限边界；
- 一个可以启动或恢复 Harness Session 的位置。

### Runtime Fleet

Runtime Fleet 是用户全部可调用 Runtime 的集合，也是 Chatty 的执行网络。每个 Runtime 持续上报身份、在线状态、负载、Harness 与能力声明。

### Daemon

Daemon 连接 Runtime 与 Chatty Control Plane，负责注册、心跳、能力发现、任务领取、Session 生命周期、事件同步、断线恢复和本地策略执行。

### Main Agent

Main Agent 是用户默认交流的 Agent，也是用户与整个协作网络之间的 Attention Interface。预计 90% 的用户交互直接发生在这里。

Main Agent 的最高职责是管理用户注意力，任务路由与团队协调服务于这一目标。它负责：

- 理解用户意图与长期偏好；
- 判断直接处理或委派；
- 选择目标 Agent；
- 协调 Agent、Harness 与 Runtime；
- 聚合所有 Agent、WorkItem 和 Runtime 的状态；
- 过滤低价值更新，合并重复信息；
- 根据紧急度、影响范围和用户偏好排序；
- 将复杂进展压缩为用户可以快速判断的摘要；
- 在 Gate 到来时提供上下文、选项、建议与风险；
- 只在需要用户判断、授权或处理异常时打扰用户。

Main Agent 使用普通 Agent 数据模型，其特殊性来自默认关系、协调职责与注意力托管职责。用户依然可以直接进入其他 Agent 的 DM，也可以选择绕过 Main Agent 参与具体协作。

### WorkItem, Artifact, Gate and Evidence

- **WorkItem:** 一次需要持续推进、可暂停与恢复的工作；
- **Artifact:** 在 Human、Agent、Harness 和 Runtime 之间传递的可审阅结果；
- **Gate:** 控制下一阶段的 `allow`、`ask` 或 `block` 决策点；
- **Evidence:** 支撑完成状态的测试、日志、截图、链接、消息 ID 或其他验证记录。

对话负责探索、协调和补充上下文；Artifact 负责跨阶段传递确定状态。

## Interaction principles

### AI-native composer

- 打开 App 后默认进入 Main Agent；
- 长按输入框开始语音转文字；
- 转写过程实时可见；
- 转写结果可继续编辑与补充；
- 最终以可搜索、可引用的文字消息进入上下文；
- 文字、图片、文件与语音共享同一个自然输入入口。

### Progressive disclosure

日常对话只显示当前最重要的信息。任务详情按需展开：

> 开发 Agent · Codex · Home Mac mini · Running

点击后才展示 WorkItem、Harness、Runtime、Session、事件流、Artifact、Evidence 和历史状态。

### Conversation as the home of work

所有结构化工作都可以从对话中产生，并最终回到对话中：

- 普通交流显示为消息；
- 持续执行显示为状态卡；
- 关键选择显示为 Decision Card；
- 敏感操作显示为 Approval Card；
- 结果显示为文档、代码、表格、图片或可交互产物。

### Human attention at gates

系统应让 Agent 尽可能持续推进，把 Human 的注意力集中在目标校准、关键取舍、敏感操作、异常处理和最终接受上。

## Lark as a capability provider

飞书通过 `larkcli` 向 Chatty 提供工作能力：

`Main Agent → Target Agent → Harness → larkcli → Lark`

`larkcli` 安装并认证在具体 Runtime，例如 Work Mac。相关凭证保留在该 Runtime 中。本地策略决定每项操作是自动允许、请求批准或阻断。

Chatty 保留独立的 AI-native IM 体验，同时调用飞书已有的消息、文档、任务与日程能力。

## Product inspirations and boundaries

| Source | What Chatty carries forward |
| --- | --- |
| 豆包 | 面向 AI 的手机交互、自然对话、长按语音转文字 |
| Buzz | Human/Agent 一级身份、消息空间、Activity 与协作关系 |
| Multica | Daemon、Runtime Fleet、跨设备与跨权限持续执行 |
| ChatGPT / Codex | AI 过程、工具调用、状态、Artifact 与结果展示 |
| 飞书 / `larkcli` | 可被 Agent 调度的完整工作能力 |
| Anthropic AI-native SDLC | Intent、Artifact、Human Gate 与可审计闭环 |

Chatty 的独特产品中心是：个人与 Main Agent 的长期关系、以人的注意力为核心的协作拓扑，以及从自然表达跨越多个 Runtime 持续执行的完整体验。

## Initial scope

Stage 1 当前提出的首期范围：

- 单个 Human；
- 一个默认 Main Agent；
- 多个拥有独立身份的 Agent；
- Agent 可被直接对话，也可被 Main Agent 委派；
- Harness 与 Runtime 独立配置；
- 至少两个 Harness 的统一 Session 与事件抽象；
- 多 Runtime 注册、心跳、能力发现、任务调度与恢复；
- 手机优先的文字、图片、文件和长按语音转文字；
- 对话内的 WorkItem 状态、Decision、Approval、Artifact 与 Evidence；
- 通过 Work Runtime 上的 `larkcli` 调度至少一项真实飞书能力；
- Runtime 本地执行 `allow / ask / block` 策略。

## Out of scope for the first release

- 完整的多人社交网络；
- 企业组织架构、复杂成员管理和计费；
- 替代飞书现有的文档、日程与任务系统；
- 自研基础模型或完整复刻各类 Harness；
- 默认自动执行高风险、不可逆或跨权限边界的操作；
- 同时覆盖所有桌面与移动平台；
- 在首个可用闭环前建设完整 Project、Issue 或 Board 管理产品。

## Constraints

- Human 与 Agent 的 Participant 模型从第一天保持对等；
- Harness 与 Runtime 必须独立建模；
- 凭证和敏感数据默认保留在目标 Runtime；
- Runtime 本地策略拥有最终阻断权；
- 任务需要支持离线、重连和 Session 恢复；
- Main Agent 是默认入口，底层复杂度逐步展开；
- Voice 是输入方式，转写文字进入可搜索上下文；
- Git 中的 Artifact 构成产品设计与实现决策的审计记录；
- 首版优先验证个人高频使用价值，控制平台范围。

## Success criteria

首个可用闭环需要证明：

1. 用户可以通过一次长按语音输入创建明确请求，并在发送前编辑转写文本；
2. 用户无需先配置 Project、Issue 或 Board，就能从 Main Agent 对话发起持续任务；
3. Main Agent 可以将任务委派给另一个 Agent；
4. Agent 可以在权限允许的 Runtime 上选择并启动 Harness Session；
5. 用户离开客户端后任务继续运行，重连后状态与事件保持连续；
6. 进度、需要确认的问题和最终结果都回到原始对话；
7. 完成状态至少包含一种可验证 Evidence；
8. Work Runtime 可以通过 `larkcli` 完成一项经过策略检查的真实工作操作；
9. Runtime 凭证不会传入 Chatty Control Plane 或其他 Runtime；
10. 用户愿意把 Chatty 作为日常调用个人 Agent 的默认入口持续使用。

第 10 项需要在首个 Dogfood 周期中通过真实使用频率、Main Agent 入口占比、任务完成率和用户主动回访进行验证。

## Open questions

1. 一个用户拥有全局 Main Agent，还是 Work / Life 各自拥有 Main Agent？
2. 一个 Agent 固定绑定 Harness 与 Runtime，还是在允许集合中动态路由？
3. WorkItem 在什么条件下从普通对话中自动产生？
4. Runtime 发现、身份验证、加密连接和撤销机制采用什么协议？
5. Daemon 与 Multica 的关系是直接复用、兼容协议、扩展，还是独立实现？
6. Buzz 的事件、Agent 身份或 Activity 模型可以复用到什么粒度？
7. Harness 之间需要统一哪些 Session、Tool Call、Permission 与 Artifact 事件？
8. Main Agent 的长期记忆如何分隔 Work、Life 与具体 Runtime？
9. 长按语音的转写服务、隐私边界、流式协议和离线能力如何选择？
10. 移动端、Control Plane、Daemon 和 Harness Adapter 的首期技术栈如何确定？
11. 哪些操作可以 `allow`，哪些必须 `ask`，哪些始终 `block`？
12. Chatty Control Plane 的托管、自托管与数据所有权边界如何设计？

这些问题允许保留到 Stage 2，但会实质改变首期架构或体验的问题需要在 `spec.md` 中明确决策。

## Acceptance gate

本 Intent 进入 Stage 2 — Design 前，需要由产品发起者确认：

- 问题描述准确反映原始体验；
- Product thesis 可以指导产品取舍；
- 核心概念定义没有混淆 Agent、Harness、Runtime 与 Daemon；
- Main Agent 的默认关系得到确认；
- 首期范围足以验证 Voice → Conversation → Execution；
- Out of scope 可以控制第一版规模；
- Open questions 已标记为 Stage 2 决策或后续假设。

接受后，下一项 Artifact 是 `spec.md`。它将定义产品需求、核心流程、信息架构、事件模型、权限模型、系统边界、首期 UX 与技术设计。

## References

- [Chatty README](./README.md)
- [Buzz](https://github.com/block/buzz)
- [Multica](https://www.multica.ai/)
- [The AI-Native SDLC Playbook](https://claude.com/blog/the-ai-native-sdlc-playbook)
