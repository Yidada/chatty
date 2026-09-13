#!/usr/bin/env python3
"""Install only the Chatty dsh plugin; preserve profile settings and other clients.

The dsh web profile live-reloads its patch. This does not restart dsh, change its
global permission default, or read/write Codex configuration. Pass --apply to install.
"""
import argparse
import datetime
import hashlib
import json
from pathlib import Path
import shutil

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--profile', type=Path, default=Path.home() / '.dsh/profiles/web')
parser.add_argument('--apply', action='store_true')
args = parser.parse_args()
source = Path(__file__).resolve().parents[1] / 'server/chatty-next-approval'
profile = args.profile.resolve()
patch = profile / 'cordis.patch.yml'
if not patch.is_file() or not (profile / 'package.json').is_file():
    raise SystemExit('An existing dsh profile is required.')
marker = '# Chatty Next automatic approval (managed by Chatty installer)'
end_marker = '# End Chatty Next automatic approval'
original = patch.read_text()
if 'id: chatty-next-approval' in original and marker not in original:
    raise SystemExit('Unmanaged chatty-next-approval entry exists; inspect it before replacing.')
files = ['package.json', 'index.js', 'review.js', 'check.js']
manifest = {name: hashlib.sha256((source / name).read_bytes()).hexdigest() for name in files}
release = hashlib.sha256(json.dumps(manifest, sort_keys=True).encode()).hexdigest()[:16]
target = profile / 'chatty-next-approval' / release
block = f'''{marker}
- insert:
    - id: chatty-next-approval
      name: {json.dumps((target / 'index.js').as_uri())}
{end_marker}'''
if marker in original:
    start = original.index(marker)
    if end_marker not in original[start:]: raise SystemExit('Incomplete managed block; inspect the patch first.')
    end = original.index(end_marker, start) + len(end_marker)
    updated = original[:start] + block + original[end:]
else:
    updated = original.rstrip() + '\n\n' + block + '\n'
print(json.dumps({'profile': str(profile), 'plugin': str(target), 'apply': args.apply, 'sha256': manifest}, indent=2))
if args.apply:
    stamp = datetime.datetime.now().strftime('%Y%m%d-%H%M%S')
    backup = profile / f'chatty-next-approval-backup-{stamp}'
    backup.mkdir(mode=0o700)
    shutil.copy2(patch, backup / patch.name)
    target.mkdir(parents=True, exist_ok=True)
    for name in files: shutil.copy2(source / name, target / name)
    # Content-addressed module paths permit live updates without stale ESM imports.
    if updated != original:
        temporary = patch.with_suffix('.chatty-next.tmp')
        temporary.write_text(updated)
        temporary.replace(patch)
    print('Installed. Backup: ' + str(backup))
