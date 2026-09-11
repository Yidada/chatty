# Android 0.2.0 acceptance

- Scope: workspace activity, review/blocked groups, read markers independent of attention, strict approval receipt, explicit resumed-work feedback.
- This release also carries the pre-existing Android work for avatar settings, project context snapshots, nonblocking FIFO/uncertain sends, account/workspace restoration, and paging retention.
- Build: `android/gradlew -p android :app:assembleDebug testDebugUnitTest lintDebug`.
- Result: 81 unit tests passed; debug lint and production-endpoint debug assembly passed.
- Distribution: version 0.2.0, version code 2, `ai.chatty.app.debug`; debug-signed acceptance APK. This is not a Play Store production release.
- Synthetic device test: start `scripts/ios-fixture.py`, POST `{"activity_scenario":true}` to `/__control`, build with `-PchattyFixture=true`, install only `ai.chatty.app.fixture`, reverse port 8765, then run `scripts/android-activity-device-test.py` with ADB, PKG and EVIDENCE_DIR set. Requires the repository's Appium UI harness.
- Production-account sends and writes are excluded from automated acceptance.

## Device result

Pixel 6 Pro: fixture install, recent activity, two attention groups, blocked item beyond the first 50 recent tasks, custom review approval, explicit 已验收 feedback, attention count 2 → 1, and blocked-discussion explanation all passed. The live run exposed and verified a fix for loading the custom status catalog when opening details directly from activity. Only synthetic data was used.
