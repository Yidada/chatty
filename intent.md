# Intent: Chatty

- **Author:** Benjamin Zhang
- **Status:** Draft — awaiting product-owner acceptance
- **Stage:** 1 of 6 — Plan
- **Last updated:** 2026-08-31
- **Source of truth:** This file and its Git history

## Originator's intent

我长期、深度使用豆包、飞书、Buzz、Multica、ChatGPT 和 Codex。它们分别解决了表达、共享 Context 与结构化工作流、Agent 协作、跨环境执行和 AI 过程展示的一部分问题，但这些能力仍然分散，缺少一个真正属于我、符合我日常习惯的统一入口。

我最深的产品体验判断是：

> **Buzz + Multica + 豆包式长按语音输入，是一个非常好的组合。**

Chatty 希望把这个组合变成完整产品：

> **用户开口表达意图，Main Agent 在 AI-native IM 中组织协作，Agent 在合适的 Runtime 上持续完成工作。**

可以将它压缩为一条核心链路：

> **Voice → Conversation → Context → Execution**

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

### 4. AI collaboration needs a shared Context Layer

长对话很难稳定承载复杂工作的全部共享状态。飞书背后的文档、多维表格、群聊、任务和日程共同构成 Chatty 的 Context Layer：

- **Knowledge Context:** 文档承载知识、决策与长内容；
- **Data Context:** 多维表格承载 Schema、记录、关系与视图；
- **Conversation Context:** 群聊与 Thread 承载参与者、讨论和事件；
- **Work Context:** 任务承载责任人、状态、优先级与依赖；
- **Temporal Context:** 日程承载时间、会议与承诺。

这些飞书原生对象提供高效率的结构化界面，同时也可以成为外部内容的索引载体。Context Layer 采用 index-first 模型：原始内容保留在各自的 Source of Truth，例如 GitHub、外部文档、本地文件、Runtime Session 或其他服务；Lark 保存可搜索的引用、元数据、摘要、关系、状态与权限范围。

`Lark = Context Index + Context Graph + Retrieval Routing + Native Work Objects`

它让 Human 和 Agent 能够发现“有哪些相关内容、位于哪里、彼此如何关联、由谁负责、何时更新，以及如何在权限允许时取回”。结构化与图形化表达减少重复说明，也降低理解、检索和审阅成本。

`larkcli` 是 Agent 查询和维护 Context Index 的接口。命中 Lark 原生对象时可以直接读取或更新；命中外部引用时，由 Source Resolver 路由到具备相应连接与权限的 Runtime 或工具读取原始内容。

## Proposed outcome

构建一个属于个人的 AI-native IM：

- 用户打开 App 后直接进入 Main Agent；
- 用户通过文字、长按语音转文字、图片或文件表达意图；
- Main Agent 理解上下文，自己处理或委派给其他 Agent；
- Agent 在权限允许的 Runtime 上调用合适的 Harness；
- 任务离开 App 后继续执行，可暂停、恢复和跨 Session 延续；
- 进度、询问、审批、证据与结果回到原始对话；
- Runtime 保留各自的文件、网络、工具、设备、账号和凭证边界；
- 飞书作为 Context Layer，索引用户有权访问的相关内容，并通过文档、多维表格、群聊、任务与日程提供原生工作对象；Agent 经由 `larkcli` 查询索引，再从对应 Source of Truth 读取或更新内容。

最终用户从一次自然对话开始；复杂工作状态沉淀为可视、可编辑、可操作的结构化 Artifact；后台完成 Agent 选择、Runtime 路由、Harness Session、持续执行和 Approval Gate。

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

> **Chatty turns spoken intent into structured, persistent work across your agents and runtimes.**

中文表达：

> **开口说一句，让意图进入共享 Context，并由你的 Agent 和 Runtime 持续推进。**

所有产品选择都应强化至少一项能力：

1. 更容易表达意图；
2. 更清楚地与 Agent 协作；
3. 更有效地用结构化与图形化 Artifact 承载复杂工作；
4. 更可靠地跨 Runtime 执行；
5. 更安全地控制权限；
6. 更自然地将结果带回对话。

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

