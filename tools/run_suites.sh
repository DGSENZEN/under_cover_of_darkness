#!/usr/bin/env bash
# Every headless suite, six at a time, each with --fixed-fps 60 and a 900 s
# alarm, logged to ${TMPDIR:-/tmp}/suites/<name>.log; then a summary line per
# suite (passes, failures) and the suites that never printed their results or
# hit a script error. Exits 1 if anything failed.
#
#   tools/run_suites.sh                         all of tests/*_test.tscn
#   tools/run_suites.sh 'tests/l*_test.tscn'    some
set -uo pipefail

GODOT=${GODOT:-/Users/tinkertailorr/Desktop/Godot.app/Contents/MacOS/Godot}
HERE="$(cd "$(dirname "$0")/.." && pwd)"
LOGS="${TMPDIR:-/tmp}/suites"
PATTERN=${1:-tests/*_test.tscn}
mkdir -p "$LOGS"
cd "$HERE"

run_one() {
  local scene=$1
  local name
  name=$(basename "$scene" .tscn)
  perl -e 'alarm 900; exec @ARGV' "$GODOT" --headless --fixed-fps 60 --path . "res://$scene" > "$LOGS/$name.log" 2>&1
}
export -f run_one
export GODOT LOGS

# shellcheck disable=SC2086
ls $PATTERN | xargs -P 6 -I{} bash -c 'run_one "$@"' _ {}

status=0

# shellcheck disable=SC2086
for scene in $(ls $PATTERN); do
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

  if [ "$fails" != "0" ]; then
    status=1
  fi

  printf "%-22s PASS %3d / FAIL %d%s\n" "$name" "$passes" "$fails" "$note"
done

exit $status
