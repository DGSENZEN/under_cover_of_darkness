"""Frames (frame_000.png ...) made into a looping GIF at 10 frames a second.

    python3 tools/eclipse/clip.py /tmp/trees_clip out.gif [width]
"""

import sys
from pathlib import Path

from PIL import Image


def main(folder, out, width=720):
    frames = [Image.open(p).convert("RGB") for p in sorted(Path(folder).glob("frame_*.png"))]
    height = round(frames[0].height * width / frames[0].width)
    frames = [f.resize((width, height), Image.Resampling.LANCZOS).quantize(colors=200) for f in frames]
    frames[0].save(out, save_all=True, append_images=frames[1:], duration=100, loop=0)
    print("clip: %d frames -> %s" % (len(frames), out))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], int(sys.argv[3]) if len(sys.argv) > 3 else 720)
