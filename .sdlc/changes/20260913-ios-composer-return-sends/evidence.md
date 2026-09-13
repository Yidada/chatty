# 验证记录：Mika 对话输入框回车改为直接发送

- 结果：改动完成，`Chatty` / `ChattyFixture` 两个 scheme 构建通过，Swift 核心 75 项与 iOS 宿主 11 项测试全绿；模拟器上软键盘回车键是系统 send 键，按下即发出草稿且草稿无残留换行，空草稿与连按无副作用；新增聚焦回放 `v2-composer-return.ad` 一次通过。
- 未执行：TestFlight 上传、版本号变更（按 Issue 边界，发布走 CLE-98）。
- 需要人工确认的两项：真机上的中文输入法手输（组词上屏）与硬件键盘 `⇧↵`（见下）。

## 变更

- `ios/Chatty/ComposerText.swift`（新增）：输入框改为 `UITextView`（`UIViewRepresentable`）。竖排 `TextField` 表达不了「回车即发送」——`axis: .vertical` 把回车变成换行，既不回调 `onSubmit` 也不接受 `.submitLabel(.send)`。新写法把回车语义显式定下来：
  - `ComposerReturnKey.action(replacement:isComposing:keepsLineBreak:)`：替换文本是 `"\n"`、且 `markedTextRange == nil`、且不是 `⇧↵` 时才发送，其余一律放行；
  - `returnKeyType = .send` → 软键盘回车键就是系统 send 键；
  - 组词中 `markedTextRange != nil`、替换文本是候选词 → 只上屏，不发送；
  - `ComposerTextView.pressesBegan` 把 `⇧↵` 留给手动换行（未按修饰键的回车与软键盘一致，都是发送）；
  - `sizeThatFits` 与 `isScrollEnabled` 保持 `lineLimit(1...6)`：一行到六行随内容增长，再多在框内滚动。
- `ios/Chatty/ChatScreen.swift`：`TextField` 换成 `ComposerText` + 空草稿占位文案；焦点由输入框自己持有（`@FocusState` → `@State`），`⌘F` 聚焦与「发送后保持键盘」的既有结论不变。
- `ios/Tests/SimulatorContractTests.swift`：新增 3 项宿主测试（回车规则、真实 `UITextView` 的组词 / 发送、六行封顶）。
- `tests/device/ios/v2-composer-return.ad`（新增）：回车发送 + 空草稿 + 连按的聚焦回放。
- `ios/README.md`：对话入口行为、输入框实现说明、回放清单与测试计数（72 → 75 + 11 项宿主测试，按实测校正）。

## 已执行验证

| 检查 | 结果与证据 |
| --- | --- |
| 两个 scheme 构建 | `xcodebuild ... -scheme ChattyFixture build`、`-scheme Chatty build` 均 `** BUILD SUCCEEDED **`；[汇总](evidence/xcodebuild-summary.log)（完整日志留在构建机 `.tools/cle101/`） |
| Swift 核心测试 | `swift test --package-path ios/Packages/ChattyKit --scratch-path .tools/ios-swift-build`：75 项通过 0 失败；[原始输出](evidence/swift-tests.log) |
| iOS 宿主 XCTest | 11 项 0 失败（1 项模拟器跳过的文件保护检查，既有）；含新增 3 项；[汇总](evidence/xcodebuild-summary.log) |
| 组词中的回车只上屏、不发送 | 宿主测试用真实 `UITextView`：`setMarkedText` 后断言 `markedTextRange != nil`，候选词替换被放行且未触发发送；不在组词中的 `"\n"` 被拦截并触发一次发送；见 `SimulatorContractTests.swift` 与上表测试结果 |
| 多行展示保留（六行封顶） | 宿主测试按同一份输入框配置测高：一行不塌陷、三行更高、二十行与六行等高（`maximumLines`） |
| 软键盘回车键 = send 键 | 模拟器（iPhone Air / iOS 26.5）键盘树中回车键为 `Button label="send" identifier="Send"`；[快照](evidence/keyboard-return-key-send.json)、[聚焦后键盘](evidence/composer-tap-focus.json)、[输入草稿时的键盘](evidence/keyboard-send-key-typed.json) |
| 按下回车即发送、草稿无残留换行 | 填 `CLE101_RETURN_SEND` 后按 send 键：出现回执 `CHATTY_CHAT_OK · CLE101_RETURN_SEND`，合成服务 `send_count` 0→1，投递内容恰为 `CLE101_RETURN_SEND`；[审计](evidence/calls-after-return.json)、[操作键盘前](evidence/01-keyboard-return-key-send.png)、[发送后](evidence/02-return-sent.png) |
| 空草稿回车无副作用 | 空草稿再按 send 键：`send_count` 仍为 1，草稿仍为空；[审计](evidence/calls-after-empty-return.json)、[截图](evidence/03-empty-draft-return.png) |
| 连按回车不重复发送 | 填 `CLE101_DOUBLE_RETURN` 后连按两次：`send_count` 1→2，投递内容各一条、无重复；[审计](evidence/calls-after-double-return.json)、[截图](evidence/04-double-return.png) |
| 点击输入框可聚焦（既有交互） | 按当前坐标点输入框后键盘出现（键盘节点 0→2→32）；[快照](evidence/composer-tap-focus.json)、[截图](evidence/09-composer-tap-keyboard.png) |
| 点 send 键发送，且发送后键盘保持 | 输入 `CLE101_TAP_SEND` 后点 send 键：回执出现，投递内容为该文本，键盘仍在（32 个键盘节点）；[审计](evidence/calls-after-tap-send.json)、[输入中](evidence/10-draft-typed.png)、[发送后](evidence/11-tap-send-key-sent.png) |
| 聚焦回放 | `agent-device replay tests/device/ios/v2-composer-return.ad`：`success: true`（一次通过），含回车发送、空草稿、连按三步；[截图](evidence/replay-01-return-key-is-send.png)、[发送后](evidence/replay-02-sent-without-newline.png)、[连按后](evidence/replay-03-double-return-sends-once.png) |
| 涉及草稿 / 发送的旧回放零回归 | `v1-core.ad` 变更前停在步骤 13 `wait id="attachment.file1"`、`v1-workspaces.ad` 停在步骤 9 `wait id="chat.attach"`；变更后停在与变更前完全相同的步骤与选择器（`replay-compare.json` 中 base 与 new 两组同点发散）；[对比](evidence/replay-compare.json) |

