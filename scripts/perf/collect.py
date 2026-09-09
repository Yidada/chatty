#!/usr/bin/env python3
"""Foreground Pixel capture; owns and reaps fixture, never leaves a service behind."""
import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
import time
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PKG = 'ai.chatty.app.benchmark'
TEST = 'ai.chatty.macrobenchmark'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', required=True)
    parser.add_argument('--serial', required=True)
    parser.add_argument('--scenario', choices=['S0', 'S1', 'S2', 'S3', 'S4'], default='S1')
    parser.add_argument('--methods', nargs='+', choices=['cold', 'hot', 'scroll', 'memory'], default=['cold', 'hot', 'scroll'])
    parser.add_argument('--rounds', type=int, default=2)
    args = parser.parse_args()
    if args.rounds < 1:
        parser.error('--rounds must be positive')
    out = Path(args.output).resolve()
    out.mkdir(parents=True, exist_ok=False)
    adb = os.environ.get('ADB', shutil.which('adb') or str(Path.home() / 'Android/Sdk/platform-tools/adb'))
    def cmd(parts, name, timeout=180):
        result = subprocess.run(parts, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=timeout)
        (out / name).write_text(result.stdout)
        if result.returncode:
            raise RuntimeError(f'{name}: exit {result.returncode}')
        return result.stdout
    def device(parts, name, timeout=180):
        return cmd([adb, '-s', args.serial] + parts, name, timeout)
    def request(path, data=None):
        req = urllib.request.Request('http://127.0.0.1:8765' + path,
            data=json.dumps(data).encode() if data is not None else None,
            headers={'Content-Type': 'application/json'})
        with urllib.request.urlopen(req, timeout=5) as response:
            return json.load(response)
    def snapshot(label):
        for service in ['battery', 'thermalservice', 'display', 'power']:
            device(['shell', 'dumpsys', service], f'{label}-{service}.txt')
        device(['shell', 'dumpsys', 'meminfo', PKG], f'{label}-meminfo.txt')
        for namespace, key in [('system', 'peak_refresh_rate'), ('system', 'min_refresh_rate'), ('global', 'low_power'), ('global', 'window_animation_scale'), ('global', 'transition_animation_scale'), ('global', 'animator_duration_scale')]:
            device(['shell', 'settings', 'get', namespace, key], f'{label}-{key}.txt')
    fixture = None
    reverse_added = False
    target_touched = False
    status = {'status': 'UNMEASURED', 'budget': 'NO_BUDGET', 'scenario': args.scenario,
              'device': 'Pixel 6 Pro', 'scope': 'synthetic loopback; not production network',
              'compilation': 'system-default (standalone PSS)' if args.methods == ['memory'] else 'None for Macrobenchmark; system-default for standalone PSS', 'r8': False, 'rounds': args.rounds, 'methods': args.methods}
    try:
        cmd([adb, 'devices', '-l'], 'devices.txt')
        model = device(['shell', 'getprop', 'ro.product.model'], 'model.txt').strip()
        if model != 'Pixel 6 Pro':
            raise RuntimeError('Required Pixel 6 Pro not selected')
        policy = device(['shell', 'dumpsys', 'window', 'policy'], 'keyguard-before.txt')
        if 'mIsShowing=true' in policy:
            raise RuntimeError('Pixel is locked; user must unlock before capture')
        device(['shell', 'getprop', 'ro.build.fingerprint'], 'fingerprint.txt')
        device(['shell', 'getprop', 'ro.build.version.sdk'], 'sdk.txt')
        cmd(['git', '-C', str(ROOT), 'rev-parse', 'HEAD'], 'commit.txt')
        cmd(['git', '-C', str(ROOT), 'diff', '--binary', 'HEAD'], 'working-tree.patch')
        cmd(['git', '-C', str(ROOT), 'status', '--short'], 'working-tree-status.txt')
        source_hashes = {}
        for folder in ('android', 'scripts/perf'):
            for source in sorted((ROOT / folder).rglob('*')):
                if source.is_file() and not any(part in ('build', '.gradle', '__pycache__') for part in source.parts) and source.name != 'local.properties':
                    source_hashes[str(source.relative_to(ROOT))] = hashlib.sha256(source.read_bytes()).hexdigest()
        (out / 'source-sha256.json').write_text(json.dumps(source_hashes, indent=2))
        device(['reverse', '--list'], 'reverse-before.txt')
        if 'tcp:8765' in (out / 'reverse-before.txt').read_text():
            raise RuntimeError('Port 8765 already reversed; stop its owner before capture')
        with (out / 'fixture.log').open('w') as log:
            fixture = subprocess.Popen([sys.executable, str(Path(__file__).with_name('fixture.py')), '--scenario', args.scenario], stdout=log, stderr=subprocess.STDOUT)
            for _ in range(50):
                if fixture.poll() is not None: raise RuntimeError('Fixture failed to bind')
                try:
                    data = request('/__manifest'); break
                except OSError: time.sleep(.1)
            else: raise RuntimeError('Fixture not ready')
        (out / 'fixture-manifest.json').write_text(json.dumps(data, indent=2))
        device(['reverse', 'tcp:8765', 'tcp:8765'], 'reverse.txt')
        reverse_added = True
        for path in [ROOT / 'android/app/build/outputs/apk/benchmark/app-benchmark.apk', ROOT / 'android/macrobenchmark/build/outputs/apk/benchmark/macrobenchmark-benchmark.apk']:
            status[path.name + '_sha256'] = hashlib.sha256(path.read_bytes()).hexdigest()
            device(['install', '-r', str(path)], path.stem + '-install.txt')
        # Only this disposable package is cleared. Production/debug app stays isolated.
        target_touched = True
        device(['shell', 'pm', 'clear', PKG], 'clear-fixture-package.txt')
        def instrument(method, name):
            output = device(['shell', 'am', 'instrument', '-w', '-r', '-e', 'class',
                'ai.chatty.macrobenchmark.ChattyBenchmark#' + method,
                TEST + '/androidx.test.runner.AndroidJUnitRunner'], name, timeout=1200)
            if 'FAILURES!!!' in output or 'OK (1 test)' not in output:
                raise RuntimeError('Instrumentation incomplete: ' + name)
        instrument('prepare', 'prepare.txt')
        snapshot('before')
        for round_id in range(1, args.rounds + 1):
            for method in args.methods:
                request('/__perf', {'reset_metrics': True})
                instrument(method, f'round-{round_id}-{method}.txt')
                (out / f'round-{round_id}-{method}-network.json').write_text(json.dumps(request('/__metrics'), indent=2))
                if method != 'memory':
                    device(['pull', f'/sdcard/Android/media/{TEST}', str(out / f'round-{round_id}-{method}-traces')], f'round-{round_id}-{method}-pull.txt')
                snapshot(f'round-{round_id}-{method}')
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
                device(['shell', 'am', 'force-stop', PKG], 'target-cleanup.txt')
            if reverse_added:
                device(['reverse', '--remove', 'tcp:8765'], 'reverse-cleanup.txt')
        finally:
            (out / 'result.json').write_text(json.dumps(status, indent=2))


if __name__ == '__main__':
    main()
