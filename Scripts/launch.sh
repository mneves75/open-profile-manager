#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
APP="$ROOT/build/Open Profile Manager.app"

"$ROOT/Scripts/package_app.sh" debug

exec /usr/bin/open -n "$APP"
