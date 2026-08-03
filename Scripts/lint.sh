#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

ast-grep scan --config sgconfig.yml --error Sources Tests Scripts/atomic_replace.swift
swift format lint --recursive --parallel --strict Sources Tests Scripts/atomic_replace.swift Package.swift
shellcheck .githooks/pre-commit Scripts/*.sh
