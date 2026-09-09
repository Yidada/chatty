# CLE-73: baseline and PR audit — 2026-09-06

- Latest fetched Chatty main: `e7e1c518daaabe65db2c74f7fae236cc955e6d8c`.
- Read-only Multica main: `7a438bd5b8bf39afd54259a7eb0971390e50a8ef`.
- CLE-72 result re-read in full. CLE-57 family active run list was empty; CLE-70 family contained only this CLE-73 run. This does not reserve files or rule out off-platform sessions.
- No product cache/polling/rendering changes in this PR. New build variant, benchmark module and scripts are measurement infrastructure.
- Source contracts rechecked: `server/internal/handler/chat.go:1207`, `server/pkg/db/queries/chat.sql:1012` composite timestamp/id cursor; `server/internal/realtime/hub.go:848` auth_ack. Synthetic pagination deliberately includes timestamp ties.

## PR #2 migration before closure (approved 6A)

GitHub connector confirmed #2 OPEN, unmerged, mergeable=false, head `f282942a58a1803f4f29dc345a5f4785f580f7ab`. Both changed files were compared with latest main, including all M0–M10 sections.

| Old content | Current destination / disposition |
| --- | --- |
| Eleven issue identifiers, UUIDs, stage, owner, priority | Already in main `.sdlc/archive/iterations/v2/ISSUES.md`; retain latest version |
| Per-stage scope, dependencies, acceptance, commands | Already present in each main issue section; preserve rather than replace with old translation |
| Stage barriers, one active implementation, later backlog | Main execution rules already cover these; current state requires verification, not resetting implemented stages to backlog |
| Structured Approval absent; three signals only open reply composer | Main execution rules + CLE-60 section + v2 spec; retained |
| No FCM/APNs; constrained polling 15–30 minutes; delayed notification | Main CLE-65 section + spec; retained; v3 5A separately stops unchanged 5-second polling |
| 150-second offline / 3-hour grace; no automatic failover | Main CLE-59 section; retained |
| M10 real Pixel/Appium gate independent of build success | Main CLE-66 section; retained |
| Explicit snapshot-vs-live-status distinction and spec stage grouping | Preserved below as the useful editorial omission |
| README Stage 3 pointer and “next promote M1” | Obsolete: main README is Stage 4 and main has implementation/navigation increments; do not revert |
| M7 browser deep links | Superseded by native navigation direction in main; do not reintroduce web exits |

Preserved planning context: task-list status is a dated snapshot, never a replacement for live Multica ownership/status or implementation evidence. Original spec group mapping: M1/M2 = A foundation/auth; M3/M4 = B chat; M5/M6 = C/D status/evidence/inbox; M7 = E fleet (now native screens); M8 = chat voice; M9 = F background; M10 = G device acceptance. Independent milestone validation must accompany each later PR even where the original stage label is stale. M10 remains the final device gate, and implementation acceptance is separate from release acceptance.

No missing product implementation was found in #2 (it changed only two Markdown files). The useful editorial context was pushed in `8af0506` and PR #4 before #2 was closed at 2026-09-06T03:08:01Z. GitHub confirmed state=closed, merged=false. No old branch was deleted and no issue was marked done by closure.

## PR #3 and parent lifecycle

GitHub confirmed #3 OPEN, head `178a67463024c3581eb09c2214e1e5d9fef28fab`, a single Intent file on the same main. The original closing-keyword association to CLE-70 was removed from its body on 2026-09-06: merging an Intent must not finish the V3 parent. Its commit is retained in this branch and the six approved decisions are synchronized here. The new review PR must contain no close intent for CLE-70 or CLE-73 until B0/T delivery is accepted. CLE-70 remains in_progress.
