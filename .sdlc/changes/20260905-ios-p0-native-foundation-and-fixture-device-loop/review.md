# Review: iOS P0 native foundation and fixture device loop

- Change ID: `20260905-ios-p0-native-foundation-and-fixture-device-loop`
- Verdict: approved
- Reviewer: Codex implementation author, self-review; no independent reviewer claimed.
- Delivery: local IOS-P0 only

## Reviewed scope

Reviewed the new Xcode targets/schemes/plists, Swift package and version locks, DTOs/Markdown/client, native views/model, contract/network tests, redirect integration probe, CLI scripts, device flow, .gitignore additions, lifecycle artifacts and curated evidence. Existing Android implementation and its closed SDLC change are unchanged. Original iOS design baseline remains intact; progress is a separate artifact.

## Findings

- Fixed the Debug architecture mismatch and Markdown lazy collection compile issue before accepting build results.
- Checked tied session timestamps preserve server order while excluding archived and non-Mika sessions; this has a regression test.
- Filled the missing HTTP redirect verification using the actual default FixtureClient and a local 302 server; target received no request.
- Confirmed the normal target compiles only ChattyApp, ShellView and Theme; package dependency is ChattyCore only. Its Release binary and plist contain no fixture marker or ATS exception.
- Removed machine-specific screenshot output paths from the reusable .ad flow and added explicit rich-content guards. Final exact flow passed 14 steps with 0 heals.
- Documented agent-device retained-runner contention and verified recovery without terminating other active sessions.
- No remaining actionable P0 findings. No tests were added for static report layout or other reversible formatting changes.

## Security and privacy

Synthetic fixture client has fixed loopback origin, GET-only routes, ephemeral session, disabled credential/cookie storage and no redirects. Test support is isolated from the normal app; there is no production auth/send/update path. Fixture audit records 0 sends and 0 Issue writes. The 302 integration check refuses an occupied port and never stops existing services. During verification, only the fixture process started by this task was replaced, then restored. Screenshots and public report contain synthetic records only; the LAN server exposes a dedicated copy directory.

## Residual risk

- Owner: next IOS-P1 change. Real login/Keychain/workspace authorization requires R3 classification, spec/plan gates and real-account evidence before acceptance.
- Owner: IOS-P2/P3. No sending, WebSocket or complete rich-content functionality is implied by P0; current rendering intentionally covers a small AST subset.
- Owner: IOS-P5. iOS 26.5 Simulator results do not prove physical-device signing, performance or distribution readiness.
- Self-review is the available review level for this local slice; no independent assessment occurred.
