#!/bin/bash
# Source from Bash or Zsh. Override IOS_SIMULATOR_ID to select a specific device.
if [ -n "${ZSH_VERSION:-}" ]; then
  CHATTY_IOS_SCRIPT_DIR="$(cd -- "$(dirname -- "${(%):-%x}")" && pwd)"
else
  CHATTY_IOS_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
fi
export CHATTY_REPO_ROOT="$(cd -- "$CHATTY_IOS_SCRIPT_DIR/.." && pwd)"
export CHATTY_IOS_DERIVED_DATA="$CHATTY_REPO_ROOT/.tools/ios-derived-data"
if [ -z "${IOS_SIMULATOR_ID:-}" ]; then
  IOS_SIMULATOR_ID="$(xcrun simctl list devices available -j | python3 -c '
import json,sys
rows=[]
for runtime,devices in json.load(sys.stdin)["devices"].items():
 if "iOS-" not in runtime: continue
 version=tuple(int(n) for n in runtime.split("iOS-")[-1].split("-"))
 if version[0]<26: continue
 for d in devices:
  if d["name"].startswith("iPhone"): rows.append((version,d["state"]=="Booted",d["name"],d["udid"]))
print(max(rows)[-1] if rows else "")
')"
fi
export IOS_SIMULATOR_ID
