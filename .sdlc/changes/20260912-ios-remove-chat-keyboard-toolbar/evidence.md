# 验证记录：去掉 Mika 对话的「收起键盘」按钮

- 结果：代码变更完成，ChattyFixture 构建通过，Swift 核心 55 项测试全绿；键盘弹起时键盘上方只剩系统键盘，v1-core / v1-workspaces 里被移除按钮之后的两步在键盘弹起状态下仍然可用。
- 未执行：TestFlight 上传、版本号变更（按 Issue 边界，发布走独立发布 Issue）。
- 需要人工确认的一项：真机/模拟器上「拖动消息列表交互式收起键盘」由 iOS 系统手势承担，当前自动化驱动无法合成该手势（见下）。

## 变更

- `ios/Chatty/ChatScreen.swift`：删除唯一的 keyboard placement 工具栏

  ```swift
  .toolbar {
      ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("收起键盘") { draftFocused = false } }
  }
  ```

  这是该 placement 下唯一的项，删除后 accessory bar 整体不再出现。`draftFocused` 焦点状态与 `.focused($draftFocused)`、`commands.focusComposer` 绑定保留；发送后保持键盘的既有行为未改动。
- `tests/device/ios/v1-core.ad`：删除 `press "role=\"button\" label=\"收起键盘\""`，改为直接点下一个目标。
- `tests/device/ios/v1-workspaces.ad`：删除两处同一按钮按压，改为直接点下一个目标。

## 已执行验证

| 检查 | 结果与证据 |
| --- | --- |
| ChattyFixture 构建 | `scripts/ios-dev-loop.sh fixture` 成功，安装并启动于 iPhone Air / iOS 26.5；[构建日志](evidence/fixture-build.log) |
| Swift 核心测试 | 55 项通过，0 失败；[原始输出](evidence/swift-tests.log) |
| 键盘上方无「收起键盘」 | 聚焦输入框后键盘可见（1 个 Keyboard 节点 + 31 个按键），整棵可访问性树中不存在 `收起键盘`；键盘区按钮仅 shift / Emoji / return / Dictate / Next keyboard；[快照](evidence/keyboard-up-snapshot.json)、[截图](evidence/01-keyboard-up-no-toolbar.png)、[判定](evidence/keyboard-check.json) |
| v1-core 替代路径（键盘弹起时打开任务过程） | 键盘弹起状态下 `trace.t1` 展开成功，出现「1 · thinking / 检查格式与上下文」；[快照](evidence/trace-expanded-keyboard-up.json) |
| v1-workspaces 替代路径（键盘弹起时进设置） | 键盘弹起状态下设置 Sheet 打开、`设置 › 切换工作区` 可达（workspace.w2 出现）；[截图](evidence/03-settings-keyboard-up.png) |
| 草稿不丢 | 关闭设置面板后 `chat.draft` 仍为 `PANEL_CHECK_DRAFT`；[快照](evidence/draft-kept-after-settings.json) |
| 回放零回归（可达部分） | 变更前 HEAD 与变更后的 `v1-core.ad` 都停在第 13 步 `wait "id=\"attachment.file1\""`、`v1-workspaces.ad` 都停在第 9 步 `wait "id=\"chat.attach\""`，divergence 原因同为 `wait_target_absent`；[对比结果](evidence/replay-compare.json) |

## 两条 V1 回放的现状（既有问题，非本次引入）

`v1-core.ad` / `v1-workspaces.ad` 是 2026-09-05 V1 导航（会话优先）时代的流程。当前 app 已是「动态 / Mika / 项目」三 Tab，登录后落在动态页，因此两条流程在到达键盘工具栏之前就已在 `attachment.file1` / `chat.attach` 处发散（`ios/README.md` 也已标注这两条 `.ad`「对应旧导航…不作为新版的验收命令」）。用 HEAD 版本的原始 `.ad` 在同一个构建上复跑得到完全相同的发散点，说明键盘工具栏的删除没有改变任何可达步骤的行为。

要让这两条流程整体通过，需要把它们的导航选择器升级到三 Tab 界面（Mika Tab、`个人与设置`、动态页等），属于独立的重构工作量，未纳入本次「只动这一处键盘工具栏与受影响的两个回放脚本」的边界，建议另开 Issue。

## 关于「拖动列表交互式收起键盘」

替代路径 `.scrollDismissesKeyboard(.interactively)`（`ChatScreen.swift`）是既有实现，本次未改动。自动化驱动只能合成 XCUIElement 级别的滚动/快扫（内容确实滚动了 800pt 以上），无法合成能触发 SwiftUI 交互式收起的连续拖拽；`agent-device keyboard dismiss` 在 iOS 上直接返回 `UNSUPPORTED_OPERATION`（键盘无 dismiss 键），其提示也建议「直接点下一个目标」。因此该项需要人工在真机/模拟器上目视确认，本记录不声称已机器验证。

## 原始日志位置

- `.tools/cle97/swift-tests.log`、`.tools/cle97/compare.json`
- `.tools/cle97-replay-compare.py`、`.tools/cle97-acceptance-check.py`（本机临时脚本，未提交）
- agent-device 诊断：`/Users/benjamin/.agent-device/sessions/cle97-final/`
