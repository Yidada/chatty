# Development records

Lifecycle records live in `changes/<change-id>/`. Start with the change's
`intent.md`, `plan.md`, and `state.json` when present. Repository-wide development
instructions are in [the workflow guide](../docs/sdlc-workflow.md).

## Current records

- [iOS V1](changes/20260905-complete-ios-v1-native-client-p1-through-p5/intent.md):
  [execution plan](changes/20260905-complete-ios-v1-native-client-p1-through-p5/plan.md),
  [original design proposal](changes/20260905-complete-ios-v1-native-client-p1-through-p5/design-plan.md),
  [progress](changes/20260905-complete-ios-v1-native-client-p1-through-p5/progress.md).
  The execution plan defines the implementation work; the design proposal preserves
  the original scope and design rationale. The recorded lifecycle remains Test.
- [iOS P0](changes/20260905-ios-p0-native-foundation-and-fixture-device-loop/intent.md):
  completed foundation work and its own `evidence/p0/` records.
- [iOS 动态与 Mika 连续发送](changes/20260910-ios-activity-mika-flow/intent.md):
  动态 / Mika / 项目三页导航、工作区全量事项进展、已读红点与待处理，以及 Mika 连续交办。
- [iOS 动态批量处理](changes/20260910-ios-activity-batch-actions/intent.md):
  [执行计划](changes/20260910-ios-activity-batch-actions/plan.md)、
  [验证记录](changes/20260910-ios-activity-batch-actions/evidence.md)。
  多选、批量已读，以及待处理页批量验收完成 / 退回待办（`POST /api/issues/batch-update`）。
- [iOS 动态逐行滑动操作](changes/20260911-ios-activity-row-swipe/intent.md):
  [执行计划](changes/20260911-ios-activity-row-swipe/plan.md)、
  [验证记录](changes/20260911-ios-activity-row-swipe/evidence.md)。
  两个列表的逐行左滑 / 右滑动作，共用同一套动作定义并复用批量通路；含全滑策略、选择态禁用、
  指针菜单与 iPad 常规宽度证据。本轮同时把 CLE-85 的批量层重新落到最新 `main`。
- [Android native experience](changes/20260905-native-experience-without-multica-web-exits/intent.md).
- [Android V3 performance baseline](changes/20260906-android-v3-performance-baseline/intent.md):
  migrated baseline preparation and samples. The migration does not create new
  approvals or change the acceptance status recorded in the intent and results.
- [iOS dynamic feed and continuous Mika send](changes/20260910-ios-activity-mika-flow/intent.md):
  implementation and its own `evidence/` records.
- [iPad / iPadOS adaptive design](changes/20260910-ios-ipad-adaptive/intent.md):
  [design specification](changes/20260910-ios-ipad-adaptive/spec.md),
  [implementation split](changes/20260910-ios-ipad-adaptive/plan.md),
  [verification](changes/20260910-ios-ipad-adaptive/evidence.md). Design stage
  only; no product code change is included.

## Historical records

[Android V1](archive/iterations/v1/intent.md) and
[Android V2](archive/iterations/v2/intent.md) retain their historical plans,
acceptance records and evidence. Archiving is a storage decision; it does not
mark unfinished acceptance checks as passed.

## Layout migration — 2026-09-09

| Previous location | Current location |
| --- | --- |
| `iterations/v1/`, `iterations/v2/` | `archive/iterations/v1/`, `archive/iterations/v2/` |
| `iterations/v3/` | `changes/20260906-android-v3-performance-baseline/` |
| `iterations/ios-v1/plan.md` | iOS V1 change's `design-plan.md` |
| `iterations/ios-v1/evidence/p0/` | iOS P0 change's `evidence/p0/` |
| Other iOS V1 reports and evidence | iOS V1 change directory |
| `iterations/ios-v1/flows/` | `tests/device/ios/` at the repository root |

Raw logs, JSON evidence, source manifests and lifecycle state files retain their
original bytes, including historical paths and approval fingerprints. Resolve old
paths with this table; do not interpret them as current runnable commands.
Documentation links and executable paths use the new locations. Existing approval
fingerprints describe the original approved documents, before path-only edits.
