#!/usr/bin/env python3
"""Strict install/launch verification; never silently select an emulator."""
import datetime, json, os, pathlib, subprocess, sys, time

def run(*args):
    return subprocess.check_output(args, text=True, stderr=subprocess.STDOUT, timeout=90).strip()

def main():
    if len(sys.argv) != 4:
        raise SystemExit('Usage: scripts/dev-loop.sh <apk> <package> <activity>')
    apk, package, activity = sys.argv[1:]
    adb = os.environ['ADB']
    rows = [l.split() for l in run(adb, 'devices').splitlines()[1:] if l.strip()]
    serial = os.environ.get('ANDROID_SERIAL')
    if serial:
        assert any(r[0] == serial and r[1] == 'device' for r in rows), 'Selected device unavailable or unauthorized'
    else:
        devices = [r[0] for r in rows if r[1] == 'device' and not r[0].startswith('emulator-')]
        assert len(devices) == 1, 'Connect exactly one authorized physical phone, or set ANDROID_SERIAL'
        serial = devices[0]
    cmd = [adb, '-s', serial]
    assert pathlib.Path(apk).is_file(), 'APK not found'
    evidence = pathlib.Path(os.environ.get('EVIDENCE_DIR', str(pathlib.Path(__file__).resolve().parents[1] / '.sdlc/changes/20260905-native-experience-without-multica-web-exits/evidence/device-runs' / datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f-launch'))))
    evidence.mkdir(parents=True, exist_ok=False)
    output = run(*cmd, 'install', '-r', apk)
    assert 'Success' in output, output
    run(*cmd, 'shell', 'am', 'force-stop', package)
    started = run(*cmd, 'shell', "date '+%m-%d %H:%M:%S.000'")
    output = run(*cmd, 'shell', 'am', 'start', '-W', '-n', package + '/' + activity)
    assert 'Error' not in output and 'Status: ok' in output, output
    time.sleep(3)
    pid = run(*cmd, 'shell', 'pidof', package)
    assert pid, 'Application exited during launch'
    logs = run(*cmd, 'logcat', '-d', '-T', started, '--pid=' + pid)
    assert 'FATAL EXCEPTION' not in logs, logs
    focus = run(*cmd, 'shell', 'dumpsys', 'window')
    focused = [l.strip() for l in focus.splitlines() if 'mCurrentFocus' in l]
    assert any(package in l for l in focused), 'App not foreground: ' + str(focused)
    (evidence / 'launch.json').write_text(json.dumps({'package':package, 'model':run(*cmd,'shell','getprop','ro.product.model'), 'android':run(*cmd,'shell','getprop','ro.build.version.release'), 'pid':pid, 'focus':focused, 'result':'PASS'}, indent=2))
    (evidence / 'logcat.txt').write_text(logs)
    with (evidence/'launch.png').open('wb') as f:
        subprocess.run([*cmd,'exec-out','screencap','-p'],stdout=f,check=True,timeout=30)
    print('PASS: installed, process alive, foreground verified. Evidence:',evidence)

if __name__ == '__main__':
    main()
