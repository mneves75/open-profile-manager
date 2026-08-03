#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
SOURCE_PNG="$ROOT/Assets/OpenProfileManager-1024.png"
OUTPUT_ICNS="$ROOT/Assets/OpenProfileManager.icns"
TEMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/open-profile-manager-icon.XXXXXX")
trap 'rm -r "$TEMP_ROOT"' EXIT
ICONSET="$TEMP_ROOT/OpenProfileManager.iconset"
mkdir -p "$ROOT/Assets" "$ICONSET"

swift "$ROOT/Scripts/build_icon.swift" "$SOURCE_PNG"

create_icon() {
  local pixels=$1
  local filename=$2
  /usr/bin/sips -z "$pixels" "$pixels" "$SOURCE_PNG" --out "$ICONSET/$filename" >/dev/null
}

create_icon 16 icon_16x16.png
create_icon 32 icon_16x16@2x.png
create_icon 32 icon_32x32.png
create_icon 64 icon_32x32@2x.png
create_icon 128 icon_128x128.png
create_icon 256 icon_128x128@2x.png
create_icon 256 icon_256x256.png
create_icon 512 icon_256x256@2x.png
create_icon 512 icon_512x512.png
cp "$SOURCE_PNG" "$ICONSET/icon_512x512@2x.png"

/usr/bin/iconutil -c icns "$ICONSET" -o "$OUTPUT_ICNS"
echo "Created $OUTPUT_ICNS"
