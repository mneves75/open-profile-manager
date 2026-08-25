#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
APP=${1:-}
if [[ -z "$APP" ]]; then
  echo "Usage: $0 <Open Profile Manager.app>" >&2
  exit 2
fi

INFO_PLIST="$APP/Contents/Info.plist"
CLI="$APP/Contents/Resources/bin/opm"
TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/opm-packaged-app-test.XXXXXX")
trap 'rm -r "$TEST_ROOT"' EXIT

if [[ ! -d "$APP" || ! -f "$INFO_PLIST" || ! -x "$CLI" ]]; then
  echo "Packaged app is missing its bundle metadata or bundled opm CLI: $APP" >&2
  exit 1
fi

app_executable_name=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$INFO_PLIST")
if [[ "$app_executable_name" != OpenProfileManager ]]; then
  echo "Packaged app has an unexpected executable name: $app_executable_name" >&2
  exit 1
fi
app_executable="$APP/Contents/MacOS/$app_executable_name"
bundle_version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")
if [[ ! -x "$app_executable" ]]; then
  echo "Packaged app executable is missing: $app_executable" >&2
  exit 1
fi
if [[ $("$CLI" version) != "$bundle_version" ]]; then
  echo "Bundled CLI version does not match the app bundle version" >&2
  exit 1
fi

"$ROOT/Scripts/test_interactive_launch.sh" "$CLI"
mkdir -m 0700 "$TEST_ROOT/home"
CFFIXED_USER_HOME="$TEST_ROOT/home" \
  /usr/bin/xcrun swift "$ROOT/Scripts/benchmark_native_launch.swift" "$app_executable" 1

echo "Packaged app smoke checks passed."
