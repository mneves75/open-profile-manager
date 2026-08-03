#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
APP="$ROOT/build/Open Profile Manager.app"

if [[ ! -d "$APP" ]]; then
  "$ROOT/Scripts/package_app.sh" debug
fi

exec /usr/bin/open -n "$APP"
