# Intent: Chatty — Multica 手机端应用

- **Author:** Benjamin Zhang
- **Status:** Draft — awaiting product-owner acceptance
- **Stage:** 1 of 6 — Plan
- **Last updated:** 2026-09-04
- **Forked from:** `iterations/v1/`（v1 未验收即关闭，本文件基于其后的新方向撰写）
- **Source of truth:** This file and its Git history

## Originator's intent

我的核心思路就一句话：

> **打造一个 Multica 的手机端应用。**

我每天通过 Multica 管理台与 CLI 调度 Mika 和一群专业 Agent（Android 开发助手、iPad 应用工程师、Vercel 部署工程师、家居智能管家、电商小助手等），它们分布在 Mac mini、omarchy 等 Runtime 上持续工作。但现有入口都要求我在电脑前：

- Multica 管理台是桌面/Web 向的，移动端体验残缺；
- `multica` CLI 适合终端，但不适合离开键盘的场景；
- 手机上没有任何一个应用，能让我自然开口、看到 Agent 网络在做什么。

Chatty 要解决的问题就是：**把 Multica 装进口袋。**

Chatty 不对 Multica 做任何替代或重新实现：Agent、Runtime、Project / Issue / Task、协调与审计全部复用 Multica。Chatty 只负责把它做成一个 ChatGPT 式的手机应用——打开就与 Mika 对话，任务状态与审批随时可见，Agent 的进展和证据自然回到对话流。

核心链路压缩为一句：

> **Voice → Conversation → Multica 协作网络 (Mika + Agents + Runtimes) → 结果回到对话**

## Problem

### 1. Multica 缺少手机入口

Multica 的核心价值（Mika 协调、Agent Fleet、Runtime Fleet、持续执行）需要在电脑前才能用足。人不在电脑前的想法、请求、追问和审批都无法自然进入协作网络。

### 2. 表达与执行分离

手机上的 AI 应用可以轻松让人开口表达，但它调度不到我真实的 Multica Agent Fleet；Multica 管理台可以调度 Agent，但表达门槛高、不移动友好。两者在手机上完全割裂。

### 3. 注意力没有移动态出口

Mika 已经承担了我的注意力管理（聚合、过滤、排序、压缩、Gate），但当我离开桌面时，这些能力就断开了。任务跑完、审批待办、Agent 卡住，我都无法及时感知和决策。

### 4. 任务结果无处落地

Agent 完成工作后产出 Evidence（截图、日志、链接、Artifact），手机上没有地方按需查看、确认和继续下发。

## Proposed outcome

一个属于我日常使用的 Multica 手机客户端：

- 打开应用直接进入与 Mika（Main Agent）的对话；
- 用户通过文字、长按语音转写、图片或文件表达意图；
- Mika 理解意图，自己处理或委派给 Multica 中的专业 Agent；
- 对话中实时出现任务状态卡：Agent · Harness · Runtime · Running / Waiting / Blocked / Failed；
- 需要确认时出现 Approval / Decision Card，手机直接确认；
- 完成时 Evidence（测试、日志、截图、链接）回到对话，可按需展开；
- 应用关闭后任务继续在 Multica Runtime 上执行，重要状态变化推送回手机；
- 手机上是 Multica 的唯一真值套壳：不做任何身份、状态或执行权的第二份拷贝。

## Target user

### Initial user

项目发起者本人：一个在 Mac mini、omarchy 等多台设备上运行 Multica Daemon，日常依赖 Mika + Agent Fleet 的个人用户。

这个用户具有：

- 高频、短时间、移动场景下产生工作与生活请求；
- 已经存在一套完整的 Multica Agent / Runtime 网络；
- 把「对着手机说一句」当作最低摩擦的表达方式；
- 希望任务离开 App 后继续执行，且手机上能收到进展、审批与证据。

### Future users

在手机核心闭环验证后，可逐步支持分享、多 Human 与组织协作——前提是 Multica 开放相应能力。

## Product thesis

> **Chatty turns Multica into your pocket companion.**

中文表达：

> **把 Multica 装进口袋：开口一句，Mika 与 Agent 网络为你持续工作。**

所有产品选择都应强化至少一项：

