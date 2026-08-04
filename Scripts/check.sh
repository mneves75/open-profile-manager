#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

Scripts/lint.sh
Scripts/test_release_artifacts.sh
swift Scripts/check_localizations.swift
swift build
Scripts/test_interactive_launch.sh
swift test --parallel

if .build/debug/opm status >/dev/null 2>&1; then
  echo "Bare 'opm status' must require a profile ID or --all" >&2
  exit 1
fi

echo "All checks passed."
