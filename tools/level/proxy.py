"""A district's proxy (the old town's spec, section 3A): what the other
districts' maps draw of it far off, in fog. Its pieces' colliders as boxes
in their slots' preview colours, a lit box at each lit window, and its
terrain thinned. Pure Python; export.write_proxy builds it in Blender.

Proxies leave out the shared edge (edges.py: each district draws its own
wall at full detail) and anything too small to read at a distance."""

import edges
import geo
import kit_recipes

# A collider whose largest side is under this (m) is left out; the terrain is
# decimated to this ratio; the whole proxy stays under this many triangles.
PROXY_MIN = 1.5
PROXY_TERRAIN = 0.15
PROXY_TRIS = 150000
# A lit window's box (m: wide, tall, deep).
WINDOW = (0.8, 1.2, 0.1)


def boxes(data):
    """Return list[(geo.Box, slot)]: the colliders of every piece of `data`
    outside the shared edge whose largest side is at least PROXY_MIN, each
    with its recipe's slot."""
    out = []

    for p in data["pieces"]:
        if p["piece"] in edges.SHARED_EDGE:
            continue

        recipe = kit_recipes.PIECES[p["piece"]]

        for box in geo.piece_boxes(recipe, p["position"], p["basis"]):
            if max(box.half) * 2.0 >= PROXY_MIN:
                out.append((box, recipe["slot"]))

    return out


def windows(data):
    """Return list[list[float]]: where the lit windows are (light markers of
    kind window)."""
    return [list(m["position"]) for m in data["markers"] if m["ucd"] == "light" and m.get("props", {}).get("kind") == "window"]
