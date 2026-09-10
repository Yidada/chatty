# CLE-86 Stage 2b measurement instrumentation

Status: **capability delivered, device numbers still UNMEASURED**. This change adds no product
optimization, no cache rollout and no budget. It turns the items CLE-73 left as
"UNMEASURED — needs instrumentation" into executable measurement paths, each with the
boundary it does and does not claim.

Everything host-side is unit-tested on the JVM/Python without a device. Device captures
remain gated on the controlled window described in `run-plan.md`.

## 1. Startup to composer interactive

| | |
| --- | --- |
| Boundary | App process start (`Process.getStartUptimeMillis()`) to the chat composer being placed in the window, enabled for typing, with its session resolved. |
| Producer | `android/core-ui/src/main/java/ai/chatty/core/ui/StartupProbe.kt`, called from the composer in `feature-chat` `ChatScreen.kt`. One record per process. |
| Consumer | `scripts/perf/collect.py --methods interactive` -> `round-N-interactive.json`, parsed by `scripts/perf/measure.py`. |
| Contract | `ChattyStartupProbe: composer-interactive elapsed_ms=<n> start_uptime_ms=<n> now_uptime_ms=<n> pid=<n> fully_drawn=<bool>` |

```bash
python3 scripts/perf/collect.py --serial <Pixel-serial> --scenario S1 --rounds 2 \
  --methods interactive --interactive-iterations 10 --output <new-evidence-directory>
```

The run also records `am start -W` `TotalTime` (first display) per iteration, so first display
and composer readiness are reported side by side from the same launch.

Not claimed:

- Message-history arrival is **not** part of the boundary. "First screen with content" is a
  different metric; the Macrobenchmark UI assertions still cover only that the fixture chat
  is reached.
- The origin is process start, not the `am start` call, so fork/exec is excluded.
- Only a COLD launch produces a record: a HOT start reuses the process, so there is no new
  boundary to measure.
- 10 iterations bound the median well and the tail poorly. Ten launches cannot establish a P99.
- If `Process.getStartUptimeMillis()` is unavailable the sample is discarded, never logged as a
  number.

## 2. Network DNS / TCP / TLS / TTFB / end-to-end

| | |
| --- | --- |
| Boundary | Per HTTP call, app-side OkHttp phases: DNS, TCP connect, TLS handshake, request-headers to response-headers (TTFB), body read, whole call. |
| Producer | `android/core-network/src/main/java/ai/chatty/core/network/NetworkProbe.kt`, installed through `createRetrofit` and armed by `ChattyApplication`. |
| Consumer | `scripts/perf/collect.py --methods network` -> `round-N-network.json`. |
| Opt-in | Device flag `settings put global chatty_network_probe 1`, set and cleared by the collector. With the flag absent every callback returns immediately: no behaviour change, no logging. |
| Privacy | Only method, host, port, redacted path, timings, status, protocol and the exception class. The path redacts identifier-shaped segments (`{id}`). Query strings, headers (including `Authorization`), bodies and payloads are never emitted. |

```bash
python3 scripts/perf/collect.py --serial <Pixel-serial> --scenario S1 --rounds 2 \
  --methods network --network-launches 3 --output <new-evidence-directory>
```

The fixture's handler time is still **not** a substitute, as required: only these app-side
records carry DNS/TCP/TLS/TTFB/end-to-end numbers, and the fixture metrics stay separate.

Not claimed:

- The default benchmark build points at cleartext loopback, which has **no DNS and no TLS in
  the path**. The collector therefore reports those phases under `unavailable_phases` instead of
  guessing. DNS/TLS stay UNMEASURED until a designated HTTPS test service is used.
- A designated service is selected at build time:
  `android/gradlew -p android :app:assembleBenchmark -PchattyBenchmarkBaseUrl=https://<designated-test-service>/`.
  Build the same way for every round that will be compared.
- `ttfb_ms` is measured when the response headers arrive; a served-from-cache response emits no
  such event and is reported as `null`, not zero.
- A single process run mixes startup traffic with refresh traffic. Per-endpoint percentiles are
  reported, but request totals are not per-launch budgets.

## 3. Cache hit / DB / query calibration

| | |
| --- | --- |
| What exists today | `scripts/perf/cache_policy.py` — an isolated replay model of the approved 4A limits (30 sessions, 10,000 messages or 50 MiB, evict on capacity, a session idle for 7 days may be evicted). |
| What it answers | Which accesses the policy can serve and when it evicts, for a synthetic access trace. `python3 scripts/perf/cache_policy.py`. |
| What it cannot answer | Database size, query latency, PSS cost or real cache-hit rate on a device. |

