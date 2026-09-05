# Chatty v2 — Android execution issues

> Stage 3 artifact. This file freezes the repository-level execution plan derived from
> `iterations/v2/spec.md` §§11–14 and the live Multica child issues of parent CLE-57.

## Execution policy

- Promote only the issue in the current stage. Every later stage stays in `backlog`
  until the preceding stage has met its acceptance criteria and landed.
- Do not implement two stages against this repository concurrently. Each stage builds
  on the merged result of the preceding stage; one active implementation branch at a
  time is the default.
- Multica is the source of truth for issue status and assignment. The status values
  below are a 2026-09-05 planning snapshot, not a replacement for Multica.
- M0 is documentation-only. It does not start any M1–M10 Android implementation.
- Each implementation issue must land independently with its own verification evidence.
  Stage 11 is the final Pixel 6 Pro/Appium gate before the Stage 4 delivery summary.

## Platform gaps that constrain V1

These are real platform gaps, not Chatty features that can be completed by renaming a
workaround:

1. **No structured Approval/Decision API.** V1 may render a “需要你回复” card only
   when the existing `agent_blocked` task reason, blocked issue category, and inbox
   activity agree. Its action opens a normal reply composer. It must not claim that an
   approve/reject decision was recorded server-side.
2. **No FCM/APNs push channel.** V1 uses 15–30 minute WorkManager polling plus a
   foreground reconnect/refetch for eventual convergence. Notifications can be delayed;
   this is not true push and must not be presented as such.

These constraints carry through implementation, EVAL, and hardening, as required by
`spec.md` §§6.3, 8.3–8.4, 10, and 12–14.

## Stage overview

| Stage | Milestone | Multica issue | UUID | Owner | Priority | Snapshot status | Spec grouping |
|---:|---|---|---|---|---|---|---|
| 1 | M0 — freeze the execution plan | CLE-68 | `01a06d29-09d6-7e03-942b-f63f1b5bfbdb` | 全能极客开发者 (`534c5e31-f4e6-4b68-b6cb-7287b62ae28a`) | High | blocked | Stage 3 artifact |
| 2 | M1 — Kotlin/Compose foundation | CLE-67 | `01a06d28-d228-7f04-bd2b-ef1ca59e268a` | Android 开发助手 (`c8705a20-7aff-4fbe-aae7-f9cfcdecfb65`) | High | backlog | Stage A shell foundation |
| 3 | M2 — auth and workspace | CLE-63 | `01a06d28-ccfe-733f-b514-72af274b67ca` | Android 开发助手 (`c8705a20-7aff-4fbe-aae7-f9cfcdecfb65`) | High | backlog | Stage A — Auth + shell |
| 4 | M3 — Mika chat core | CLE-62 | `01a06d28-c76b-728e-b918-84330f217f77` | Android 开发助手 (`c8705a20-7aff-4fbe-aae7-f9cfcdecfb65`) | High | backlog | Stage B — Chat core |
| 5 | M4 — foreground WebSocket | CLE-61 | `01a06d28-c72e-77aa-9783-c42a43f20f1a` | Android 开发助手 (`c8705a20-7aff-4fbe-aae7-f9cfcdecfb65`) | High | backlog | Stage B — Chat core |
| 6 | M5 — task/agent/runtime status | CLE-59 | `01a06d28-c70a-7af3-9ef9-cf1263079727` | Android 开发助手 (`c8705a20-7aff-4fbe-aae7-f9cfcdecfb65`) | High | backlog | Stage C — Status + Evidence |
| 7 | M6 — Evidence, Inbox, reply card | CLE-60 | `01a06d28-c70e-7e92-88c6-ebe1011cff19` | Android 开发助手 (`c8705a20-7aff-4fbe-aae7-f9cfcdecfb65`) | High | backlog | Stages C/D — Evidence + Inbox |
| 8 | M7 — Agent Fleet and deep links | CLE-58 | `01a06d28-c706-7198-bbea-6835be462633` | Android 开发助手 (`c8705a20-7aff-4fbe-aae7-f9cfcdecfb65`) | Medium | backlog | Stage E — Agent Fleet + deep links |
| 9 | M8 — voice transcription | CLE-64 | `01a06d28-cd44-7d3b-9390-bc3954cb7a7c` | Android 开发助手 (`c8705a20-7aff-4fbe-aae7-f9cfcdecfb65`) | High | backlog | Chat/acceptance criterion 2 |
| 10 | M9 — background convergence | CLE-65 | `01a06d28-cf40-7105-80df-3608ebda074d` | Android 开发助手 (`c8705a20-7aff-4fbe-aae7-f9cfcdecfb65`) | High | backlog | Stage F — Background convergence |
| 11 | M10 — device/Appium acceptance | CLE-66 | `01a06d28-d0f8-79ce-88a8-0b50356350bc` | Android 开发助手 (`c8705a20-7aff-4fbe-aae7-f9cfcdecfb65`) | High | backlog | Stage G — adb + Appium acceptance |

