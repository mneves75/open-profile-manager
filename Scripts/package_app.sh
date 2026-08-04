#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

# shellcheck disable=SC1091
source "$ROOT/version.env"

APP_NAME="Open Profile Manager"
EXECUTABLE_NAME="OpenProfileManager"
BUNDLE_ID="io.github.mneves75.open-profile-manager"
CONFIGURATION=${1:-release}
MACOS_MIN_VERSION="15.0"
APP_IDENTITY=${APP_IDENTITY:-}
ARCH_VALUES=${ARCHES:-$(uname -m)}
read -r -a ARCH_LIST <<< "$ARCH_VALUES"

if [[ ! "$MARKETING_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]]; then
  echo "Invalid MARKETING_VERSION: $MARKETING_VERSION" >&2
  exit 1
fi
if [[ ! "$BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]]; then
  echo "BUILD_NUMBER must be a positive integer" >&2
  exit 1
fi
for architecture in "${ARCH_LIST[@]}"; do
  if [[ "$architecture" != "arm64" && "$architecture" != "x86_64" ]]; then
    echo "Unsupported architecture: $architecture" >&2
    exit 1
  fi
done

for architecture in "${ARCH_LIST[@]}"; do
  swift build -c "$CONFIGURATION" --arch "$architecture"
done

product_path() {
  local product=$1
  local architecture=$2
  local bin_path
  bin_path=$(swift build -c "$CONFIGURATION" --arch "$architecture" --show-bin-path)
  printf '%s/%s' "$bin_path" "$product"
}

STAGE_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/open-profile-manager-package.XXXXXX")
trap 'rm -r "$STAGE_ROOT"' EXIT
STAGE_APP="$STAGE_ROOT/$APP_NAME.app"
mkdir -p "$STAGE_APP/Contents/MacOS" "$STAGE_APP/Contents/Resources/bin"

install_universal_binary() {
  local product=$1
  local destination=$2
  local binaries=()
  for architecture in "${ARCH_LIST[@]}"; do
    local source_path
    source_path=$(product_path "$product" "$architecture")
    if [[ ! -x "$source_path" ]]; then
      echo "Missing build product: $source_path" >&2
      exit 1
    fi
    binaries+=("$source_path")
  done

  if [[ ${#binaries[@]} -eq 1 ]]; then
    cp "${binaries[0]}" "$destination"
  else
    /usr/bin/lipo -create "${binaries[@]}" -output "$destination"
  fi
  chmod 0755 "$destination"
}

install_universal_binary "$EXECUTABLE_NAME" "$STAGE_APP/Contents/MacOS/$EXECUTABLE_NAME"
install_universal_binary opm "$STAGE_APP/Contents/Resources/bin/opm"

FIRST_BUILD_DIR=$(dirname "$(product_path "$EXECUTABLE_NAME" "${ARCH_LIST[0]}")")
while IFS= read -r -d '' resource_bundle; do
  cp -R "$resource_bundle" "$STAGE_APP/Contents/Resources/"
done < <(find "$FIRST_BUILD_DIR" -maxdepth 1 -type d -name '*.bundle' -print0)

LOCALIZATION_CATALOG="$ROOT/Sources/OpenProfileManager/Resources/Localizable.xcstrings"
/usr/bin/xcrun xcstringstool compile "$LOCALIZATION_CATALOG" \
  --output-directory "$STAGE_APP/Contents/Resources" \
  --serialization-format binary
cp "$ROOT/Sources/OpenProfileManager/Resources/PrivacyInfo.xcprivacy" \
  "$STAGE_APP/Contents/Resources/PrivacyInfo.xcprivacy"
test -f "$STAGE_APP/Contents/Resources/pt-BR.lproj/Localizable.strings"
test -f "$STAGE_APP/Contents/Resources/en-US.lproj/Localizable.strings"
test -f "$STAGE_APP/Contents/Resources/PrivacyInfo.xcprivacy"

if [[ ! -f "$ROOT/Assets/OpenProfileManager.icns" ]]; then
  Scripts/build_icon.sh
fi
cp "$ROOT/Assets/OpenProfileManager.icns" "$STAGE_APP/Contents/Resources/OpenProfileManager.icns"

cat > "$STAGE_APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>en-US</string>
  <key>CFBundleLocalizations</key>
  <array>
    <string>en-US</string>
    <string>pt-BR</string>
  </array>
  <key>CFBundleDisplayName</key><string>$APP_NAME</string>
  <key>CFBundleExecutable</key><string>$EXECUTABLE_NAME</string>
  <key>CFBundleIconFile</key><string>OpenProfileManager</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$MARKETING_VERSION</string>
  <key>CFBundleVersion</key><string>$BUILD_NUMBER</string>
  <key>ITSAppUsesNonExemptEncryption</key><false/>
  <key>LSApplicationCategoryType</key><string>public.app-category.developer-tools</string>
  <key>LSMinimumSystemVersion</key><string>$MACOS_MIN_VERSION</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSHumanReadableCopyright</key><string>Copyright © 2026 Marcus Neves. MIT licensed.</string>
  <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST

/usr/bin/plutil -lint "$STAGE_APP/Contents/Info.plist"
/usr/bin/xattr -cr "$STAGE_APP"

if [[ -n "$APP_IDENTITY" ]]; then
  SIGN_ARGS=(--force --timestamp --options runtime --sign "$APP_IDENTITY")
else
  SIGN_ARGS=(--force --sign -)
fi

/usr/bin/codesign "${SIGN_ARGS[@]}" "$STAGE_APP/Contents/Resources/bin/opm"
/usr/bin/codesign "${SIGN_ARGS[@]}" "$STAGE_APP"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$STAGE_APP"

OUTPUT_DIR="$ROOT/build"
OUTPUT_APP="$OUTPUT_DIR/$APP_NAME.app"
mkdir -p "$OUTPUT_DIR"
if [[ -e "$OUTPUT_APP" ]]; then
  case "$OUTPUT_APP" in
    "$ROOT/build/$APP_NAME.app") rm -r "$OUTPUT_APP" ;;
    *) echo "Refusing to replace unexpected path: $OUTPUT_APP" >&2; exit 1 ;;
  esac
fi
cp -R "$STAGE_APP" "$OUTPUT_APP"

echo "Created $OUTPUT_APP"
