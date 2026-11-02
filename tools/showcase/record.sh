#!/bin/zsh
# Records each showcase shot on its own, and says which did what they are there to show.
# usage: tools/showcase/record.sh <out dir> [shot ...]
G=/Users/tinkertailorr/Desktop/Godot.app/Contents/MacOS/Godot
OUT=$1
shift
SHOTS=("$@")

if [ ${#SHOTS[@]} -eq 0 ]; then
	SHOTS=(${=$(sed -n 's/^const SHOTS := \[\(.*\)\]/\1/p' tests/diag_showcase_video.gd | tr -d '"' | tr ',' ' ')})
fi

mkdir -p "$OUT"

for s in $SHOTS; do
	timeout 120 "$G" --path . --resolution 1920x1080 --fixed-fps 60 --write-movie "$OUT/$s.avi" res://tests/diag_showcase_video.tscn -- --shot=$s > "$OUT/$s.log" 2>&1
	echo "== $s exit=$? err=$(grep -c 'SCRIPT ERROR\|SHADER ERROR' "$OUT/$s.log") len=$(/opt/homebrew/bin/ffprobe -v error -select_streams v -show_entries stream=duration -of csv=p=0 "$OUT/$s.avi" 2>/dev/null)"
	grep -E '^SHOW' "$OUT/$s.log" | cut -c1-90
done

echo DONE
