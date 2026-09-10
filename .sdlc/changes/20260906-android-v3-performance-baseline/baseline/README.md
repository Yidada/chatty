# CLE-73 / CLE-86 Stage 2 baseline harness

1A–6A were approved on 2026-09-06. This change prepares measurement; it does not optimize the product or freeze budgets. See `../intent.md` and `pr-audit.md`. Device measurements and omissions belong in `results.md`. CLE-86 added the remaining instrument set (composer-interactive boundary, app-side network phases, S2/S3/S4 UI paths, soak runner): see `instrumentation.md`, `run-plan.md` and `budget-proposal.md`.

## Reproduce

```bash
export ANDROID_HOME=/Users/benjamin/Android/Sdk   # use the installed SDK on your host
source scripts/android-env.sh
python3 -m unittest discover -s scripts/perf -p 'test_*.py' -v
android/gradlew -p android :app:assembleBenchmark :macrobenchmark:assembleBenchmark
python3 scripts/perf/collect.py --serial <Pixel-serial> --scenario S1 \
  --rounds 2 --methods cold hot scroll --output <new-evidence-directory>
```

CLE-86 method families (full boundaries and limits in `instrumentation.md`):

```bash
# process start -> composer interactive, plus first display from the same launch
python3 scripts/perf/collect.py --serial <Pixel-serial> --scenario S1 --rounds 2 \
  --methods interactive --interactive-iterations 10 --output <dir>
# app-side DNS/TCP/TLS/TTFB/end-to-end phases (opt-in device flag is set and cleared by the collector)
python3 scripts/perf/collect.py --serial <Pixel-serial> --scenario S1 --rounds 2 \
  --methods network --network-launches 3 --output <dir>
# S2 full paging / live event, S3 traversal, S4 fault correctness
python3 scripts/perf/collect.py --serial <Pixel-serial> --scenario S2 --rounds 1 \
  --methods s2Pagination s2LiveEvent --output <dir>
# 24h soak, energy proxy, degraded-network window (bounded dry run first)
python3 scripts/perf/soak.py --serial <Pixel-serial> --output <dir> --iterations 3 --interval-min 1
# isolated cache-policy replay against the approved 4A limits (policy model, not a device measurement)
python3 scripts/perf/cache_policy.py
```

The collector installs `ai.chatty.app.benchmark` and a separate self-instrumenting test APK. It clears only the disposable benchmark package, logs in using synthetic email/code via UI, owns a loopback fixture and adb reverse mapping, and terminates both before returning. Never point it at the production/debug package. Output must be a new directory. Do not share port 8765 with another test run. Unlock the Pixel and keep its screen on before running; no PIN or real token is required.

The app variant is based on release, non-debuggable, profileable, debug-signed, with unchanged R8=false and dependencies falling back to release. Cleartext is limited to localhost in this variant only. No production behavior or caching strategy changes. `CompilationMode.None()` is recorded explicitly; comparison runs must keep this mode. No Baseline Profile is installed by this change.

