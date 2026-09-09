#!/bin/bash
set -euo pipefail
source "$(dirname -- "$0")/ios-env.sh"
cd "$CHATTY_REPO_ROOT"
mode="${1:-fixture}"
case "$mode" in
  fixture) scheme=ChattyFixture; bundle=ai.chatty.ios.fixture ;;
  app|shell) scheme=Chatty; bundle=ai.chatty.ios ;;
  *) printf 'Usage: %s [fixture|app]\n' "$0" >&2; exit 2 ;;
esac
if [ -z "$IOS_SIMULATOR_ID" ]; then
  printf 'Install an iOS 26+ iPhone Simulator in Xcode, or set IOS_SIMULATOR_ID.\n' >&2; exit 1
fi
if [ "$mode" = fixture ]; then
  python3 - <<'PY'
import urllib.request,json
opener=urllib.request.build_opener(urllib.request.ProxyHandler({}))
req=urllib.request.Request('http://127.0.0.1:8765/api/workspaces',headers={'Authorization':'Bearer synthetic-device-fixture-token','X-Workspace-Slug':'fixture'})
try:
 data=json.load(opener.open(req,timeout=3))
 assert any(x.get('slug')=='fixture' for x in data)
except Exception:
 raise SystemExit('Start the synthetic service in another terminal: python3 scripts/ios-fixture.py')
PY
fi
artifact_dir="$CHATTY_REPO_ROOT/.tools/ios-v1/$(date +%Y%m%d-%H%M%S)-$mode"
mkdir -p "$artifact_dir"
xcodebuild -project ios/Chatty.xcodeproj -scheme "$scheme" -configuration Debug \
  -destination "platform=iOS Simulator,id=$IOS_SIMULATOR_ID" \
  -derivedDataPath "$CHATTY_IOS_DERIVED_DATA" CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- build > "$artifact_dir/build.log" 2>&1
sim_state="$(xcrun simctl list devices -j | python3 -c 'import json,sys; print(next(d["state"] for ds in json.load(sys.stdin)["devices"].values() for d in ds if d["udid"]==sys.argv[1]))' "$IOS_SIMULATOR_ID")"
if [ "$sim_state" = Shutdown ]; then xcrun simctl boot "$IOS_SIMULATOR_ID"; fi
xcrun simctl bootstatus "$IOS_SIMULATOR_ID" -b
xcrun simctl install "$IOS_SIMULATOR_ID" "$CHATTY_IOS_DERIVED_DATA/Build/Products/Debug-iphonesimulator/$scheme.app"
xcrun simctl launch "$IOS_SIMULATOR_ID" "$bundle"
printf 'Started %s on %s\nBuild log: %s/build.log\n' "$scheme" "$IOS_SIMULATOR_ID" "$artifact_dir"
