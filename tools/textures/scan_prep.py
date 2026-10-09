"""A photo scan made ready for painting over (the painterly brief,
docs/superpowers/refs/mexico_city/painterly_texturing.md, step 1): brought
to the painter's density by its real size, the light it was photographed in
taken out (divided by its own blur), then turned to paint by the anisotropic
Kuwahara filter, its normal map filtered with the colour's own weights so
relief and colour keep the same shapes. Prepared once and kept beside the
scan (textures/scans/<name>/prepared.npz) until the settings change.

    prepare(name)   (colour 0-1, normals -1..1 unit, size in metres)
"""

import json
from pathlib import Path

import numpy as np
from PIL import Image

import kuwahara

ROOT = Path(__file__).resolve().parents[2]
SCANS = ROOT / "textures" / "scans"
# The painter draws at four times an atlas of ~50 px/m.
PX_PER_M = 200
RADIUS = 6
ITERATIONS = 2
# The light taken out: shading broader than this (m) is the photograph's
# light (cracks and pores are finer and stay). The brief's 0.5 m is for larger
# photographs: on a seamless 1-2 m tile it would leave everything in.
DELIGHT_M = 0.15


def prepare(name, scans_dir=SCANS, px_per_m=PX_PER_M, radius=RADIUS, iterations=ITERATIONS, delight_m=DELIGHT_M):
    folder = Path(scans_dir) / name
    settings = {"px_per_m": px_per_m, "radius": radius, "iterations": iterations, "delight_m": delight_m}
    cache = folder / "prepared.npz"

    if cache.exists():
        with np.load(cache) as data:
            if json.loads(str(data["settings"])) == settings:
                return data["colour"], data["normal"], data["size"]

    info = json.loads((folder / "info.json").read_text())
    size = np.array(info.get("dimensions_mm") or [1000, 1000], dtype=np.float64)[:2] / 1000.0
    w, h = (max(8, int(round(s * px_per_m))) for s in size)
    colour = np.asarray(Image.open(folder / "diffuse.jpg").convert("RGB").resize((w, h), Image.Resampling.LANCZOS),
                        dtype=np.float64) / 255.0
    normal = np.asarray(Image.open(folder / "normal.jpg").convert("RGB").resize((w, h), Image.Resampling.LANCZOS),
                        dtype=np.float64) / 255.0 * 2 - 1

    # The photograph's light out: each texel over the broad light round it.
    luma = colour @ np.array([0.299, 0.587, 0.114])
    light = np.maximum(kuwahara.gaussian(luma, delight_m * px_per_m), 1e-3)
    colour = np.clip(colour * (luma.mean() / light)[..., None], 0.0, 1.0)

    colour, normal = kuwahara.anisotropic(colour, radius, iterations=iterations, extra=normal)
    normal /= np.maximum(np.linalg.norm(normal, axis=-1, keepdims=True), 1e-6)
    np.savez_compressed(cache, colour=colour, normal=normal, size=size, settings=json.dumps(settings))
    return colour, normal, size