## Stage 1 — M0: freeze the Android execution plan (CLE-68)

**Depends on:** merged PR #1, completed CLE-56, and the Stage 2–11 child
issues existing in `backlog`.

**Acceptance criteria**

- `iterations/v2/ISSUES.md` exists and lists every child issue and stage.
- README Status points to Stage 3 and `iterations/v2/ISSUES.md`.
- The plan remains consistent with `spec.md` §§11–14.
- A reviewable PR contains CLE-68 and `Closes CLE-68`.

**Verification**

```bash
test -f iterations/v2/ISSUES.md
rg -n "Stage 3|ISSUES.md|CLE-" README.md iterations/v2/ISSUES.md
git diff --check
```

## Stage 2 — M1: Kotlin/Compose foundation (CLE-67)

**Depends on:** Stage 1 `ISSUES.md` accepted.

**Scope:** create the Gradle wrapper and Android application baseline; freeze the
application ID, SDK levels, and version strategy; create `app`, `core-network`,
`core-auth`, `core-model`, `feature-chat`, `feature-status`, `feature-approval`,
`feature-inbox`, `feature-agents`, and `feature-issue-link`; add Compose Material 3,
Coroutines/Flow, Hilt, Retrofit/OkHttp, JSON serialization, navigation, theme, and test
scaffolding. Do not connect real Multica features yet.

**Acceptance criteria**

- Debug APK, unit tests, and lint pass.
- The APK installs and launches through the existing dev loop without crashing.
- Module dependency direction matches the Spec; features do not depend backwards and
  server entities are not copied into a local database.

**Verification**

```bash
cd android && ./gradlew :app:assembleDebug test lint
```

## Stage 3 — M2: auth, secure token storage, workspace selection (CLE-63)

**Depends on:** M1 foundation complete.

**Scope:** implement two-step email-code login, Keystore-backed encrypted JWT storage,
logout and 401 semantics, workspace selection/restoration, Bearer JWT plus
`X-Workspace-Slug` injection, and typed DTO/error parsing. Document the residual risk
that the 30-day token has no per-session revocation or device binding.

**Acceptance criteria**

- A successful session and workspace selection survive app restart.
- A real 401 returns to login; timeout and 5xx failures do not erase credentials.
- Tokens never enter logs, plaintext preferences, screenshots, or the repository.

**Verification**

```bash
cd android && ./gradlew :core-auth:test :core-network:test :app:assembleDebug lint
```

## Stage 4 — M3: Mika chat core (CLE-62)

**Depends on:** M2 auth and workspace foundation complete.

**Scope:** open Mika by default, support required per-agent conversation references,
use cursor pagination, send messages, anchor pending UI to the server `task_id`, and
render the final complete message. Do not simulate token streaming. Cover loading,
empty, retry, 403, and 5xx states.

**Acceptance criteria**

- A real workspace can send text to Mika and receive the final response.
- Pagination, duplicate-send protection, and server refetch after process restart have tests.
- Server messages are not persisted as a second local source of truth.

**Verification**

```bash
cd android && ./gradlew :feature-chat:test :core-network:test :app:assembleDebug lint
```

## Stage 5 — M4: foreground WebSocket convergence (CLE-61)

**Depends on:** M3 REST chat core complete.

**Scope:** implement one OkHttp user WebSocket at `GET /ws`, auth/auth_ack, lifecycle,
and exponential backoff; process chat, task, issue, agent, and runtime events; render
thinking/tool activity progressively; retain unknown event payloads in Generic Activity;
and precisely invalidate/refetch feature data after reconnect. Do not assume missed-event
replay.

**Acceptance criteria**

- A real chat converges from queued/running state to the final response.
- Disconnect/reconnect creates no duplicate socket, duplicate message, or permanent pending state.
- Unknown events neither crash the app nor interrupt task presentation.

**Verification**

```bash
cd android && ./gradlew :core-network:test :feature-chat:test :app:assembleDebug lint
```

## Stage 6 — M5: task, agent, and runtime status (CLE-59)

**Depends on:** M4 realtime event layer complete.

**Scope:** map persistent task and agent states, port Multica `derive-health` thresholds,
show elapsed time, update age, and retry attempt, and communicate that roughly 150-second
offline detection and three-hour failure grace are not instantaneous. Show “waiting for
original Runtime”; do not imply automatic failover.

**Acceptance criteria**

