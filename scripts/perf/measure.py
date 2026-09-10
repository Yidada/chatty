#!/usr/bin/env python3
"""Parse and aggregate Stage 2b measurement artifacts.

This module is deliberately free of device access so every rule below can be
unit-tested on a host. Collectors write raw text (logcat, dumpsys, fixture JSON);
summarizers call the ``parse_*``/``summarize_*`` functions here.

Boundaries that this module does not claim:

* A fixture-handler elapsed time is never end-to-end latency; only the app-side
  ``netcall`` records carry DNS/TCP/TLS/TTFB/end-to-end numbers.
* A ``composer-interactive`` record is measured inside the app process, so it
  excludes process fork/exec before ``Process.getStartUptimeMillis()``. It is a
  boundary relative to process start, not to the ``am start`` invocation.
* PSS snapshots are periodic samples, not true peaks. A "peak" here is the
  maximum observed sample; a leak trend is a slope on observed samples only.
"""
from __future__ import annotations

import argparse
import json
import re
import statistics
from dataclasses import asdict, dataclass, field
from pathlib import Path

STARTUP_TAG = 'ChattyStartupProbe'
NETWORK_TAG = 'ChattyNetProbe'
# Battery/thermal/refresh gates agreed for budget-grade B0 (see baseline/README.md).
BATTERY_MIN_PCT = 40
BATTERY_MAX_PCT = 80
THERMAL_NONE = 0
FIXED_REFRESH_HZ = 60.0

_STARTUP_RE = re.compile(
    r'composer-interactive\s+elapsed_ms=(?P<elapsed>-?\d+)\s+start_uptime_ms=(?P<start>\d+)'
    r'\s+now_uptime_ms=(?P<now>\d+)\s+pid=(?P<pid>\d+)'
    r'(?:\s+fully_drawn=(?P<fully>true|false))?'
)
_NETCALL_RE = re.compile(r'netcall (?P<payload>\{.*\})\s*$')


def percentile(values, fraction):
    """Linear interpolation, matching the convention used by the CLE-73 report."""
    if not values:
        raise ValueError('percentile needs at least one value')
    if not 0.0 <= fraction <= 1.0:
        raise ValueError('fraction must be within [0, 1]')
    ordered = sorted(float(v) for v in values)
    if len(ordered) == 1:
        return ordered[0]
    position = fraction * (len(ordered) - 1)
    lower = int(position)
    upper = min(lower + 1, len(ordered) - 1)
    weight = position - lower
    return ordered[lower] * (1 - weight) + ordered[upper] * weight


def summarize(values, prefix=''):
    """Return count/median/P95/P99/max for a numeric series."""
    numbers = [float(v) for v in values if v is not None]
    if not numbers:
        return {'n': 0}
    out = {
        'n': len(numbers),
        'min': min(numbers),
        'median': statistics.median(numbers),
        'p95': percentile(numbers, 0.95),
        'max': max(numbers),
    }
    if len(numbers) >= 20:
        out['p99'] = percentile(numbers, 0.99)
    else:
        out['p99'] = None
    return {prefix + key: value for key, value in out.items()} if prefix else out


@dataclass
class StartupSample:
    elapsed_ms: int
    start_uptime_ms: int
    now_uptime_ms: int
    pid: int
    fully_drawn: bool = False


@dataclass
class NetworkCall:
    call_id: str = ''
    method: str = ''
    host: str = ''
    port: int | None = None
    path: str = ''
    dns_ms: float | None = None
    tcp_ms: float | None = None
    tls_ms: float | None = None
    ttfb_ms: float | None = None
    body_ms: float | None = None
    e2e_ms: float | None = None
    status: int | None = None
    protocol: str = ''
    outcome: str = ''
    error: str = ''

    def phase_summary(self):
        return {
            'dns': summarize([c.dns_ms for c in [self]]),
            'tcp': summarize([c.tcp_ms for c in [self]]),
            'tls': summarize([c.tls_ms for c in [self]]),
            'ttfb': summarize([c.ttfb_ms for c in [self]]),
            'body': summarize([c.body_ms for c in [self]]),
            'e2e': summarize([c.e2e_ms for c in [self]]),
        }


