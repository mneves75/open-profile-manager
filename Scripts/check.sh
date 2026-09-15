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
# A single-thread cooperative pool turns blocking inside Swift tasks into a starvation failure.
LIBDISPATCH_COOPERATIVE_POOL_STRICT=1 swift test --filter statusReadsDoNotOccupyCooperativePool
Scripts/check_web_video.sh

if .build/debug/opm status >/dev/null 2>&1; then
  echo "Bare 'opm status' must require a profile ID or --all" >&2
  exit 1
fi

# The CLI must hand paths to ProfileCore unstandardized: Foundation can truncate long standardized paths.
# Components stay within NAME_MAX so only the whole-path limit can reject this CODEX_HOME.
LONG_PATH_HOME=$(mktemp -d "${TMPDIR:-/tmp}/opm-long-path.XXXXXX")
trap 'rm -r "$LONG_PATH_HOME"' EXIT
LONG_CODEX_HOME=$LONG_PATH_HOME
for _ in 1 2 3 4 5; do
  LONG_CODEX_HOME="$LONG_CODEX_HOME/$(printf 'p%.0s' {1..250})"
done
if long_path_output=$(CFFIXED_USER_HOME="$LONG_PATH_HOME" .build/debug/opm profile add long \
  --name Long --home "$LONG_CODEX_HOME" 2>&1); then
  echo "An over-long CODEX_HOME must be rejected" >&2
  exit 1
fi
if [[ "$long_path_output" != *"CODEX_HOME must be an absolute path."* ]]; then
  echo "An over-long CODEX_HOME must fail path validation, not filesystem access: $long_path_output" >&2
  exit 1
fi

echo "All checks passed."
