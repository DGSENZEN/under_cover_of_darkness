"""The user's brush sheets made ready for the painters: five greyscale
painterly masks (blocky flat-brush strokes, spray speckle, chipped patches),
the user's own work, kept out of the public repository (textures/brushes/
is git-ignored). Each is made 1024 square and seamless, alpha kept.

    python3 tools/textures/brushes.py ~/Downloads

Their sources are named Texture_Abstract00.png to 04.png; 01 has a space
before its extension ("Texture_Abstract01 .png").
"""

import re
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
BRUSHES = ROOT / "textures" / "brushes"
SIZE = 1024
# How wide the band is, at each border, that hides the seam where a sheet's ends meet when tiled
# (the user's sheets nearly tile already: their ends differ by a few percent at most).
BAND = 24


def _sources(src_dir):
    """The sheets by their number, whatever stray spaces their names have."""
    found = {}

    for path in Path(src_dir).glob("Texture_Abstract0?*.png"):
        number = re.match(r"Texture_Abstract(\d\d)\s*\.png$", path.name)

        if number:
            found[int(number.group(1))] = path

    return [found[i] for i in sorted(found)]


def _seamless(values, axis):
    """The seam where the sheet's two ends meet hidden by blending each end toward the other
    across a narrow band, halfway at the very edge; the rest of the sheet left as painted."""
    n = values.shape[axis]
    a = np.moveaxis(values, axis, 0).copy()
    source = a.copy()

    for k in range(BAND):
        t = 1.0 - k / BAND
        w = 0.5 * t * t * (3 - 2 * t)
        a[k] = source[k] * (1 - w) + source[n - 1 - k] * w
        a[n - 1 - k] = source[n - 1 - k] * (1 - w) + source[k] * w

    return np.moveaxis(a, 0, axis)


def prepare(src_dir, out_dir=BRUSHES):
    """Each source sheet resized, made seamless and written as brush_NN.png
    (greyscale with alpha). Returns the paths written."""
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    written = []

    for i, path in enumerate(_sources(src_dir)):
        image = Image.open(path).convert("LA").resize((SIZE, SIZE), Image.LANCZOS)
        values = np.asarray(image).astype(np.float32)

        for axis in (0, 1):
            values = _seamless(values, axis)

        out = out_dir / ("brush_%02d.png" % i)
        Image.fromarray(np.clip(values + 0.5, 0, 255).astype(np.uint8), "LA").save(out)
        written.append(out)

    return written


def load(name, folder=BRUSHES):
    """A prepared sheet as float32 values in [0, 1]: its grey times its alpha."""
    path = Path(folder) / (name + ".png")

    if not path.exists():
        raise FileNotFoundError("brush sheet %s missing: run python3 tools/textures/brushes.py ~/Downloads" % path)

    grey, alpha = np.asarray(Image.open(path).convert("LA")).astype(np.float32).transpose(2, 0, 1) / 255.0

    return grey * alpha


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("usage: python3 tools/textures/brushes.py <folder with Texture_Abstract0N.png>")

    for p in prepare(Path(sys.argv[1]).expanduser()):
        print("wrote", p.relative_to(ROOT))
