# iOS：动态页批量处理（多选 + 批量动作）

动态页此前只能逐条点进详情。本次在既有动态流程上增量补齐批量能力，不重做页面、不新建第二套真值。

## 交付行为

- 新进展与待处理都支持进入选择态、逐条勾选、全选当前已加载页、退出；选择态下点击行只切换选中，不进入详情。
- 批量已读：一次写入所选事项的本机已读指纹，不改事项业务状态。
- 待处理页批量「验收完成」置 done、批量「退回待办」置 todo，走 `POST /api/issues/batch-update`。
- 结果反馈：成功 / 未生效 / 失败分开计数，可重试未完成批次；提交期间拒绝重复提交；部分失败不显示为全部成功。
- 批量成功后从服务端重新读取两个列表与待处理计数，并按 `ActivityModel.apply` 的既有语义把已生效行标记已读。

## 服务端契约（已核对源码）

`multica-ai/multica` 只读参考：`server/cmd/server/router.go` 注册 `POST /api/issues/batch-update`，handler 为 `server/internal/handler/issue.go` 的 `BatchUpdateIssues`。

- 请求 `{"issue_ids":[...],"updates":{...}}`，响应 `{"updated": N}`。
- 不存在或无权的 issue 被静默 `continue`，响应不会说明是哪几条，因此客户端只能如实上报「未生效」的聚合数量。
- `updates` 不含任何变更字段时短路返回 `{"updated": 0}`，所以 `updated: 0` 绝不能被当成成功。
- 状态 key 按工作区状态目录校验，非法状态整批 400 拒绝；状态变更中途竞态返回 409，此时已应用子集未知，必须重新读取核对。

## 范围与取舍

- 只做批量状态（done / todo）与批量已读；`IssueBatchUpdate` 已覆盖端点支持的 priority / assignee / project / due_date / stage，但界面不提供无实际用途的入口。
- 不做服务端批量审批流、跨工作区批量、批量删除；不改「动态 = 工作区全量可访问事项」的定位。
- 本轮不发布、不上传 TestFlight；版本号与构建号保持不变。

## 与 CLE-84 的关系

CLE-84（iPad 自适应设计）处于设计阶段，未改动 `ActivityScreen.swift` / `WorkspaceModel.swift`，因此本项可直接在同文件实现。选择栏与批量操作栏不硬编码宽度，紧凑宽度会用 `ViewThatFits` 折成两行；常规宽度与多窗口的完整适配仍属 CLE-84 实现阶段。
