# Numerical budget proposal T — methodology and current status

Status: **NO_BUDGET**. No absolute or relative threshold is proposed for acceptance yet, because
there is still no controlled B0. This document proposes (a) the decision rule that will produce T,
(b) a pre-registered measurement floor derived from the noise actually observed in the CLE-73
exploratory capture, and (c) what has to be true on the day for T to be frozen. Benjamin accepts
the numbers; until then Stage 3 (product optimization) does not start.

## Why no number can be frozen today

The only device data available is the CLE-73 exploratory capture, taken at battery 83%,
thermal LIGHT and adaptive refresh. Round-to-round changes on the **same** build were:

| Metric | Round 1 | Round 2 | Relative change |
| --- | --- | --- | --- |
| COLD first display median | 315.05 ms | 304.92 ms | -3.2% |
| COLD first display P95 | 366.26 ms | 337.83 ms | -7.8% |
| HOT first display median | 42.38 ms | 44.39 ms | +4.7% |
| HOT first display P95 | 59.00 ms | 49.69 ms | -15.8% |
| Frame CPU P95 | 7.65 ms | 7.59 ms | -0.8% |

Those are repeatability observations, not gains. They already show that a "win" of a few percent
on HOT P95 is inside the variation of the same binary, and the capture violated the thermal,
battery and refresh-rate conditions, so its absolute values cannot become the budget baseline.
Deriving T from them would manufacture a target from an invalid sample.

## Decision rule T will follow (proposed for acceptance now)

1. **Per metric, T uses the equal-condition noise first.** From the controlled B0 rounds, compute
   each metric's observed spread with `collect.py`'s `noise-envelope.json` (max absolute relative
   change between rounds for the same metric).
2. **Relative improvement must clear twice that spread**, and never less than a 10% engineering
   floor. A change smaller than the measurement floor is not a result.
3. **Absolute ceilings come from the B0 median of the same metric**, not from an aspiration:
   `T_absolute = median(round medians) x (1 + regression allowance)`, where the regression
   allowance is the observed equal-condition spread of that metric (so a metric may not move by
   more than its own noise before it counts as a regression).
4. **Tail metrics need enough samples.** P95 requires at least 10 launches per round; P99 is only
   reported, and only gated, when a round contributes at least 20 samples. Ten launches cannot
   establish a P99 budget.
5. **Budget covers the whole set, not one headline number.** Suggested gate list: cold first
   display (median/P95), hot first display (median/P95), composer-interactive (median/P95),
   frame CPU P95/P99, frame overrun P95/P99, post-start PSS, 24h peak PSS and leak slope,
   crash/ANR count, and degraded-network notice latency.
6. **Correctness gates are not negotiable against performance.** No cache or network change may
   pass by masking a server error, weakening a permission check, losing a write, or making
   cached data look fresher than it is. Those are pass/fail, not percentages.

## Pre-registered measurement floor (proposed)

Before any optimization is claimed, the controlled B0 must demonstrate that the harness is
stable enough for the gate to mean anything:

- primary medians (cold/hot first display, composer-interactive, frame CPU P95): equal-condition
  round-to-round spread **≤ 5%**;
- P95 metrics: spread **≤ 10%**;
- PSS snapshots: spread **≤ 3%**.

If a round exceeds that, the cause is found (thermal drift, background traffic, a device service,
an interrupted run) and the round is repeated. A capture that cannot meet the floor produces
exploratory data only — which is exactly the status of everything measured so far.

## What the collector delivers toward T

- `noise-envelope.json` — spread per metric from the repeated rounds, the input to rule 1.
- `<label>-gate.json` / `result.json` — whether the device conditions held; `budget_grade` must be
  true for the capture to be B0 at all.
- per-method raw evidence (logcat, probe JSON, Macrobenchmark JSON, traces, PSS, energy proxy) so
  every proposed number can be recomputed from the raw samples.

## What Benjamin is asked to accept

1. The decision rule above (relative improvements must clear the measured noise; absolute ceilings
   are B0-derived, not aspirational).
2. The measurement floor above as the precondition for calling a capture "B0".
3. A controlled window for the re-capture in `run-plan.md`. The concrete T values are submitted
   **after** that capture, as a single table with absolute and relative thresholds per metric and
   the raw evidence behind each number.
