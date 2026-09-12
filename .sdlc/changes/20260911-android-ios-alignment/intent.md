# Intent: Android 对齐 iOS 体验 + 性能热点修复

- Author: Mika
- Status: 用户已确认「全量对齐」并授权「先优化、后补 B0」
- Stage: Implementation（进行中）
- Related: Android non-blocking chat queue（同一工作区，未提交）；Android V3 performance baseline
- Last updated: 2026-09-11

## 1. 目标

让 Android 客户端的功能与信息架构对齐 iOS（Chatty iOS 的 `动态 / Mika / 项目` + 头像设置 Sheet），并在没有真机基线的前提下先修复已定位的性能热点。原 V3 Gate 要求「先 B0 后优化」，用户 于本轮明确授权先优化、设备可用后再补 B0 与前后对比，接受暂时无法量化收益。

## 2. 范围

In scope：

- 一级导航从 `对话 / 项目 / 设置` 改为 `动态 / Mika / 项目`；设置改为右上头像打开的 Sheet。
- 动态 feed：工作区全量事项、`新进展`/`待处理` 独立分页、已读指纹、未读红点。
- 项目页补齐：验收通过、和 Mika 继续讨论、全发起人提示。
- 性能：去掉 5 秒全量刷新轮询；内容刷新与身份/权限检查分离，任务事件只做内容级收敛。

Out of scope（本轮未做，记录为后续）：

- 会话切换列表（iOS 的 Mika 只显示最近会话，无会话列表 UI，故按对齐语义不新增）。
- 服务端分页/数据库缓存（V3 Stage 3+）、真机 B0 与 soak。
- iOS 侧改动、服务端协议修改。

已完成对齐补充：Mika 项目选择 + 逐条消息项目快照；动态 `hasAttention` 底部徽标（controller 常驻）。

## 3. 成功标准

- Android 三个 Tab 与设置入口与 iOS 一致；动态能看到跨项目待处理与未读。
- 构建、全部 JVM 单测、lint 通过。
- 轮询请求量下降有代码级证据（5 秒全量 → 无变化不轮询）。
