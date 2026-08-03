#!/usr/bin/env bash
set -euo pipefail

unset \
  APP_STORE_CONNECT_API_KEY_P8 \
  ASC_BYPASS_KEYCHAIN \
  ASC_CONFIG_PATH \
  ASC_ISSUER_ID \
  ASC_KEY_ID \
  ASC_KEY_TYPE \
  ASC_PROFILE \
  ASC_PRIVATE_KEY \
  ASC_PRIVATE_KEY_B64 \
  ASC_PRIVATE_KEY_PATH \
  ASC_STRICT_AUTH || true

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

# shellcheck disable=SC1091
source "$ROOT/version.env"
# shellcheck disable=SC1091
source "$ROOT/Scripts/release_artifacts.sh"

APP_NAME="Open Profile Manager"
APP_IDENTITY=${APP_IDENTITY:-}
ARCHES_VALUE=${ARCHES:-"arm64 x86_64"}
APP="$ROOT/build/$APP_NAME.app"
APP_ZIP="$ROOT/build/$(opm_app_zip_name "$MARKETING_VERSION" "$ARCHES_VALUE")"
DSYM_ZIP="$ROOT/build/$(opm_dsym_zip_name "$MARKETING_VERSION" "$ARCHES_VALUE")"
CHECKSUMS="$ROOT/build/$(opm_checksums_name "$MARKETING_VERSION")"

verify_distribution_policy() {
  local app=$1
  if command -v syspolicy_check >/dev/null 2>&1; then
    syspolicy_check distribution "$app"
  else
    /usr/sbin/spctl --assess --type execute --verbose=2 "$app"
  fi
}

if [[ "$ARCHES_VALUE" != "arm64 x86_64" && "$ARCHES_VALUE" != "x86_64 arm64" ]]; then
  echo "Public releases must be universal (arm64 and x86_64)" >&2
  exit 1
fi
if [[ "$APP_IDENTITY" != Developer\ ID\ Application:* ]]; then
  echo "APP_IDENTITY must name a Developer ID Application identity" >&2
  exit 1
fi
if ! /usr/bin/security find-identity -v -p codesigning | grep -Fq "\"$APP_IDENTITY\""; then
  echo "Developer ID identity is not available in the current keychain search list" >&2
  exit 1
fi
if ! command -v asc >/dev/null 2>&1; then
  echo "asc is required for notarization" >&2
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required to validate asc authentication" >&2
  exit 1
fi
if ! asc_notarization_help=$(ASC_TELEMETRY_DISABLED=1 asc notarization submit --help 2>&1); then
  echo "The installed asc does not support notarization submit" >&2
  exit 1
fi
for required_flag in --file --wait --timeout; do
  if [[ "$asc_notarization_help" != *"$required_flag"* ]]; then
    echo "The installed asc notarization client does not support $required_flag" >&2
    exit 1
  fi
done
asc_auth_status=$(
  ASC_STRICT_AUTH=true ASC_TELEMETRY_DISABLED=1 asc auth status --output json
)
if ! jq -e '
  .storageBackend == "System Keychain"
  and .environmentCredentialsProvided == false
  and any(.credentials[]; .isDefault == true and .storedIn == "keychain")
  and all(.credentials[]; .isDefault != true or .storedIn == "keychain")
' <<< "$asc_auth_status" >/dev/null; then
  echo "asc must use a System Keychain profile without environment credentials" >&2
  exit 1
fi

rm -f "$APP_ZIP" "$DSYM_ZIP" "$CHECKSUMS"

NOTARIZATION_TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/open-profile-manager-notarize.XXXXXX")
chmod 0700 "$NOTARIZATION_TEMP_DIR"
NOTARIZATION_ZIP="$NOTARIZATION_TEMP_DIR/OpenProfileManagerNotarize.zip"
DSYM_STAGE="$NOTARIZATION_TEMP_DIR/Open-Profile-Manager-$MARKETING_VERSION-dSYMs"
trap 'rm -r "$NOTARIZATION_TEMP_DIR"' EXIT

ARCHES="$ARCHES_VALUE" APP_IDENTITY="$APP_IDENTITY" Scripts/package_app.sh release

/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP"
if find "$APP" -name '._*' -print -quit | grep -q .; then
  echo "AppleDouble files are not allowed in the release bundle" >&2
  exit 1
fi

/usr/bin/ditto --norsrc -c -k --keepParent "$APP" "$NOTARIZATION_ZIP"
ASC_STRICT_AUTH=true ASC_TELEMETRY_DISABLED=1 asc notarization submit \
  --file "$NOTARIZATION_ZIP" \
  --wait \
  --timeout 30m

/usr/bin/xcrun stapler staple "$APP"
/usr/bin/xattr -cr "$APP"
find "$APP" -name '._*' -delete
/usr/bin/ditto --norsrc -c -k --keepParent "$APP" "$APP_ZIP"

/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP"
verify_distribution_policy "$APP"
/usr/bin/xcrun stapler validate "$APP"

mkdir -p "$DSYM_STAGE"
for executable_name in OpenProfileManager opm; do
  if [[ "$executable_name" == OpenProfileManager ]]; then
    executable_path="$APP/Contents/MacOS/$executable_name"
  else
    executable_path="$APP/Contents/Resources/bin/$executable_name"
  fi
  dsym_path="$DSYM_STAGE/$executable_name.dSYM"
  /usr/bin/dsymutil "$executable_path" -o "$dsym_path"
  executable_uuids=$(/usr/bin/dwarfdump --uuid "$executable_path" | awk '{print $2, $3}' | sort)
  dsym_uuids=$(/usr/bin/dwarfdump --uuid "$dsym_path" | awk '{print $2, $3}' | sort)
  if [[ "$executable_uuids" != "$dsym_uuids" ]]; then
    echo "dSYM UUID mismatch for $executable_name" >&2
    exit 1
  fi
done
/usr/bin/ditto --norsrc -c -k --keepParent "$DSYM_STAGE" "$DSYM_ZIP"

(
  cd "$ROOT/build"
  /usr/bin/shasum -a 256 "$(basename "$APP_ZIP")" "$(basename "$DSYM_ZIP")" \
    > "$(basename "$CHECKSUMS")"
)

echo "Notarized artifact: $APP_ZIP"
echo "Debug symbols: $DSYM_ZIP"
echo "Checksums: $CHECKSUMS"
