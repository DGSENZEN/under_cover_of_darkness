#!/usr/bin/env bash
# The wardrobe (tools/wardrobe): Blender, headless, one step at a time.
#
#   tools/wardrobe/wardrobe.sh build watchman [--force]   recipe -> source/watchman.blend
#   tools/wardrobe/wardrobe.sh check watchman             the geometry rules, nothing written
#   tools/wardrobe/wardrobe.sh bake watchman              textures, palettized
#   tools/wardrobe/wardrobe.sh export watchman            validated GLB + PNG + JSON
#   tools/wardrobe/wardrobe.sh preview watchman           pictures of it (--out=<dir>)
#   tools/wardrobe/wardrobe.sh test                       the validation rules' own test
#
# Targets: a kind (watchman...), heads, headgear, or all (heads, headgear,
# then every kind: a kind's export reads its parts' triangle counts).
# Exits non-zero when a step fails.
set -euo pipefail

BLENDER=${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
SOURCE="$ROOT/assets/characters/wardrobe/source"
KINDS=(watchman)

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
  test)
    exec "$BLENDER" -b --factory-startup --python-exit-code 1 --python "$HERE/test_validate.py"
    ;;
  build|check|bake|export|preview)
    target=${1:?"usage: wardrobe.sh $verb <kind|heads|headgear|all> [options]"}
    shift

    if [ "$target" = all ]; then
      for each in heads headgear "${KINDS[@]}"; do
        run "$verb" "$each" "$@"
      done
    else
      run "$verb" "$target" "$@"
    fi
    ;;
  *)
    echo "usage: wardrobe.sh <build|check|bake|export|preview|test> [target] [options]" >&2
    exit 2
    ;;
esac