Macrobenchmark 1.3.4 matches the existing Kotlin 1.9.25/compileSdk 35 toolchain. Its built-in gfxinfo launch confirmation failed on this Android 16 build, so the harness uses `am start -W` plus required fixture UI assertions; Macrobenchmark still owns COLD/HOT process handling, tracing and metrics. This workaround is disclosed as part of the measurement method. The newer 1.4 line requires Kotlin 2.0, so it was not used to force an unrelated toolchain upgrade ([release notes](https://developer.android.com/jetpack/androidx/releases/benchmark#1.4.0-alpha11)). Setup follows [Android's Macrobenchmark guide](https://developer.android.com/topic/performance/benchmarking/macrobenchmark-overview) and [MacrobenchmarkRule API](https://developer.android.com/reference/androidx/benchmark/macro/junit4/MacrobenchmarkRule). StartupTimingMetric reports first display, **not composer readiness**. The UI assertions ensure navigation reaches the fixture chat, but are not a first-interactive metric. `hot` uses HOT (same Activity), distinct from WARM (Activity recreation); intent terminology must not conflate them.

## Fixture and scope

Run independently with `python3 scripts/perf/fixture.py --scenario S2`. It binds only 127.0.0.1:8765, and never calls Multica.

- S0: same deterministic service, intended for logged-out/login tests; current collector prepares login, so S0 must not be labeled a logged-out startup capture with that collector.
- S1: one session, 50 messages, no attachments.
- S2: 20 sessions, 1,000 messages in target s1, 20% Markdown, 10 image metadata entries, active pending task, 200 traces. Only s1 has history. Pagination includes tied timestamps and uses the `(created_at,id)` cursor contract. `s2Pagination` now loads every page; `s2LiveEvent` appends one message through `/__perf` and requires the app to render the broadcast `chat:message` frame.
- S3: 50 projects, 2,000 issues, 34 agents + 33 runtimes + 33 squads. `s3Traversal` now walks projects -> issues and the Runtimes/Agents/Squads detail round trips.
- S4: S2 plus `POST /__perf` controls: `delay_ms`, `status`, `retry_after`, `disconnect`, `drop_ws`, `append_message`, ordered `events` (caller may intentionally reorder). A delay above the unchanged 25s call timeout exercises timeout. `s4FaultCorrectness` asserts 5xx/429/reset/dropped-socket correctness without claiming a performance budget.

Control examples (Python, host loopback only):

```python
import json, urllib.request
payload = {'delay_ms': 500, 'status': 429, 'retry_after': 2}
request = urllib.request.Request('http://127.0.0.1:8765/__perf',
    data=json.dumps(payload).encode(), headers={'Content-Type': 'application/json'})
urllib.request.urlopen(request).close()
# Restore: {'delay_ms': 0, 'status': 200, 'disconnect': False}
# Drop socket: {'drop_ws': True}
# Append one message and broadcast chat:message: {'append_message': {'content': 'Live event 1'}}
# Reset counters: {'reset_metrics': True}
```

`/__manifest` returns dataset hash and cardinalities. `__metrics` logs endpoint templates, method/status, response bytes and fixture-handler elapsed time, without headers, request bodies or query strings. It excludes client scheduling, transport, DNS/TLS and is not end-to-end latency. Request totals include setup/compilation/measurement overhead; do not divide them by iteration count and call that per-launch traffic. Active socket count is an instantaneous snapshot, not proof of no concurrent overlap. Cache counters remain UNMEASURED because no business cache exists in baseline main.

## Evidence and quality gates

Keep APK hashes, source revision plus working-tree patch, dataset manifest, Android fingerprint, battery/thermal/display/power snapshots, individual instrumentation results, Macrobenchmark JSON, Perfetto traces and network records. A failed `prepare`, failed instrumentation, missing required UI or missing JSON is not a valid sample. Keep failures alongside subsequent successes rather than deleting them.

Before budget-grade B0: fix 60 Hz, retain animation scales, battery saver off, battery 40–80%, stable temperature, no overlapping device automation, identical APK/dataset/compilation per repeated run. Keep fixture numbers separate from production network numbers. Two rounds quantify only initial noise; tail percentiles from 10 launches remain exploratory. The `memory` method produces five PSS snapshots one second after fixture messages become visible, captured through instrumentation output. Post-Macrobenchmark meminfo may say "No process found" because the library kills the app; those are not zero-valued samples. PSS snapshots are not sampled peaks or leak proof.

The collector now evaluates those conditions itself per snapshot (`<label>-environment.json`, `<label>-gate.json`, `result.json:budget_grade`) and writes `noise-envelope.json` across repeated rounds. `interactive` measures process start to composer readiness; `network` captures app-side DNS/TCP/TLS/TTFB/end-to-end for the benchmark build's API base URL (DNS/TLS need a designated HTTPS service selected with `-PchattyBenchmarkBaseUrl`); `soak.py` owns the 24h plan. Boundaries and non-claims per method: `instrumentation.md`, `run-plan.md`, `budget-proposal.md`.

No B0/T = no product optimization. Benjamin accepts actual absolute and relative budgets only after representative repeated captures and noise review. The absence of a crash in one test is not 24-hour stability evidence. Long soak, offline recovery, permission/identity cleanup, cache/DB calibration and fault-path correctness require their own executions.
