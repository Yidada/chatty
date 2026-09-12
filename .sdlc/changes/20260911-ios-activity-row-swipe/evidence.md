# 验证记录

环境：Xcode 26.6 / iOS 26.5 Simulator / Swift 6.3.3。
原生交互证据机：iPhone Air（iOS 26.5，420×912 pt，紧凑宽度）与 iPad Pro 11-inch (M5)
（iOS 26.5，834×1210 pt，侧栏-详情，常规宽度）。
合成服务：`scripts/ios-fixture.py`，本轮回放用 `CHATTY_FIXTURE_PORT=8777` 独立实例
（同一台机器上 8765 已被另一个任务占用），先 `POST /__control {"activity_scenario":true}`。

## 1. Swift 测试

```
swift test --disable-sandbox --package-path ios/Packages/ChattyKit --scratch-path .tools/ios-swift-build
→ Executed 72 tests, with 0 failures
```

新增 `ActivityRowActionsTests`（6 项）覆盖动作映射：每个列表的 leading / trailing 种类与标题、
`ordered` 顺序、只有 `markRead` 允许全滑、`done` / `todo` 请求体字段与强调色、VoiceOver 镜像
名称与手势名称一致、identifier 唯一。

新增 `ClientFlowTests` 两项：

- `testActivityRowSwipeSubmitsTheSharedActionBodyAndReportsASilentSkip`：单行滑动与批量走同一
  端点与同一请求体（`{"issue_ids":["i0"],"updates":{"status":"done","suppress_run":true}}`），
  服务端静默跳过时 `updated: 0`、`skipped: 1`、非成功、可重试，重试请求体与首次完全一致。
- `testActivityRowMarkUnreadRestoresTheRedDotAndOnlyCountsRealChanges`：已读 / 未读往返，
  重复写入返回 0、不发任何请求、`hasAttention` 恢复。

日志：`evidence/swift-tests.log`。

iOS 宿主 XCTest（`ChattyFixture` scheme）：

```
xcodebuild … -scheme ChattyFixture … test
→ Executed 8 tests, with 1 test skipped and 0 failures · ** TEST SUCCEEDED **
```

日志：`evidence/ios-host-tests.log`。

## 2. 原生交互（`tests/device/ios/v2-activity-row-swipe.ad`）

```
agent-device replay tests/device/ios/v2-activity-row-swipe.ad --session iphone --device "iPhone Air"
→ Replayed 46 steps in 27.5s
```

覆盖「两个列表 × 两个方向 + 全滑策略 + 选择态禁用」，全部以语义 id / 文案断言：

| 截图 | 断言到的状态 |
| --- | --- |
| `01-recent-trailing-reveal.png` | 新进展左滑滑出 `activity.swipe.markRead.i3` |
| `02-recent-marked-read.png` | 文案「已标记「Issue 04」为已读。」，该行红点消失 |
| `03-recent-leading-reveal.png` | 新进展右滑滑出 `activity.swipe.markUnread.i3` |
| `04-recent-marked-unread.png` | 文案「已恢复「Issue 04」的未读标记。」，红点回来 |
| `05-pending-list.png` | 待处理列表初始状态（i0 / i54） |
| `06-pending-trailing-reveal.png` | 待处理左滑滑出 `activity.swipe.complete.i54` |
| `07-pending-complete-success.png` | 文案「已提交 1 项，全部成功。」 |
| `08-pending-full-swipe-not-executed.png` | 待处理行从最右拖到最左**只展开按钮**，动作未执行 |
| `09-pending-leading-reveal.png` | 待处理右滑滑出 `activity.swipe.returnToTodo.i0` |
| `10-pending-return-success.png` | 文案「已提交 1 项，全部成功。」 |
| `11-selection-swipe-disabled.png` | 选择态下横拖后不存在任何 `activity.swipe.*` 元素，选择态仍为激活 |

回放日志：`evidence/replay-swipe.log`。

## 3. 服务端审计（证明与批量同源）

`evidence/api-audit.json`（干净实例，只跑了一次本轮回放）中 `u1:fixture` 作用域：

```
batch_writes:
  {"issue_ids":["i54"],"updates":{"suppress_run":true,"status":"done"},"updated":1,"skipped":[]}
  {"issue_ids":["i0"], "updates":{"suppress_run":true,"status":"todo"},"updated":1,"skipped":[]}
issue_writes: []
```

即：两次状态变更都走 `POST /api/issues/batch-update`（与 CLE-85 完全相同的请求体），
没有一次走单条 `PUT/PATCH` 通路；两次「已读 / 未读」在审计里**完全没有**对应请求。

## 4. 指针入口

- `12-pointer-menu-recent.png`：新进展行长按 / 右键菜单为「标记已读、标为未读、更改状态、复制链接」。
- `13-pointer-menu-pending.png`：待处理行长按 / 右键菜单为「验收完成、退回待办、更改状态、复制链接」。

与滑动动作同名同源；待处理行不再出现与「验收完成」重复的「验收通过」。

## 5. iPad 常规宽度

- `14-ipad-regular-full-swipe-read.png`：iPad 上对已读行全滑（`allowsFullSwipe`）直接执行，
  出现「已标记「Issue 04」为已读。」
- `15-ipad-regular-trailing-reveal.png`：较短横拖滑出「标记已读」按钮。
- `16-ipad-regular-pending-trailing.png` / `17-ipad-regular-pending-leading.png`：待处理行
  两侧方向都能滑出按钮。

紧凑宽度由 iPhone Air 的回放覆盖（同一份代码路径；`WorkspaceTabs` 用 `.tabViewStyle(.sidebarAdaptable)`，
紧凑宽度即 iPhone 的 Tab 布局）。

## 6. 零回归

CLE-85 的批量回放原样重跑通过：

```
agent-device replay tests/device/ios/v2-activity-batch.ad --device "iPhone Air"
→ Replayed 25 steps in 14.9s
```

日志：`evidence/replay-batch-regression.log`。这条曾经在列表容器改成 `List` 后失败过一次
（`ContentUnavailableView` 在列表行里塌陷，「当前没有待处理事项」不再出现），修复后重跑通过；
修复细节见 `plan.md`。

## 7. 未验证 / 留给人工

- **VoiceOver 旁白走查没有做成。** 自定义动作按实现挂上了（`ActivityScreen.swift` 的
  `.accessibilityAction(named:)`，名称来自被单测固定的 `ActivityRowActions`），但这台机器上
  无法产出旁白实证：iOS 模拟器没有 `simctl` 级 VoiceOver 开关，而 `agent-device snapshot
  --actions`（读 iOS 模拟器的 `UIAccessibilityCustomAction`）对本页 52 个合并元素读了 12 个，
  都没有列出这两条动作，因此**不能**用它的空结果断言自定义动作不存在，也不能用它当旁白证据。
  复核命令：`agent-device snapshot -i --actions`。
  真实旁白走查需要人工在模拟器 / 真机上开启 VoiceOver 后转一次行元素，属 CLE-92（D 阶段，
  已 cancelled）原本的范围。
- **键盘路径**：行级动作通过右键菜单（Full Keyboard Access 下等同系统「显示菜单」动作）与
  选择态批量栏（⌘A 全选 + 回车）可达，但本轮没有做键盘专项回放。
- 触摸板 / Pencil 未单独走查；`hoverEffect` 与 `contextMenu` 沿用 CLE-90 的实现，未改动。
