#!/bin/bash
set -euo pipefail
source "$(dirname -- "$0")/ios-env.sh"
cd "$CHATTY_REPO_ROOT"
python3 - <<'PY'
import json,urllib.request,subprocess
try:
    data=json.load(urllib.request.urlopen('http://127.0.0.1:8765/__calls',timeout=3))
    assert len(data['scopes'])==4
    assert all(x['send_count']==0 and not x['issue_writes'] for x in data['scopes'].values())
except Exception:
    raise SystemExit('Start a fresh python3 scripts/ios-fixture.py, and log out of ChattyFixture before replay.')
sessions=json.loads(subprocess.check_output(['agent-device','session','list'],text=True))
if sessions.get('sessions'):
    raise SystemExit('Close active agent-device sessions before running the isolated replay suite.')
# An ended interactive session may retain XCTest ownership. Only release it
# after confirming this daemon has no active sessions.
subprocess.run(['agent-device','daemon','stop','--clean'],check=True)
PY
run_dir="$CHATTY_REPO_ROOT/.tools/ios-v1/$(date +%Y%m%d-%H%M%S)-replay"
mkdir -p "$run_dir"
for flow in core resources workspaces; do
    agent-device replay "tests/device/ios/v1-$flow.ad" --platform ios \
        --udid "$IOS_SIMULATOR_ID" --session "chatty-ios-v1-$flow" --json > "$run_dir/$flow.json"
done
python3 - "$run_dir" "$IOS_SIMULATOR_ID" <<'PY'
import json,sys,urllib.request,subprocess
from pathlib import Path
folder=Path(sys.argv[1]); audit=json.load(urllib.request.urlopen('http://127.0.0.1:8765/__calls'))
(folder/'fixture-audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n')
first=audit['scopes']['u1:fixture']
assert first['send_count']==2,first['send_count']
assert first['issue_writes']==[{'status':'qa_custom','suppress_run':True,'expected_revision':1}],first['issue_writes']
assert all(x['active_sockets']==0 for x in audit['scopes'].values())
assert all(not x.get('token_in_url',False) and x.get('active_total',0)<=1 for x in audit['ws_events'])
assert all(not x['authorization_header_present'] for x in audit['auth_calls'])
for key,value in audit['scopes'].items():
    if key!='u1:fixture': assert value['send_count']==0 and value['issue_writes']==[]
container=Path(subprocess.check_output(['xcrun','simctl','get_app_container',sys.argv[2],'ai.chatty.ios.fixture','data'],text=True).strip())
root=container/'Library/Application Support/ai.chatty.ios.fixture'
remaining=[str(p.relative_to(root)) for p in root.rglob('*') if p.is_file()]
assert remaining==[],remaining
summary={'flows':['core','resources','workspaces'],'passed':True,'message_writes':2,'issue_writes':1,'max_active_sockets':max(x.get('active_total',0) for x in audit['ws_events']),'credentials_on_auth_or_in_socket_url':False,'protected_files_after_logout':remaining}
(folder/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps(summary,indent=2));print('Evidence: '+str(folder))
PY