1. 更自然地表达意图（语音优先、编辑可见）；
2. 更清晰地看到 Agent 网络在做什么（状态卡、渐进展开）；
3. 更及时地做出需要人类的判断（Gate、审批、异常）；
4. 更可靠地查看和读懂结果（Evidence、摘要、原文链接）；
5. 手机与桌面/CLI 的目标一致（同一个 Multica 真值，不产生分叉）。

## Core experience

一个代表性的完整流程：

1. 用户早上通勤时按住输入框说：「让 Android 开发助手看一下 Chatty 仓库，把 dev-loop 文档里的遗留问题处理掉。」
2. 语音实时转文字，允许编辑后发送。
3. 客户端以最小依赖提交给 Multica；Mika 理解意图。
4. Mika 在 Multica 中创建/定位 Task 并委派给 Android 开发助手。
5. Android 开发助手在其主 Runtime（omarchy）上启动 Harness Session。
6. 用户关闭应用，任务继续执行。
7. 对话中持续更新轻量状态卡：
   - 已委派给 Android 开发助手；
   - Opencode · omarchy · Running；
   - 已提交 2 个 commit · 待验证。
8. 需要判断时（例如确认是否推送远端），手机弹出 Approval Card。
9. 完成状态附带 Evidence：构建结果、Appium 截图、验证命令摘要。
10. 用户确认后，Mika 汇总收口；整个闭环留在同一段对话里。

## Core concept decisions

### 1. Chatty 是 Multica 的移动端 thin client

**Decision:** Chatty 不重新实现任何后端能力。Agent、Runtime、Project / Issue / Task、协调、授权与审计的事实源全部在 Multica。

- Chatty 通过 Multica 提供的 API（与 `multica` CLI 同一服务端）完成认证、会话、任务与事件流；
- 客户端保存的只有 UI 状态、本地偏好与离线队列；
- 不做身份、权限或执行状态的第二真值；
- Multica 的能力边界（API、权限、事件覆盖范围）就是 Chatty 的能力边界，Server 不支持的不在客户端伪造。

### 2. Main Agent = Mika

**Decision:** 打开应用默认进入的是 Multica 的 Mika（核心管理人），不新建额外的主 Agent。

- 协调、委派、优先级、聚合与 Gate 交互由 Mika 在 Multica 中完成；
- 客户端呈现 Mika 的回复、任务路由结果与注意力摘要；
- 用户依然可以直接进入某个专业 Agent 的对话（对应 Multica Agent 对话/引用）。

### 3. Agent Fleet / Runtime Fleet 原样复用

Multica 中已注册的 Agent 与 Runtime 就是客户端的 Agent 与 Runtime：

- Agent 列表、头像、角色、在线状态直接来自 Multica；
- 每个 Agent 的主 Harness 与主 Runtime 是 Multica 配置，不在客户端重复或改绑；
- Runtime 的等待、恢复、心跳与任务领取由 Multica 管理；
- 客户端展示的状态一律映射自 Multica（发现新状态类型时回退到可展开的 Generic Activity）。

### 4. 对话是最小产品单元

**Decision:** V1 的最小验证单元是「一段完整对话」：开口 → Mika 响应 → 委派 → 状态 → Gate → Evidence → 收口。

- 对话承担入口、摘要、通知与 Gate；
- 深层的 Project / Issue / Board / Runtime 治理先不搬进手机（留给 Multica 桌面端/CLI），但可通过链接在 App 内打开对应页面；
- 首期不做一个完整的 Multica Administration 客户端。

### 5. 移动体验基准：ChatGPT 手机应用

- 沉浸式消息流、简洁输入、建议性交互、渐进展开与系统级推送通知；
- 长按语音转写保留（豆包式语音交互作为输入方式参考）；
- 状态卡与 Evidence 卡片是 Chatty 侧新增的 Multica 投影组件。

### 6. 平台策略：Android 优先，iOS 随后

- V1 目标平台 Android（开发闭环、真机 Pixel 6 Pro、adb + Appium 体系已经就绪）；
- 架构保持单代码库优先的可移植性（Kotlin + Compose），spec 阶段再冻结技术栈；
- iOS 不在 V1 验收范围内。

## Initial scope

V1（Android）范围：

