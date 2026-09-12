# Plan

1. `core-model`：`Issue` 增加 `creator_id/creator_type/updated_at/last_activity_at`；`ChatUser` 增加 `name/email`。
2. `core-network`：`WorkspaceApi` 增加 `me()` 与 `issues(statuses,sort,direction)`；`MulticaApi` 增加 `me()`。
3. `core-auth` / `app`：`AuthRepository.me()`；`AuthState` 增加 `me/loginEmail`；头像来源。
4. `feature-inbox`：启用 Compose 依赖；新增 `ActivityReads`（DataStore 持久化）、`ActivityController`（分页/已读/状态迁移纯函数）、`ActivityRoute`（动态列表 + 未读 + 待处理）。
5. `app.MainActivity`：三 Tab 重构 + 头像设置 Sheet；串联动态→项目详情、项目→Mika 讨论。
6. `feature-workspace`：`ProjectsRoute` 支持 `openIssue/onIssueOpened/onDiscussIssue`；Issue 详情增加验收/讨论/摘要。
7. `feature-chat`：`refreshContent()` 与轮询降载；Mika 项目选择（`ChatApi.projects/updateSession`、草稿键持久化、发送前 PATCH+校验）；`prepareIssueDiscussion`。
8. 测试：`ActivityControllerTest`（纯函数 + apply/markRead + 目录失败）；更新受接口变更影响的 Fake。
9. 验证：`source scripts/android-env.sh && android/gradlew -p android testDebugUnitTest assembleDebug lintDebug`。

## 验证命令

```bash
source scripts/android-env.sh
android/gradlew -p android testDebugUnitTest --rerun-tasks
android/gradlew -p android :app:assembleDebug :app:lintDebug
```

## 后续（未纳入本轮）

- Mika 项目选择 + 逐条消息项目 PATCH；会话列表与未读徽标。
- 真机 B0（macrobenchmark）与前后对比；V3 Stage 3+ 缓存。
