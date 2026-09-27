#!/usr/bin/env bash
# Records one whole night of the NPC showcase with Godot's Movie Maker, as
# the Cinema editor films it, and makes an .mp4 of it with ffmpeg.
#   tools/record_showcase.sh <out_dir> [ending] [resolution]
# ending: escape (default), overwhelmed, victor. resolution: 1280x720 by
# default: the retro filter draws the picture on a 640x360 grid, so a larger
# frame shows nothing more, and the Movie Maker's .avi is large (about 3 GB
# at 1280x720 for a night); it is removed once the .mp4 is made.
set -euo pipefail

out="${1:?usage: tools/record_showcase.sh <out_dir> [ending] [resolution]}"
ending="${2:-escape}"
resolution="${3:-1280x720}"
godot="${GODOT:-/Users/tinkertailorr/Desktop/Godot.app/Contents/MacOS/Godot}"
here="$(cd "$(dirname "$0")/.." && pwd)"

mkdir -p "$out"
free_kb=$(df -Pk "$out" | awk 'NR==2 {print $4}')

if [ "$free_kb" -lt $((4 * 1024 * 1024)) ]; then
	echo "record_showcase: less than 4 GB free on $out ($((free_kb / 1024)) MB); not recording" >&2
	exit 1
fi

avi="$out/showcase_${ending}.avi"
mp4="$out/showcase_${ending}.mp4"

"$godot" --path "$here" --write-movie "$avi" --fixed-fps 60 --resolution "$resolution" \
	res://maps/npc_showcase.tscn -- --auto --ending="$ending" --quit-at-end

ffmpeg -y -loglevel error -i "$avi" -c:v libx264 -crf 20 -preset medium -pix_fmt yuv420p -c:a aac -b:a 160k "$mp4"
rm -f "$avi"
echo "record_showcase: $mp4"