def parse_startup_probe(text):
    """Extract ``composer-interactive`` records from logcat text.

    Duplicate records for the same pid are collapsed to the earliest elapsed
    value: a process reaches the composer boundary once, and a later duplicate
    would be a re-layout, not a startup sample.
    """
    samples = {}
    order = []
    for line in text.splitlines():
        match = _STARTUP_RE.search(line)
        if not match:
            continue
        pid = int(match.group('pid'))
        sample = StartupSample(
            elapsed_ms=int(match.group('elapsed')),
            start_uptime_ms=int(match.group('start')),
            now_uptime_ms=int(match.group('now')),
            pid=pid,
            fully_drawn=(match.group('fully') == 'true'),
        )
        if sample.elapsed_ms < 0:
            continue
        previous = samples.get(pid)
        if previous is None or sample.elapsed_ms < previous.elapsed_ms:
            if previous is None:
                order.append(pid)
            samples[pid] = sample
    return [samples[pid] for pid in order]


def summarize_startup(text_or_samples):
    samples = parse_startup_probe(text_or_samples) if isinstance(text_or_samples, str) else list(text_or_samples)
    return {
        'samples': len(samples),
        'elapsed_ms': summarize([s.elapsed_ms for s in samples]),
        'fully_drawn_observed': sum(1 for s in samples if s.fully_drawn),
    }


def parse_netcalls(text):
    """Extract app-side ``netcall`` JSON records from logcat text."""
    calls = []
    for line in text.splitlines():
        match = _NETCALL_RE.search(line)
        if not match:
            continue
        try:
            payload = json.loads(match.group('payload'))
        except json.JSONDecodeError:
            continue
        if not isinstance(payload, dict):
            continue
        known = {}
        for field_name in NetworkCall.__dataclass_fields__:
            source = 'id' if field_name == 'call_id' else field_name
            if source in payload:
                known[field_name] = payload[source]
        calls.append(NetworkCall(**known))
    return calls


def summarize_netcalls(text_or_calls):
    calls = parse_netcalls(text_or_calls) if isinstance(text_or_calls, str) else list(text_or_calls)
    succeeded = [c for c in calls if c.outcome == 'success']
    failed = [c for c in calls if c.outcome != 'success']
    return {
        'calls': len(calls),
        'failed_calls': len(failed),
        'failure_classes': sorted({c.error for c in failed if c.error}),
        'statuses': sorted({c.status for c in calls if c.status is not None}),
        'by_phase': {phase: summarize([getattr(c, phase + '_ms') for c in succeeded]) for phase in ('dns', 'tcp', 'tls', 'ttfb', 'body', 'e2e')},
        # A phase with no samples is unavailable on this path, not zero. DNS and
        # TLS never appear on cleartext loopback, so they stay UNMEASURED until a
        # designated HTTPS test service is used.
        'unavailable_phases': sorted(phase for phase in ('dns', 'tcp', 'tls', 'ttfb', 'body', 'e2e')
                                     if not [c for c in succeeded if getattr(c, phase + '_ms') is not None]),
        # Latency percentiles per endpoint cover completed calls only; mixing
        # failures in would report error-path durations as service latency.
        'by_endpoint': {path: summarize([c.e2e_ms for c in group])
                        for path, group in sorted(_group_by(succeeded, lambda c: c.path).items())},
        'protocols': sorted({c.protocol for c in calls if c.protocol}),
    }


def _group_by(items, key):
    groups = {}
    for item in items:
        groups.setdefault(key(item), []).append(item)
    return groups


def parse_battery_level(text):
    """``dumpsys battery`` -> percentage, or None when the section is absent."""
    match = re.search(r'^\s*level:\s*(\d+)\s*$', text, re.MULTILINE)
    return int(match.group(1)) if match else None


