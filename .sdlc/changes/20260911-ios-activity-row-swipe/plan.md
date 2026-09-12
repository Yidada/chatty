# 实施计划与落地位置

## 分层

动作定义与传输分开：动作表是纯策略，可脱离服务端与界面测试；请求体与结果折叠继续复用
CLE-85 的批量通路。

| 单元 | 位置 | 职责 |
| --- | --- | --- |
| `ActivityFeedList` / `ActivityRowAction` / `ActivityRowActions` | `ios/Packages/ChattyKit/Sources/ChattyCore/ActivityRowActions.swift` | 每个列表的 leading / trailing 一对动作：标题、图标、强调色、是否允许全滑、对应的批量请求体 |
| `IssueBatchUpdate` / `BatchAccumulator` / `BatchResult` / `BatchChunking` | `ios/Packages/ChattyKit/Sources/ChattyCore/BatchOperations.swift`（CLE-85，本轮重新落到 main） | `updates` 请求体、`{"updated": N}` 折叠、按 20 条分批 |
| `ActivityModel.markRead(ids:)` / `markUnread(ids:)` | `ios/Packages/ChattyKit/Sources/ChattyCore/ActivityModel.swift` | 本机已读指纹写入 / 清除，返回**真正发生变化**的条数 |
| `ActivityModel.batchUpdate` / `retryLastBatch` | 同上（CLE-85） | 分批提交、失败分类、提交后强制重读与已读收敛 |
| `ActivityScreen` | `ios/Chatty/ActivityScreen.swift` | `List` 行、`.swipeActions`、VoiceOver 自定义动作、指针菜单、选择态禁用 |

## 关键决策

- **`.swipeActions` 只对 `List` 行生效。** 先在原来的 `ScrollView` + `LazyVStack` 上接
  `.swipeActions`，模拟器实测横拖不展开按钮，反而落到行内 `Button` 上触发了导航——正是
  验收第 3 条要防的误触。改用 `List` 后阈值、回弹、全滑策略都是系统默认值，不需要自造。
  代价是列表容器换成 `List`，因此：行高用 `.listRowInsets` + `.defaultMinListRowHeight = 0`
  保持原有 20 pt 垂直节奏；分隔线由 `List` 自带；空态 / 错误 / 加载提示移到 `List` 之外
  （在列表行里 `ContentUnavailableView` 会塌陷，导致 CLE-85 的「当前没有待处理事项」断言失败）。
- **行身份挂在行容器上。** `List` 会把一行折叠成一个辅助功能元素，identifier 挂在 cell 内部
  的 `Button` 上不会被发布；改挂在行容器后 `activity.issue.<id>` 依旧可被自动化解析，
  CLE-85 与 CLE-94 的回放都依赖它。
- **只有本地已读允许全滑。** `allowsFullSwipe` 只对 `markRead` 为 true；`done` / `todo` 一律
  滑出按钮后点按。实测：待处理行从最右拖到最左只展开按钮，服务端审计里不会多出写请求。
- **一套动作、三处消费。** `rowActions` 计算属性按当前列表取表，滑动手势按钮、VoiceOver
  自定义动作、右键菜单都从同一 `ActivityRowActions` 取值，因此三者不可能描述不同动作。
- **已读反馈只报真实变化。** `ActivityModel.store` 改为返回真正改动的条数；对已读行再次
  「标记已读」会显示「已是最新已读状态」，不谎报「已标记」。
- **选择态不挂手势。** `selecting` 为真时既不接 `.swipeActions` 也不接自定义动作，退出后恢复。
- **leading 与系统手势。** 动态页是所在 `NavigationStack` 的根（`WorkspaceTabs.swift`），
  根上没有交互式返回手势；iPad 侧栏切换是屏幕边缘手势，起点在屏幕最左侧，而行滑动从行内
  起手，两者实测不冲突（回放里 leading 均正常展开且未导航）。

## 验证

```sh
swift test --disable-sandbox --package-path ios/Packages/ChattyKit --scratch-path .tools/ios-swift-build
source scripts/ios-env.sh
xcodebuild -project ios/Chatty.xcodeproj -scheme ChattyFixture -configuration Debug \
  -destination "platform=iOS Simulator,id=$IOS_SIMULATOR_ID" \
  -derivedDataPath "$CHATTY_IOS_DERIVED_DATA" CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test
```

原生交互证据：`tests/device/ios/v2-activity-row-swipe.ad`（本轮，覆盖两个列表 × 两个方向、
全滑策略、选择态禁用），并回归跑通 CLE-85 的 `v2-activity-batch.ad`。

## 未改动

- `ios/Chatty.xcodeproj`：未新增宿主 Swift 文件，`scripts/generate-ios-project.py` 无需重跑。
- 版本号 / 构建号：保持 `0.1.0 (3)`，本 Issue 不上传 TestFlight。
