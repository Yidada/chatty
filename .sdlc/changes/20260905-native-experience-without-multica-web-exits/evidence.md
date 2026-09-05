# Evidence
- Outcome: pass
- Recorded: 2026-09-05T08:16:22.740181+00:00
- Repository: /Users/benjamin/Workspace/chatty
- Branch: codex/native-experience; base aa339a2; local uncommitted changes.
- Environment: macOS, JDK 17, Gradle 8.7, USB Pixel 6 Pro Android 16, Appium 3.0.2.

## Build and unit verification
- `source scripts/android-env.sh && cd android && ./gradlew testDebugUnitTest assembleDebug lintDebug` -> exit 0, BUILD SUCCESSFUL. 35 independent tests, 0 failures/errors. Lint has existing newer-dependency warnings, no errors.
- `source scripts/android-env.sh && cd android && ./gradlew -PchattyFixture=true :app:assembleDebug` -> exit 0.
- `PYTHONPYCACHEPREFIX=/tmp/chatty-pyc python3 -m py_compile scripts/native-device-test.py scripts/chat-fixture.py scripts/tabs-device-test.py` -> exit 0.
- `git diff --check` -> exit 0.
- Logs and summary: `iterations/v2/evidence/native-validation/{build-test-lint.log,fixture-build.log,tests.json,apk.json}`.

## Pixel isolated acceptance
Setup: source scripts/android-env.sh; Appium on 127.0.0.1:4725; `python3 scripts/chat-fixture.py` on 127.0.0.1:8765; adb reverse tcp:8765 tcp:8765; fixture APK installed.
- `EVIDENCE_DIR="$PWD/iterations/v2/evidence/native-tabs-loop" python3 scripts/tabs-device-test.py` -> exit 0; 80 recorded checks; project aggregates, single Issue PUT with suppress_run=true/revision, search/filter/paging, empty and unassigned project, resource details, three tab loops. Every screenshot checkpoint rejects removed web labels and checks foreground package.
- `EVIDENCE_DIR="$PWD/iterations/v2/evidence/native-chat-loop" python3 -u scripts/chat-device-test.py` -> exit 0; 36 checks; two synthetic sends, trace, reconnect, draft/cold start, cursor paging, error recovery and text attachment preview.
- First `native-device-test.py` run -> exit 1: new native-rich message was in viewport but previous link was above it; area-based scroll did not find link. Kept `native-content-loop/failure.*` and `native-validation/content-round1.log`.
- Corrected harness to wait for refreshed conversation and scroll by actual chat list element. No application change after the original successful build.
- `EVIDENCE_DIR="$PWD/iterations/v2/evidence/native-content-loop-2" python3 -u scripts/native-device-test.py` -> exit 0. Multica label preserves text and does not leave app; Mermaid code has no web fallback; both Markdown image and image attachment open/close native previews. Screenshots visually inspected.
- Original evidence folders and failed run retained. Test server restarted with new image fixture after chat regression.

## Real installed app and delivery
- `adb -s 1A021FDEE004VC install -r /tmp/chatty-native-real.apk` -> Success; build fingerprint stored in apk.json.
- `EVIDENCE_DIR=/tmp/chatty-native-live python3 -u /tmp/chatty-native-live.py` -> exit 0; Mika, native settings and all three resource sections visited, returned to Mika. Sanitized result: `native-validation/live-smoke.json`; live screenshots stay in /tmp.
- Current app process running, no FATAL EXCEPTION in its AndroidRuntime log; `native-validation/process.json`.
- No real messages sent, no real Issue writes. Real smoke verifies navigation, not full live resource administration or new chat sends.
- Fixture package uninstalled; USB 8765 reverse removed; only this run's Appium/API processes stopped. Real app/login preserved.

## Delivery boundary and maintenance
Local implementation and Pixel installation complete. No commit/push, PR, main merge or production release performed. V2 overall remains in development.
Follow-up trigger: a reproducible application-provided Multica browser exit should become a fixture regression. Native configuration editors and interactive HTML/Mermaid require a separately scoped change.
