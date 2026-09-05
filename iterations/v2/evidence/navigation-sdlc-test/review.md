# Android 导航连续性：sdlc-test 复核

2026-09-05。结论：**需要修复 NAV-TEST-01 后再验收本轮导航改动。**

- 对照：`codex/android-navigation-continuity`，基线 `3c003f9`，当前未提交的导航连续性实现。
- 审查类型：实现者自审，补充可执行边界测试与 Pixel 复现；未进行独立审查。
- 本轮只添加测试复现材料、证据与评估记录，应用代码保持原样。
- 已执行用户指定的 `sdlc-test`；未启动其他生命周期阶段。

## 发现

### NAV-TEST-01 · P2 · 对话保留了过期的 Mika Runtime 绑定状态

- **触发**：进入尚未绑定 Runtime 的 Mika 对话；服务端完成绑定；在设置 → Agents 详情确认新 Runtime；返回对话并点击刷新。
- **实际结果**：对话仍显示“此 Agent 尚未绑定 Runtime”，发送按钮持续禁用。重启应用后恢复，原有草稿仍在。
- **影响**：用户完成配置后无法在当前对话继续工作，设置页与对话页显示不一致。
- **位置**：`android/feature-chat/src/main/java/ai/chatty/feature/chat/ChatScreen.kt:81-86`。新加入的 `initialized` 让保留的控制器只初始化一次。后续进入页面调用 `start()` → `refresh()`；`ChatController.kt:115-120` 在 agents 非空时只读取会话和消息，未更新 Agent 与 Runtime 绑定信息。
- **建议修正**：保留会话、草稿、分页和滚动位置，同时在返回页面及显式刷新时重新同步 Mika 的调用能力及权限数据。避免用完整初始化覆盖正在发送的消息或当前阅读状态。
- **验收要求**：绑定后无需重启即可发送；解绑或失去调用权限后及时禁用；失败时保留草稿与阅读位置；不得误投其他 Agent。
- **证据**：[JVM 失败结果](TEST-ai.chatty.feature.chat.NavigationChatBoundaryTest.xml)、[设备观察与请求清单](device-runtime-refresh/observation.json)、[设置已识别 Runtime](device-runtime-refresh/settings-sees-new-runtime.png)、[对话仍不可用](device-runtime-refresh/chat-retains-stale-runtime.png)、[重启后恢复](device-runtime-refresh/restart-recovers-runtime.png)。

## 验证结果

| 检查 | 结果 | 证据 |
| --- | --- | --- |
| 原有单元测试实际重跑 | 41 项通过，0 失败 | [baseline-tests.json](baseline-tests.json) |
| 构建、Lint | 通过 | [最终命令日志](final-build-test-lint.log) |
| 保留的对话更新 Runtime 绑定 | 失败；JVM 与 Pixel 均复现 | [边界测试日志](boundary-tests.log)、[设备日志](device-runtime-refresh.log) |
| 等待发送回执时离开对话 | 通过；请求继续且只发送一次 | [Chat 边界结果](TEST-ai.chatty.feature.chat.NavigationChatBoundaryTest.xml) |
| 第二页刷新失败 | 通过；55 条记录、分页、筛选保留，重试恢复 | [Project 边界结果](TEST-ai.chatty.feature.workspace.NavigationProjectBoundaryTest.xml) |
| 详情刷新失败 | 通过；页面保留、旧版本写入被禁止、重试更新 revision | [Project 边界结果](TEST-ai.chatty.feature.workspace.NavigationProjectBoundaryTest.xml) |

新增边界测试共 4 项，3 项通过、1 项失败。失败用例保存在 `repro/`，通过 Gradle 初始化脚本临时加入测试源集；没有删掉断言或改写现有应用测试来获得通过结果。

## 命令与环境

- macOS、项目已有 JDK 17 / Android SDK / Gradle Wrapper。
- Pixel 6 Pro，Android 16，ADB 序列号 `1A021FDEE004VC`。
- 真实 APK SHA-256：`1376f65370fa474ae5ed93bc8797f400be49551a750ad782c8af709e5da74de8`，与上一轮真机证据中的 APK 一致。
- [source-manifest.json](source-manifest.json) 记录当前改动源文件哈希；[result.json](result.json) 记录最终判定。

以下命令从当前 Android worktree 的 `android/` 目录执行：

```sh
source /Users/benjamin/Workspace/chatty/scripts/android-env.sh
./gradlew testDebugUnitTest assembleDebug lintDebug
./gradlew -I ../iterations/v2/evidence/navigation-sdlc-test/repro/init.gradle :feature-chat:testDebugUnitTest --tests '*NavigationChatBoundaryTest' :feature-workspace:testDebugUnitTest --tests '*NavigationProjectBoundaryTest' --continue
./gradlew assembleDebug -PchattyFixture=true
./gradlew -I ../iterations/v2/evidence/navigation-sdlc-test/repro/fresh-tests.gradle testDebugUnitTest assembleDebug lintDebug
```

第二条命令预期返回失败，保留 NAV-TEST-01 的复现。最后一条强制原有 Test 任务重新执行，同时恢复真实服务构建；其通过结果覆盖原有 41 项测试，不包括临时加入的 4 项边界测试。

真机复现从 worktree 根目录执行，使用新的 `EVIDENCE_DIR`，两个服务分别运行：

```sh
source /Users/benjamin/Workspace/chatty/scripts/android-env.sh
python3 -B iterations/v2/evidence/navigation-sdlc-test/repro/device-fixture.py
appium --address 127.0.0.1 --port 4725
# 在 fixture 构建完成后安装；该包名为 ai.chatty.app.fixture。
adb -s 1A021FDEE004VC install -r android/app/build/outputs/apk/debug/app-debug.apk
adb -s 1A021FDEE004VC reverse tcp:8765 tcp:8875
ANDROID_SERIAL=1A021FDEE004VC EVIDENCE_DIR=/tmp/chatty-runtime-refresh-new python3 -B iterations/v2/evidence/navigation-sdlc-test/repro/device-runtime-refresh.py
```

本机服务仅监听 `127.0.0.1:8875`，设备通过 ADB reverse 使用它。脚本修改合成 Mika 绑定，不访问真实 Multica；合成 Chat 发送与 Issue 写入均为 0。

## 测试诊断和边界

- 初次构建在 worktree 根目录调用了不存在的 `./gradlew`，属于命令路径错误；随后在 `android/` 运行成功。
- 首次设备脚本读到了发送图标的 enabled 属性。实际禁用状态位于父按钮 `chat-send`；修正定位后重跑同一断言。原始尝试日志保存在 [device-harness-attempt-1.log](device-harness-attempt-1.log)，与产品缺陷分开记录。
- 前一轮完整导航、聊天、项目与视觉真机证据继续适用于相同 APK。本轮补测了上述边界，没有重复运行全部旧设备脚本。
- 本轮未验证真实账户的发送、Issue 写入、权限撤回、进程重建后的完整导航恢复或多设备布局。Runtime 绑定缺陷不能直接证明权限撤回的具体表现。
- 隔离测试包及本次 ADB reverse 已移除；本轮 Appium 和合成服务已关闭；Pixel 已恢复打开原有真实服务版本。
- 应用修复尚未实施；修复后需让失败用例通过，并重跑受影响的对话、导航与权限边界检查。
