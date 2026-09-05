## Spec: Chatty v2 — Android Client Spec (based on Multica source)

> 2026-09-05 用户确认导航调整：三个 Tab 为 Mika 单对话、按 Project 管理 Issues 进度、设置（Runtime / Agents / Squads 等）。具体页面行为以 [NAVIGATION.md](NAVIGATION.md) 为准；下文接口与数据边界继续适用。


- **Author:** Android 开发助手 (agent)
- **Status:** Reviewed — CLE-56 已完成；2026-09-05 按用户指示进入实现
- **Stage:** 2 of 6 — Spec
- **Last updated:** 2026-09-04
- **Based on:** `iterations/v2/intent.md` (Accepted 2026-09-04)
- **Source of truth for API claims:** `https://github.com/multica-ai/multica` (read-only reference; no writes made). Every claim below cites `path:line`. Anything not confirmed by source reading is marked `UNCONFIRMED`.

---

## 0. Objective

Turn the accepted v2 Intent into a spec an implementing Android engineer can build against without re-deriving Multica's API surface from scratch. Concretely:

1. Resolve all 6 Intent Open Questions with a decision, or an explicit blocker with owner and unblock condition.
2. Give the Android client a concrete tech stack, module boundary, and data-mapping for every entity Chatty renders.
3. Draw a hard line between "Multica already supports this," "Multica supports it but Chatty must adapt/derive," and "Multica does not support this — client must work around it or the platform must add it."
4. Keep Chatty a thin client: no second identity source, no second task/state source, no local re-implementation of server logic beyond what §6/§8 explicitly call out as client-owned derivation (mirrored from `packages/core`, not invented).

This spec satisfies SDLC Gate G2 (`docs/sdlc-workflow.md`): objective (this section), schedule (§11 implementation split), acceptance criteria (§12), eval plan (§13).

---

## 1. Product loop, mapped to concrete calls

Walking the Intent's 10-step "Core experience" against real endpoints:

| Step | Intent description | Concrete Multica mechanism |
|---|---|---|
| 1–2 | User speaks, transcript editable before send | Client-only (§7). No Multica API involved until send. |
| 3 | Client submits to Multica; Mika understands intent | `POST /api/chat/sessions/{sessionId}/messages` against the session bound to Mika's `agent_id` (`server/internal/handler/chat.go:832-1020`). Response carries `task_id` immediately (`chat.go:809-830`) — this is the anchor for the optimistic "pending" state, not a client-generated id. |
| 4 | Mika creates/locates a Task, delegates | Server-side dispatch; client sees it as `task:queued` → `task:dispatch` events (`server/pkg/protocol/events.go:35`) and, if the delegated work is issue-shaped, a new/updated `Issue` via `issue:*` events. |
| 5 | Target agent starts a Harness Session on its Runtime | Not client-visible in structured form — client sees `task:running` (`events.go:36`) and `task:message` trace entries (`server/internal/handler/messages.go:187-198`, type `text/thinking/tool_use/tool_result/error`). |
| 6 | User closes app; task continues | No client action needed — task execution is entirely server/daemon-owned (§5). |
| 7 | Status card updates: Agent · Harness · Runtime · state | Agent presence: `ListSquadMemberStatus` 5-bucket derivation (`server/internal/handler/squad.go:629-647`) or per-agent `agent.status` (`idle/working/blocked/error/offline`, `server/migrations/001_init.up.sql:44`). Runtime: `agent_runtime.status` (`online/offline` only, `server/migrations/004_agent_runtime_loop.up.sql:8`) plus derived `deriveRuntimeHealth` (`packages/core/runtimes/derive-health.ts:14-29`). |
| 8 | Approval Card on risky action | **No structured approval object exists in Multica** (§4.1). Chatty must approximate — see §6.3. Flagged as Open Question #7 (new), blocking a *faithful* Approval Card, not the whole loop. |
| 9 | Evidence (build result, screenshots, logs) returns to chat | **No distinct "Evidence" entity** (§4.2). Agent output reaches the user as ordinary comment/chat attachments (`POST /api/upload-file`, `server/internal/handler/file.go:377`) or as chat message content. Chatty renders attachments as Evidence cards; the underlying object is a plain `Attachment`. |
| 10 | User confirms; Mika closes the loop in the same conversation | Reply is just another chat message (step 3) or issue comment reply; no separate "close" API. |

**Conclusion:** steps 1–7 and 9–10 are directly supported by existing Multica surface. Step 8 (Approval) needs a client-side approximation documented in §6.3, and background delivery in step 6/7 (push after app close) has a platform-side gap documented in §8.4.

---

## 2. Android tech stack and module boundaries

Per Intent §"平台策略" (Kotlin + Compose, single-codebase-friendly). Note: `apps/mobile` in the Multica repo is Expo/React Native and iOS-only (`apps/mobile/CLAUDE.md:1-3` — "Independent from web/desktop... Mobile is independent... owns its UI, state, hooks"); it is **not** a codebase Chatty shares or ports from mechanically. It is used here purely as a *behavioral reference* for how a first-party client already consumes this exact backend — its API client, cache, and realtime patterns are worth mirroring in design, not in code.

