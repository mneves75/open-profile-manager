#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

# shellcheck disable=SC1091
source "$ROOT/version.env"

if [[ -z "${APP_IDENTITY:-}" ]]; then
  APP_IDENTITY=$(
    /usr/bin/security find-identity -v -p codesigning \
      | awk -F '"' '/Developer ID Application:|Apple Development:/ { print $2; exit }'
  )
fi
if [[ -z "$APP_IDENTITY" ]]; then
  echo "A Developer ID Application or Apple Development identity is required for local installation" >&2
  exit 1
fi

APP_IDENTITY="$APP_IDENTITY" Scripts/package_app.sh release

BIN_DIR="$HOME/.local/bin"
APP_DIR="$HOME/Applications"
SOURCE_APP="$ROOT/build/Open Profile Manager.app"
DESTINATION_APP="$APP_DIR/Open Profile Manager.app"

mkdir -p "$BIN_DIR" "$APP_DIR"
STAGE_APP=$(mktemp -d "$APP_DIR/.open-profile-manager-install.app.XXXXXX")
STAGE_CLI=$(mktemp "$BIN_DIR/.opm-install.XXXXXX")
cleanup() {
  if [[ -e "$STAGE_CLI" ]]; then
    rm "$STAGE_CLI"
  fi
  if [[ -e "$STAGE_APP" ]]; then
    rm -r "$STAGE_APP"
  fi
}
trap cleanup EXIT

/usr/bin/ditto "$SOURCE_APP" "$STAGE_APP"
install -m 0755 "$SOURCE_APP/Contents/Resources/bin/opm" "$STAGE_CLI"
/usr/bin/codesign --verify --deep --strict "$STAGE_APP"
/usr/bin/codesign --verify --strict "$STAGE_CLI"
test "$("$STAGE_CLI" version)" = "$MARKETING_VERSION"

/usr/bin/xcrun swift "$ROOT/Scripts/atomic_replace.swift" "$STAGE_CLI" "$BIN_DIR/opm"
/usr/bin/xcrun swift "$ROOT/Scripts/atomic_replace.swift" "$STAGE_APP" "$DESTINATION_APP"
/usr/bin/codesign --verify --deep --strict "$DESTINATION_APP"
test "$("$BIN_DIR/opm" version)" = "$MARKETING_VERSION"

echo "Installed CLI: $BIN_DIR/opm"
echo "Installed app: $DESTINATION_APP"
