#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

required_commands=(swift ast-grep shellcheck git expect)
for command_name in "${required_commands[@]}"; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Missing required command: $command_name" >&2
    exit 1
  fi
done

swift package resolve
git config core.hooksPath .githooks
chmod +x .githooks/pre-commit Scripts/*.sh

echo "Bootstrap complete. Run Scripts/check.sh."
