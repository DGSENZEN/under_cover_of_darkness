#!/usr/bin/env bash
# The props (tools/props): light fixtures built in Blender, headless.
#
#   tools/props/props.sh flames               the effect sheets (assets/vfx/)
#   tools/props/props.sh build <fixture|all>  recipe -> assets/props/source/<fixture>.blend
#   tools/props/props.sh check <fixture|all>  the rules, nothing written
#   tools/props/props.sh list                 the fixtures the recipes make
#   tools/props/props.sh test                 the pipeline's own tests
#
# Exits non-zero when a step fails.
set -euo pipefail

BLENDER=${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}
HERE="$(cd "$(dirname "$0")" && pwd)"

SOURCE="$HERE/../../assets/props/source"
fixtures() {
  PYTHONDONTWRITEBYTECODE=1 python3 -c "import sys; sys.path.insert(0, '$HERE'); import recipes; print(' '.join(recipes.KINDS))"
}

verb=${1:-}
shift || true

run() {
  local step=$1 target=$2
  shift 2
  local file="$SOURCE/$target.blend"
  local open=(--factory-startup)

  if [ "$step" != build ] && [ -f "$file" ]; then
    open=("$file")
  fi

  "$BLENDER" -b "${open[@]}" --python-exit-code 1 --python "$HERE/$step.py" -- "$target" "$@"
}

case "$verb" in
  list)
    fixtures
    ;;
  test)
    exec "$BLENDER" -b --factory-startup --python-exit-code 1 --python "$HERE/test_check.py"
    ;;
  build|check)
    target=${1:?"usage: props.sh $verb <fixture|all>"}
    shift

    if [ "$target" = all ]; then
      every=$(fixtures)

      for one in $every; do
        run "$verb" "$one" "$@"
      done
    else
      run "$verb" "$target" "$@"
    fi
    ;;
  flames)
    exec "$BLENDER" -b --factory-startup --python-exit-code 1 --python "$HERE/flames.py" -- "${1:-all}"
    ;;
  *)
    sed -n '2,10p' "$0"
    exit 1
    ;;
esac
