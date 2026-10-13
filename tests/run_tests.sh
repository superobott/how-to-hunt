#!/usr/bin/env bash
# Runs the headless test suite and fails on any test failure OR any GDScript runtime error.
#
# Why a wrapper: Godot 4.4 gives the runner no hook to catch script errors, so a test that hits
# a runtime error (for example calling a method on null) prints "SCRIPT ERROR" and the runner
# would still report PASS and exit 0. This script rejects that output.
#
# Usage: tests/run_tests.sh            (uses `godot` from PATH)
#        GODOT=/path/to/godot tests/run_tests.sh
set -uo pipefail

GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.." || exit 1

output="$("$GODOT" --headless --path . -s tests/run_tests.gd 2>&1)"
status=$?
printf '%s\n' "$output"

if [ "$status" -ne 0 ]; then
	echo "run_tests.sh: test runner exited with status $status" >&2
	exit "$status"
fi

# Here-string, not a pipe: with pipefail, grep -q closing the pipe early could hide a match.
if grep -q "SCRIPT ERROR" <<< "$output"; then
	echo "run_tests.sh: GDScript runtime error found in test output" >&2
	exit 1
fi
