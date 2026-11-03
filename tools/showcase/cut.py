#!/usr/bin/env python3
"""Cuts the recorded showcase shots into one film: each shot's load trimmed off, a short fade between.
usage: cut.py <shots dir> <out.mp4> [the list in diag_showcase_video.gd, SHOTS if none]"""
import json
import re
import subprocess
import sys

FFMPEG = "/opt/homebrew/bin/ffmpeg"
FFPROBE = "/opt/homebrew/bin/ffprobe"
## The gym's load and the walk to the mark, on the front of every shot but the first (s).
LOAD = 1.05
FADE = 0.2
## Shots to show closer: the readout, bottom right, so what is chosen can be seen.
CLOSE = {"choose": "crop=720:405:1200:675,scale=1920:1080:flags=neighbor,setsar=1"}

shots_dir, out = sys.argv[1:3]
which = sys.argv[3] if len(sys.argv) > 3 else "SHOTS"
source = open("tests/diag_showcase_video.gd").read()
shots = re.findall(r'"(\w+)"', re.search(rf"^const {which} := \[(.*)\]", source, re.M).group(1))
inputs, parts, labels = [], [], ""

for n, shot in enumerate(shots):
    path = f"{shots_dir}/{shot}.avi"
    length = float(json.loads(subprocess.check_output([FFPROBE, "-v", "error", "-select_streams", "v", "-show_entries", "stream=duration", "-of", "json", path]))["streams"][0]["duration"])
    start = 0.0 if n == 0 and which == "SHOTS" else LOAD
    span = length - start
    inputs += ["-i", path]
    close = CLOSE.get(shot, "")
    close = close + "," if close else ""
    parts.append(f"[{n}:v]trim={start}:{length},setpts=PTS-STARTPTS,{close}fade=t=in:d={FADE},fade=t=out:st={span - FADE:.3f}:d={FADE}[v{n}]")
    parts.append(f"[{n}:a]atrim={start}:{length},asetpts=PTS-STARTPTS,afade=t=in:d={FADE},afade=t=out:st={span - FADE:.3f}:d={FADE}[a{n}]")
    labels += f"[v{n}][a{n}]"

parts.append(f"{labels}concat=n={len(shots)}:v=1:a=1[v][a]")
subprocess.check_call([FFMPEG, "-v", "error", "-y"] + inputs + ["-filter_complex", ";".join(parts), "-map", "[v]", "-map", "[a]", "-c:v", "libx264", "-crf", "19", "-preset", "medium", "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", out])