def parse_thermal_status(text):
    """``dumpsys thermalservice`` -> worst current thermal status integer.

    Android reports 0 NONE, 1 LIGHT, 2 MODERATE, 3 SEVERE, 4 CRITICAL,
    5 EMERGENCY, 6 SHUTDOWN. ``Current thermal status: N`` is authoritative when
    present; otherwise the maximum status in the service dump is used.
    """
    match = re.search(r'Current thermal status:\s*(\d+)', text)
    if match:
        return int(match.group(1))
    statuses = [int(m) for m in re.findall(r'Thermal Status:\s*(\d+)', text)]
    return max(statuses) if statuses else None


def parse_refresh_rate(text):
    """``settings get system peak_refresh_rate`` -> float Hz, or None for adaptive."""
    value = text.strip()
    if not value or value in ('null', 'Infinity', 'inf'):
        return None
    try:
        return float(value)
    except ValueError:
        return None


def parse_total_pss_kib(meminfo_text):
    """``dumpsys meminfo <pkg>`` -> TOTAL PSS in KiB, rejecting dead-process dumps.

    Android prints the total in two shapes depending on version and flags:
    an ``App Summary`` block with ``TOTAL PSS:`` and the per-process table row
    ``TOTAL   123456  ...``. Both are accepted; a dump without either is None,
    never zero.
    """
    if 'No process found' in meminfo_text:
        return None
    match = re.search(r'TOTAL PSS:\s*(?P<total>\d+)', meminfo_text)
    if match:
        return int(match.group('total'))
    match = re.search(r'^[ \t]*TOTAL[ \t]+(?P<total>\d+)[ \t]*$', meminfo_text, re.MULTILINE)
    if match:
        return int(match.group('total'))
    match = re.search(r'^[ \t]*TOTAL[ \t]+(?P<total>\d+)', meminfo_text, re.MULTILINE)
    return int(match.group('total')) if match else None


def parse_energy_mah(text):
    """``dumpsys batterystats`` -> estimated mAh for the whole device.

    The dump exposes an ``Estimated power use (mAh)`` block whose ``Computed
    drain`` line is the battery historian estimate. It is an aggregate proxy for
    device energy, not a per-process measurement, and stays a proxy until a
    dedicated energy profile is captured.
    """
    match = re.search(r'Computed drain:\s*([0-9.]+)', text)
    return float(match.group(1)) if match else None


def parse_uid_energy_mah(text, uid):
    """Per-UID energy estimate for a numeric uid when the dump provides one."""
    if uid is None:
        return None
    match = re.search(r'Uid\s+' + str(uid) + r':\s*([0-9.]+)', text)
    return float(match.group(1)) if match else None


def environment_gate(environment):
    """Decide whether a capture met the agreed budget-grade device conditions."""
    battery = environment.get('battery_pct')
    thermal = environment.get('thermal_status')
    peak = environment.get('peak_refresh_rate')
    min_rate = environment.get('min_refresh_rate')
    low_power = environment.get('low_power')
    checks = {
        'battery_in_range': battery is not None and BATTERY_MIN_PCT <= battery <= BATTERY_MAX_PCT,
        'thermal_none': thermal == THERMAL_NONE,
        'fixed_60hz': peak == FIXED_REFRESH_HZ and min_rate == FIXED_REFRESH_HZ,
        'battery_saver_off': low_power in (0, '0', False, None),
    }
    blocking = sorted(name for name, ok in checks.items() if not ok)
    return {
        'checks': checks,
        'blocking': blocking,
        'budget_grade': not blocking,
        'observed': {
            'battery_pct': battery,
            'thermal_status': thermal,
            'peak_refresh_rate': peak,
            'min_refresh_rate': min_rate,
            'low_power': low_power,
            'expected': {'battery_pct': [BATTERY_MIN_PCT, BATTERY_MAX_PCT], 'thermal_status': THERMAL_NONE,
                          'refresh_hz': FIXED_REFRESH_HZ, 'low_power': 0},
        },
    }


def peak_pss_kib(samples):
    values = [s for s in samples if s is not None]
    return max(values) if values else None


