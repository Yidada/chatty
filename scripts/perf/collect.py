#!/usr/bin/env python3
"""Foreground Pixel capture; owns and reaps fixture, never leaves a service behind.

Two families of method:

* Instrumented methods run a Macrobenchmark test by name (`cold`, `hot`,
  `scroll`, `memory`, `s2Pagination`, `s2LiveEvent`, `s3Traversal`,
  `s4FaultCorrectness`). Their logcat is scanned for app-side probe records.
* Host-driven methods do not use Macrobenchmark: `interactive` launches the
  benchmark build cold and reads the composer boundary from logcat, `network`
  arms the opt-in HTTP phase probe and collects DNS/TCP/TLS/TTFB/end-to-end
  records for the configured test service.

Every method is bracketed by a device-state snapshot; the run records whether
the agreed budget-grade conditions held and never claims a budget otherwise.
"""
import argparse
import hashlib
import json
import os
import shutil
import socket
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
PROBE_SETTING = 'chatty_network_probe'
INSTRUMENTED_METHODS = ['cold', 'hot', 'scroll', 'memory', 's2Pagination', 's2LiveEvent', 's3Traversal', 's4FaultCorrectness']
HOST_METHODS = ['interactive', 'network']
ALL_METHODS = INSTRUMENTED_METHODS + HOST_METHODS
SETTINGS_KEYS = [('system', 'peak_refresh_rate'), ('system', 'min_refresh_rate'), ('global', 'low_power'),
                 ('global', 'window_animation_scale'), ('global', 'transition_animation_scale'), ('global', 'animator_duration_scale')]
# The app and the Macrobenchmark test both speak to this port on the device; it is
# compiled into the benchmark build and intentionally fixed. Only the host side of
# the adb reverse mapping is selectable, so an unrelated local service squatting on
# 8765 cannot block a capture.
DEVICE_FIXTURE_PORT = 8765


def reverse_spec(host_port, device_port=DEVICE_FIXTURE_PORT):
    """adb reverse arguments mapping the device's fixed fixture port to a chosen host port."""
    return ['reverse', f'tcp:{device_port}', f'tcp:{host_port}']


def host_port_available(port):
    """True when nothing on this host holds 127.0.0.1:<port>; a failed bind means busy."""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as probe:
        probe.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        try:
            probe.bind(('127.0.0.1', port))
        except OSError:
            return False
        return True


