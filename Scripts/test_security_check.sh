#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/opm-security-check-test.XXXXXX")
BIN_DIR="$TEST_ROOT/bin"
LOG_FILE="$TEST_ROOT/trufflehog-arguments"
trap 'rm -r "$TEST_ROOT"' EXIT

mkdir "$BIN_DIR"

cat > "$BIN_DIR/gitleaks" <<'SH'
#!/bin/sh
exit 0
SH

cat > "$BIN_DIR/git" <<'SH'
#!/bin/sh
if [ "${1:-}" = rev-parse ] && [ "${2:-}" = --verify ] && [ "${3:-}" = HEAD ]; then
  exit 1
fi
exit 0
SH

cat > "$BIN_DIR/swift" <<'SH'
#!/bin/sh
exit 0
SH

cat > "$BIN_DIR/trufflehog" <<'SH'
#!/bin/sh
printf '%s\n' "$*" >> "$OPM_SECURITY_TEST_LOG"
SH

chmod 0700 "$BIN_DIR"/*

run_security_check() {
  PATH="$BIN_DIR:/usr/bin:/bin" \
    OPM_SECURITY_TEST_LOG="$LOG_FILE" \
    "$ROOT/Scripts/security-check.sh" "$@"
}

run_security_check
normal_arguments=$(<"$LOG_FILE")
if [[ "$normal_arguments" != *"--results verified ."* ]]; then
  echo "Normal security checks must request verified TruffleHog results" >&2
  exit 1
fi

: > "$LOG_FILE"
run_security_check --release
release_arguments=$(<"$LOG_FILE")
if [[ "$release_arguments" != *"--results verified,unknown,unverified ."* ]]; then
  echo "Release security checks must request all actionable TruffleHog results" >&2
  exit 1
fi

rm "$BIN_DIR/trufflehog"
if run_security_check --release >/dev/null 2>&1; then
  echo "Release security checks must fail when TruffleHog is unavailable" >&2
  exit 1
fi

if run_security_check --unsupported >/dev/null 2>&1; then
  echo "Security checks must reject unsupported arguments" >&2
  exit 1
fi
if run_security_check --release extra >/dev/null 2>&1; then
  echo "Security checks must reject extra arguments" >&2
  exit 1
fi

echo "Security-check contract passed."
