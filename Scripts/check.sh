#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

Scripts/lint.sh
Scripts/test_release_artifacts.sh
Scripts/test_security_check.sh
swift Scripts/check_localizations.swift
swift build

# shellcheck disable=SC1091
source "$ROOT/version.env"
if [[ $(.build/debug/opm version) != "$MARKETING_VERSION" ]]; then
  echo "Built opm version does not match MARKETING_VERSION=$MARKETING_VERSION" >&2
  exit 1
fi

Scripts/test_interactive_launch.sh
swift test --parallel
Scripts/check_web_video.sh

if .build/debug/opm status >/dev/null 2>&1; then
  echo "Bare 'opm status' must require a profile ID or --all" >&2
  exit 1
fi

echo "All checks passed."