- Multica API 客户端（认证会话、Mika 对话、消息流、Task / Issue 读取）；
- 打开即 Mika 的对话主界面；
- 文本 + 长按语音转写（实时可见、可编辑再发送）；
- Multica 事件 → 客户端卡片：任务状态卡、Approval / Decision Card、Evidence 卡（截图/链接/日志摘要）、Generic Activity 兜底；
- 后台轮询/推送同步：应用离开后状态持续更新；
- Agent 列表视图：查看 Multica 中已注册 Agent 与运行状态；
- 通过 Multica 引用打开网页版的深层入口（Issue、Runtime、Agent）；
- 与现有 Android 开发闭环（`scripts/dev-loop.sh` + Appium）打通，作为验收手段。

## Out of scope for V1

- 自建后端、自建认证、自建 Agent/通信协议；
- 重新实现 Multica 的 Participant、Issue、Runtime、Session 模型；
- iOS 客户端（V2 候选）；
- 完整的 Multica 管理台功能（治理、成员、配置、计费等）；
- 飞书 / Lark Context Layer 深度集成（作为后续增强候选）；
- 多人协作与组织能力（跟随 Multica 服务端能力演进）。

## Constraints

- Chatty 只消费 Multica 已暴露的能力，不重写、不绕过、不伪造；
- 客户端不做第二真值，任何状态以服务端事件为准；
- 长按语音转写是输入方式，转写文字进入可搜索上下文；
- 不把敏感凭证保存在客户端本地；认证与授权遵循 Multica 与平台安全规范；
- 应用被杀/离线后任务继续执行，恢复后状态必须收敛到服务端真值；
- 客户端默认不自动执行高风险、不可逆操作（由 Multica 权限体系与 Gate 约束）；
- 每一处新事件映射保持原始 Payload 可溯源（Generic Activity 兜底）；
- 代码与文档遵循仓库 SDLC 模具（intent → spec → ISSUES → 实现 → EVAL → Hardening），验证走 adb + Appium 实证闭环。

## Success criteria

首个可用闭环需要证明：

1. 用户在 Pixel 6 Pro 上打开 Chatty 即可与 Mika 对话，回复正常；
2. 长按语音转写后可在发送前编辑；
3. 发起一个真实委派请求后，对话中出现任务状态卡，且状态随 Multica 侧变化更新；
4. 需要确认时手机出现 Approval Card 并完成确认动作；
5. 任务完成后 Evidence（截图、链接、日志摘要）可点击查看；
6. 关闭并重新打开 App 后，对话与状态与 Multica 真值一致；
7. Agent 卡片/列表显示 Multica 中的真实 Agent 与运行状态；
8. 整个流程由 Appium 自动化脚本作为实证闭环通过；
9. 用户愿意把 Chatty 作为移动端调用 Mika 与 Agent 网络的默认入口持续使用。

## Open questions

1. Multica 暴露给客户端的 API 覆盖哪些会话与事件（WebSocket/轮询/推送），鉴权如何做？
2. 语音转写采用何种服务与隐私边界（本地/云端、离线可用性）？
3. 状态同步的推送通道（FCM/自建 socket）与耗电策略？
4. 对话/任务的历史分页与语义摘要由谁生成（Mika 回复是否足够）？
5. 客户端安全存储（凭据）与设备绑定策略？
6. iOS 与桌面扩展的优先级排序？

上述问题允许保留到 Stage 2（spec.md），其中影响首期架构的（尤其是 API 与登录）在 spec 中必须明确决策。

## Acceptance gate

本 Intent 进入 Stage 2 — Spec 前，需要由产品发起者确认：

- 「Multica 手机端应用」是否准确表达定位；
- 打开即 Mika、thin client、Android 优先三个决策确认；
- V1 范围足以验证 Voice → Conversation → Execution → Evidence 回到对话；
- Out of scope 控制首期规模；
- Open questions 已标记为 Stage 2 决策。

接受后，下一项 Artifact 是 `iterations/v2/spec.md`。

## References

- [Chatty README](../../README.md)
- [Android 开发闭环](../../docs/android-dev-loop.md)
- [SDLC 模具与轮次规则](../../docs/sdlc-workflow.md)
- [v1 intent (closed)](../v1/intent.md)
- [Multica](https://www.multica.ai/)
- [Anthropic Agentic SDLC](https://claude.com/blog/the-ai-native-sdlc-playbook)