### Context Spaces and isolation

**Decision:** 一个用户拥有一个全局 Main Agent 身份；Work 与 Life 是硬隔离的 Context Spaces。

- Main Agent 的名称、头像和关系身份保持全局一致；
- 每个 Conversation 必须绑定唯一的 `context_space_id`；
- Session、Memory、Context Index、Agent、WorkItem、Artifact、RuntimeScope、Tool 与 Credential 都继承当前 ContextSpace；
- Main Agent 的注意力管理只覆盖当前空间；
- 当前空间禁止读取、搜索、总结、通知、委派或执行另一个空间的任何内容；
- 跨空间限制由服务端授权与 Runtime 本地策略共同执行，不能只依赖 Prompt；
- 用户在 Life 空间提出 Work 请求时，系统展示边界提示，不自动转发或携带内容；
- 用户需要手动切换到 Work 空间，并在目标空间重新发起请求；
- 全局层仅保存 Agent 身份和不包含 Work / Life 内容的产品设置。

这一选择提供最强的工作与生活隔离，同时取消跨空间统一 Inbox、全局优先级排序和自动汇总。用户分别查看每个空间的 Main Agent 会话。

### Context Layer

Context Layer 为 Human、Main Agent 与其他 Agent 提供统一、可检索的上下文视图：

`Context Layer = Index + Graph + Retrieval Routing + Native Work Objects`

每个 ContextRef 指向一个真实内容源，并携带足够的检索与理解信息：

`ContextRef = Source + External ID + Canonical URL + Type + Owner + Scope + Updated At + Summary + Relations + Permission Projection`

每项内容保留一个明确的 Source of Truth。Lark 原生文档、群聊、多维表格、任务与日程可以同时充当 ContextRef 与内容源；GitHub、外部文档、本地文件和 Runtime Session 等内容在 Lark 中保留索引节点，使用时按需取回。

Main Agent 查询 Context Index 来理解用户、过滤信息和组织 Gate；其他 Agent 使用同一索引发现任务背景、协作状态与已有 Artifact。Source Resolver 根据 ContextRef 将读取或写入操作路由到具备相应连接、凭证和权限的 Runtime 或工具。

`larkcli` 是 Context Index 的 Query / Read / Write Interface。Context 的搜索结果与实际取回过程都受 Agent 权限、RuntimeScope、源系统权限和本地策略约束。

### WorkItem, Artifact, Gate and Evidence

- **WorkItem:** 一次需要持续推进、可暂停与恢复的工作；
- **Artifact:** 在 Human、Agent、Harness 和 Runtime 之间传递的可审阅结果；
- **Gate:** 控制下一阶段的 `allow`、`ask` 或 `block` 决策点；
- **Evidence:** 支撑完成状态的测试、日志、截图、链接、消息 ID 或其他验证记录。

对话负责捕获意图、探索、协调和补充上下文；Artifact 负责跨阶段传递确定状态。Lark Context Layer 通过索引与关系图连接飞书原生对象及外部 Source of Truth，形成 Human 与 Agent 的共享工作地图。

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

### Conversation is the entry; Context Layer carries shared state

对话是最低摩擦的意图入口，也是 Main Agent 管理用户注意力的主要界面。复杂工作通过适合它的结构化载体持续推进：

- 普通交流与即时协调显示为消息；
- 长内容与共同编辑沉淀为文档；
- 结构化记录、关系和多视图管理进入多维表格；
- 责任、状态和截止时间进入任务与日程；
- 多 Participant 的持续协作进入群聊与 Thread；
- 持续执行显示为状态卡；
- 关键选择显示为 Decision Card；
- 敏感操作显示为 Approval Card。

对话中呈现摘要、通知、预览、操作入口与关键 Gate。完整内容保留在对应的 Source of Truth；Context Layer 保存索引、关系和必要投影，用户与 Agent 可以从同一个 ContextRef 定位并继续工作。

