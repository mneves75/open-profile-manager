#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

required_commands=(swift ast-grep shellcheck git expect node npm python3)
for command_name in "${required_commands[@]}"; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Missing required command: $command_name" >&2
    exit 1
  fi
done

if [[ $(node --version) != v24.* || $(npm --version) != 11.* ]]; then
  echo "Node 24 and npm 11 are required; select the runtime in .nvmrc first." >&2
  exit 1
fi

swift package resolve
npm ci --prefix video
git config core.hooksPath .githooks
echo "Bootstrap complete. Run Scripts/check.sh."
