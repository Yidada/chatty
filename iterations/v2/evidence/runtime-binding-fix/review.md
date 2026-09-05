# NAV-TEST-01：Mika Runtime 状态同步修复

2026-09-05。实现者自审；基于 `8345bb3` 的本地修复。

## 修复行为

- 原因：保留的 ChatController 在后续刷新中只读取会话和消息，继续使用初始化时的 Agent 绑定与权限。
- 返回对话、回到前台、手动刷新及同步事件现在重新读取 Agent、当前用户和工作区成员权限。
- 保留当前会话、草稿、附件、已加载历史、分页游标与 UI 阅读位置。刷新不重新初始化页面，也不取消正在发送的请求。
- 同步期间和同步失败后暂停发送，保留草稿；重试成功后按最新绑定与权限恢复。
- Agent 暂时消失或归档时禁用发送，继续保留会话与新对话草稿的身份，避免选择其他 Agent。

## 证据

| 检查 | 结果 | 证据 |
| --- | --- | --- |
| 原始缺陷复现 | 修改前失败 | [修改前日志](before-regression.log) |
| 原始 Chat 边界用例 | 2 项通过，原失败断言保持不变 | [边界结果](TEST-ai.chatty.feature.chat.NavigationChatBoundaryTest.xml) |
| 正式 JVM 测试 | 46 项通过，包含 5 项新增回归 | [测试汇总](unit-summary.json) |
| 真实服务包构建、Lint | 通过 | [最终构建日志](final-build-test-lint.log) |
| Pixel Runtime 状态切换 | 31 个检查点通过；绑定、解绑、重试均无需重启，1 次合成发送完成 | [结果](device-transitions/result.json)、[恢复发送截图](device-transitions/tab-return-recovers-binding.png) |
| Pixel 原有聊天回归 | 33 个检查点通过；2 次合成收发、附件、任务过程、重连、草稿、冷启动、历史分页、错误恢复 | [结果](chat-regression/result.json) |
| Pixel 导航回归 | 96 个检查点通过；详情、筛选、55 条分页、阅读位置、逐级返回、工作区取消与隔离、1 次跨 Tab 合成发送 | [结果](navigation-regression/result.json) |

新增 JVM 回归还覆盖成员权限撤销与恢复、慢请求与失败期间禁止过期发送、Agent 消失/归档、草稿存储身份、发送中刷新。

## 复跑入口

在 Android worktree 的 `android/` 目录运行：

```sh
source /Users/benjamin/Workspace/chatty/scripts/android-env.sh
./gradlew testDebugUnitTest assembleDebug lintDebug
./gradlew -I ../iterations/v2/evidence/navigation-sdlc-test/repro/init.gradle :feature-chat:testDebugUnitTest --tests '*NavigationChatBoundaryTest*'
./gradlew assembleDebug -PchattyFixture=true
```

在 worktree 根目录分别启动 `scripts/runtime-binding-fixture.py` 和 Appium 4725，安装 fixture 包，将 Pixel 的 tcp:8765 转发到主机 tcp:8875，再运行 `scripts/runtime-binding-device-test.py`。脚本要求全新的 `EVIDENCE_DIR` 和 `ANDROID_SERIAL`。原有聊天与导航脚本使用重置后的 `scripts/chat-fixture.py`，主机端口同样为 8875。

## 交付范围

- 修复包使用真实服务配置，包名 `ai.chatty.app.debug`，版本名 `0.2.0-dev`，保留设备原有登录与数据。
- 修复包已覆盖安装到 Pixel 6 Pro；读取手机中 APK 校验得到相同 SHA-256，当前进程无 FATAL EXCEPTION。见 [安装回执](installed.json)。
- 真实工作区的 Mika 连接、工作区选择取消、Runtime / Agent / Squad 列表跨 Tab 保留检查通过，见 [真实包检查](installed-live-smoke.json)。
- APK 与测试源文件哈希记录在 [manifest.json](manifest.json)。
- 隔离测试包、ADB 转发和本轮服务已清理，真实应用保持打开。
- Runtime 绑定变更和发送闭环使用 Pixel 上的隔离合成服务；权限撤销边界由 JVM 回归验证。
- 真实工作区不发送消息，也不修改 Issues。
- 历史失败证据与已发布的 `v0.2.0-android.20260905` 保持原样；修复随本次代码提交保存，尚未发布新包，主分支不变。
