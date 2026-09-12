# Evidence

- Outcome: implementation verified by build/unit/lint; device loop pending
- Recorded: 2026-09-09
- Re-verified: 2026-09-11 `testDebugUnitTest --rerun-tasks` BUILD SUCCESSFUL with 122 module-wide tests (0 failures); queue tests included. Device loop still pending.
- Repository: <repository>
- Branch: main; local uncommitted changes (no commit/push performed).
- Environment: macOS, JDK 17, Gradle 8.7, Android SDK 35.

## Build and unit verification

- `source scripts/android-env.sh && cd android && ./gradlew testDebugUnitTest assembleDebug lintDebug` -> exit 0, BUILD SUCCESSFUL.
- Unit tests: 65 total, 0 failures, 0 errors. Feature-chat: ChatControllerTest 22, ChatPendingTest 8, NativeNavigationTest 3. Core-network: ChatApiTest 6, MulticaApiTest 9, WorkspaceApiTest 3.
- `python3 -m py_compile scripts/chat-fixture.py scripts/chat-device-test.py` -> exit 0.
- Lint: `lintDebug` BUILD SUCCESSFUL, no errors.

## New coverage

- ChatPendingTest: enqueue head/queue, rich-over-sparse dedupe, created_at ordering, promote head/next, remove head/queued, prioritize front, hide queued messages, wait_reason lifetime.
- ChatControllerTest: running send queues follow-up and keeps head; blocked without `supports_queue`; stop restores draft and removes message; edit appends to existing draft; remove/clear queue; send-now prioritizes + stops active; sparse lifecycle events converge.
- ChatApiTest: `X-Client-Capabilities: chat-draft-restore-v1`; cancel wire path + query params; prioritize/clear routes and methods.

## Pending verification

- Pixel synthetic device loop (`scripts/chat-device-test.py`) now includes a non-blocking queue segment (`slow=True`, `待发消息 · 1`, both replies). Not executed in this session because no device/Appium was attached. Run when a Pixel is available and store evidence under `.sdlc/archive/iterations/v2/evidence/`.

## Delivery boundary

Local implementation only. No commit, push, PR, merge, or production release.
