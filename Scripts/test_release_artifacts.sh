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
assert_equal macos-universal "$(opm_release_arch_label 'x86_64,arm64')"
assert_equal macos-arm64 "$(opm_release_arch_label arm64)"
assert_equal macos-x86_64 "$(opm_release_arch_label x86_64)"
assert_equal Open-Profile-Manager-macos-universal-0.1.0.zip \
  "$(opm_app_zip_name 0.1.0 'arm64 x86_64')"
assert_equal Open-Profile-Manager-macos-universal-0.1.0.dSYM.zip \
  "$(opm_dsym_zip_name 0.1.0 'arm64 x86_64')"

echo "Release artifact naming passed."
