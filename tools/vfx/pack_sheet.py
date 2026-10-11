"""Frames rendered by sim_render.py packed into sheets (the effects plan,
Task 2): six-way smoke into two sheets, A (lit from the right, top and back
in r, g, b, coverage in a) and B (from the left, bottom and front), each
frame following its billow; fire into one, its emission's colour and
coverage. Each with <name>.json: its grid,
frame count and frame size.

    python3 tools/vfx/pack_sheet.py plume|puff|fire <frames dir>
"""

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

VFX = Path(__file__).resolve().parents[2] / "assets" / "vfx"
GRIDS = {"plume": (8, 4), "puff": (4, 4), "fire": (4, 4)}
A, B = ("right", "top", "back"), ("left", "bottom", "front")


def _load(path):
    return np.asarray(Image.open(path).convert("RGBA"), dtype=np.float64) / 255.0


def _lum(rgba):
    return rgba[:, :, 0] * 0.3 + rgba[:, :, 1] * 0.59 + rgba[:, :, 2] * 0.11


def pack(frames, grid):
    """Frames (h x w x 4 arrays) laid left to right, top to bottom."""
    h, v = grid
    px = frames[0].shape[0]
    sheet = np.zeros((v * px, h * px, 4))

    for k, f in enumerate(frames):
        j, i = divmod(k, h)
        sheet[j * px:(j + 1) * px, i * px:(i + 1) * px] = f

    return sheet


def pack_six_way(kind, src):
    """Sheets A and B from a kind's six lights a frame; each light's
    brightness normalised over the whole sequence."""
    src = Path(src)
    count = len(sorted(src.glob("%s_*_right.png" % kind)))
    renders = {light: [_load(src / ("%s_%02d_%s.png" % (kind, n, light))) for n in range(count)] for light in A + B}
    # Each frame cut round its own smoke, one cut for all six lights (their
    # coverage is the same smoke).
    cuts = follow([np.max([renders[light][n][:, :, 3] for light in A + B], axis=0) for n in range(count)])
    renders = {light: [_cut(f, box) for f, box in zip(renders[light], cuts)] for light in A + B}
    peak = max(_lum(r).max() for frames in renders.values() for r in frames) or 1.0
    sheets = []

    for lights in (A, B):
        frames = []

        for n in range(count):
            f = np.zeros(renders["right"][n].shape)

            for c, light in enumerate(lights):
                f[:, :, c] = np.clip(_lum(renders[light][n]) / peak, 0, 1)

            f[:, :, 3] = np.max([renders[light][n][:, :, 3] for light in A + B], axis=0)
            frames.append(f)

        sheets.append(pack(frames, GRIDS[kind]))

    return sheets, count, renders["right"][0].shape[0]


def pack_fire(src):
    """Fire glows without absorbing (its alpha is near nothing): its coverage
    is its glow."""
    src = Path(src)
    frames = []

    for p in sorted(src.glob("fire_*_emission.png")):
        # (A thin glowing volume renders speckled, each pixel's samples few:
        # a median filter takes the speckle and keeps the tongues' edges.)
        image = Image.open(p).convert("RGBA").filter(ImageFilter.MedianFilter(5))
        f = np.asarray(image, dtype=np.float64) / 255.0
        f[:, :, 3] = np.clip(np.maximum(f[:, :, 3], _lum(f) * 1.6), 0, 1)
        frames.append(f)

    frames = crop(frames)
    # Brightened together till their brightest channel is near full: hot
    # gold at the core, never bleached to white (each channel scaled alike).
    peak = np.percentile(np.concatenate([f[:, :, :3].max(axis=2)[f[:, :, 3] > 0.05] for f in frames]), 99.5)

    for f in frames:
        f[:, :, :3] = np.clip(f[:, :, :3] / max(peak, 1e-3), 0, 1)
        f[:, :, 3] = np.clip(np.maximum(f[:, :, 3], _lum(f) * 1.6), 0, 1)

    return pack(frames, GRIDS["fire"]), len(frames), frames[0].shape[0]


def crop(frames, margin=3):
    """Every frame cut to the square round all of them that holds anything
    (their union's bounding box, `margin` px round it), resized back: the
    smoke fills its frames, never a speck in an empty square."""
    from PIL import Image as _Image
    px = frames[0].shape[0]
    union = np.max([f[:, :, 3] for f in frames], axis=0) > 0.02
    ys, xs = np.nonzero(union)

    if len(xs) == 0:
        return frames

    cx, cy = (xs.min() + xs.max()) / 2, (ys.min() + ys.max()) / 2
    half = max(xs.max() - xs.min(), ys.max() - ys.min()) / 2 + margin
    x0, y0 = int(max(0, cx - half)), int(max(0, cy - half))
    x1, y1 = int(min(px, cx + half + 1)), int(min(px, cy + half + 1))
    out = []

    for f in frames:
        cut = _Image.fromarray((np.clip(f[y0:y1, x0:x1], 0, 1) * 255).astype(np.uint8), "RGBA")
        out.append(np.asarray(cut.resize((px, px), _Image.Resampling.LANCZOS), dtype=np.float64) / 255.0)

    return out


def follow(alphas, margin=3, smooth=5):
    """Square boxes (x0, y0, size) following a billow frame to frame: each
    round its frame's smoke, their sizes smoothed (a moving mean over
    `smooth` frames, never smaller than the smoke) so the billow fills every
    frame without the frames jumping in scale. The particle carries its
    growth; the frames carry its shape."""
    boxes = []

    for a in alphas:
        ys, xs = np.nonzero(a > 0.02)

        if len(xs) == 0:
            boxes.append((a.shape[1] / 2, a.shape[0] / 2, 1.0))
            continue

        boxes.append(((xs.min() + xs.max()) / 2, (ys.min() + ys.max()) / 2,
                      max(xs.max() - xs.min(), ys.max() - ys.min()) + 2 * margin))

    sizes = np.array([b[2] for b in boxes])
    half = smooth // 2
    smoothed = [max(sizes[max(0, n - half):n + half + 1].mean(), sizes[n]) for n in range(len(sizes))]
    return [(cx - s / 2, cy - s / 2, s) for (cx, cy, _), s in zip(boxes, smoothed)]


def _cut(frame, box):
    """`frame` cut to `box` (x0, y0, size; out past its edges is empty),
    resized back to the frame's size."""
    px = frame.shape[0]
    x0, y0, size = box
    image = Image.fromarray((np.clip(frame, 0, 1) * 255).astype(np.uint8), "RGBA")
    cut = image.transform((px, px), Image.Transform.EXTENT, (x0, y0, x0 + size, y0 + size), Image.Resampling.BICUBIC)
    return np.asarray(cut, dtype=np.float64) / 255.0


def _save(array, name):
    Image.fromarray((np.clip(array, 0, 1) * 255).astype(np.uint8), "RGBA").save(VFX / (name + ".png"))


def main(kind, src):
    if kind == "fire":
        sheet, count, px = pack_fire(src)
        _save(sheet, "fire")
    else:
        (a, b), count, px = pack_six_way(kind, src)
        _save(a, kind + "_a")
        _save(b, kind + "_b")

    (VFX / (kind + ".json")).write_text(json.dumps({"grid": list(GRIDS[kind]), "frames": count, "px": px}))
    print("pack_sheet: %s, %d frames of %d px" % (kind, count, px))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
