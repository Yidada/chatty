# CLE-73 first Pixel samples — 2026-09-06

Status: **EXPLORATORY_MEASURED / NO_BUDGET**. First 10 valid cold-start samples were delivered on CLE-73 at 03:09 UTC with original JSON/traces/environment archive. Repetition and quality-check results follow below. No product optimization has started.

## Source and environment

- Product base `e7e1c518daaabe65db2c74f7fae236cc955e6d8c`; startup/scroll harness `8af0506c578b0439ef8e19fe141be22b3d80fa43`. S1 started on `2aad123` plus the working tree subsequently committed in `8af0506`; raw evidence includes patch and per-file hashes. Later collector/PSS additions do not change the installed S1 startup/scroll APKs.
- App APK SHA-256: `1c264e7b05ca52e5d69090b871951f29875c7be1a777d1334eecb9040c9d4ad4`.
- S1 test APK SHA-256: `c45bf20b9e206b7a0c94574a5f118a59986125b1b6d082aefeb3ea21a75dd848`.
- Pixel 6 Pro, Android 16 / SDK 36; fingerprint `google/raven/raven:16/CP1A.260405.003.A1/14990782:user/release-keys`.
- App non-debuggable/profileable, R8=false, CompilationMode.None; ART mainline `371000140`, CPU clocks unlocked.
- S1: one session, 50 messages, no attachments. Synthetic loopback + adb reverse; no production login/network data.
- Capture began at battery 83%, 37.5°C; thermal LIGHT (1), adaptive refresh (`peak=Infinity`, `min=0`), battery saver off. This violates the intended 40–80%/stable thermal/fixed 60 Hz protocol: **not budget-grade B0**.

## Valid repeated S1 samples

| Metric | Round 1 | Round 2 | Valid samples |
| --- | --- | --- | --- |
| COLD first display median / P95 (ms) | 315.05 / 366.26 | 304.92 / 337.83 | 10 + 10 |
| HOT first display median / P95 (ms) | 42.38 / 59.00 | 44.39 / 49.69 | 20 + 20 |
| Frame CPU P95 / P99 (ms) | 7.65 / 15.52 | 7.59 / 15.10 | 10 + 10 scroll iterations |
| Frame overrun P95 / P99 (ms) | -3.38 / 2.70 | -3.53 / 1.91 | 10 + 10 scroll iterations |

Frame samples: 5,135 + 5,124 = **10,259**. Positive frame overrun: 152/5,135 (2.96%) and 134/5,124 (2.62%). These are this trace metric’s deadline overruns, not a frozen jank acceptance threshold.

Observed round-to-round changes on the **same app**: cold median −3.22%, cold P95 −7.76%; hot median +4.74%, hot P95 −15.79%. CPU frame P95 differs by about −0.84%. These are repeatability observations, not optimization gains or statistical noise confidence bounds. Do not derive production budgets from the overheated/adaptive-refresh condition.

Fixture request totals per complete suite (including setup/warmup/reconciliation): cold 130/130, hot 265/265, scroll 13/13; all recorded REST responses were 200. They exclude the WebSocket protocol and are not per-launch network budgets. Fixture-handler time excludes transport/DNS/TLS/client scheduling.

All six measurement tests passed. Raw iteration arrays are in `samples/s1-benchmark.json`; complete instrumentation/fixture/environment logs and all unique Perfetto traces are delivered as private issue attachments. The `timeToInitialDisplayMs` startup metric is first display, not first-interactive or fully-drawn timing. No offline/cache/soak success is implied.

## Running-process PSS

Five S1 force-stop/launch cycles, sampled one second after fixture messages were visible: **[151100, 149822, 149826, 150037, 150181] KiB**, median **146.52 MiB**, range **146.31–147.56 MiB**. All five snapshots passed the live-process assertion. These are post-start snapshots, not peaks or a leak trend.

