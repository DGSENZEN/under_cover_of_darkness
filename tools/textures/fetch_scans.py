#!/usr/bin/env python3
"""The CC0 photo scans the Eclipse city's atlases are projected from
(Poly Haven, all CC0): each scan's colour and OpenGL normal map at 1K and its
real size, into textures/scans/ (kept out of git: only the baked atlases are
committed). The painter projects them world-aligned into each piece's atlas
and paints its weathering over them (eclipse_atlas.py).

    python3 tools/textures/fetch_scans.py          every scan not yet fetched
"""

import json
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "textures" / "scans"
API = "https://api.polyhaven.com"

# The scans by name; which slot uses which is the slot's recipe ("scan").
SCANS = ["japanese_stone_wall", "sandstone_cracks", "white_rough_plaster", "green_metal_rust", "metal_plate_02",
         "stained_pine", "square_tiles_03", "long_white_tiles", "terrazzo_tiles", "cobblestone_floor_04"]


def _get(url):
    # Poly Haven refuses Python's default agent.
    request = urllib.request.Request(url, headers={"User-Agent": "a-world-of-darkness-alpha texture fetch"})

    with urllib.request.urlopen(request, timeout=60) as r:
        return r.read()


def fetch(name):
    folder = OUT / name

    if (folder / "info.json").exists():
        return False

    folder.mkdir(parents=True, exist_ok=True)
    files = json.loads(_get("%s/files/%s" % (API, name)))
    info = json.loads(_get("%s/info/%s" % (API, name)))
    (folder / "diffuse.jpg").write_bytes(_get(files["Diffuse"]["1k"]["jpg"]["url"]))
    (folder / "normal.jpg").write_bytes(_get(files["nor_gl"]["1k"]["jpg"]["url"]))
    # Real size (mm), and who made it, for CREDITS.md.
    (folder / "info.json").write_text(json.dumps({"name": name, "dimensions_mm": info.get("dimensions"),
                                                  "authors": info.get("authors"), "licence": "CC0",
                                                  "source": "https://polyhaven.com/a/" + name}, indent=1))
    return True


def main(argv):
    for name in argv or SCANS:
        print("fetch_scans:", name, "fetched" if fetch(name) else "already here")


if __name__ == "__main__":
    main(sys.argv[1:])
