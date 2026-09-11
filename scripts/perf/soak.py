#!/usr/bin/env python3
"""24-hour soak, energy proxy and degraded-network harness for the benchmark build.

The runner owns its loopback fixture and adb reverse mapping and reaps both before
returning, so no capture service survives the process. It samples:

* PSS every interval (observed peak and leak trend, never a true peak),
* battery level, thermal status and free-running process liveness,
* crash-buffer entries for the target package (crash/ANR counts),
* a device-wide batterystats energy proxy at start and end,
* one degraded-network window: the fixture is made unreachable and the harness
  measures how long the app takes to show its connection notice, then confirms
  recovery.

Baseline has no offline read-only path, so this harness does **not** claim offline
convergence to cached content; that boundary stays UNMEASURED until Stage 3 ships
the offline read-only UI.

Usage (bounded dry run first, then the real window):

    python3 scripts/perf/soak.py --serial <Pixel-serial> --output <dir> --iterations 3 --interval-min 1
    python3 scripts/perf/soak.py --serial <Pixel-serial> --output <dir> --hours 24 --interval-min 5
"""
import argparse
import json
import os
import shutil
import subprocess
import sys
import time
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import measure

ROOT = Path(__file__).resolve().parents[2]
PKG = 'ai.chatty.app.benchmark'
TEST = 'ai.chatty.macrobenchmark'
ACTIVITY = PKG + '/ai.chatty.app.MainActivity'
DEGRADED_NOTICE_NEEDLE = '暂时无法连接'
FAILURE_STREAK_LIMIT = 5


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--serial', required=True)
    parser.add_argument('--output', required=True)
    parser.add_argument('--hours', type=float, default=24.0)
    parser.add_argument('--interval-min', type=float, default=5.0)
    parser.add_argument('--iterations', type=int, default=0, help='bounded dry run; overrides --hours when positive')
    parser.add_argument('--interaction-min', type=float, default=30.0)
    parser.add_argument('--scenario', choices=['S0', 'S1', 'S2', 'S3', 'S4'], default='S2')
    parser.add_argument('--degraded-check', dest='degraded', action='store_true', default=True)
    parser.add_argument('--no-degraded-check', dest='degraded', action='store_false')
    parser.add_argument('--degraded-poll-seconds', type=float, default=60.0)
    parser.add_argument('--owner', default='Mika')
    args = parser.parse_args()

    out = Path(args.output).resolve()
    out.mkdir(parents=True, exist_ok=False)
    adb = os.environ.get('ADB', shutil.which('adb') or str(Path.home() / 'Android/Sdk/platform-tools/adb'))
    started_at = time.time()
    deadline = started_at + args.hours * 3600
    state = {'status': 'RUNNING', 'package': PKG, 'scenario': args.scenario, 'owner': args.owner,
             'requested_hours': args.hours, 'interval_min': args.interval_min,
             'generated_by': 'scripts/perf/soak.py'}

    def cmd(parts, name=None, timeout=300, allow_failure=False):
        result = subprocess.run([adb, '-s', args.serial] + parts, text=True, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, timeout=timeout)
        if name:
            (out / name).write_text(result.stdout)
        if result.returncode and not allow_failure:
            raise RuntimeError(f'{name or parts}: exit {result.returncode}')
        return result.stdout

    def request(path, data=None):
        payload = json.dumps(data).encode() if data is not None else None
        req = urllib.request.Request('http://127.0.0.1:8765' + path, data=payload,
                                     headers={'Content-Type': 'application/json'})
        with urllib.request.urlopen(req, timeout=5) as response:
            return json.load(response)

    def sample(index, at_s):
        meminfo = cmd(['shell', 'dumpsys', 'meminfo', PKG], None, allow_failure=True)
        battery = cmd(['shell', 'dumpsys', 'battery'], None, allow_failure=True)
        thermal = cmd(['shell', 'dumpsys', 'thermalservice'], None, allow_failure=True)
        alive = bool(cmd(['shell', 'pidof', PKG], None, allow_failure=True).strip())
        crashes = cmd(['logcat', '-d', '-b', 'crash', '-v', 'brief'], None, allow_failure=True)
        row = {'index': index, 'at_s': round(at_s, 3), 'pss_kib': measure.parse_total_pss_kib(meminfo),
               'battery_pct': measure.parse_battery_level(battery),
               'thermal_status': measure.parse_thermal_status(thermal), 'pid_alive': alive,
               'crash_lines': crashes.count(PKG),
               'anr_lines': sum(1 for line in crashes.splitlines() if 'ANR in ' + PKG in line)}
        (out / f'pss-{index}.json').write_text(json.dumps([{'at_s': row['at_s'], 'pss_kib': row['pss_kib']}]))
        with (out / 'soak-samples.ndjson').open('a') as stream:
            stream.write(json.dumps(row) + '\n')
        return row

    def dump_ui():
        cmd(['shell', 'uiautomator', 'dump', '/sdcard/soak-window.xml'], None, allow_failure=True)
        return cmd(['shell', 'cat', '/sdcard/soak-window.xml'], None, allow_failure=True)

    def degraded_check():
        """Make the fixture unreachable, time the user-visible notice, verify recovery."""
        request('/__perf', {'disconnect': True, 'delay_ms': 30_000})
        notice_at, polled = None, 0.0
        began = time.time()
        try:
            while time.time() - began < args.degraded_poll_seconds:
                polled = time.time() - began
                if measure.ui_contains(dump_ui(), DEGRADED_NOTICE_NEEDLE):
                    notice_at = polled
                    break
                time.sleep(2)
        finally:
            request('/__perf', {'disconnect': False, 'delay_ms': 0, 'status': 200})
        recovery = False
        for _ in range(15):
            if not measure.ui_contains(dump_ui(), DEGRADED_NOTICE_NEEDLE):
                recovery = True
                break
            time.sleep(2)
        payload = {'degraded_notice_seconds': round(notice_at, 3) if notice_at is not None else None,
                   'polled_seconds': round(polled, 3), 'notice_observed': notice_at is not None,
                   'recovered_after_reset': recovery,
                   'needle': DEGRADED_NOTICE_NEEDLE,
                   'scope': 'degraded-network notice latency; baseline has no offline read-only path, '
                            'so this is not offline convergence to cached content'}
        (out / 'degraded-window.json').write_text(json.dumps(payload, indent=2))
        return payload

    fixture = None
    reverse_added = False
    crashes = anrs = 0
    energy_start = energy_end = None
    battery_start = battery_end = None
    degraded = None
    samples = []
    try:
        cmd(['devices', '-l'], 'devices.txt')
        model = cmd(['shell', 'getprop', 'ro.product.model'], 'model.txt').strip()
        if model != 'Pixel 6 Pro':
            raise RuntimeError('Required Pixel 6 Pro not selected')
        policy = cmd(['shell', 'dumpsys', 'window', 'policy'], 'keyguard-before.txt')
        if measure.keyguard_locked(policy):
            raise RuntimeError('Pixel is locked; user must unlock before soak')
        cmd(['shell', 'pm', 'path', PKG], 'package-path.txt')
        if 'package:' not in (out / 'package-path.txt').read_text():
            raise RuntimeError('Benchmark build not installed; install it before soaking')
        cmd(['shell', 'getprop', 'ro.build.fingerprint'], 'fingerprint.txt')
        cmd(['git', '-C', str(ROOT), 'rev-parse', 'HEAD'], 'commit.txt')
        # Crash counting must only see this window, not every crash since boot.
        cmd(['logcat', '-b', 'crash', '-c'], None, allow_failure=True)
        cmd(['reverse', '--list'], 'reverse-before.txt')
        if 'tcp:8765' in (out / 'reverse-before.txt').read_text():
            raise RuntimeError('Port 8765 already reversed; stop its owner before soak')
        with (out / 'fixture.log').open('w') as log:
            fixture = subprocess.Popen([sys.executable, str(Path(__file__).with_name('fixture.py')),
                                        '--scenario', args.scenario], stdout=log, stderr=subprocess.STDOUT)
            for _ in range(50):
                if fixture.poll() is not None:
                    raise RuntimeError('Fixture failed to bind')
                try:
                    manifest = request('/__manifest')
                    break
                except OSError:
                    time.sleep(.1)
            else:
                raise RuntimeError('Fixture not ready')
        (out / 'fixture-manifest.json').write_text(json.dumps(manifest, indent=2))
        cmd(['reverse', 'tcp:8765', 'tcp:8765'], 'reverse.txt')
        reverse_added = True

        battery_start = measure.parse_battery_level(cmd(['shell', 'dumpsys', 'battery'], 'battery-start.txt'))
        energy_start = measure.parse_energy_mah(cmd(['shell', 'dumpsys', 'batterystats'], 'batterystats-start.txt', timeout=300))

        index = 0
        failures = 0
        next_interaction = started_at
        while True:
            if args.iterations:
                if index >= args.iterations:
                    break
            elif time.time() >= deadline:
                break
            try:
                row = sample(index, time.time() - started_at)
                samples.append(row)
                crashes, anrs = row['crash_lines'], row['anr_lines']
                failures = 0
            except Exception as error:  # a 24h run must survive transient adb hiccups
                failures += 1
                with (out / 'soak-errors.ndjson').open('a') as errors:
                    errors.write(json.dumps({'at_s': time.time() - started_at, 'error': str(error)}) + '\n')
                if failures >= FAILURE_STREAK_LIMIT:
                    raise
            if args.degraded and index == 1:
                degraded = degraded_check()
            if time.time() >= next_interaction:
                cmd(['shell', 'am', 'start', '-n', ACTIVITY], None, allow_failure=True)
                next_interaction = time.time() + args.interaction_min * 60
            index += 1
            if args.iterations and index >= args.iterations:
                break
            time.sleep(max(1.0, args.interval_min * 60))

        battery_end = measure.parse_battery_level(cmd(['shell', 'dumpsys', 'battery'], 'battery-end.txt'))
        energy_end = measure.parse_energy_mah(cmd(['shell', 'dumpsys', 'batterystats'], 'batterystats-end.txt', timeout=300))
        state['status'] = 'MEASURED_CANDIDATE'
    except Exception as error:
        state['status'] = 'FAILED'
        state['error'] = str(error)
    finally:
        if fixture is not None:
            fixture.terminate()
            try:
                fixture.wait(timeout=10)
            except subprocess.TimeoutExpired:
                fixture.kill(); fixture.wait()
        if reverse_added:
            cmd(['reverse', '--remove', 'tcp:8765'], 'reverse-cleanup.txt', allow_failure=True)
        report = measure.soak_report(samples, crashes=crashes, anrs=anrs,
                                     energy_start_mah=energy_start, energy_end_mah=energy_end,
                                     battery_start_pct=battery_start, battery_end_pct=battery_end,
                                     degraded_notice_seconds=(degraded or {}).get('degraded_notice_seconds'))
        if degraded is not None:
            report['degraded_window'] = degraded
        (out / 'soak-report.json').write_text(json.dumps(report, indent=2))
        state['report'] = report
        (out / 'soak-plan.json').write_text(json.dumps({
            'owner': args.owner, 'requested_hours': args.hours, 'interval_min': args.interval_min,
            'scenario': args.scenario, 'interaction_min': args.interaction_min,
            'started_at_epoch_s': started_at,
            'elapsed_s': time.time() - started_at,
            'gates': {'battery_pct': [measure.BATTERY_MIN_PCT, measure.BATTERY_MAX_PCT],
                      'thermal_status': measure.THERMAL_NONE,
                      'refresh_hz': measure.FIXED_REFRESH_HZ},
            'note': 'Owner and duration are recorded here; a 24h window still needs Benjamin to grant it.'}, indent=2))
        (out / 'summary.json').write_text(measure.summarize_capture(out).to_json() + '\n')
        (out / 'result.json').write_text(json.dumps(state, indent=2))
        print(json.dumps({'status': state['status'], 'samples': len(samples),
                          'report': report}, indent=2))


if __name__ == '__main__':
    main()