- State transitions, `recently_lost`/`long_offline` boundaries, and retry attempt have
  deterministic tests.
- A real delegated task card updates through WebSocket and REST state changes.

**Verification**

```bash
cd android && ./gradlew :feature-status:test :core-model:test :app:assembleDebug lint
```

## Stage 7 — M6: Evidence, Inbox, and “需要你回复” (CLE-60)

**Depends on:** M5 status cards complete.

**Scope:** render attachment Evidence cards, use persistent authenticated
`markdown_url` values, deduplicate attachments, filter archived inbox entries, dedupe by
issue, and derive the “需要你回复” surface from the three existing signals. Its primary
action opens a reply composer; there are no fabricated approve/reject endpoints.

**Acceptance criteria**

- Attachment dedupe, download failure, unknown type, and all true/false combinations of
  the three signals have tests.
- Appium can open Evidence and navigate from “需要你回复” to the composer.

**Verification**

```bash
cd android && ./gradlew :feature-inbox:test :feature-approval:test :feature-status:test :app:assembleDebug lint
```

## Stage 8 — M7: Agent Fleet and web deep links (CLE-58)

**Depends on:** M2 auth and M5 status model complete.

**Scope:** use the richest available presence endpoint for Agent identity/status/activity;
build workspace-scoped HTTPS URLs for Issue, Runtime, and Agent pages; render
`mention://` references without treating them as external system deep links; and provide
failure UI for forbidden/missing objects and unavailable browsers.

**Acceptance criteria**

- The Agent list matches Multica CLI results for the same workspace.
- Issue, Runtime, and Agent links open the correct web pages.

**Verification**

```bash
cd android && ./gradlew :feature-agents:test :feature-issue-link:test :app:assembleDebug lint
```

## Stage 9 — M8: long-press voice transcription (CLE-64)

**Depends on:** M3 chat composer complete.

**Scope:** request `RECORD_AUDIO` on first long press, use Android `SpeechRecognizer`
with offline recognition preferred, disclose the Google-hosted privacy boundary before
online fallback, keep audio out of Multica, and send only editable text through the normal
message path. Handle cancellation, timeout, recognition failure, rotation, and lifecycle
interruption.

**Acceptance criteria**

- Transcribed text can be edited and sent; permission denial and recognition failure do
  not lose an existing draft.
- Appium or reproducible device steps cover long press, editing, and sending.

**Verification**

```bash
cd android && ./gradlew :feature-chat:test :app:assembleDebug lint
```

## Stage 10 — M9: background convergence and offline strategy (CLE-65)

**Depends on:** M4 WebSocket and M6 Inbox/“需要你回复” complete.

**Scope:** keep WebSocket foreground-only; use idempotent 15–30 minute WorkManager
polling for unread summary and active task state in the background; post deduplicated
local notifications for unseen action-required items; reconnect and refetch on foreground
resume; define 401, 403, timeout, 5xx, Doze, offline, and duplicate-worker behavior.
Never claim FCM/APNs push support.

**Acceptance criteria**

- State converges to server truth after backgrounding, network recovery, and cold start.
- Workers are idempotent, do not duplicate notifications, and do not incorrectly clear tokens.

**Verification**

```bash
cd android && ./gradlew :core-network:test :feature-inbox:test :app:assembleDebug lint
```

## Stage 11 — M10: Pixel 6 Pro and Appium acceptance (CLE-66)

**Depends on:** M1–M9 complete and merged.

**Scope:** on Pixel 6 Pro, validate Mika chat, long-press transcription/edit/send, real
delegation and state transitions, the “需要你回复” approximation, Evidence, process
restart convergence, real Agent Fleet state, and the complete Appium flow.

**Acceptance criteria**

- Intent success criteria 1–8 each have a command, conclusion, and independent evidence
  path under `iterations/v2/evidence/`.
- Screenshots and logs do not overwrite older evidence.
- Failures remain explicit and move to EVAL/HARDENING with reproduction commands; verbal
  PASS statements are not evidence.
- Produce the Stage 4 implementation-delivery summary and recommendation for Stage 5 EVAL.

**Verification**

```bash
cd android && ./gradlew :app:assembleDebug test lint
scripts/dev-loop.sh android/app/build/outputs/apk/debug/app-debug.apk <applicationId> <mainActivity>
scripts/appium-ui.sh "<expected Mika reply>" "<action text>"
```

## Stage 3 exit and implementation entry

After this artifact is reviewed and merged, promote **only Stage 2 / CLE-67** from
`backlog`. Keep CLE-63, CLE-62, CLE-61, CLE-59, CLE-60, CLE-58, CLE-64, CLE-65, and
CLE-66 in `backlog`. Subsequent stages advance serially only after their declared
dependencies and verification commands pass.