### Context Layer as shared external memory

Context Index 把分散内容组织成可搜索、可关联的共享工作地图。Human 可以通过图形化视图扫描、比较、筛选和定位；Agent 可以按语义、Schema、来源、关系、负责人、状态和时间检索，并在需要时取回原始内容。索引记录只保存检索和协调所需的信息，完整内容继续由对应 Source of Truth 管理。

### Human attention at gates

系统应让 Agent 尽可能持续推进，把 Human 的注意力集中在目标校准、关键取舍、敏感操作、异常处理和最终接受上。

## Lark as the Context Layer

`Lark = Context Index + Context Graph + Retrieval Routing + Native Work Objects`

Lark Context Layer 为所有获得授权的相关内容建立统一索引。它重点保存：

- 稳定 ID、来源类型和 Canonical URL；
- 标题、摘要、标签、负责人和更新时间；
- 项目、任务、对话、Artifact、Agent 与 Human 之间的关系；
- 当前状态与必要的结构化投影；
- 权限范围及获取原始内容所需的路由信息。

飞书文档、多维表格、群聊、任务和日程继续提供原生工作对象。GitHub、外部文档、本地文件、Runtime Session 及其他系统保留各自的 Source of Truth，并在 Lark 中注册 ContextRef。

`larkcli = Context Index Query / Read / Write Interface`

检索链路：

`User Intent → Main Agent → Query Lark Index → Ranked ContextRefs`

取回链路：

`ContextRef → Source Resolver → Authorized Runtime / Connector → Source of Truth`

执行与回写链路：

`Target Agent → Harness + Runtime → Update Source → Refresh ContextRef → Main Agent`

回流链路：

`Context Change / Artifact → Main Agent → Summary / Card / Gate → Human`

命中飞书原生对象时，`larkcli` 可以直接读取或更新。命中外部内容时，Source Resolver 根据 ContextRef 选择具备相应连接、凭证和网络环境的 Runtime 或工具。索引查询与源内容访问都执行权限检查，避免索引元数据泄露无权访问的信息。

Chatty 的 V1 可以先验证一个混合闭环：索引一种飞书原生对象与一种外部 Source of Truth，通过 Main Agent 完成检索、按需取回、执行、回写和索引刷新。

## Product inspirations and boundaries

| Source | What Chatty carries forward |
| --- | --- |
| 豆包 | 面向 AI 的手机交互、自然对话、长按语音转文字 |
| Buzz | Human/Agent 一级身份、消息空间、Activity 与协作关系 |
| Multica | Daemon、Runtime Fleet、跨设备与跨权限持续执行 |
| ChatGPT / Codex | AI 过程、工具调用、状态、Artifact 与结果展示 |
| 飞书 | Context Layer：索引所有获得授权的相关内容，并提供关系图、检索路由与原生工作对象 |
| `larkcli` | Agent 查询和维护 Lark Context Index，并操作飞书原生对象的接口 |
| Anthropic AI-native SDLC | Intent、Artifact、Human Gate 与可审计闭环 |

Chatty 的独特产品中心是：个人与 Main Agent 的长期关系、以人的注意力为核心的协作拓扑，以及从自然表达跨越多个 Runtime 持续执行的完整体验。

## Initial scope

Stage 1 当前提出的首期范围：