def leak_slope_kib_per_hour(samples):
    """Least-squares slope over ``[{'at_s': seconds, 'pss_kib': kib}, ...]``.

    Returns None when fewer than three samples exist or all timestamps coincide;
    two points are a line by construction and cannot show a trend.
    """
    points = [(float(s['at_s']), float(s['pss_kib'])) for s in samples if s.get('pss_kib') is not None]
    if len(points) < 3:
        return None
    times = [p[0] for p in points]
    values = [p[1] for p in points]
    if max(times) == min(times):
        return None
    mean_t = statistics.fmean(times)
    mean_v = statistics.fmean(values)
    denominator = sum((t - mean_t) ** 2 for t in times)
    if denominator == 0:
        return None
    slope_kib_per_s = sum((t - mean_t) * (v - mean_v) for t, v in points) / denominator
    return slope_kib_per_s * 3600.0


def noise_envelope(rounds):
    """Round-to-round relative spread per metric, used as the measurement floor.

    ``rounds`` is ``{round_label: {metric: value}}``. The envelope is the maximum
    absolute relative change between any two rounds (or None when fewer than two
    rounds define a metric). It is an observed spread, not a confidence bound.
    """
    metrics = sorted({metric for values in rounds.values() for metric in values})
    envelope = {}
    for metric in metrics:
        values = [(label, values[metric]) for label, values in rounds.items() if metric in values]
        if len(values) < 2:
            envelope[metric] = {'max_abs_relative_change': None, 'signed_change': None, 'pair': None,
                                'reason': 'fewer than two rounds define this metric'}
            continue
        base_label, base = values[0]
        worst = 0.0
        worst_pair = None
        for label, value in values[1:]:
            if base in (None, 0) or value is None:
                continue
            change = (value - base) / base
            if abs(change) >= abs(worst):
                worst = change
                worst_pair = [base_label, label]
        envelope[metric] = {'max_abs_relative_change': abs(worst), 'signed_change': worst, 'pair': worst_pair}
    return envelope


def relative_change(before, after):
    if before in (None, 0) or after is None:
        return None
    return (after - before) / before


def ui_texts(xml):
    """Extract visible ``text=``/``content-desc=`` values from a uiautomator dump."""
    values = []
    for match in re.finditer(r'(?:text|content-desc)="([^"]*)"', xml or ''):
        value = match.group(1).strip()
        if value:
            values.append(value)
    return values


def ui_contains(xml, needle):
    return any(needle in value for value in ui_texts(xml))


def soak_report(samples, crashes=0, anrs=0, energy_start_mah=None, energy_end_mah=None,
                battery_start_pct=None, battery_end_pct=None, degraded_notice_seconds=None):
    """Summarize a soak sample series. Percentiles/trends only; no pass/fail budget."""
    ordered = sorted(samples, key=lambda s: s['at_s'])
    duration_hours = (ordered[-1]['at_s'] - ordered[0]['at_s']) / 3600.0 if len(ordered) > 1 else 0.0
    energy_delta = None
    if energy_start_mah is not None and energy_end_mah is not None:
        energy_delta = energy_end_mah - energy_start_mah
    battery_delta = None
    if battery_start_pct is not None and battery_end_pct is not None:
        battery_delta = battery_start_pct - battery_end_pct
    return {
        'samples': len(ordered),
        'duration_hours': duration_hours,
        'peak_pss_kib': peak_pss_kib([s.get('pss_kib') for s in ordered]),
        'leak_slope_kib_per_hour': leak_slope_kib_per_hour(ordered),
        'crashes': crashes,
        'anrs': anrs,
        'device_energy_mah': energy_delta,
        'battery_pct_drop': battery_delta,
        'degraded_notice_seconds': degraded_notice_seconds,
        'peak_pss_is_observed_max': True,
        'verdict': 'MEASURED_CANDIDATE' if len(ordered) >= 3 else 'UNMEASURED',
    }


@dataclass
class CaptureSummary:
    startup: dict = field(default_factory=dict)
    network: dict = field(default_factory=dict)
    environment: dict = field(default_factory=dict)
    memory: dict = field(default_factory=dict)
    energy: dict = field(default_factory=dict)

    def to_json(self):
        return json.dumps(asdict(self), indent=2, sort_keys=True)


