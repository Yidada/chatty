#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/android-env.sh"
exec python3 "$CHATTY_ROOT/scripts/device-loop.py" "$@"
