#!/usr/bin/env bash
# tools/run_suites.sh against a stand-in for Godot that prints what each case
# needs, so the runner's verdicts are checked without running the game.
#
#   tools/test_run_suites.sh        prints ok / FAIL per case, exits 1 on any FAIL
set -uo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
failed=0

# A fake Godot: the log it prints is chosen by the scene's name.
cat > "$WORK/godot" <<'FAKE'
#!/usr/bin/env bash
scene="${*: -1}"
echo "==== RESULTS ===="
echo "PASS  X1 something"
case "$scene" in
  *engine_error*) echo "ERROR: Something went wrong in the engine." ;;
  *exit_leaks*)
    echo "ERROR: 3 RID allocations of type 'N13RendererDummy9DummyMeshE' were leaked at exit."
    echo "ERROR: Pages in use exist at exit in PagedAllocator: N20RasterizerSceneDummy21GeometryInstanceDummyE"
    echo "ERROR: 2 resources still in use at exit (run with --verbose for details)." ;;
  *expected*) echo "ERROR: LightFixture: no fixture called 'no_such_fixture' (res://assets/props/lights/no_such_fixture.json): a bare flame instead" ;;
esac
FAKE
chmod +x "$WORK/godot"

check() {
  local label=$1 want=$2 scene=$3
  mkdir -p "$WORK/tests"
  touch "$WORK/tests/$scene.tscn"
  local out code
  out=$(cd "$WORK" && GODOT="$WORK/godot" TMPDIR="$WORK/tmp" "$HERE/tools/run_suites.sh" "$WORK/tests/$scene.tscn" 2>&1)
  code=$?

  if [ "$code" = "$want" ]; then
    echo "ok    $label"
  else
    echo "FAIL  $label (exit $code, wanted $want): $out"
    failed=1
  fi
}

check "an engine ERROR line fails the run" 1 engine_error_test
check "Godot's own at-exit leak reports do not" 0 exit_leaks_test
check "an error a suite provokes on purpose (tools/expected_errors.txt) does not" 0 expected_test
check "a clean suite passes" 0 clean_test
exit $failed
