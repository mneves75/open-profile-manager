#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

ast-grep test --config sgconfig.yml --skip-snapshot-tests
ast-grep scan --config sgconfig.yml --error Sources Tests Scripts/atomic_replace.swift Scripts/check_localizations.swift
swift format lint --recursive --parallel --strict Sources Tests Scripts/atomic_replace.swift Scripts/check_localizations.swift Package.swift
shellcheck .githooks/pre-commit Scripts/*.sh
