#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
# shellcheck disable=SC1091
source "$ROOT/version.env"

if ! command -v asc >/dev/null 2>&1; then
  echo "asc is required for notarization" >&2
  exit 1
fi
if [[ -z "${APP_IDENTITY:-}" ]]; then
  echo "Set APP_IDENTITY to a Developer ID Application identity" >&2
  exit 1
fi
if [[ "$APP_IDENTITY" != Developer\ ID\ Application:* ]]; then
  echo "APP_IDENTITY must be a Developer ID Application identity" >&2
  exit 1
fi

ARCHES=${ARCHES:-"arm64 x86_64"} APP_IDENTITY="$APP_IDENTITY" Scripts/package_app.sh release

APP="$ROOT/build/Open Profile Manager.app"
ARCHIVE="$ROOT/build/Open-Profile-Manager-$MARKETING_VERSION.zip"
/usr/bin/ditto --norsrc -c -k --keepParent "$APP" "$ARCHIVE"

asc notarization submit --file "$ARCHIVE" --wait --timeout 30m
/usr/bin/xcrun stapler staple "$APP"
/usr/bin/xcrun stapler validate "$APP"
/usr/sbin/spctl --assess --type execute --verbose=2 "$APP"

/usr/bin/ditto --norsrc -c -k --keepParent "$APP" "$ARCHIVE"
echo "Notarized artifact: $ARCHIVE"
