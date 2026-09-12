# 验证记录

- 变更范围：见 [intent.md](intent.md)；实现位置与决策见 [plan.md](plan.md)。
- 结构化审计（两次原生流程、服务端实际收到的批量写、测试计数）：[evidence/api-audit.json](evidence/api-audit.json)。
- 本机 8765 / 8766 / 8767 已被其他进程占用，按 `ios/README.md` 的 `CHATTY_FIXTURE_PORT` 约定把合成服务与 Fixture 应用同时切到 8791，未终止任何非本次运行的进程。

## 单元与宿主测试

| 检查 | 结果与证据 |
| --- | --- |
| Swift 核心 | 51 项通过，0 失败（改动前 42 项）；[原始输出](evidence/swift-tests.log) |
| 新增用例 | `BatchOperationsTests` 覆盖选择集切换 / 全选 / 按页裁剪、请求体只含目标字段与 `suppress_run`、分块 20/20/5 保序、跳过与失败分开计数、服务端超报被夹紧、`updated: 0` 不算成功 |
| 模型级用例 | `ClientFlowTests` 覆盖批量验收后两个列表与计数按服务端收敛、按刷新后指纹标记已读且可持久、整批跳过如实上报并可重试、整批失败不改本地行、45 项分 3 批、在途期间第二次提交与重试被拒绝且只发出一次写 |
| 原生 iOS 宿主 | iPhone Air / iOS 26.5（服务端端口 8791）：5 通过，0 失败，1 跳过（模拟器不暴露物理文件保护属性）；[原始输出](evidence/simulator-tests.log) |
| 构建 | `ChattyFixture` Debug 通过；`scripts/generate-ios-project.py` 重跑后 `ios/Chatty.xcodeproj` 无差异 |

## 原生交互证据（agent-device replay）

全部流程都在**全新 fixture 实例 + 全新安装的 Fixture 应用**上运行，断言用精确文本 `wait`。

### 1. 全部成功路径 `tests/device/ios/v2-activity-batch.ad`

25 步全部通过，无自动修复步骤；[replay 结果](evidence/batch-replay.json)。

| 断言 | 结果 |
| --- | --- |
| 进入选择态后底部栏出现，逐条勾选 `activity.issue.i0` → `已选 1 项` | 通过；[截图](evidence/01-selection-mode.png) |
| 批量已读 → `已标记 1 项为已读。`，退出选择态后该行不再显示红点 | 通过；[截图](evidence/02-batch-read-note.png) |
| 待处理页「全选」→ `已选 2 项` | 通过；[截图](evidence/03-pending-select-all.png) |
| 「验收完成」→ `已提交 2 项，全部成功。` | 通过；[截图](evidence/04-batch-done-success.png) |
| 待处理转为 `当前没有待处理事项` | 通过 |

服务端审计只收到一次批量写，且没有逐条 PUT：

```json
{"issue_ids": ["i0", "i54"], "updates": {"status": "done", "suppress_run": true}, "updated": 2, "skipped": []}
```

### 2. 部分未生效与重试 `tests/device/ios/v2-activity-batch-partial.ad`

夹具用 `batch_skip: ["i0"]` 让服务端静默跳过一条（与真实 handler 的 `continue` 一致）。17 步全部通过；[replay 结果](evidence/batch-partial-replay.json)。

| 断言 | 结果 |
| --- | --- |
| 提交 2 项 → `已提交 2 项：成功 1，未生效 1。`，不出现「全部成功」 | 通过；[截图](evidence/06-batch-partial-result.png) |
| 结果横幅提供 `重试未完成 1 项`，重试后仍如实显示 `成功 1，未生效 1` | 通过；[截图](evidence/07-batch-partial-retry.png) |

服务端审计两次请求都只写入 1 条，且明确列出被跳过项；重试提交的仍是同一批 id，未把已生效行重复提交为新写：

```json
[{"issue_ids": ["i0", "i54"], "updated": 1, "skipped": ["i0"]},
 {"issue_ids": ["i0", "i54"], "updated": 1, "skipped": ["i0"]}]
```

### 3. 普通浏览零回归

选择态改造后点击 `activity.issue.i1` 仍进入事项详情（`现在的情况` / `和 Mika 继续` / `目标与记录`），[截图](evidence/08-browse-mode-detail.png)。

## 本轮发现并修复的缺陷

- 选择态用 `Button`、浏览态用 `NavigationLink` 会让同一行身份在退出选择态后留下陈旧的辅助功能节点：行标签退化为 `activity.issue.i0` 并保留「已选中」特征。改用单一 `Button` + `navigationDestination(item:)` 后消失，同时保留选择态不导航的语义。
- 底部操作栏容器上的 `accessibilityIdentifier` 会遮蔽内部按钮的 identifier，自动化无法定位；移除容器标识后 `activity.batch.read` / `activity.select.all` / `activity.batch.count` 均可解析。两处都是无障碍层面的修正，不是测试专用开关。

## 未执行

- 未上传 TestFlight、未改版本号 / 构建号（仍为 0.1.0 (2)）；是否出包待 Benjamin 确认。
- 未做 VoiceOver 人工走查与真机体验，未做 iPad 常规宽度 / Stage Manager 实机验证（属 CLE-84 实现阶段）。
