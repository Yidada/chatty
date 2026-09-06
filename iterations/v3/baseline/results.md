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

## Invalid attempts retained

1. Locked Pixel: prepare failed before measurement.
2. Unlocked retry: unconditional test Back exited login when no keyboard was shown; fixed in harness.
3. Prepare then passed, but Macrobenchmark 1.3.4 gfxinfo launch confirmation failed on Android 16; no valid metric emitted. Its failed trace is retained, excluded from metric counts.
4. Current launch uses `am start -W` Status=ok plus actual fixture UI assertions. Macrobenchmark still controls COLD/HOT lifecycle, tracing and extraction. No unrelated Kotlin/product upgrade was introduced.

No failed preparation counts as a slow launch; no missing meminfo process counts as zero PSS. Percentiles use linear interpolation of raw iteration values. Ten launches cannot establish a stable P99 budget.

## Remaining gates and next checkpoint

| Item | State / wait owner / unlock / next check |
| --- | --- |
| Fixed-condition B0 and numerical T | NO_BUDGET; Mika coordinates with Benjamin; Pixel at 40–80%, thermal NONE/stable, fixed 60 Hz and exclusive test window; repeat equal-condition rounds before optimization decisions |
| Startup to composer readiness | UNMEASURED; Mika instrumentation follow-up; define timing boundary beyond UI assertions; next device capture |
| Network DNS/TLS/TTFB/end-to-end latency | UNMEASURED; measurement integration + designated test service; next network capture; fixture-handler time is not a substitute |
| Cache hit/DB/query calibration | UNMEASURED; baseline has no business cache; isolated cache prototype/measurement before rollout |
| S2 all-page/live-event rendering, S3 traversal, S4 fault correctness | UNMEASURED on device; data/control fixtures ready; add exact UI paths in next controlled window |
| Peak PSS/leaks, offline convergence, energy, 24h soak | UNMEASURED; scenario instrumentation + reserved duration; next checkpoint: concrete run plan/owner/time before execution |

CLE-70 remains the overall V3 tracker. PR #2 was closed only after migration; #3 no longer carries parent close intent; #4 does not close CLE-70/CLE-73 on merge. The collector owns and cleans its fixture/reverse mapping before returning.
