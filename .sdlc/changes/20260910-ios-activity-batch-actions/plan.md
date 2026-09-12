# 实施计划与落地位置

## 分层

纯策略与传输分开，让批量语义可以在没有服务端的情况下被测试：

| 单元 | 位置 | 职责 |
| --- | --- | --- |
| `SelectionSet` | `ios/Packages/ChattyKit/Sources/ChattyCore/BatchOperations.swift` | 本机选择集：切换、全选、按当前页裁剪 |
| `IssueBatchUpdate` | 同上 | `updates` 请求体构造，`hasMutation` 与服务端短路条件一致 |
| `BatchAccumulator` / `BatchResult` | 同上 | 每批 `{"updated": N}` 折叠成成功 / 未生效 / 失败与可重试批次 |
| `BatchChunking` | 同上 | 保序去重，按 20 条分批 |
| `ActivityModel.batchUpdate` / `retryLastBatch` | `ios/Packages/ChattyKit/Sources/ChattyCore/ActivityModel.swift` | 顺序提交分批、失败分类、提交后强制刷新与已读收敛 |
| `ActivityScreen` | `ios/Chatty/ActivityScreen.swift` | 选择态、底部操作栏、结果横幅、无障碍与键盘 |

## 关键决策

- **只有 `{"updated": N}`，没有逐条回执。** 服务端静默跳过无法解析或无权的 id，因此 `skipped` 只能是聚合值，重试以「整批」为单位；状态写入幂等，重复提交不会二次生效。
- **不做乐观更新。** 提交后 `refresh(force: true)`（generation 递增，丢弃并发轮询的旧快照）从服务端重新读取两个列表与计数，再按刷新后的指纹标记已读；否则状态变更会立刻让指纹失配、红点重生。
- **全部未生效不标记已读。** 只有至少一条真正写入的批次才把该批行标为已读，失败不能顺带清掉红点。
- **提交期间拒绝重复提交。** `batching` 门闩在 `await` 之前置位，第二个提交直接返回 nil，网络层不会收到第二次写。
- **行只有一种视图类型。** 原先在选择态用 `Button`、浏览态用 `NavigationLink`，退出选择态后同一行身份留下陈旧的辅助功能节点（标签退化成 identifier 并保留选中特征）。改为始终使用 `Button`，浏览态经由 `navigationDestination(item:)` 入栈，既消除陈旧节点，也保持普通浏览零回归。
- **底部栏容器不再带 identifier。** 容器上的 `accessibilityIdentifier` 会遮蔽子按钮的 identifier；移除后子按钮标识可被自动化解析。

## 验证

```sh
swift test --package-path ios/Packages/ChattyKit --scratch-path .tools/ios-swift-build --disable-sandbox
source scripts/ios-env.sh
xcodebuild -project ios/Chatty.xcodeproj -scheme ChattyFixture -configuration Debug \
  -destination "platform=iOS Simulator,id=$IOS_SIMULATOR_ID" \
  -derivedDataPath "$CHATTY_IOS_DERIVED_DATA" CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test
```

原生交互证据用 `agent-device replay`：`tests/device/ios/v2-activity-batch.ad` 与 `v2-activity-batch-partial.ad`。

## 未改动

- `ios/Chatty.xcodeproj`：本轮未新增宿主 Swift 文件，`scripts/generate-ios-project.py` 重跑无差异。
- 版本号 / 构建号：仍为 0.1.0 (2)，未上传 TestFlight。
