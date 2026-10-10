#!/usr/bin/env bash
# lab.sh guards the user's vertex-paint strokes: when reading them from a
# piece's last .blend fails, the piece is not rebuilt (the rebuild would save
# over the only copy of the strokes). Stub Blender and Godot: nothing real
# is touched.
#
#   tools/eclipse/test_lab_sh.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK:?}"' EXIT

cat > "$WORK/stub" <<'STUB'
#!/usr/bin/env bash
for a in "$@"; do
  case "$a" in
    *harvest.py) echo "Traceback (most recent call last): stub harvest failure"; exit 1 ;;
  esac
done
touch "$MARK"
exit 0
STUB
chmod +x "$WORK/stub"

MARK="$WORK/built" BLENDER="$WORK/stub" GODOT="$WORK/stub" "$HERE/lab.sh" kiosk > "$WORK/out.log" 2>&1
status=$?

if [ "$status" -ne 0 ] && [ ! -e "$WORK/built" ]; then
  echo "PASS  a failed harvest stops the build (exit $status, nothing built)"
else
  echo "FAIL  a failed harvest stops the build (exit $status, built: $([ -e "$WORK/built" ] && echo yes || echo no))"
  cat "$WORK/out.log"
  exit 1
fi