**Stack decision:**

- **Language/UI:** Kotlin, Jetpack Compose (Material 3). Matches the existing `docs/android-dev-loop.md` toolchain (JDK 21, Gradle 8.7, Android SDK 35) already provisioned.
- **Architecture:** MVVM with unidirectional data flow (`StateFlow` per screen), Repository layer per domain.
- **Networking:** Retrofit + OkHttp for REST; OkHttp `WebSocket` for the realtime channel (§8). Moshi or kotlinx.serialization for JSON — server responses are camel_case snake_case JSON per handler DTOs (e.g. `IssueResponse` at `server/internal/handler/issue.go:37-104`), so use `@Json(name=...)` mapping, not reflection-based guessing.
- **Async:** Kotlin Coroutines + Flow.
- **DI:** Hilt.
- **Local persistence:** Jetpack DataStore for UI prefs/drafts only (never server data — see §6.4). Room is **not** used for a second copy of server entities; in-memory + DataStore-backed cache only, mirroring the "no local persistent chat cache beyond in-memory query cache" pattern Multica's own mobile client uses (chat query `staleTime: Infinity`, WS-driven correctness, not polling — chat/message research report, mobile `apps/mobile/data/queries/chat.ts:12-16`).
- **Secure storage:** Jetpack Security `EncryptedSharedPreferences` (AES-256, Android Keystore-backed) for the JWT — the Android equivalent of `expo-secure-store`'s Keychain backing that `apps/mobile/data/secure-storage.ts:8-20` uses on iOS.
- **Background work:** `WorkManager` for periodic sync fallback (§8.4); a foreground `Service` only while the user has an active voice-transcription session (Android background mic restrictions), not for general sync.

**Module boundaries (Gradle modules):**

```
android/
├── app/                     # Compose UI shell, navigation, DI graph assembly
├── core-network/            # Retrofit/OkHttp client, auth interceptor, WS client (single socket, §8.1)
├── core-auth/                # Login flows, token storage, 401 handling (§6)
├── core-model/                # DTOs mirroring server handler responses (IssueResponse, ChatMessage, AgentTask, InboxItem, AttachmentResponse, etc.), one file per Multica entity, each with a source-citation comment
├── feature-chat/             # Mika + per-agent chat screens, message list, composer, voice input
├── feature-status/           # Task/agent/runtime status cards, progressive disclosure
├── feature-approval/         # Approval-card approximation (§6.3) — isolated because it's the one feature built on a workaround, not a stable contract
├── feature-inbox/            # Inbox list (needs `deduplicateInboxItems`-equivalent, §6.2)
├── feature-agents/           # Agent Fleet list view
└── feature-issue-link/       # Deep-link-out to web app for Issue/Runtime/Agent (§6.5)
```

`core-model` is the single place server DTOs are defined — every other module depends on it, never on raw JSON. This mirrors the repo-wide rule in `apps/mobile/CLAUDE.md` ("Every new read-side method... must use `fetchValidated`") adapted to Kotlin: **every network response is parsed through a typed adapter with a documented fallback/default, never force-cast.**

---

## 3. API integration point: internal App API, not Public API v1

Multica exposes two distinct server-side API surfaces. Chatty must use the first, not the second:

1. **Internal App API** (`/api/*`, e.g. `/api/chat/sessions/...`, `/api/issues`, `/api/inbox`) — Bearer JWT + `X-Workspace-Slug` header, the same surface `apps/web`, `apps/desktop`, and `apps/mobile` use. Full coverage of chat, issues, tasks, agents, runtimes, inbox, attachments (all of §4–§9 below).
2. **Public API v1** (`server/pkg/publicapi/v1/`) — a separately-versioned, explicitly narrower contract intended for OAuth apps and Plugins. Its own README states the rollout ledger plainly: *"The migrated slice is Issue read/content update and Comment read/create... Projects, Members, Issue search/create/transition, Agents, Squads, Skills, Tasks/Runs, and Autopilots are subsequent vertical slices"* (`server/pkg/publicapi/v1/README.md:50-55`). Chat is not mentioned at all. Auth is `user_oauth` or `personal_access_token` (`server/pkg/publicapi/v1/foundation.go:16-19`), not first-party session JWT.

**Decision:** Chatty is a first-party Multica client, so it authenticates and talks like `apps/mobile` does — internal App API, Bearer JWT (§6.1), `X-Workspace-Slug` per request. The Public API v1 is irrelevant to Chatty's V1 scope; revisit only if Multica later extends it to cover chat/agents and a business reason emerges to decouple Chatty's auth from first-party login (there is none today).

---

## 4. API capability matrix

Legend: ✅ Supported as-is · 🟡 Supported, needs client-side adaptation/derivation · ❌ Missing/blocked (platform-side gap)