def summarize_capture(output_dir):
    """Read a collector output directory and produce one machine-readable summary."""
    out = Path(output_dir)
    text = _read_joined(out, '*-logcat.txt')
    startup = summarize_startup(text)
    network = summarize_netcalls(text)
    environment = {}
    for label in ('before', 'after'):
        candidate = out / f'{label}-environment.json'
        if candidate.exists():
            environment[label] = json.loads(candidate.read_text())
    memory_samples = []
    for candidate in sorted(out.glob('pss-*.json')):
        payload = json.loads(candidate.read_text())
        memory_samples.extend(payload if isinstance(payload, list) else [payload])
    memory = {
        'samples': len(memory_samples),
        'peak_pss_kib': peak_pss_kib([s.get('pss_kib') for s in memory_samples]),
        'leak_slope_kib_per_hour': leak_slope_kib_per_hour(memory_samples),
    }
    batterystats = _read_joined(out, '*batterystats*.txt')
    energy = {
        'estimated_device_mah': parse_energy_mah(batterystats),
        'scope': 'device-wide batterystats proxy; not a per-process energy measurement',
    }
    return CaptureSummary(startup=startup, network=network, environment=environment, memory=memory, energy=energy)


def _read_joined(directory, pattern):
    chunks = []
    for path in sorted(Path(directory).glob(pattern)):
        chunks.append(path.read_text(errors='replace'))
    return '\n'.join(chunks)


def summarize_benchmark_dir(directory):
    """Summarize raw Macrobenchmark ``*benchmarkData.json`` files under a directory.

    Moved here from ``summarize.py`` so the collector, the CLI summarizer and the
    budget envelope all use one implementation. Identical records are emitted once
    (a pull can contain an earlier run's file), and a metric whose runs are not all
    numeric is reported as ``UNMEASURED`` rather than as zero.
    """
    output = []
    seen = set()
    for path in sorted(Path(directory).rglob('*benchmarkData.json')):
        data = json.loads(path.read_text())
        for benchmark in data.get('benchmarks', []):
            signature = json.dumps(benchmark, sort_keys=True)
            if signature in seen:
                continue
            seen.add(signature)
            row = {'source': str(path.relative_to(directory)), 'name': benchmark.get('name', 'unknown'),
                   'context': data.get('context', {}), 'metrics': {}}
            for name, metric in benchmark.get('metrics', {}).items():
                runs = metric.get('runs', [])
                if not runs or not all(isinstance(v, (int, float)) for v in runs):
                    row['metrics'][name] = {'status': 'UNMEASURED', 'raw': metric}
                    continue
                row['metrics'][name] = {'n': len(runs), 'runs': runs, 'median': statistics.median(runs),
                    'p95': percentile(runs, .95), 'p99': percentile(runs, .99), 'min': min(runs), 'max': max(runs)}
            # Frame metrics use sampledMetrics in this library. Preserve iteration
            # grouping and library-computed distribution, never average percentiles.
            row['sampledMetrics'] = benchmark.get('sampledMetrics', {})
            output.append(row)
    return output


def round_metrics(records, prefix=''):
    """Flatten summarized benchmark records into ``{name:metric: median}`` values.

    Only metrics with a recorded median contribute; UNMEASURED entries are absent
    so a round is never credited with a number it did not produce.
    """
    metrics = {}
    for record in records:
        for name, metric in record.get('metrics', {}).items():
            if isinstance(metric, dict) and metric.get('median') is not None:
                metrics[f'{prefix}{record.get("name", "unknown")}:{name}'] = metric['median']
        for name, distribution in (record.get('sampledMetrics') or {}).items():
            if isinstance(distribution, dict) and distribution.get('P50') is not None:
                metrics[f'{prefix}{record.get("name", "unknown")}:{name}:P50'] = distribution['P50']
    return metrics


def main():
    parser = argparse.ArgumentParser(description='Summarize raw Stage 2b capture artifacts.')
    parser.add_argument('--capture', required=True, help='collector output directory')
    parser.add_argument('--output', help='write summary JSON here instead of stdout')
    args = parser.parse_args()
    summary = summarize_capture(args.capture)
    payload = summary.to_json()
    if args.output:
        Path(args.output).write_text(payload + '\n')
    else:
        print(payload)


if __name__ == '__main__':
    main()
