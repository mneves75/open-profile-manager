#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
OPM=${1:-"$ROOT/.build/debug/opm"}
TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/opm-interactive-test.XXXXXX")
trap 'rm -r "$TEST_ROOT"' EXIT

mkdir -m 0700 "$TEST_ROOT/home" "$TEST_ROOT/codex-home" "$TEST_ROOT/bin"
FAKE_CODEX="$TEST_ROOT/bin/codex"
cat > "$FAKE_CODEX" <<'SH'
#!/bin/sh
pgid=$(/bin/ps -o pgid= -p "$$" | /usr/bin/tr -d ' ')
tpgid=$(/bin/ps -o tpgid= -p "$$" | /usr/bin/tr -d ' ')
printf 'PID=%s PGID=%s TPGID=%s ARGS=' "$$" "$pgid" "$tpgid"
for argument in "$@"; do
  printf '<%s>' "$argument"
done
printf '\nREADY\n'
IFS= read -r marker
printf 'READ:%s\n' "$marker"
SH
chmod 0700 "$FAKE_CODEX"

export CFFIXED_USER_HOME="$TEST_ROOT/home"
export PATH="$TEST_ROOT/bin:/usr/bin:/bin"
"$OPM" profile add personal --name Personal --home "$TEST_ROOT/codex-home" >/dev/null

export TEST_OPM="$OPM"
expect <<'TCL'
set timeout 5
set opm $env(TEST_OPM)

proc run_case {opm arguments expected_arguments} {
  spawn -noecho $opm {*}$arguments
  set original_pid [exp_pid]
  expect {
    -re {PID=([0-9]+) PGID=([0-9]+) TPGID=([0-9]+) ARGS=([^\r\n]*)\r?\n} {
      set child_pid $expect_out(1,string)
      set pgid $expect_out(2,string)
      set tpgid $expect_out(3,string)
      set actual_arguments $expect_out(4,string)
      if {$child_pid != $original_pid} {
        error "PID changed from $original_pid to $child_pid"
      }
      if {$pgid != $tpgid} {
        error "child process group $pgid does not own terminal foreground group $tpgid"
      }
      if {$actual_arguments ne $expected_arguments} {
        error "arguments mismatch: $actual_arguments"
      }
    }
    timeout { error "timed out before process identity was reported" }
    eof { error "process exited before process identity was reported" }
  }
  expect {
    READY { send -- "terminal-marker\r" }
    timeout { error "timed out before terminal read" }
    eof { error "process exited before terminal read" }
  }
  expect {
    "READ:terminal-marker" {}
    timeout { error "timed out waiting for interactive terminal read" }
    eof { error "process exited before completing terminal read" }
  }
  expect eof
}

run_case $opm [list run personal "literal value" {--flag=$dollar}] {<literal value><--flag=$dollar>}
run_case $opm [list login personal] {<login>}
run_case $opm [list logout personal] {<logout>}
TCL

echo "Interactive launch checks passed."
