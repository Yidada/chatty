# Verification evidence: iOS P0 native foundation and fixture device loop

- Change ID: `20260905-ios-p0-native-foundation-and-fixture-device-loop`
- Outcome: pass
- Date: 2026-09-05, Asia/Singapore
- Scope: IOS-P0 local synthetic-data delivery

## Verification

| Check | Command or method | Result | Evidence |
|---|---|---|---|
| Swift contracts and client | `swift test --package-path ios/Packages/ChattyKit --scratch-path .tools/ios-swift-build` | Exit 0; 13 tests, 0 failures, 22:01 | iterations/ios-v1/evidence/p0/swift-tests.log |
| Fixture Debug native app | XcodeBuildMCP build_run_sim; ChattyFixture, iPhone 17 Pro iOS 26.5 | Build/install/run pass at 22:06; 0 source warnings/errors | XcodeBuildMCP log build_run_sim_2026-09-05T14-06-06-513Z_pid78253_f6102b80.log |
| iOS XCTest | XcodeBuildMCP test_sim, parallel-testing-enabled NO | 2 tests passed, 0 failures, 22:10 | test_sim_2026-09-05T14-10-49-630Z_pid78253_9bd5f12d.xcresult |
| Normal Release arm64 simulator | XcodeBuildMCP build_run_sim; Chatty Release, ONLY_ACTIVE_ARCH=YES | Build/install/run pass, 22:11; disconnected UI observed | build_run_sim_2026-09-05T14-11-03-700Z_pid78253_223ab454.log; shell.png |
| Interactive fixture data | agent-device open, semantic waits, screenshots | 50 messages; GFM table/task/code; project 25/55; Runtime online | iterations/ios-v1/evidence/p0/{chat,projects,settings,runtime}.png |
| Stable replay including Markdown guards | `agent-device replay iterations/ios-v1/flows/p0-navigation.ad --platform ios --udid 054F32F8-3406-4DB7-A1BF-1579A78D2088 --session chatty-ios-p0 --json` | Exit 0; 14 steps, 0 heals, 11.0s | iterations/ios-v1/evidence/p0/replay.json; verification.json binds final flow SHA256 |
| 503 and recovery | Existing /__control status 503 → fixture.refresh → error wait; status 200 → fixture.retry | Error visible with previous messages; error removed after successful retry | error.png, recovered.png; agent-device chatty-ios-recovery session |
| Real HTTP 302 | `python3 scripts/ios-check-redirect.py` | Exit 0; default FixtureClient rejected 302; only /api/projects requested, redirect sink 0 | .tools/ios-p0-redirect-check.log; tracked verification executable and script |
| No external writes | GET /__calls before 302 service replacement | 35 GET reads in fixture workspace, send_count 0, issue_writes empty | iterations/ios-v1/evidence/p0/service-calls.json |
| Normal app isolation | PBX target sources/products, compiled plist, binary byte scan | No Fixture source/product, synthetic token, loopback service URL or ATS exceptions | verification.json normal_app_isolation + binary hash |
| Repeatable CLI loop | `scripts/ios-dev-loop.sh fixture`; Bash/Zsh syntax + source check | Exit 0; built, installed and launched; shell environment selected target | .tools/ios-p0-dev-loop.log; .tools/ios-v1/20260905-221204-fixture/build.log |
| Theme | Simulator light/dark switching and visual inspection | Text/table/task/code readable; restored light | chat-dark.png and chat.png |
| LAN progress delivery | HTTP GET /progress.html and 9 linked assets on 192.168.88.32:8876 | All HTTP 200 and byte-equal; old preview process had exited, restarted at same address | Dedicated .tools/ios-plan-lan/public copy; no full repository serving |
| Static review | plutil, git diff --check, target dependency audit | Pass; reviewed new files as well as tracked diff | review.md |

XcodeBuildMCP raw logs and xcresult reside under `~/Library/Developer/XcodeBuildMCP/workspaces/chatty-a525cea81dd1/`. Curated synthetic screenshots, logs and JSON evidence are tracked under iterations/ios-v1/evidence/p0; DerivedData stays ignored.

## Failures and follow-up

- First package compile: Markdown Table lazy sequences required explicit Array conversion; fixed and all tests passed.
- First simulator build: app tried x86_64 while package products were arm64. Set Debug ONLY_ACTIVE_ARCH=YES; simulator build passed. Release verification explicitly targeted current simulator architecture.
- First replay: agent-device 0.20.10 spawned an isolated daemon while the interactive daemon retained its iOS runner. Confirmed no active sessions, stopped only the owned daemon with --clean, and replay passed. README records the ownership rule.
- First dark screenshot was captured before the appearance transition. Waited for UI stability and recaptured; final screenshot reviewed as dark.
- Self-review found no live redirect evidence. Added a real HTTP 302 integration probe; it passed, and the owned synthetic fixture was restored.
- XCTest reports nine Apple-signed test-framework stripping warnings. These did not affect test results; normal Release app built without warnings. No unresolved P0 checks.

## Evidence boundaries

All network/UI evidence uses synthetic data. Real authentication, Keychain, real workspaces, sending, WebSocket recovery, production authorization, full Markdown/attachment interaction, physical iPhone signing and App Store distribution remain unverified and outside this slice. This is a local implementation, with no commit, push or application release. The HTML progress page contains actual simulator captures; it is separate from the original design mockups.
