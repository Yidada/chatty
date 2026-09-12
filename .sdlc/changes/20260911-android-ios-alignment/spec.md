# Spec: Android 对齐 iOS（第一增量）

## 导航与信息架构

- 底部三个 Tab：`动态` / `Mika` / `项目`。
- 顶部栏右侧头像按钮（`profile.open`）；点按打开设置 Sheet，包含当前工作区切换、Runtimes/Agents/Squads、退出登录（沿用既有 `SettingsRoute`）。
- 头像首字母取 `/api/me` 的 `name`，其次 `email`，再其次本次登录邮箱；都缺失时显示「我」。

## 动态 feed（`ai.chatty.feature.inbox`）

- 数据源为工作区全量 Issue，不按个人 Inbox 收件人或发起人过滤。
- `新进展`：`limit=50, sort=last_activity, direction=desc`，独立分页。
- `待处理`：在状态目录分类为 `in_review`/`blocked` 的 key 上追加字面量 `in_review,blocked` 后作为 `statuses` 查询；本地再按分类过滤。
- 已读指纹：`"${last_activity_at ?: updated_at ?: revision}|${status}"`，按 `account(sha256 token)+workspace` 隔离持久化到 DataStore。查看只更新指纹，不写业务状态。
- 未读红点：指纹不一致时在分类图标右上显示红点。
- 底部 `动态` Tab 在 `hasAttention`（存在待处理或未读）时显示徽标。controller 提升到 shell 常驻，切换 Tab 时仍按 30 秒轮询，保持徽标实时。
- 状态目录失败：项目与 `新进展` 仍展示，`待处理` 暂停并提示；不影响 `新进展`。
- 点按条目：`markRead` 后切换到 `项目` Tab 打开该 Issue 详情。
- 复用 `WorkspaceApi.issues` 新增的 `statuses/sort/direction` 查询参数。

## 项目页

- Issue 详情增加「现在的情况」摘要、「验收通过」（分类为 `in_review` 且存在 `done` 分类状态时）、「有修改意见，和 Mika 说」。
- 「和 Mika 继续」切换到 `Mika` Tab，并在草稿为空时预填 `关于 [ID · title](mention://issue/<id>)：`；草稿非空时不覆盖并提示。
- Issue 列表头注明「全部事项 · 包含所有发起人」。

## 性能（预先授权）

- `ChatController`：新增 `refreshContent()`（仅 messages + pending），任务/聊天事件改用内容级收敛；`chat:session_*`、`auth_ack`、手动刷新仍走完整 `refresh()`。
- 去掉 5 秒全量刷新：`fallback` 改为每 15 秒，仅在断线或存在 pending 任务时做内容级 `refreshContent()`；无真实业务变化时不轮询。
- 身份/权限检查（`capabilitiesCurrent`）仍只在完整 `refresh()` 中更新，`canSend` 语义不变。

## Mika 项目选择

- 加载 `/api/projects`；composer 提供项目选择器（`不指定项目` + 项目列表 + `刷新项目`）。
- 选择随草稿键持久化（DataStore，按 token 摘要隔离）；打开会话时优先已保存选择，否则回退会话 `project_id`。
- 发送时为每条消息快照项目：新建会话带 `project_id`，既有会话 `PATCH /api/chat/sessions/{id}`；校验返回 `project_id` 与快照一致，不一致则不 POST 并提示「项目归属未能确认，消息没有提交。」。
- 「有修改意见，和 Mika 说」会把事项项目带入选择。

## 边界

- 未引入 Room、OkHttp 业务缓存或新 Worker。
- 未改队列/uncertain 语义；发送新增「发送前项目 PATCH + 校验」。
