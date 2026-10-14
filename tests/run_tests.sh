#!/usr/bin/env bash
# Runs the whole headless test suite and fails on any test failure OR any GDScript runtime error.
#
# Suites:
#   1. Unit tests   (tests/run_tests.gd)   - fast, no physics
#   2. Smoke test   (tests/smoke_world.gd) - loads the real scene and plays it with simulated input
#
# Why a wrapper: Godot 4.4 gives a runner no hook to catch script errors, so a test that hits
# a runtime error (for example calling a method on null) prints "SCRIPT ERROR" and the runner
# would still report PASS and exit 0. This script rejects that output.
#
# Usage: tests/run_tests.sh            (uses `godot` from PATH)
#        GODOT=/path/to/godot tests/run_tests.sh
set -uo pipefail

GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.." || exit 1

overall=0

# run_suite <label> <godot args...>
run_suite() {
	local label="$1"
	shift
	echo "=== $label ==="
	local output status
	output="$("$GODOT" --headless --path . "$@" 2>&1)"
	status=$?
	printf '%s\n' "$output"

	if [ "$status" -ne 0 ]; then
		echo "run_tests.sh: $label exited with status $status" >&2
		overall=1
		return
	fi
	# Here-string, not a pipe: with pipefail, grep -q closing the pipe early could hide a match.
	if grep -q "SCRIPT ERROR" <<< "$output"; then
		echo "run_tests.sh: GDScript runtime error found in $label output" >&2
		overall=1
	fi
}

run_suite "unit tests" -s tests/run_tests.gd
# --fixed-fps makes every frame exactly 1/60 s, so physics is deterministic and runs fast.
run_suite "smoke test" --fixed-fps 60 -s tests/smoke_world.gd

exit "$overall"