设备与前置：iPhone Air / iOS 26.5 模拟器（`557AF636-76C2-4D56-8FAE-5B4B0473665D`）、`ChattyFixture` 新装、全新 `scripts/ios-fixture.py`（8765 已被其他进程占用，本轮按 `ios/README.md` 的 `CHATTY_FIXTURE_PORT` 约定用 8791 / 8792 独立实例，未终止任何非本次运行的进程）。

## 未机器验证、需要人工确认的两项

1. **真机 / 模拟器上的中文输入法手输**：本轮尝试用 `defaults write com.apple.Preferences AppleKeyboards`（`zh_Hans@sw=Pinyin-Simplified`）给模拟器加拼音键盘，结果该键值使软件键盘不再加载；已删除该键并在重启模拟器后确认键盘恢复（上表「点击输入框可聚焦」「回车键 = send 键」两项即恢复后采集）。因此「组词中的回车只上屏候选词」目前由宿主 XCTest 用真实 `UITextView` + `setMarkedText` + 真实 delegate 覆盖（可复跑），模拟器上按屏幕键盘逐键组词的目视确认仍需人工做一次，或后续用 Settings 界面手动加键盘后补。
2. **硬件键盘 `⇧↵` 手动换行**：实现为 `ComposerTextView.pressesBegan` 识别 `⇧`+回车后放行换行；本机自动化无法合成硬件键盘事件，未机器验证。需在接键盘的 iPad/iPhone 上确认一次：`↵` 发送、`⇧↵` 换行、`⌘↵`（菜单「发送」）与 `⌘F`（聚焦输入框）保持既有行为。

## 需要 Benjamin 决定的一项：回车键键帽文案

软键盘回车键已变成系统 send 键，键帽文字跟随 app 本地化。当前 app 只有英文本地化（Info.plist `CFBundleDevelopmentRegion` 为 en、无 `zh-Hans.lproj`），因此模拟器上键帽显示英文 **send**（该 app 的其他系统文案同样是英文：Emoji / space / delete）。若要键帽显示「发送」，需要给 app 增加 zh-Hans 本地化（`CFBundleLocalizations` + `zh-Hans.lproj`），这属于 app 级本地化配置、超出本 Issue「只动输入区」的边界，本轮未改，列出供你决定。

## 旧回放（v1）的现状

`v1-core.ad` / `v1-workspaces.ad` 是 2026-09-05 会话优先导航时代的流程，当前 app 已是「动态 / Mika / 项目」三 Tab，两条流程在到达输入框之前就在 `attachment.file1` / `chat.attach` 处发散（`ios/README.md` 已标注它们「不作为新版的验收命令」）。本轮把**变更前（base 构建 + 原脚本）与变更后（new 构建 + 原脚本）**在各自全新安装上各跑一遍，发散点完全相同（`replay-compare.json`），说明本次输入区改动没有引入新回归。要让这两条流程整体通过需要把它们的选择器升级到三 Tab 界面，属独立工作量，建议另开 Issue。涉及草稿 / 发送的新行为由 `v2-composer-return.ad` 承担，本轮一次通过。

## 原始日志位置

- 构建与测试：`.tools/cle101/{fixture-build,app-build,host-tests,swift-tests}.log`
- 设备驱动：`.tools/cle101/device/*.json`、`.tools/cle101/final/*.json`
- 回放：`.tools/cle101/replay/*.json`（base/new 两组）
- 本机临时脚本（未提交）：`.tools/cle101/{build-test,device-setup,device-verify,final-check,tap-check,replay-pass,replay-only,ime-probe,keyboard-restore}.sh`
- agent-device 诊断：`/Users/benjamin/.agent-device/sessions/cle101*/`
