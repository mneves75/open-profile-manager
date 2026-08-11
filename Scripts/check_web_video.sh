#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

MODE=${1:-all}
if [[ "$MODE" != all && "$MODE" != --site-only ]]; then
  echo "usage: Scripts/check_web_video.sh [--site-only]" >&2
  exit 64
fi

if [[ $(node --version) != v24.* ]]; then
  echo "Node 24 is required for web and video checks" >&2
  exit 1
fi
node --check docs/app.js
Scripts/benchmark_site.sh --validate-only

if [[ "$MODE" == --site-only ]]; then
  exit 0
fi

if [[ $(npm --version) != 11.* ]]; then
  echo "npm 11 is required for web and video checks" >&2
  exit 1
fi

npm ci --prefix video
npm --prefix video run lint
npm audit --prefix video --audit-level=high