def parse_am_start_total_time(text):
    """`am start -W` output -> TotalTime ms (first frame), or None."""
    for line in text.splitlines():
        if line.startswith('TotalTime:'):
            try:
                return int(line.split(':', 1)[1].strip())
            except ValueError:
                return None
    return None


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', required=True)
    parser.add_argument('--serial', required=True)
    parser.add_argument('--scenario', choices=['S0', 'S1', 'S2', 'S3', 'S4'], default='S1')
    parser.add_argument('--methods', nargs='+', choices=ALL_METHODS, default=['cold', 'hot', 'scroll'])
    parser.add_argument('--rounds', type=int, default=2)
    parser.add_argument('--interactive-iterations', type=int, default=10)
    parser.add_argument('--network-launches', type=int, default=3)
    parser.add_argument('--probe-timeout', type=float, default=20.0)
    parser.add_argument('--host-port', type=int, default=DEVICE_FIXTURE_PORT,
                        help='host port for the fixture; the device side stays on %d' % DEVICE_FIXTURE_PORT)
    args = parser.parse_args()
    if args.rounds < 1:
        parser.error('--rounds must be positive')
    if not 1 <= args.host_port <= 65535:
        parser.error('--host-port must be a valid TCP port')
    if not host_port_available(args.host_port):
        parser.error('host port %d is already in use; pass --host-port <free port> '
                     '(the device side stays on %d)' % (args.host_port, DEVICE_FIXTURE_PORT))
    out = Path(args.output).resolve()
    out.mkdir(parents=True, exist_ok=False)
    adb = os.environ.get('ADB', shutil.which('adb') or str(Path.home() / 'Android/Sdk/platform-tools/adb'))

    def cmd(parts, name, timeout=180, allow_failure=False):
        result = subprocess.run(parts, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=timeout)
        if name:
            (out / name).write_text(result.stdout)
        if result.returncode and not allow_failure:
            raise RuntimeError(f'{name}: exit {result.returncode}')
        return result.stdout

    def device(parts, name=None, timeout=180, allow_failure=False):
        return cmd([adb, '-s', args.serial] + parts, name, timeout, allow_failure)

    def request(path, data=None):
        req = urllib.request.Request('http://127.0.0.1:%d' % args.host_port + path,
            data=json.dumps(data).encode() if data is not None else None,
            headers={'Content-Type': 'application/json'})
        with urllib.request.urlopen(req, timeout=5) as response:
            return json.load(response)

    def snapshot(label):
        """Raw dumpsys/settings for one point in time, plus its evaluated gate."""
        texts = {}
        for service in ['battery', 'thermalservice', 'display', 'power']:
            texts[service] = device(['shell', 'dumpsys', service], f'{label}-{service}.txt')
        device(['shell', 'dumpsys', 'meminfo', PKG], f'{label}-meminfo.txt')
        for namespace, key in SETTINGS_KEYS:
            texts[key] = device(['shell', 'settings', 'get', namespace, key], f'{label}-{key}.txt')
        environment = {
            'battery_pct': measure.parse_battery_level(texts['battery']),
            'thermal_status': measure.parse_thermal_status(texts['thermalservice']),
            'peak_refresh_rate': measure.parse_refresh_rate(texts['peak_refresh_rate']),
            'min_refresh_rate': measure.parse_refresh_rate(texts['min_refresh_rate']),
            'low_power': texts['low_power'].strip(),
        }
        (out / f'{label}-environment.json').write_text(json.dumps(environment, indent=2))
        gate = measure.environment_gate(environment)
        (out / f'{label}-gate.json').write_text(json.dumps(gate, indent=2))
        return gate

    def energy_snapshot(label):
        """Device-wide batterystats proxy, kept out of the per-method snapshot churn."""
        dump = device(['shell', 'dumpsys', 'batterystats'], f'{label}-batterystats.txt', timeout=300)
        payload = {'estimated_device_mah': measure.parse_energy_mah(dump),
                   'scope': 'device-wide batterystats proxy; not per-process energy'}
        (out / f'{label}-energy.json').write_text(json.dumps(payload, indent=2))
        return payload

    def logcat_clear():
        device(['logcat', '-c'], None, allow_failure=True)

    def logcat_dump(name, tags):
        selectors = []
        for tag in tags:
            selectors += ['-s', tag + ':I']
        return device(['logcat', '-d', '-v', 'threadtime'] + selectors, name, allow_failure=True)

    def instrument(method, name, timeout=1200):
        output = device(['shell', 'am', 'instrument', '-w', '-r', '-e', 'class',
            'ai.chatty.macrobenchmark.ChattyBenchmark#' + method,
            TEST + '/androidx.test.runner.AndroidJUnitRunner'], name, timeout=timeout)
        if 'FAILURES!!!' in output or 'OK (1 test)' not in output:
            raise RuntimeError('Instrumentation incomplete: ' + name)

    def probe_summary(method, round_id):
        log = logcat_dump(f'round-{round_id}-{method}-logcat.txt', [measure.STARTUP_TAG, measure.NETWORK_TAG])
        payload = {'round': round_id, 'method': method,
                   'composer_interactive': measure.summarize_startup(log),
                   'network': measure.summarize_netcalls(log)}
        (out / f'round-{round_id}-{method}-probe.json').write_text(json.dumps(payload, indent=2))
        return payload

    def run_instrumented(method, round_id):
        logcat_clear()
        instrument(method, f'round-{round_id}-{method}.txt')
        if method != 'memory':
            device(['pull', f'/sdcard/Android/media/{TEST}', str(out / f'round-{round_id}-{method}-traces')],
                   f'round-{round_id}-{method}-pull.txt', allow_failure=True)
        probe_summary(method, round_id)

    def launch_cold(iteration_prefix):
        started = device(['shell', 'am', 'start', '-W', '-a', 'android.intent.action.MAIN',
                          '-c', 'android.intent.category.LAUNCHER', '-f', '0x10008000', '-n', ACTIVITY],
                         f'{iteration_prefix}-start.txt')
        return parse_am_start_total_time(started)

    def run_interactive(round_id):
        """Cold launch loop: `am start -W` gives first display, the probe gives composer readiness."""
        iterations = []
        for index in range(args.interactive_iterations):
            prefix = f'round-{round_id}-interactive-{index}'
            device(['shell', 'am', 'force-stop', PKG], None, allow_failure=True)
            logcat_clear()
            first_display = launch_cold(prefix)
            samples = []
            log = ''
            deadline = time.time() + args.probe_timeout
            while time.time() < deadline:
                log = device(['logcat', '-d', '-v', 'threadtime', '-s', measure.STARTUP_TAG + ':I'], None, allow_failure=True)
                samples = measure.parse_startup_probe(log)
                if samples:
                    break
                time.sleep(0.25)
            (out / f'{prefix}-logcat.txt').write_text(log)
            sample = samples[0] if samples else None
            iterations.append({'iteration': index, 'first_display_ms': first_display,
                               'composer_interactive_ms': sample.elapsed_ms if sample else None,
                               'fully_drawn': sample.fully_drawn if sample else None})
        valid = [row for row in iterations if row['composer_interactive_ms'] is not None]
        payload = {'round': round_id, 'method': 'interactive',
                   'boundary': 'app process start -> composer placed, enabled and session resolved',
                   'first_display_ms': measure.summarize([row['first_display_ms'] for row in valid]),
                   'composer_interactive_ms': measure.summarize([row['composer_interactive_ms'] for row in valid]),
                   'valid_samples': len(valid), 'timeouts': len(iterations) - len(valid),
                   'iterations': iterations}
        (out / f'round-{round_id}-interactive.json').write_text(json.dumps(payload, indent=2))
        return payload

    def run_network(round_id):
        device(['shell', 'settings', 'put', 'global', PROBE_SETTING, '1'],
               f'round-{round_id}-network-probe-enable.txt', allow_failure=True)
        logs = []
        try:
            for index in range(args.network_launches):
                device(['shell', 'am', 'force-stop', PKG], None, allow_failure=True)
                logcat_clear()
                launch_cold(f'round-{round_id}-network-{index}')
                time.sleep(3)
                logs.append(logcat_dump(f'round-{round_id}-network-{index}-logcat.txt', [measure.NETWORK_TAG]))
        finally:
            device(['shell', 'settings', 'delete', 'global', PROBE_SETTING],
                   f'round-{round_id}-network-probe-clear.txt', allow_failure=True)
        payload = measure.summarize_netcalls('\n'.join(logs))
        payload.update({'round': round_id, 'method': 'network',
                        'scope': 'app-side OkHttp phases for the benchmark build API base URL',
                        'phase_note': 'DNS/TLS stay UNMEASURED on cleartext loopback; a designated HTTPS test service '
                                      'is selected at build time with -PchattyBenchmarkBaseUrl'})
        (out / f'round-{round_id}-network.json').write_text(json.dumps(payload, indent=2))
        return payload

    def round_metrics(round_id):
        metrics = {}
        interactive = out / f'round-{round_id}-interactive.json'
        if interactive.exists():
            data = json.loads(interactive.read_text())
            for key in ('first_display_ms', 'composer_interactive_ms'):
                if data.get(key, {}).get('median') is not None:
                    metrics[f'interactive:{key}:median'] = data[key]['median']
        network = out / f'round-{round_id}-network.json'
        if network.exists():
            data = json.loads(network.read_text())
            for phase, stats in data.get('by_phase', {}).items():
                if stats.get('median') is not None:
                    metrics[f'network:{phase}_ms:median'] = stats['median']
        for method in args.methods:
            if method in INSTRUMENTED_METHODS:
                metrics.update(measure.round_metrics(
                    measure.summarize_benchmark_dir(out / f'round-{round_id}-{method}-traces'),
                    prefix=f'{method}:'))
        return metrics

    fixture = None
    reverse_added = False
    target_touched = False
    gates = []
    status = {'status': 'UNMEASURED', 'budget': 'NO_BUDGET', 'scenario': args.scenario,
              'device': 'Pixel 6 Pro', 'scope': 'synthetic loopback; not production network',
              'compilation': 'None for Macrobenchmark; system-default for standalone PSS'
                             if set(args.methods) - {'memory'} else 'system-default (standalone PSS)',
              'r8': False, 'rounds': args.rounds, 'methods': args.methods,
              'fixture_host_port': args.host_port, 'fixture_device_port': DEVICE_FIXTURE_PORT,
              'budget_grade': False,
              'budget_grade_note': 'true only when every snapshot met battery 40-80%, thermal NONE, fixed 60 Hz, battery saver off'}
    try:
        cmd([adb, 'devices', '-l'], 'devices.txt')
        model = device(['shell', 'getprop', 'ro.product.model'], 'model.txt').strip()
        if model != 'Pixel 6 Pro':
            raise RuntimeError('Required Pixel 6 Pro not selected')
        policy = device(['shell', 'dumpsys', 'window', 'policy'], 'keyguard-before.txt')
        if measure.keyguard_locked(policy):
            raise RuntimeError('Pixel is locked; user must unlock before capture')
        device(['shell', 'getprop', 'ro.build.fingerprint'], 'fingerprint.txt')
        device(['shell', 'getprop', 'ro.build.version.sdk'], 'sdk.txt')
        cmd(['git', '-C', str(ROOT), 'rev-parse', 'HEAD'], 'commit.txt')
        cmd(['git', '-C', str(ROOT), 'diff', '--binary', 'HEAD'], 'working-tree.patch')
        cmd(['git', '-C', str(ROOT), 'status', '--short'], 'working-tree-status.txt')
        source_hashes = {}
        for folder in ('android', 'scripts/perf'):
            for source in sorted((ROOT / folder).rglob('*')):
                if source.is_file() and not any(part in ('build', '.gradle', '__pycache__', '.tools') for part in source.parts) and source.name != 'local.properties':
                    source_hashes[str(source.relative_to(ROOT))] = hashlib.sha256(source.read_bytes()).hexdigest()
        (out / 'source-sha256.json').write_text(json.dumps(source_hashes, indent=2))
        device(['reverse', '--list'], 'reverse-before.txt')
        if 'tcp:%d' % DEVICE_FIXTURE_PORT in (out / 'reverse-before.txt').read_text():
            raise RuntimeError('Device port %d already reversed; stop its owner before capture' % DEVICE_FIXTURE_PORT)
        with (out / 'fixture.log').open('w') as log:
            fixture = subprocess.Popen([sys.executable, str(Path(__file__).with_name('fixture.py')),
                                        '--scenario', args.scenario, '--port', str(args.host_port)],
                                       stdout=log, stderr=subprocess.STDOUT)
            for _ in range(50):
                if fixture.poll() is not None: raise RuntimeError('Fixture failed to bind on host port %d' % args.host_port)
                try:
                    data = request('/__manifest'); break
                except OSError: time.sleep(.1)
            else: raise RuntimeError('Fixture not ready')
        (out / 'fixture-manifest.json').write_text(json.dumps(data, indent=2))
        device(reverse_spec(args.host_port), 'reverse.txt')
        reverse_added = True
        for path in [ROOT / 'android/app/build/outputs/apk/benchmark/app-benchmark.apk', ROOT / 'android/macrobenchmark/build/outputs/apk/benchmark/macrobenchmark-benchmark.apk']:
            status[path.name + '_sha256'] = hashlib.sha256(path.read_bytes()).hexdigest()
            device(['install', '-r', str(path)], path.stem + '-install.txt')
        # Only this disposable package is cleared. Production/debug app stays isolated.
        target_touched = True
        device(['shell', 'pm', 'clear', PKG], 'clear-fixture-package.txt')
        instrument('prepare', 'prepare.txt')
        gates.append(snapshot('before'))
        energy_snapshot('before')
        for round_id in range(1, args.rounds + 1):
            for method in args.methods:
                request('/__perf', {'reset_metrics': True})
                if method == 'interactive':
                    run_interactive(round_id)
                elif method == 'network':
                    run_network(round_id)
                else:
                    run_instrumented(method, round_id)
                (out / f'round-{round_id}-{method}-fixture-metrics.json').write_text(json.dumps(request('/__metrics'), indent=2))
                gates.append(snapshot(f'round-{round_id}-{method}'))
        status['budget_grade'] = all(gate['budget_grade'] for gate in gates)
        status['environment_gates'] = gates
        rounds = {f'round-{round_id}': round_metrics(round_id) for round_id in range(1, args.rounds + 1)}
        (out / 'round-metrics.json').write_text(json.dumps(rounds, indent=2))
        (out / 'noise-envelope.json').write_text(json.dumps({
            'metrics': measure.noise_envelope(rounds),
            'note': 'Observed round-to-round spread on this capture. It is a measurement floor for repeated '
                    'same-condition rounds, not a confidence bound and not an optimization result.'}, indent=2))
        status['status'] = 'MEASURED_CANDIDATE'
    except Exception as error:
        status['error'] = str(error)
        raise
    finally:
        if fixture is not None:
            try:
                (out / 'final-network.json').write_text(json.dumps(request('/__metrics'), indent=2))
            except Exception: pass
            fixture.terminate()
            try: fixture.wait(timeout=10)
            except subprocess.TimeoutExpired: fixture.kill(); fixture.wait()
        try:
            if target_touched:
                device(['shell', 'am', 'force-stop', PKG], 'target-cleanup.txt', allow_failure=True)
                try: energy_snapshot('final')
                except Exception: pass
            if reverse_added:
                device(['reverse', '--remove', 'tcp:%d' % DEVICE_FIXTURE_PORT], 'reverse-cleanup.txt', allow_failure=True)
        finally:
            (out / 'result.json').write_text(json.dumps(status, indent=2))
            (out / 'summary.json').write_text(measure.summarize_capture(out).to_json() + '\n')


if __name__ == '__main__':
    main()
