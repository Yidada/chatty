# 三 Tab 信息架构

2026-09-05，按用户最新指示收敛为原生体验。此文件覆盖旧版独立 Agent / 动态 Tab 和网页设置兜底安排。

本次变更契约：`.sdlc/changes/20260905-native-experience-without-multica-web-exits/`。

| Tab | 内容 | 当前行为 |
| --- | --- | --- |
| 对话 | 我与 Mika 的单一对话 | 默认接续当前工作区最近更新的有效 Mika 会话；没有会话时首次发送创建。页面没有会话列表、新对话按钮或其他 Agent 选择器。后端已有会话保持原样。 |
| 项目 | 按 Project 展示所有 Issues 的进度 | 项目完成数/总数取自服务端；项目内支持搜索、工作区状态目录筛选、分页、详情和状态修改；未归属 Project 的 Issues 有独立入口。 |
| 设置 | 工作区、Runtimes、Agents、Squads | 工作区切换/退出；原生资源列表和详情。 |

## 项目管理

- `GET /api/projects` 读取 `issue_count` 和 `done_count`。进度使用完整项目统计，不把当前页当作全部任务。
- `GET /api/issues` 使用 `project_id`、`include_no_project`、`q`、`status`、`limit=50` 和 `offset`。
- `GET /api/issue-statuses` 提供自定义状态；目录失败时仍展示项目，并暂停状态编辑。
- `GET /api/issues/{id}` 在打开详情时读取最新版本。
- `PUT /api/issues/{id}` 明确发送 `suppress_run=true`，有 revision 时同时发送 `expected_revision`。页面说明此操作仅修改进度，不自动启动 Agent。
- 提交期间禁用重复操作。错误或并发冲突后要求重新读取状态，不自动重发写请求。
- 原生管理重点是进度；未实现的描述编辑、创建、分派、依赖关系不展示入口。

## 设置对齐

参考 Multica `packages/core/types/{agent,squad}.ts` 和 `packages/views/settings/components/settings-page.tsx`。

- Runtimes：自定义名称优先、在线状态、运行模式、provider、设备信息、最后在线时间。
- Agents：当前可见且未归档的 Agent、状态和 Runtime 绑定。
- Squads：团队、成员数量、说明和负责人。
- 删除账号与工作区共 20 个网页设置菜单，删除资源管理及配置外跳。
- 已有原生能力提供查看与刷新；未实现的配置不展示入口。

## 对话内的内容

- 删除 HTML / Mermaid 的 Multica 网页查看按钮；当前保留文本/代码阅读。
- Multica 域名和当前 API 主机的消息链接保留文字与强调格式，移除点击跳转语义。
- 图片和图片附件使用原生弹窗预览，关闭后回到当前对话。
- 第三方资料链接和 Android 文件查看器继续提供内容访问；应用不构造 Multica 网页导航。

## 验证与边界

- 此前三 Tab 基线为 32 个独立 JVM 测试。本次增加链接策略测试，结果见本次 SDLC evidence.md。
- Pixel 合成闭环验证：单 Mika 入口、服务器进度、Issue 状态修改、搜索/自定义状态筛选、55 条分页、空项目、无项目 Issues、三个资源详情、三轮 Tab 切换。
- 状态测试只修改本机合成 Issue，服务端记录为一次 PUT，携带 suppress_run 和 revision；没有启动真实 Agent。
- 首次真机发现 Retrofit 代理用作 Compose key 引发反复重建；改成 workspace ID / base URL 后，通过稳定请求次数断言。
- 原有 Mika 收发和真机真实只读检查单独记录在 EVAL；完整 V2 gate 仍未通过。