| Capability | Status | Evidence | Chatty responsibility |
|---|---|---|---|
| Email-code login | ✅ | `server/internal/handler/auth.go:286` (`SendCode`), `:376` (`VerifyCode`) | Implement the two-step flow; no OTP UI beyond a 6-digit field. |
| Google OAuth login | ✅ (server supports it) | `auth.go:528` (`GoogleLogin`) | Optional for V1 — `apps/mobile` doesn't wire it either; email-code alone satisfies the "打开就对话" loop. |
| JWT session | 🟡 | `auth.go:164-171` (claims), `server/internal/auth/cookie.go:20-89` (30-day TTL) | No refresh endpoint exists — client must re-authenticate via send-code/verify-code when the JWT expires (no silent renewal is possible; see §6.1). |
| Token revocation / logout | ❌ (JWT is stateless, no revoke) | Confirmed: `Logout` only clears cookies (`auth.go:745`); no server-side blacklist found | Chatty's "sign out" is a local-only token clear. A stolen JWT remains valid until its 30-day `exp` regardless of client action. Documented as a residual risk (§14), not solvable client-side. |
| Device binding / session list / logout-all-devices | ❌ | Confirmed absent — no session inventory or device-registration table for user auth (auth research report) | Not implementable in V1. If Benjamin wants this, it is a platform ask, not a Chatty ask. |
| Workspace selection | ✅ | `X-Workspace-Slug` header (`apps/mobile/data/api.ts:220-225` pattern), `GET /api/workspaces` | Store last-used workspace slug for cold-start routing (mirror `apps/mobile/data/workspace-store.ts` pattern). |
| Chat send/receive | ✅ | `POST /api/chat/sessions/{id}/messages` (`chat.go:832-1020`) | — |
| Chat message pagination | 🟡 | Two endpoints exist: unbounded `GET /api/chat/sessions/{id}/messages` (`chat.go:1174-1205`, what `apps/mobile` currently uses) vs cursor `GET /api/chat/sessions/{id}/messages/page` (`chat.go:1207-1274`) | **Chatty must use the cursor endpoint from day one**, not copy `apps/mobile`'s unbounded call — mobile's choice is legacy, not a recommended pattern, and an unbounded history fetch is a poor mobile-data citizen. |
| Realtime chat/task/issue events | ✅ | Single user-facing WS `GET /ws` (`server/internal/realtime/hub.go:775-884`), typed events in `server/pkg/protocol/events.go` | Build the 3-layer WS client described in §8. |
| Token-level assistant streaming | ❌ | Confirmed: only step-level `task:message` trace + one complete `chat:done` payload (`server/internal/handler/messages.go:187-292`); no delta/partial-text event | Render the trace (thinking/tool_use/tool_result) as a live activity feed, then swap in the final message on `chat:done` — do not attempt to fake token streaming. |
| Missed-event replay after reconnect | ❌ | Explicit in mobile client comment: "any events between disconnect and reconnect were lost (no replay in v1)" (chat/message research report, `ws-client.ts:179-183`) | On reconnect, invalidate and refetch affected queries — never assume WS delivered a complete history (§8.3). |
| Issue/Task/Project CRUD + query | ✅ | `server/internal/handler/issue.go`, `project.go`; rich filter/sort on `GET /api/issues` (`issue.go:1042,1234-1282`) | — |
| Issue status state machine | 🟡 | 7 canonical categories (`server/internal/issuestatus/issuestatus.go:41-48`); **no transition graph enforced server-side** — any catalog status is writable | Chatty must not invent client-side transition restrictions beyond what the UI needs for sanity (e.g. don't offer "done → todo" as a swipe action if it's confusing), because the server won't reject it either way. |
| Comments (read/create/thread) | ✅ | `server/internal/handler/comment.go:28-80,394-470+` | Reuse `roots_only`/`summary`/`fold` query modes for a lightweight thread view, exactly as the Multica CLI does (per this agent's own `## Available Commands`). |
| Sub-issue / stage hierarchy | ✅ | `parent_issue_id`, `stage` fields; barrier logic (`server/internal/service/issue_child_done.go:17-60`) | Out of scope to *edit* in V1 (deep Project/Issue governance is explicitly out of scope per Intent); fine to *display* read-only. |
| Structured Approval/Decision gate | ❌ | Confirmed absent after exhaustive search — closest analog is `ReasonAgentBlocked` task failure + `issue.status=blocked` + inbox notification, not an approve/reject API (`server/pkg/taskfailure/failure.go:98-101`) | See §6.3 — approximate with existing primitives, do not claim a fidelity Multica doesn't have. |
| Attachments (upload/download) | ✅ | `POST /api/upload-file` (100MB cap, `server/internal/handler/file.go:36,377`); multiple download modes (`file.go:41-45`) | — |
| Distinct "Evidence" entity | ❌ | "Evidence"/"Artifact" terms in Multica source mean attribution-tracking and disk-GC respectively, unrelated to agent output (`server/internal/attribution/attribution.go:104-120`; `server/internal/daemon/gc.go`) | Evidence cards in Chatty are a UI concept over plain `Attachment` objects — do not build against a server entity that doesn't exist. |
| Deep link to Issue/Runtime/Agent from chat | 🟡 | No custom external URL scheme; the actual pattern is a plain `https://` URL into the web app (`apps/mobile/app/(app)/[workspace]/issue/[id].tsx:115-117,144`) | Build `${WEB_BASE_URL}/{workspaceSlug}/issue/{identifier}` and open via Android `Intent(ACTION_VIEW)` — same mechanism as `apps/mobile`, no custom scheme needed. `mention://...` links are markdown-embedded and render-only; never treat them as external deep links. |
| Push notifications (background) | ❌ | Confirmed absent: `notification_preference` only gates inbox-row creation, no FCM/APNs/device-token infrastructure anywhere in `server/` or any first-party client (§8.4 evidence) | Platform-side gap — flagged as Open Question #3/blocker (§10). |
| Inbox ("needs attention" aggregator) | 🟡 | `inbox_item` table + full CRUD API (`server/cmd/server/router.go:2273-2293`) | Raw rows include duplicates and archived items — client must dedupe (mirror `deduplicateInboxItems`, §6.2), per Multica's own documented 2026-05-09 incident. |
| Agent Fleet list + status | ✅ | `ListSquadMemberStatus` 5-bucket presence (`server/internal/handler/squad.go:629-647`) | Prefer this endpoint over raw `agent.status` for the Agent list screen — it's the richest signal without daemon-protocol access. |
| Runtime status | 🟡 | Server persists only `online`/`offline` (`server/migrations/004_agent_runtime_loop.up.sql:8`); richer buckets (`recently_lost`, `long_offline`) are client-derived | Port the *logic* of `packages/core/runtimes/derive-health.ts:14-29` to Kotlin (Chatty cannot import TS) — same thresholds (`<5min` → recently_lost, `>6 days` → long_offline), cited inline so drift is detectable on review. |
| Automatic runtime failover | N/A (confirmed not to exist) | `server/internal/service/agent_ready.go:105-148`; grep for "failover" across `server/` and `packages/core/` found none | Matches Intent's explicit design (`### 5. Agent aggregates Harness and Runtime` — "WorkItem 等待原 Runtime 恢复，系统不执行自动 Failover"). Chatty's status card must say "waiting for Runtime" honestly, never imply retry-elsewhere. |

---

## 5. Runtime/Daemon semantics Chatty must respect (read-only understanding)

Chatty never talks to `/api/daemon/*` — that surface is authenticated by machine-only daemon tokens (`mdt_`/`mcn_` prefixes, `server/internal/middleware/daemon_auth.go:107-190`) and its WebSocket is a best-effort wakeup sidecar, not a state channel: *"Messages are best-effort wakeup hints; the daemon still uses HTTP claim for correctness"* (`server/internal/daemonws/hub.go:311`). This matters for how Chatty should *interpret* what it sees:

- **Heartbeat/offline detection:** effective staleness threshold is ~150s (15s heartbeat + 30s batch flush + margin, `server/internal/handler/heartbeat_scheduler.go:1039-1046`), swept every 30s (`server/cmd/server/runtime_sweeper.go:26`). So a runtime that just went offline may take up to ~3 minutes to show as offline — don't design a status card that implies sub-second accuracy.
- **In-flight task grace period:** an offline runtime's dispatched/running tasks are only force-failed after a **3-hour** reconnect grace (`runtime_sweeper.go:39-43`) — a task can sit "running" for hours after its runtime actually died. Chatty should surface elapsed time on the status card so the user can judge staleness themselves rather than trusting "running" at face value.
- **Recovery is fail-and-retry, not resume:** when a daemon reconnects, orphaned tasks are explicitly failed (`server/internal/handler/task_lifecycle.go:19-58`, `RecoverOrphanedTasks`) and may auto-retry as a **fresh** attempt — never silently resumed mid-execution. Chatty's status card for a task that flips running → failed → running again should read that as a retry, not a bug.
- **Task claiming is daemon-pull:** the server never pushes task payloads to a runtime; it only signals `daemon:task_available`/`daemon:pending_work` (`server/internal/daemonws/hub.go:446-468`). This is invisible to Chatty and needs no client handling — noted here only so a future engineer doesn't assume Chatty could ever "wake up" a runtime.

---

## 6. Data mapping and client-side derivation rules

### 6.1 Auth, secure storage, device binding

- Login: email-code flow (`POST /auth/send-code`, `POST /auth/verify-code`). Store the returned JWT in `EncryptedSharedPreferences` (Keystore-backed AES-256), keyed similarly to `apps/mobile`'s `"multica_token"` (`apps/mobile/data/secure-storage.ts:8-20`).
- No refresh flow exists server-side (§4 table) — on JWT expiry (401), clear the token and route to login. Do **not** build a refresh-retry loop; there is nothing on the server to call.
- **Only clear the stored token on an actual 401**, never on network error or 5xx — mirrors `apps/mobile/data/auth-store.ts:51-53`'s explicit design comment, so a flaky connection doesn't force a needless re-login.
- No device binding exists server-side. **Decision:** Chatty does not build one either — Open Question #5 resolves to "no device binding in V1," see §10.
- Workspace scoping: send `X-Workspace-Slug` on every request; persist last-used slug for cold start (mirrors `apps/mobile/data/workspace-store.ts`).
- Residual risk accepted for V1: a 30-day bearer JWT with no revocation means a stolen/leaked token is valid for up to 30 days regardless of what the user does in Chatty. This is a platform property, not a Chatty bug — documented in §14, not solved here.

### 6.2 Inbox dedup (mandatory, not optional polish)

Raw `GET /api/inbox` rows include archived items and multiple rows per issue (comment + status-change + assignment can each fire independently). Multica's own mobile client shipped without this once and produced a documented incident (`apps/mobile/CLAUDE.md` "⚠️ Incident (2026-05-09)"). Chatty must, before counting or rendering any inbox/unread badge:

1. Filter `archived == true` out.
2. Group by `issue_id`, keep only the newest row per group.
3. Sort by `created_at` desc.

Treat `severity == "action_required"` (set for `issue_assigned` and `task_failed`) as the strongest "needs you" signal for badge/notification prioritization.

### 6.3 Approval/Decision Card — approximation, not a real gate

Since Multica has no approve/reject API (§4), Chatty's "Approval Card" is a UI affordance layered over three existing signals, not a new server contract:

1. Task fails with `failure_reason == "agent_blocked"` (`server/pkg/taskfailure/failure.go:98-101`) — mobile's own label for this is literally "Waiting on human input" (`apps/mobile/lib/failure-reason-label.ts:27`).
2. The associated issue's status is `blocked` (or workspace-custom status mapped to that category).
3. An `agent_activity`-typed inbox row exists for it (`server/cmd/server/notification_listeners.go:86,148`).

When all three line up, Chatty renders an "Approval needed" card. **Resuming is a normal reply**, not a decision-endpoint call: posting a chat message or issue comment re-triggers the agent through the ordinary mention/dispatch path — there is no accept/reject payload to send. The card's primary action is therefore "reply" (opens the composer prefilled with context), not "approve"/"reject" buttons that call an API that doesn't exist. Do not build UI that implies a formal decision was recorded server-side — it wasn't.

This is flagged as Open Question #7 (§10) for Benjamin: accept the approximation for V1, or treat a real approval primitive as a prerequisite (which would block V1 on platform work).

### 6.4 No second source of truth (hard rule)

Following the pattern documented across every layer of the reference client (`apps/mobile/CLAUDE.md` State Rules, root `CLAUDE.md` "State Rules"):

- Chatty's local stores hold only: UI/view state (composer draft text, selected tab, theme), the JWT, and the last-used workspace slug. Nothing else survives an app restart.
- All server-derived data (chat messages, issues, tasks, agents, runtimes, inbox) lives in an in-memory cache that is either (a) patched in place by a typed WS event handler when the event carries the full updated object, or (b) invalidated and refetched when it doesn't (mirrors "patch over invalidate," `apps/mobile/CLAUDE.md` §Realtime).
- On WS reconnect, invalidate exactly the caches that hook owns — no global "refetch everything" sweep (cellular-data cost; mirrors `apps/mobile/CLAUDE.md` §Reconnect handling table).
- Optimistic UI is limited to the "pending message" pattern for chat sends (anchor on the server-returned `task_id`, not a client-generated id) — never silent optimism for state that could diverge from the server (mirrors root `CLAUDE.md` "Chat/message send uses the pending-message pattern").

### 6.5 Deep links out of the app

Build `https://{WEB_BASE_URL}/{workspaceSlug}/issue/{identifier}` (and equivalent for agent/runtime pages) and open with `Intent(ACTION_VIEW)`. This is exactly what `apps/mobile` does (`apps/mobile/app/(app)/[workspace]/issue/[id].tsx:115-117,144`) — there is no custom URL scheme to integrate with. `mention://...` links inside message/comment markdown are render-only navigation within Chatty's own content view; they are never used as an outbound Android deep link.

---

## 7. Voice input: long-press transcription

Multica's server has no speech-to-text endpoint (not found anywhere in `server/` during this review, and not expected — transcription is explicitly a client input method per Intent, not a platform capability). **Decision:**

- Use Android's on-device `SpeechRecognizer` (`RecognizerIntent.ACTION_RECOGNIZE_SPEECH` with `EXTRA_PREFER_OFFLINE` where the device supports an offline language pack) for V1.
- Audio never leaves the device and is never sent to Multica — only the resulting transcript text does, as an ordinary editable composer draft (satisfies Intent's "长按语音转写是输入方式，转写文字进入可搜索上下文").
- If the device has no offline model installed, fall back to Android's online recognition (Google-hosted, standard OS-level privacy boundary, not a Multica-side concern) rather than blocking the feature — but surface this to the user (e.g. a one-time "using online transcription" notice) so the privacy boundary is visible, not silent.
- No third-party cloud ASR vendor in V1 — avoids introducing a second external data processor beyond what Android itself already is.
- Mic permission (`RECORD_AUDIO`) requested at first long-press, not at app launch.

This resolves Open Question #2 (§10).

---

## 8. Realtime, background, and foreground state convergence

### 8.1 Three-layer WS client (mirrors the reference client's proven shape)

```
Layer 1  WsClient        — single OkHttp WebSocket, no UI coupling. Exponential
                            backoff with jitter. idle/active/paused lifecycle so
                            it can pause on Activity background and resume on
                            foreground without racing its own reconnect timer.
Layer 2  RealtimeProvider — owns the WsClient. (Re)connects on auth + workspace
                            + process lifecycle changes.
Layer 3  use-case flows   — per-feature event → cache-mutation mappers (chat,
                            inbox, issue, agent/runtime presence).
```

Auth handshake: connect to `GET /ws?workspace_id=...`, send `{type:"auth", payload:{token}}` as the first frame (mirrors `apps/mobile/data/realtime/ws-client.ts:211-216`), await `{type:"auth_ack"}`. Client is then auto-subscribed to `workspace:{id}` and `user:{id}` rooms server-side (`server/internal/realtime/hub.go:331-335`) — no explicit per-issue/per-chat subscribe call is required for V1 (the server currently broadcasts every relevant event to the whole workspace room regardless of granular `subscribe` frames — confirmed still-dormant per-resource routing, chat/message research report).

### 8.2 Foreground behavior

WS connection is the source of live updates while the app is foregrounded. Patch typed caches in place when the event carries a full object (`chat:message`, `chat:done`, `issue:updated`); invalidate-and-refetch only when it doesn't (id-only payloads, rare events, or post-reconnect).

### 8.3 Background/killed behavior (within V1's honest limits)

- On Activity background, pause the WS client rather than tearing it down immediately (short grace window), then disconnect if backgrounded beyond a short threshold — standard Android lifecycle hygiene, not a Multica requirement.
- **WorkManager periodic sync** (e.g. every 15–30 min, OS-constrained minimum) polls `GET /api/inbox/unread-summary` and any active task status while backgrounded, posting a local Android notification for `severity == action_required` items the user hasn't seen. This is polling, not push — it is bounded by Android's Doze/App-Standby buckets and is **not** a substitute for real push; it exists so Chatty isn't silent for hours, not so it's instant.
- On foreground resume, force a reconnect and invalidate all mounted caches once (acceptable cost — this is the one deliberate exception to the "no global invalidate" rule, justified because a background period may have missed an unbounded number of events with no replay mechanism, per §8.4).

### 8.4 Push notifications — platform gap, not a Chatty implementation choice

Confirmed absent server-side: no FCM/APNs integration, no device-token registration table, no push-sender code anywhere in `server/` or any existing first-party client. `notification_preference` (`server/internal/handler/notification_preference.go:14-27`) only gates whether an *inbox row* is created — it has a `system_notifications` field whose own doc-comment calls it a "delivery-channel toggle" for native banners, but nothing consumes that toggle to actually send one.

**This means Intent's "应用关闭后任务继续在 Multica Runtime 上执行，重要状态变化推送回手机" cannot be delivered with true push in V1.** §8.3's WorkManager polling is the best available approximation. Real push requires platform-side work: an FCM device-token registration endpoint and a server-side push sender wired to the existing event bus. This is Open Question #3 (§10) — flagged as **blocked**, owner **Multica backend team**, unblock condition **a device-token registration API + push-sender exists**.

---

## 9. Offline, retries, idempotency, error handling, Generic Activity fallback

- **Read paths:** standard exponential-backoff retry on transient network errors (timeout, 5xx); no retry on 4xx (surface the error).
- **Write paths (chat send, comment post, issue update):** Multica's public-API foundation establishes an `Idempotency-Key` convention for create/trigger/replay/retry operations (`server/pkg/publicapi/v1/foundation.go:7-8`, `README.md:36-38`) — but this is documented for the *Public API v1* surface, not confirmed present on the internal App API endpoints Chatty actually calls. **Action:** do not assume idempotency-key support on `/api/chat/sessions/*/messages` or `/api/issues/*` without verifying the specific handler at implementation time; where unconfirmed, protect against duplicate-send-on-retry with a client-side "already sent this pending message" guard instead (check for an existing pending/sent message with the same client-generated composer-draft id before retrying a failed send).
- **Optimistic conflict resolution:** mirrors `apps/mobile/data/revision.ts` — issues and comments carry a `revision` integer (`issue.go:37-104` `Revision`); on a conflicting write, last-write-wins from the server's perspective — Chatty applies the server's authoritative state on the resulting WS event without a merge UI in V1 (matches the reference client's explicit choice not to build conflict UI, per chat/message research report).
- **Unknown/future event types → Generic Activity:** per Intent's constraint ("发现新状态类型时回退到可展开的 Generic Activity"), any WS event type or `task:message` sub-type Chatty doesn't recognize renders as a collapsed "Activity" card showing the raw JSON payload, tagged with its originating `issue_id`/`task_id` so it stays attached to the right conversation, and does not interrupt the run. This directly follows the same fallback rule Multica's own event-adapter design already assumes (`README.md` Harness section — "遇到尚未识别的事件时... 生成 `activity.generic`... 继续当前 Run").
- **Error surface:** map HTTP problem responses to a single in-app error sheet pattern; 401 → forced logout (§6.1); 403 → "you don't have access" (no retry); 5xx/timeout → retry with backoff, then a dismissible banner, never a blocking modal that halts the whole app.

---

## 10. Open Questions — decisions

Resolving all 6 from `iterations/v2/intent.md` §Open questions, plus one new one surfaced by this review:

1. **API coverage (WS/polling/push) and auth** — ✅ Decided. Internal App API (§3), Bearer JWT + `X-Workspace-Slug` (§6.1), single user-facing WS at `GET /ws` (§8.1) for realtime, no true push in V1 (see #3 below).
2. **Voice transcription service and privacy boundary** — ✅ Decided. On-device Android `SpeechRecognizer`, offline-preferred, audio never sent to Multica (§7).
3. **Push channel and battery strategy** — ⚠️ **Blocked** for true push. No FCM/APNs/device-token infrastructure exists server-side (§8.4). Owner: Multica backend team. Unblock condition: a device-token registration endpoint + push sender wired to the existing event bus. **V1 workaround (not blocked):** WorkManager periodic poll of unread-summary/active-task status while backgrounded (§8.3), with an explicit "notifications may be delayed" expectation set in-app.
4. **History pagination / semantic summaries** — ✅ Decided. Use the cursor `GET /api/chat/sessions/{id}/messages/page` endpoint (§4 table), not the unbounded one `apps/mobile` currently uses. No separate semantic-summary generation exists or is needed for V1 — Mika's own replies plus task status cards serve as the de facto summary; a dedicated summarization endpoint is out of scope unless a specific UX gap appears in EVAL.
5. **Client secure storage and device binding** — ✅ Decided. `EncryptedSharedPreferences` (Keystore-backed) for the JWT (§6.1); no device binding, because none exists server-side to bind against — accepted as a residual risk (§14), not solved client-side.
6. **iOS/desktop extension priority** — ✅ Already decided in Intent (Android-first, iOS out of V1 scope); this spec doesn't revisit it.
7. **(New) Approval/Decision fidelity** — ⚠️ Needs Benjamin's call, not blocked but a real trade-off: Multica has no approve/reject API (§4, §6.3). Chatty can ship V1 with the three-signal approximation in §6.3 (task `agent_blocked` + issue `blocked` status + inbox row → "reply to resume" card), which satisfies Intent's Success Criterion 4 in spirit (a confirmation surface exists and is actionable) but not to the letter (there's no recorded "decision," just a reply that happens to unblock the agent). **Recommendation:** accept the approximation for V1 — it's honest about what exists, ships on schedule, and doesn't block on platform work; revisit if EVAL shows users are confused by "reply" standing in for "approve."

---

## 11. Implementation split (input to `ISSUES.md`)

Suggested stage grouping for the eventual Multica Issue breakdown (Stage 3 of the SDLC):

- **Stage A — Auth + shell:** login (email-code), secure token storage, workspace selection, empty Compose shell, `core-network`/`core-auth`/`core-model` modules.
- **Stage B — Chat core:** Mika default session, send/receive, cursor-paginated history, WS client (Layer 1+2), `chat:message`/`chat:done` handling, pending-message pattern.
- **Stage C — Status + Evidence:** task/agent/runtime status cards (§1 step 7, §5), attachment rendering as Evidence cards (§4), Generic Activity fallback (§9).
- **Stage D — Inbox + Approval:** deduped inbox list (§6.2), Approval Card approximation (§6.3).
- **Stage E — Agent Fleet + deep links:** Agent list view, issue/runtime/agent deep links out to web (§6.5).
- **Stage F — Background convergence:** WorkManager polling fallback (§8.3), reconnect/invalidate correctness, offline/error handling (§9).
- **Stage G — adb+Appium acceptance:** wire the full loop from `docs/android-dev-loop.md` against Success Criteria 1–8 (§12).

Each stage should land as its own Multica Issue chain (`--parent`/`--stage`), consistent with `docs/sdlc-workflow.md`'s Gate G3 requirement (assignee, priority, verification command per Issue).

---

## 12. Acceptance criteria — mapping Intent's 9 Success Criteria to modules and verification

| # | Success criterion (Intent) | Implementing module(s) | Verification method |
|---|---|---|---|
| 1 | Open Chatty on Pixel 6 Pro, chat with Mika, get a reply | `feature-chat`, `core-network` | `scripts/appium-ui.sh` sends a message, asserts reply text appears |
| 2 | Long-press transcription editable before send | `feature-chat` voice input (§7) | Appium: long-press composer, assert transcript text populates, edit, send |
| 3 | Delegation request shows a task status card that updates live | `feature-status`, WS Layer 3 (§8.1) | Trigger a real delegated task via Mika; Appium polls for status-card text transitions (queued→running→completed) |
| 4 | Approval Card appears and can be actioned | `feature-approval` (§6.3) | Force an `agent_blocked` task in a test workspace; Appium asserts card renders and "reply" action opens composer |
| 5 | Evidence (screenshot/link/log) clickable after completion | `feature-status` attachment rendering | Appium taps an Evidence card, asserts it opens/expands |
| 6 | Close+reopen app; state matches server truth | `core-network` cache invalidation (§6.4, §8.3) | Kill app, reopen, assert chat/task state matches a freshly-fetched REST snapshot |
| 7 | Agent list/card shows real Multica agents + status | `feature-agents` (`ListSquadMemberStatus`) | Appium asserts agent list matches `multica` CLI's `agent list` output for the same workspace |
| 8 | Whole flow passes via Appium automation | All | `scripts/dev-loop.sh` + `scripts/appium-ui.sh`, chained per `docs/android-dev-loop.md` |
| 9 | User adopts Chatty as default mobile entry point | N/A — qualitative, post-V1 | Not a build-time gate; tracked via actual daily usage after Stage G ships, not part of this spec's EVAL |

---

## 13. Eval plan

Per `docs/sdlc-workflow.md` evidence rules: every row above (Criteria 1–8) needs a command/script + an evidence artifact path under `iterations/v2/evidence/` (screenshot, logcat excerpt, or Appium session id) before Stage 5 (`EVAL.md`) can go green. No criterion is accepted on verbal confirmation. Failures get logged to `HARDENING.md` with a reproducible command, per the repo's evidence discipline — this spec does not relax that rule for any of the gaps identified in §4/§8.4; those gaps are pre-declared as "cannot pass," not silently skipped, and Criterion 3/4's EVAL rows should explicitly note they're testing the §6.3/§8.3 approximations, not a fidelity Multica doesn't offer.

---

## 14. V1 non-goals, risks, residual gaps

**Non-goals (reaffirming Intent's Out-of-scope, unchanged):** self-hosted backend/auth/agent protocol, iOS, full Multica admin console, Lark/Feishu integration, multi-human/org collaboration.

**New non-goals surfaced by this review (not in Intent, added because the source review revealed them):**
- True push notifications (blocked, §8.4/§10.3) — V1 ships with WorkManager polling only.
- A formal Approval/Decision API integration — V1 ships with the §6.3 approximation.
- Device binding / multi-session management — doesn't exist server-side to build against.
- Token-level "typing" streaming of Mika's replies — server doesn't support it (§4 table); Chatty shows step-trace + final message, not simulated typing.

**Risks:**
- **30-day non-revocable JWT** (§6.1): a lost/stolen phone leaks a bearer token valid up to 30 days with no server-side kill switch beyond a full password/account-level intervention outside Chatty's control. Mitigate with Keystore-backed storage (raises the bar for extraction) and clear user guidance to revoke via account settings if a device is lost — but this is a platform limitation, not fully closable client-side.
- **~150s runtime-offline detection lag + 3h task-failure grace** (§5): status cards can be stale for a meaningful window; mitigated by showing elapsed time, not by pretending accuracy Multica doesn't have.
- **No missed-event replay** (§4 table, §8.3): a long background period requires a full cache invalidation on resume — acceptable but means Chatty is not "always live," only "live while foregrounded, eventually-consistent on resume."
- **Approval approximation (§6.3) could read as a real Approval/Decision feature to Benjamin during daily use** if the UI doesn't clearly communicate "this is a reply, not a recorded decision" — a wording/UX risk to watch in EVAL, not an engineering risk.

---

## 15. Consistency check performed for this spec

- `README.md` "Status" section updated to point at Stage 2 and this spec, per acceptance criteria.
- **Follow-up (2026-09-04, per Benjamin's review comment on this Issue):** `README.md`'s Lark/Context-Layer narrative — previously left as pre-pivot `iterations/v1/` content and flagged but not fixed in the first pass — has been downgraded throughout: every Lark-referencing section (`Why Chatty`, Core Principle 2, `Context Layer`, `Execution Flow`, `Lark Context Layer`, `Initial Product Scope`, `Product Statement`) now carries an explicit "候选后续能力，V1 范围外" banner, and the former "Initial Product Scope" section (which listed a `larkcli` bullet as if it were V1 scope) is renamed "Product Scope（跨轮次概念，非本轮 V1 清单）" with that bullet moved to a separate "候选后续能力" list and an explicit pointer to `iterations/v2/intent.md` as the authoritative V1 scope. A V1-only simplified Execution Flow (no Lark steps) was added alongside the original concept diagram, which is now labeled as long-term vision, not V1 implementation.
- `iterations/v2/intent.md` header updated to `Status: Accepted` to reflect Benjamin's 2026-09-04 acceptance recorded in this Issue's description, satisfying Gate G1 before this spec could be written.
- No changes made to `https://github.com/multica-ai/multica` — read-only throughout, per repo-boundary constraint.
