#!/usr/bin/env bash
# Every headless suite, six at a time, each with --fixed-fps 60 and a 900 s
# alarm, logged to ${TMPDIR:-/tmp}/suites/<name>.log; then a summary line per
# suite (passes, failures) and the suites that never printed their results,
# hit a script error, or printed an engine ERROR line (other than Godot's own
# reports at exit and the errors a suite provokes on purpose, listed in
# tools/expected_errors.txt), those lines below. Exits 1 if anything failed.
#
#   tools/run_suites.sh                                   all of tests/*_test.tscn
#   tools/run_suites.sh tests/retro_test.tscn tests/l*    some
set -uo pipefail

GODOT=${GODOT:-/Users/tinkertailorr/Desktop/Godot.app/Contents/MacOS/Godot}
HERE="$(cd "$(dirname "$0")/.." && pwd)"
LOGS="${TMPDIR:-/tmp}/suites"
mkdir -p "$LOGS"
cd "$HERE"

if [ $# -gt 0 ]; then
  SCENES=$(ls "$@")
else
  SCENES=$(ls tests/*_test.tscn)
fi

run_one() {
  local scene=$1
  local name
  name=$(basename "$scene" .tscn)
  perl -e 'alarm 900; exec @ARGV' "$GODOT" --headless --fixed-fps 60 --path . "res://$scene" > "$LOGS/$name.log" 2>&1
}
export -f run_one
export GODOT LOGS

# Headless Godot reports the renderer objects it leaves behind at exit: not a
# failure. Nor is an error a suite provokes on purpose.
EXIT_NOISE='leaked at exit|Pages in use exist at exit|still in use at exit'
EXPECTED=$(grep -v '^#' "$HERE/tools/expected_errors.txt" 2>/dev/null | grep -v '^[[:space:]]*$' || true)

engine_errors() {
  local lines
  lines=$(grep "^ERROR:" "$1" | grep -Ev "$EXIT_NOISE" || true)

  if [ -n "$EXPECTED" ] && [ -n "$lines" ]; then
    lines=$(printf '%s\n' "$lines" | grep -vF "$EXPECTED" || true)
  fi

  if [ -n "$lines" ]; then
    printf '%s\n' "$lines"
  fi
}

echo "$SCENES" | xargs -P 6 -I{} bash -c 'run_one "$@"' _ {}

status=0
reports=""

for scene in $SCENES; do
  name=$(basename "$scene" .tscn)
  log="$LOGS/$name.log"
  passes=$(grep -c "^PASS" "$log" || true)
  fails=$(grep -c "^FAIL" "$log" || true)
  note=""

  if ! grep -q "==== RESULTS ====" "$log"; then
    note=" NO RESULTS"
    status=1
  fi

  if grep -q "SCRIPT ERROR" "$log"; then
    note="$note SCRIPT ERROR"
    status=1
  fi

  errors=$(engine_errors "$log")

  if [ -n "$errors" ]; then
    note="$note ENGINE ERROR x$(printf '%s\n' "$errors" | wc -l | tr -d ' ')"
    reports="$reports$name: $(printf '%s\n' "$errors" | head -1)"$'\n'
    status=1
  fi

  if [ "$fails" != "0" ]; then
    status=1
  fi

  printf "%-22s PASS %3d / FAIL %d%s\n" "$name" "$passes" "$fails" "$note"
done

if [ -n "$reports" ]; then
  printf '\nEngine errors (first of each suite; the full lines in its log):\n%s' "$reports"
fi

exit $status
