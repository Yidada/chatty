# Evidence

- Outcome: 构建、全部 JVM 单测、lint 通过；真机与 B0 未执行
- Recorded: 2026-09-11
- Repository: <repository>（工作区含未提交改动）
- Environment: macOS, JDK 17, Gradle 8.7, Android SDK 35；`adb devices` 无设备

## 构建与测试

- `source scripts/android-env.sh && android/gradlew -p android testDebugUnitTest --rerun-tasks` -> BUILD SUCCESSFUL。
- 单测汇总（各模块 report XML）：feature-inbox 8、feature-chat 53、feature-workspace 16、core-network 33、core-auth 6、app 9，共 125，0 failures，0 errors。
- `android/gradlew -p android :app:assembleDebug :app:lintDebug` -> BUILD SUCCESSFUL。
- 底部 `动态` Tab 徽标：`ActivityController` 提升到 shell 常驻，`hasAttention` 驱动 `BadgedBox`；构建与 lint 通过。

## 新增覆盖

- `ActivityControllerTest`（8）：指纹优先语义时间戳、未读比较、`needsAction` 分类与目录回退、`actionKeys`、摘要/状态名、`apply` 在 `新进展/待处理` 间迁移并标记已读、状态目录失败降级。
- `ChatControllerTest` 新增 3：项目选择随草稿键持久化并在发送后清理；发送前对既有会话 `PATCH project_id` 并校验；服务端项目与快照不一致时拒绝 POST（错误含「项目归属」）。

## 性能改动（代码级）

- `ChatController` 删除 5 秒全量轮询；`fallback` 15 秒且仅在断线或 pending 时 `refreshContent()`。
- 任务/聊天事件从 `refresh()`（4+2 请求）改为 `refreshContent()`（2 请求）；身份/权限只在完整刷新读取。
- 无真机请求日志，故不声明量化收益；待 B0 后补前后对比。

## 边界与未验证

- 会话切换列表（iOS 无此 UI，按对齐语义未新增）。
- 未做真机 UI 与无障碍验证；未采集 Macrobenchmark/fixture 请求计数。
- 未提交、未推送。
