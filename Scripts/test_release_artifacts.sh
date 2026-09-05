#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
# shellcheck disable=SC1091
source "$ROOT/Scripts/release_artifacts.sh"

assert_equal() {
  local expected=$1
  local actual=$2
  if [[ "$actual" != "$expected" ]]; then
    echo "Expected '$expected', got '$actual'" >&2
    exit 1
  fi
}

assert_equal macos-universal "$(opm_release_arch_label 'arm64 x86_64')"
assert_equal v0.1.7 "$(opm_release_tag 0.1.7)"
assert_equal v0.1.7-beta1 "$(opm_release_tag 0.1.7 --beta 1)"
assert_equal v0.1.7-beta12 "$(opm_release_tag 0.1.7 --beta 12)"
for invalid_count in 0 -1 01 abc ''; do
  if opm_release_tag 0.1.7 --beta "$invalid_count" >/dev/null; then
    echo "Invalid beta count accepted: $invalid_count" >&2
    exit 1
  fi
done
for invalid_argument in --unknown --beta; do
  if opm_release_tag 0.1.7 "$invalid_argument" >/dev/null; then
    echo "Invalid release arguments accepted" >&2
    exit 1
  fi
done
if opm_release_tag 0.1.7 --beta 1 extra >/dev/null \
  || opm_release_tag 0.1.7-beta1 >/dev/null; then
  echo "Malformed release arguments accepted" >&2
  exit 1
fi
assert_equal macos-universal "$(opm_release_arch_label 'x86_64,arm64')"
assert_equal macos-arm64 "$(opm_release_arch_label arm64)"
assert_equal macos-x86_64 "$(opm_release_arch_label x86_64)"
assert_equal Open-Profile-Manager-macos-universal-0.1.0.zip \
  "$(opm_app_zip_name 0.1.0 'arm64 x86_64')"
assert_equal Open-Profile-Manager-macos-universal-0.1.0.dSYM.zip \
  "$(opm_dsym_zip_name 0.1.0 'arm64 x86_64')"

echo "Release artifact naming passed."