App APK is unchanged. Memory test source is in `e9e44da`; test APK SHA-256 is `85c7a99c58d6128fa5a3169c014ddf750ef424e8e46f4b6d6f7f08ef2b690314`. This standalone PSS test uses normal system compilation state, **not** Macrobenchmark's None reset. The raw collector's generic `compilation: None` field in this memory-only run is a labeling bug; the corrected interpretation is preserved here and in `samples/s1-memory.json`, and future collector output is fixed.

All capture processes completed in the foreground. The fixture was terminated, adb reverse removed, and the isolated benchmark app force-stopped. No collection remains running after handoff.

## Invalid attempts retained

1. Locked Pixel: prepare failed before measurement.
2. Unlocked retry: unconditional test Back exited login when no keyboard was shown; fixed in harness.
3. Prepare then passed, but Macrobenchmark 1.3.4 gfxinfo launch confirmation failed on Android 16; no valid metric emitted. The failure log is retained; that failed attempt’s device trace was not exported before the next run, and is not included in the 80 valid traces.
4. Current launch uses `am start -W` Status=ok plus actual fixture UI assertions. Macrobenchmark still controls COLD/HOT lifecycle, tracing and extraction. No unrelated Kotlin/product upgrade was introduced.

Macrobenchmark 1.3.4 predates the runtime-image workaround added in 1.4.0-rc01; `CompilationMode.None` is the recorded mode, not a guarantee that every iteration represents worst-case ART state ([release notes](https://developer.android.com/jetpack/androidx/releases/benchmark#1.4.0-rc01)).

No failed preparation counts as a slow launch; no missing meminfo process counts as zero PSS. Percentiles use linear interpolation of raw iteration values. Ten launches cannot establish a stable P99 budget.

## Remaining gates and next checkpoint

CLE-86 turned the instrumentation column below into executable measurement paths (see
`instrumentation.md`); the numbers remain UNMEASURED until the controlled window in `run-plan.md`.

| Item | State / wait owner / unlock / next check |
| --- | --- |
| Fixed-condition B0 and numerical T | NO_BUDGET; Mika coordinates with Benjamin; Pixel at 40–80%, thermal NONE/stable, fixed 60 Hz and exclusive test window; repeat equal-condition rounds before optimization decisions. Decision rule and measurement floor proposed in `budget-proposal.md`. |
| Startup to composer readiness | Instrumentation ready (`collect.py --methods interactive`, one record per process); UNMEASURED on device; next device capture |
| Network DNS/TLS/TTFB/end-to-end latency | App-side phase probe ready (`--methods network`); TCP/TTFB/end-to-end measurable on loopback, DNS/TLS need a designated HTTPS service via `-PchattyBenchmarkBaseUrl`; UNMEASURED on device |
| Cache hit/DB/query calibration | Policy model ready (`cache_policy.py`); baseline has no business cache, so device cache-hit/DB/query/PSS stay UNMEASURED pending the isolated Room prototype |
| S2 all-page/live-event rendering, S3 traversal, S4 fault correctness | UI paths now defined (`s2Pagination`, `s2LiveEvent`, `s3Traversal`, `s4FaultCorrectness`); never executed on a device; next controlled window |
| Peak PSS/leaks, energy, 24h soak, degraded network | `soak.py` owns the sampling, energy proxy, crash/ANR counting and degraded-network window; 24h owner/duration recorded in `soak-plan.json`; not yet run |
| Offline convergence to cached content | UNMEASURED; baseline has no offline read-only UI (Stage 3); the soak runner deliberately does not assert a banner that does not exist |

CLE-70 remains the overall V3 tracker. PR #2 was closed only after migration; #3 no longer carries parent close intent; #4 does not close CLE-70/CLE-73 on merge. The collector owns and cleans its fixture/reverse mapping before returning.

## Local validation

Benchmark app/test APK builds, Debug APK build and lint passed. JVM executions: 46 Debug + 46 Release + 3 app Benchmark, all passed; variant executions overlap and are not 95 distinct cases. Three Python fixture tests passed (composite cursor coverage without gaps/duplicates, deterministic fixture shape, fault status/Retry-After/metric redaction). Final Python syntax and diff checks passed. No CI result is asserted.
