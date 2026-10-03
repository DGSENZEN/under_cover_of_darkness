#!/usr/bin/env bash
# The level kit pipeline (tools/level): levels built in Blender from a kit of
# pieces, gameplay placed as markers, exported for Godot. The levels are the
# layouts in tools/level/layouts: garrison, city_harbour, city_massing (and
# fixture, the tests' own).
#
#   tools/level/level.sh kit               the kit's pieces -> assets/level/source/kit.blend
#                                          (LEVEL_KIT_OUT: another .blend; LEVEL_KIT_ONLY: those pieces, a,b,c)
#   tools/level/level.sh build <level> [--force]  its layout -> assets/level/source/<level>.blend (then the
#                                          user's: not built over once edited, its ground's paint
#                                          included, unless --force)
#   tools/level/level.sh check <level>     the rules, nothing written
#   tools/level/level.sh export <level>    checked, then glTF per sector, its proxy (proxy.glb) + the manifest, imported by Godot
#   tools/level/level.sh preview <level> [out]  a plan and four bird's-eye pictures
#   tools/level/level.sh all <level>       kit, build, export
#   tools/level/level.sh navmesh <district>  its map's navmesh baked and saved
#                                          (assets/level/navmesh/<district>.scn, data/districts.json)
#   tools/level/level.sh test              the rules against broken levels, the terrain, the kit's shapes
#                                          and pieces, the ships, occlusion, overlap, shading; the build's guard
#
# Exits non-zero when a step fails.
set -euo pipefail

BLENDER=${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}
GODOT=${GODOT:-/Users/tinkertailorr/Desktop/Godot.app/Contents/MacOS/Godot}
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
# The levels' .blend files (LEVEL_SOURCE: elsewhere, as the guard's test builds).
SOURCE="${LEVEL_SOURCE:-$ROOT/assets/level/source}"

verb=${1:-}
level=${2:-}

need_level() {
  if [ -z "$level" ]; then
    echo "level: $verb needs a level" >&2
    exit 2
  fi
}

case "$verb" in
  kit)
    "$BLENDER" -b --factory-startup --python-exit-code 1 --python "$HERE/kit.py"
    ;;
  build)
    need_level
    # Once edited in Blender the level is the user's: not built over.
    if [ -f "$SOURCE/$level.blend" ] && [ "${3:-}" != "--force" ]; then
      if ! said=$("$BLENDER" -b "$SOURCE/$level.blend" --python-exit-code 1 --python "$HERE/edited.py" 2>&1); then
        echo "$said" | grep "^level:" >&2
        exit 3
      fi
    fi
    "$BLENDER" -b --factory-startup --python-exit-code 1 --python "$HERE/build.py" -- "$level"
    ;;
  check)
    need_level
    "$BLENDER" -b "$SOURCE/$level.blend" --python-exit-code 1 --python "$HERE/check.py" -- "${3:-stage2}"
    ;;
  export)
    need_level
    "$BLENDER" -b "$SOURCE/$level.blend" --python-exit-code 1 --python "$HERE/export.py" -- "${3:-stage2}"
    perl -e 'alarm 600; exec @ARGV' "$GODOT" --headless --path "$ROOT" --import > /dev/null 2>&1 || true
    echo "level: imported by Godot"
    ;;
  preview)
    need_level
    "$BLENDER" -b "$SOURCE/$level.blend" --python-exit-code 1 --python "$HERE/preview.py" -- "${3:-$ROOT/tmp_preview}"
    ;;
  navmesh)
    need_level
    # (The district's map, from the registry: baked, saved, quit.)
    map=$(python3 -c "import json,sys; print(json.load(open('$ROOT/data/districts.json'))['districts'][sys.argv[1]]['map'])" "$level")
    perl -e 'alarm 1800; exec @ARGV' "$GODOT" --headless --fixed-fps 60 --path "$ROOT" "$map" -- --bake-navmesh
    ;;
  all)
    need_level
    "$0" kit
    "$0" build "$level"
    "$0" export "$level"
    ;;
  test)
    python3 "$HERE/test_rules.py"
    python3 "$HERE/test_terrain.py"
    python3 "$HERE/test_kit_shapes.py"
    python3 "$HERE/test_kits.py"
    python3 "$HERE/test_occlusion.py"
    python3 "$HERE/test_ships.py"
    python3 "$HERE/test_overlap.py"
    python3 "$HERE/test_mole.py"
    python3 "$HERE/test_spit.py"
    python3 "$HERE/test_shade.py"
    python3 "$HERE/test_districts.py"
    python3 "$HERE/test_proxy.py"
    python3 "$HERE/test_town_rules.py"
    python3 "$HERE/test_town.py"
    "$HERE/test_guard.sh"
    ;;
  *)
    sed -n '2,21p' "$0"
    exit 2
    ;;
esac
