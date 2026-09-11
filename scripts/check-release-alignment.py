#!/usr/bin/env python3
"""Read-only source version/contract check. Does not build, publish, or inspect credentials."""
import argparse
import json
from pathlib import Path
import re
import sys

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--web-repo', type=Path, default=root / 'web', help='Sites source checkout (default: <repo>/web)')
args = parser.parse_args()
manifest = json.loads((root / 'docs/releases/0.2.0.json').read_text())
expected = manifest['version']
errors = []

def check_version(label, path, pattern):
    try:
        values = set(re.findall(pattern, path.read_text()))
        if values != {expected}:
            raise ValueError(f'expected {expected}; found {sorted(values)}')
        print(f'PASS {label}: {expected}')
    except (OSError, ValueError) as exc:
        errors.append(f'{label}: {exc}')

check_version('Android', root / 'android/app/build.gradle.kts', r'versionName\s*=\s*"([^"]+)"')
for label, generator, project in [
    ('iOS', 'scripts/generate-ios-project.py', 'ios/Chatty.xcodeproj/project.pbxproj'),
    ('macOS', 'macos/scripts/generate-project.py', 'macos/Chatty.xcodeproj/project.pbxproj'),
]:
    check_version(label + ' generator', root / generator, r"'MARKETING_VERSION'\s*:\s*'([^']+)'")
    check_version(label + ' project', root / project, r'"MARKETING_VERSION"\s*=\s*"([^"]+)"')
try:
    version = json.loads((args.web_repo / 'package.json').read_text())['version']
    if version != expected:
        raise ValueError(f'expected {expected}; found {version}')
    print(f'PASS Web: {version}')
except (OSError, ValueError, KeyError) as exc:
    errors.append(f'Web: {exc}')

canonical = (root / 'docs/releases/activity-contract.md').read_text()
if not canonical.startswith(f"# Activity contract {manifest['activity_contract']} — release {expected}"):
    errors.append('Release contract header does not match manifest')
for label, path in [('Android', root / 'android/docs/activity-contract.md'), ('Web', args.web_repo / 'docs/activity-contract.md')]:
    try:
        if path.read_text() != canonical:
            raise ValueError('contract differs from release snapshot')
        print(f"PASS {label} contract: {manifest['activity_contract']}")
    except (OSError, ValueError) as exc:
        errors.append(f'{label}: {exc}')
if errors:
    for error in errors:
        print('FAIL ' + error, file=sys.stderr)
    sys.exit(1)
print('Source declarations align. Build and distribution availability still require channel-specific evidence.')