- 单个 Human；
- 一个全局 Main Agent 身份；
- Work / Life 两个硬隔离的 Context Spaces；
- 多个拥有独立身份的 Agent；
- Agent 可被直接对话，也可被 Main Agent 委派；
- Harness 与 Runtime 独立配置；
- 至少两个 Harness 的统一 Session 与事件抽象；
- 多 Runtime 注册、心跳、能力发现、任务调度与恢复；
- 手机优先的文字、图片、文件和长按语音转文字；
- 对话内的 WorkItem 状态、Decision、Approval、Artifact 与 Evidence；
- 通过 `larkcli` 索引至少一种飞书原生对象与一种外部 Source of Truth，完成查询、按需取回、回写与索引刷新，并在 Chatty 对话中呈现摘要、预览或操作卡片；
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
- Work / Life 跨空间访问在服务端与 Runtime 策略层直接阻断；
- Voice 是输入方式，转写文字进入可搜索上下文；
- 每项内容保留明确的 Source of Truth，Lark Context Layer 负责索引、关联和检索路由；
- Context Index 只保存发现、理解、协调和取回所需的信息；
- Chatty 对话负责入口、摘要、通知与 Gate；
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
8. Main Agent 可以从 Lark Context Index 找到一个外部 Artifact，经 Source Resolver 在授权环境中取回，完成操作后回写 Source of Truth 并刷新索引；
9. Runtime 凭证不会传入 Chatty Control Plane 或其他 Runtime；
10. Life 空间内的请求无法发现、读取或调用 Work 空间中的 Context、Agent、Runtime 和 Tool；
11. 用户愿意把 Chatty 作为日常调用个人 Agent 的默认入口持续使用。

第 11 项需要在首个 Dogfood 周期中通过真实使用频率、Main Agent 入口占比、任务完成率和用户主动回访进行验证。

## Open questions

1. 一个 Agent 固定绑定 Harness 与 Runtime，还是在允许集合中动态路由？
2. WorkItem 在什么条件下从普通对话中自动产生？
3. Runtime 发现、身份验证、加密连接和撤销机制采用什么协议？
4. Daemon 与 Multica 的关系是直接复用、兼容协议、扩展，还是独立实现？
5. Buzz 的事件、Agent 身份或 Activity 模型可以复用到什么粒度？
6. Harness 之间需要统一哪些 Session、Tool Call、Permission 与 Artifact 事件？
7. Main Agent 的长期记忆如何按 ContextSpace 存储，GlobalAgentProfile 允许包含哪些非上下文设置？
8. 长按语音的转写服务、隐私边界、流式协议和离线能力如何选择？
9. 移动端、Control Plane、Daemon 和 Harness Adapter 的首期技术栈如何确定？
10. 哪些操作可以 `allow`，哪些必须 `ask`，哪些始终 `block`？
11. ContextRef 的最小 Schema、关系类型和生命周期如何定义？
12. 全文、关键词、结构化过滤、语义向量和关系图检索如何组合与排序？
13. Source Resolver 如何把 ContextRef 映射到正确的 Runtime、Connector 与凭证环境？
14. 源内容变化后，通过 Webhook、事件、轮询或按需校验中的哪些机制刷新索引？
15. 如何镜像源系统权限，并处理权限变化、索引泄露和过期摘要？
16. Chatty 原生实现哪些 Context 展示与交互组件，哪些直接复用或嵌入飞书对象？
17. 对话消息、Chatty WorkItem 与 ContextRef 之间如何建立稳定引用与双向状态同步？
18. Chatty Control Plane 的托管、自托管与数据所有权边界如何设计？

这些问题允许保留到 Stage 2，但会实质改变首期架构或体验的问题需要在 `spec.md` 中明确决策。

## Acceptance gate

本 Intent 进入 Stage 2 — Design 前，需要由产品发起者确认：

- 问题描述准确反映原始体验；
- Product thesis 可以指导产品取舍；
- 核心概念定义没有混淆 Agent、Harness、Runtime 与 Daemon；
- Main Agent 的默认关系得到确认；
- 首期范围足以验证 Voice → Conversation → Context → Execution；
- Out of scope 可以控制第一版规模；
- Open questions 已标记为 Stage 2 决策或后续假设。

接受后，下一项 Artifact 是 `spec.md`。它将定义产品需求、核心流程、信息架构、事件模型、权限模型、系统边界、首期 UX 与技术设计。

## References

- [Chatty README](./README.md)
- [Buzz](https://github.com/block/buzz)
- [Multica](https://www.multica.ai/)
- [The AI-Native SDLC Playbook](https://claude.com/blog/the-ai-native-sdlc-playbook)
