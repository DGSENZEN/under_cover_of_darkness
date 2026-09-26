#!/usr/bin/env bash
# The wardrobe (tools/wardrobe): Blender, headless, one step at a time.
#
#   tools/wardrobe/wardrobe.sh build watchman [--force]   recipe -> source/watchman.blend
#   tools/wardrobe/wardrobe.sh check watchman             the geometry rules, nothing written
#   tools/wardrobe/wardrobe.sh bake watchman              textures, palettized
#   tools/wardrobe/wardrobe.sh export watchman            validated GLB + PNG + JSON
#   tools/wardrobe/wardrobe.sh preview watchman           pictures of it (--out=<dir>)
#   tools/wardrobe/wardrobe.sh test                       the validation rules', the bake's and the build's own tests
#   tools/wardrobe/wardrobe.sh list                       the kinds the recipes make
#
# Targets: a kind (watchman...), heads, heads_female, hair, hair_female,
# headgear, or all (the heads and hair of each body, headgear, then every
# kind: a kind's export reads its parts' triangle counts). Each body's heads
# and hair are their own file, on their own skeleton.
# Exits non-zero when a step fails.
set -euo pipefail

BLENDER=${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
SOURCE="$ROOT/assets/characters/wardrobe/source"
# The kinds are the recipes' (recipes.py is plain data: any Python reads it).
kinds() {
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
    kinds
    ;;
  test)
    "$BLENDER" -b --factory-startup --python-exit-code 1 --python "$HERE/test_validate.py"
    "$BLENDER" -b --factory-startup --python-exit-code 1 --python "$HERE/test_bake.py"
    exec "$BLENDER" -b --factory-startup --python-exit-code 1 --python "$HERE/test_build.py"
    ;;
  build|check|bake|export|preview)
    target=${1:?"usage: wardrobe.sh $verb <kind|heads|heads_female|hair|hair_female|headgear|all> [options]"}
    shift

    if [ "$target" = all ]; then
      # Asked first: set -e never sees a substitution in a loop's list fail.
      every=$(kinds)

      for each in heads heads_female hair hair_female headgear $every; do
        run "$verb" "$each" "$@"
      done
    else
      run "$verb" "$target" "$@"
    fi
    ;;
  *)
    echo "usage: wardrobe.sh <build|check|bake|export|preview|test|list> [target] [options]" >&2
    exit 2
    ;;
esac
