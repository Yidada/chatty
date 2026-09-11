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
