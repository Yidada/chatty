# CLE-86 controlled B0 and soak run plan

Owner: **Mika** (operator, records the evidence). Window and numerical budget acceptance:
**Benjamin**. This plan is executable now; it is not executing — no Pixel was attached during
Stage 2b, so every device number below is still UNMEASURED.

## Waiting object, unlock conditions, checkpoints

- **Waiting object:** Benjamin's exclusive Pixel 6 Pro test window.
- **Unlock conditions:** Pixel 6 Pro attached and unlocked with the screen on; battery 40-80%;
  thermal status `NONE` and stable; fixed 60 Hz (`peak_refresh_rate` = `min_refresh_rate` = 60);
  battery saver off; no other adb automation against the device; port 8765 not already reversed.
- **Checkpoint discipline:** after every session, record on this issue the commit, APK hashes,
  device build, dataset manifest, valid/invalid sample counts, raw evidence, gate results and the
  still-UNMEASURED items. A session whose `result.json` reports `budget_grade: false` produces
  **no** B0 sample: the numbers are labelled exploratory and cannot feed the budget.
- **Abort rule:** stop the session if the device leaves the 40-80% / thermal NONE / 60 Hz envelope,
  if a measurement test fails, or if another process touches the device. Keep the failed attempt
  as evidence; never delete it and never count it as a slow or fast sample.

`collect.py` now evaluates the gate itself: it writes `<label>-environment.json` and
`<label>-gate.json` for every snapshot and only reports `budget_grade: true` when battery, thermal,
refresh and battery-saver checks all pass.

## Build (once per session; identical binaries for every compared round)

```bash
export ANDROID_HOME=<your Android SDK>
source scripts/android-env.sh
python3 -m unittest discover -s scripts/perf -p 'test_*.py'
android/gradlew -p android :app:assembleBenchmark :macrobenchmark:assembleBenchmark
```

The benchmark variant is release-based, non-debuggable, profileable, `R8=false`,
`CompilationMode.None`. Do not change the build or the dataset between the rounds you compare.
For DNS/TLS coverage against the designated test service, add
`-PchattyBenchmarkBaseUrl=https://<designated-test-service>/` and keep it for every round.

## Session A — controlled B0 re-capture (about 60-75 minutes)

Same scenarios as the CLE-73 exploratory capture (S1), now with the full instrument set.

```bash
python3 scripts/perf/collect.py --serial <Pixel-serial> --scenario S1 --rounds 3 \
  --methods cold hot scroll interactive network memory \
  --interactive-iterations 10 --network-launches 3 --output <new-evidence-directory>
```

Recorded per round: cold/hot `timeToInitialDisplayMs` (10/20 iterations), frame CPU and overrun
percentiles, composer-interactive boundary, app-side DNS/TCP/TLS/TTFB/end-to-end phases, PSS
snapshots, fixture request counts, environment gates, and a `noise-envelope.json` computed from
the three rounds.

Acceptance for "this is B0": three equal-condition rounds whose per-metric round-to-round spread
is inside the pre-registered envelope in `budget-proposal.md`; otherwise the capture is another
exploratory round and the cause is investigated before repeating.

## Session B — S2/S3/S4 scenario paths (about 45 minutes)

```bash
python3 scripts/perf/collect.py --serial <Pixel-serial> --scenario S2 --rounds 1 \
  --methods s2Pagination s2LiveEvent --output <dir-s2>
python3 scripts/perf/collect.py --serial <Pixel-serial> --scenario S3 --rounds 1 \
  --methods s3Traversal --output <dir-s3>
python3 scripts/perf/collect.py --serial <Pixel-serial> --scenario S4 --rounds 1 \
  --methods s4FaultCorrectness --output <dir-s4>
```

These paths have never run on a device. Expect the first device run to surface fixture or
selector gaps; fix them in the harness (never by weakening the assertion) and re-run. Their
numbers are correctness evidence, not performance budgets.

## Session C — 24-hour soak (24 hours plus setup, device must stay otherwise idle)

```bash
python3 scripts/perf/soak.py --serial <Pixel-serial> --output <dir-soak> --hours 24 --interval-min 5
```

Owner Mika; the device stays on the charger-free 40-80% envelope as long as it holds, and the
run records the drift instead of pretending it stayed constant. Outputs: `soak-samples.ndjson`,
`pss-N.json`, crash-buffer evidence, `degraded-window.json`, `soak-report.json`, `soak-plan.json`.
A dry run (`--iterations 3 --interval-min 1`) must pass before the 24-hour window is requested.

## Still UNMEASURED after this plan

| Item | Why | Unlock |
| --- | --- | --- |
| DNS / TLS phases | Cleartext loopback has neither | Designated HTTPS test service + `-PchattyBenchmarkBaseUrl` |
| Cache-hit rate, database size, query time, cache PSS cost | Baseline has no business cache; only the policy model exists | Isolated Room prototype per `instrumentation.md` section 3, run in a controlled window |
| Offline convergence to cached content | Baseline has no offline read-only UI | Stage 3 offline read-only implementation |
| True peak PSS / per-process energy | Only periodic samples and a device-wide proxy exist | Longer sampling window plus a dedicated energy profile |

## Issue checkpoints

1. After the build: post commit + APK SHA-256 and the plan being started.
2. After Session A: post gate results, valid/invalid counts, per-round summaries, noise envelope.
3. After Sessions B and C: post the correctness and soak evidence, or the concrete blocker.
4. If the window is not granted: keep every device item UNMEASURED, state the waiting object and
   the next check, and do not imply that collection is running in the background.