Baseline main has no business cache, so cache-hit rate is `UNMEASURED` and no product cache is
introduced here. The device half of the calibration is specified but not executed:

1. Land an isolated Room prototype behind a test-only module or `androidTest` source set; no
   production repository or UI path may read it.
2. Populate the approved 4A shape (30 sessions, 10,000 messages, 50 MiB ceiling), then measure
   database file size, p50/P95 query time (newest page, one older page, trace by task) and PSS
   with the database open.
3. Record the numbers next to this model's hit-rate expectation for the same trace. Treat any
   `4A` capacity revision as a new proposal for Benjamin, not a silent adjustment.

## 4. S2 / S3 / S4 scenario UI paths

`android/macrobenchmark/src/main/java/ai/chatty/macrobenchmark/ChattyBenchmark.kt` now defines
the exact paths CLE-73 lacked:

| Method | Path | Assertion |
| --- | --- | --- |
| `s2Pagination` | S2, load every older page through `加载更早消息` | The affordance disappears (fixture `has_more=false`) and at least 18 older pages were offered; bounded at 25 so a non-terminating pager fails instead of hanging. |
| `s2LiveEvent` | S2, append a message and broadcast `chat:message` | The appended marker renders without a manual refresh. |
| `s3Traversal` | S3, projects -> issues, then Runtimes/Agents/Squads detail round trips | Each list and `resource-detail` is reached with the fixture's own titles. |
| `s4FaultCorrectness` | S4, injected 500, 429, connection reset, WebSocket drop | The failure is surfaced, the composer survives, the socket reconnects (`已连接`), and a healthy refresh recovers. |

The fixture gained one deterministic control for this: `POST /__perf {"append_message": {...}}`
appends one synthetic assistant message (timestamped after the seeded maximum) and broadcasts
the matching `chat:message` frame. It is covered by `test_fixture.py`.

`s4FaultCorrectness` is a correctness test, not a benchmark: injected faults make timings
meaningless, so it runs once and asserts no crash, no permanent pending task and no dead socket.

## 5. Peak PSS / leak trend / energy proxy / degraded network / 24h soak

| | |
| --- | --- |
| Runner | `scripts/perf/soak.py` — owns its fixture and adb reverse mapping, reaps both before returning. |
| Samples | PSS, battery level, thermal status, process liveness every interval; crash-buffer crash/ANR counts for the target package; device-wide `batterystats` energy proxy at start and end. |
| Degraded window | Makes the fixture unreachable, measures how long until the connection notice appears in a `uiautomator` dump, then confirms recovery after reset. |
| Output | `soak-samples.ndjson`, `pss-N.json`, `crash` evidence, `degraded-window.json`, `soak-report.json`, `soak-plan.json`, `summary.json`. |

```bash
# bounded dry run first
python3 scripts/perf/soak.py --serial <Pixel-serial> --output <dir> --iterations 3 --interval-min 1
# the real window
python3 scripts/perf/soak.py --serial <Pixel-serial> --output <dir> --hours 24 --interval-min 5
```

Not claimed:

- "Peak PSS" is the maximum observed sample, not a true peak; the leak slope needs three
  distinct timestamps and is reported as `null` otherwise.
- The energy number is device-wide `batterystats`, a proxy, not per-process energy.
- The degraded window measures the connection-notice boundary. Baseline has **no offline
  read-only path**, so offline convergence to cached content stays UNMEASURED until Stage 3
  ships it. The runner deliberately does not assert an offline banner that does not exist.
- One clean soak is not proof of stability; crash/ANR counts cover the crash buffer for the
  window only.

## Host-side verification in this change

- `python3 -m unittest discover -s scripts/perf -p 'test_*.py'` — 44 tests: logcat contracts,
  network phase aggregation, environment gate, PSS/leak/energy parsing, noise envelope,
  benchmark-record summarization, uiautomator text parsing, the fixture append control and the
  cache-policy model.
- `./android/gradlew -p android :app:assembleBenchmark :macrobenchmark:assembleBenchmark
  :core-ui:testDebugUnitTest :core-network:testDebugUnitTest` — benchmark APKs build and the
  `StartupProbe`/`NetworkProbe` log-line contracts are pinned by JVM unit tests.

No device capture was possible for this change: no Pixel was attached, so every number above
remains UNMEASURED.
