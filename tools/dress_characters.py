#!/usr/bin/env python3
"""Paints clothes onto the base characters' skin textures.

    python3 tools/dress_characters.py

The Universal Base Characters come in their underwear. A guard needs a
gambeson, a tabard, trousers, boots and gloves; the player's arms need dark
sleeves and leather. Each outfit below is painted straight into a copy of the
body's colour texture, PS2-style: one skinned mesh, one texture, clothes and
all.

The painting is done in 3D, not by guessing at the texture's layout: every
triangle of the body is unwrapped onto the texture, and each texel painted by
where it sits on the body (its height, which way it faces) and which bone
moves it (torso, arm, thigh, foot). Quilting follows the body round; boots
come up to the calf; the tabard hangs front and back. The face and neck keep
their skin, and everything keeps a little of the original shading so cloth
has folds.

Writes assets/characters/outfits/T_<outfit>.png. Needs numpy and Pillow.
"""

import json
import os
import struct

import numpy as np
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
BASE = os.path.join(ROOT, "assets", "characters", "base")
OUT = os.path.join(ROOT, "assets", "characters", "outfits")
SIZE = 512

# Colours are linear-ish 0..1 RGB. None leaves skin.
OUTFITS = {
    # The plain watchman of the stealth levels: tan gambeson, the city's
    # yellow and black on his tabard.
    "watchman": dict(body="male", skin="Dark", tunic=(0.36, 0.29, 0.2), sleeves=True, tabard=(0.62, 0.52, 0.16),
                     stripe=(0.08, 0.08, 0.08), trousers=(0.2, 0.19, 0.18), boots=(0.24, 0.15, 0.09),
                     gloves=(0.2, 0.13, 0.08), belt=(0.2, 0.12, 0.07)),
    # The swordsman: blue-grey gambeson, a red tabard with a white stripe.
    "swordsman": dict(body="male", skin="Ligh", tunic=(0.25, 0.29, 0.37), sleeves=True, tabard=(0.46, 0.08, 0.07),
                      stripe=(0.78, 0.76, 0.7), trousers=(0.15, 0.15, 0.16), boots=(0.2, 0.13, 0.08),
                      gloves=(0.16, 0.11, 0.07), belt=(0.18, 0.11, 0.06)),
    # The duelist: a crimson doublet trimmed in gold, black hose, tall boots.
    "duelist": dict(body="female", skin="Light", tunic=(0.44, 0.07, 0.09), sleeves=True, tabard=None,
                    trim=(0.72, 0.56, 0.22), trousers=(0.08, 0.08, 0.09), boots=(0.1, 0.07, 0.05),
                    boot_top=0.5, gloves=(0.08, 0.07, 0.07), belt=(0.1, 0.07, 0.05), quilt=False),
    # The brute: bare arms, a dark stained jerkin, bracers.
    "brute": dict(body="male", skin="Dark", tunic=(0.17, 0.16, 0.15), sleeves=False, bracers=(0.22, 0.14, 0.08),
                  tabard=(0.26, 0.17, 0.1), stripe=None, trousers=(0.22, 0.16, 0.11), boots=(0.14, 0.1, 0.07),
                  gloves=None, belt=(0.12, 0.08, 0.05)),
    # The archer: forest green, a leather jerkin over it.
    "archer": dict(body="male", skin="Ligh", tunic=(0.18, 0.25, 0.14), sleeves=True, tabard=(0.3, 0.19, 0.1),
                   stripe=None, trousers=(0.2, 0.16, 0.11), boots=(0.22, 0.14, 0.08), gloves=(0.2, 0.13, 0.08),
                   belt=(0.16, 0.1, 0.06)),
    # The arms master: undyed quilted linen and a dark sash.
    "trainer": dict(body="male", skin="Dark", tunic=(0.6, 0.55, 0.45), sleeves=True, tabard=None,
                    trousers=(0.22, 0.2, 0.18), boots=(0.2, 0.13, 0.08), gloves=(0.25, 0.17, 0.1),
                    belt=(0.12, 0.1, 0.12)),
    # You: charcoal sleeves, leather bracers and gloves. Only the arms show.
    "player": dict(body="male", skin="Ligh", tunic=(0.1, 0.1, 0.11), sleeves=True, bracers=(0.16, 0.11, 0.07),
                   tabard=None, trousers=(0.1, 0.1, 0.1), boots=(0.14, 0.1, 0.07), gloves=(0.13, 0.09, 0.06),
                   belt=(0.12, 0.08, 0.05), quilt=False),
}

REGIONS = {
    "head": ["Head", "neck_01"],
    "hand": ["hand_", "index_", "middle_", "pinky_", "ring_", "thumb_"],
    "upper": ["upperarm_", "clavicle_"],
    "lower": ["lowerarm_"],
    "torso": ["spine_01", "spine_02", "spine_03"],
    "pelvis": ["pelvis", "root"],
    "thigh": ["thigh_"],
    "calf": ["calf_"],
    "foot": ["foot_", "ball_"],
}
REGION_IDS = {name: i for i, name in enumerate(REGIONS)}


def region_of(bone):
    for name, prefixes in REGIONS.items():
        for p in prefixes:
            if bone == p or bone.startswith(p):
                return REGION_IDS[name]
    return REGION_IDS["torso"]


def read_gltf(path):
    j = json.load(open(path))
    buffers = [open(os.path.join(os.path.dirname(path), b["uri"]), "rb").read() for b in j["buffers"]]

    def accessor(i):
        a = j["accessors"][i]
        v = j["bufferViews"][a["bufferView"]]
        data = buffers[v["buffer"]]
        comps = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[a["type"]]
        dtype = {5126: np.float32, 5123: np.uint16, 5121: np.uint8, 5125: np.uint32}[a["componentType"]]
        start = v.get("byteOffset", 0) + a.get("byteOffset", 0)
        stride = v.get("byteStride", 0)
        item = np.dtype(dtype).itemsize * comps
        if stride and stride != item:
            raw = np.frombuffer(data, dtype=np.uint8, count=stride * a["count"], offset=start).reshape(a["count"], stride)
            return raw[:, :item].copy().view(dtype).reshape(a["count"], comps)
        return np.frombuffer(data, dtype=dtype, count=a["count"] * comps, offset=start).reshape(a["count"], comps)

    body = max(j["meshes"], key=lambda m: j["accessors"][m["primitives"][0]["attributes"]["POSITION"]]["count"])
    prim = body["primitives"][0]
    joint_names = [j["nodes"][n]["name"] for n in j["skins"][0]["joints"]]
    pos = accessor(prim["attributes"]["POSITION"]).astype(np.float64)
    uv = accessor(prim["attributes"]["TEXCOORD_0"]).astype(np.float64)
    joints = accessor(prim["attributes"]["JOINTS_0"]).astype(np.int64)
    weights = accessor(prim["attributes"]["WEIGHTS_0"]).astype(np.float64)
    tris = accessor(prim["indices"]).astype(np.int64).reshape(-1, 3)
    dominant = joints[np.arange(len(joints)), np.argmax(weights, axis=1)]
    regions = np.array([region_of(joint_names[d]) for d in dominant])
    return pos, uv, regions, tris


def rasterise(pos, uv, regions, tris):
    """Per texel: the body position under it and its region (-1: nothing)."""
    where = np.zeros((SIZE, SIZE, 3))
    region = -np.ones((SIZE, SIZE), dtype=np.int64)
    px = uv * SIZE - 0.5
    for a, b, c in tris:
        pa, pb, pc = px[a], px[b], px[c]
        x0, x1 = int(np.floor(min(pa[0], pb[0], pc[0]))), int(np.ceil(max(pa[0], pb[0], pc[0])))
        y0, y1 = int(np.floor(min(pa[1], pb[1], pc[1]))), int(np.ceil(max(pa[1], pb[1], pc[1])))
        x0, y0 = max(x0, 0), max(y0, 0)
        x1, y1 = min(x1, SIZE - 1), min(y1, SIZE - 1)
        if x1 < x0 or y1 < y0:
            continue
        gx, gy = np.meshgrid(np.arange(x0, x1 + 1), np.arange(y0, y1 + 1))
        d = (pb[1] - pc[1]) * (pa[0] - pc[0]) + (pc[0] - pb[0]) * (pa[1] - pc[1])
        if abs(d) < 1e-12:
            continue
        w0 = ((pb[1] - pc[1]) * (gx - pc[0]) + (pc[0] - pb[0]) * (gy - pc[1])) / d
        w1 = ((pc[1] - pa[1]) * (gx - pc[0]) + (pa[0] - pc[0]) * (gy - pc[1])) / d
        w2 = 1.0 - w0 - w1
        # A little outside, so the seams between islands are painted too.
        inside = (w0 >= -0.02) & (w1 >= -0.02) & (w2 >= -0.02)
        if not inside.any():
            continue
        ys, xs = gy[inside], gx[inside]
        p = (w0[inside, None] * pos[a] + w1[inside, None] * pos[b] + w2[inside, None] * pos[c])
        where[ys, xs] = p
        nearest = np.argmax(np.stack([w0[inside], w1[inside], w2[inside]]), axis=0)
        region[ys, xs] = np.array([regions[a], regions[b], regions[c]])[nearest]
    return where, region


def paint(outfit, where, region, skin):
    rng = np.random.default_rng(3)
    img = skin.copy()
    lum = skin.mean(axis=2)
    shade = 0.8 + 0.5 * (lum - np.median(lum[region >= 0])) if (region >= 0).any() else np.ones_like(lum)
    shade = np.clip(shade, 0.55, 1.25)
    noise = 1.0 + rng.normal(0, 0.025, lum.shape)
    x, y, z = where[:, :, 0], where[:, :, 1], where[:, :, 2]
    R = REGION_IDS

    def put(mask, colour):
        if colour is None:
            return
        c = np.array(colour)
        img[mask] = c[None, :] * (shade[mask] * noise[mask])[:, None]

    def darken(mask, amount):
        img[mask] *= (1.0 - amount)

    quilt = outfit.get("quilt", True)
    # the tunic over the torso and pelvis (down to mid thigh), stitched in a grid
    body = (region == R["torso"]) | (region == R["pelvis"]) | ((region == R["thigh"]) & (y > 0.7))
    put(body, outfit["tunic"])
    if quilt:
        around = np.arctan2(x, z + 0.02) * 0.16
        stitch = (((around / 0.045) % 1.0) < 0.12) | (((y / 0.07) % 1.0) < 0.1)
        darken(body & stitch, 0.28)
    if outfit.get("trim") is not None:
        hem = body & (np.abs(y - 0.72) < 0.02)
        put(hem, outfit["trim"])
        placket = body & (np.abs(x) < 0.012) & (z > 0) & (y > 0.9)
        put(placket, outfit["trim"])
    # sleeves, or bare arms
    arms = (region == R["upper"]) | (region == R["lower"])
    if outfit.get("sleeves", True):
        put(arms, outfit["tunic"])
        if quilt:
            darken(arms & (((np.abs(x) / 0.05) % 1.0) < 0.14), 0.26)
        cuff = (region == R["lower"]) & (np.abs(x) > 0.62)
        darken(cuff, 0.15)
    if outfit.get("bracers") is not None:
        bracer = (region == R["lower"]) & (np.abs(x) > 0.5)
        put(bracer, outfit["bracers"])
        darken(bracer & (((np.abs(x) / 0.03) % 1.0) < 0.15), 0.3)
    # gloves
    put(region == R["hand"], outfit.get("gloves"))
    # trousers, then boots up to the calf, a darker sole
    legs = ((region == R["thigh"]) & (y <= 0.7)) | (region == R["calf"])
    put(legs, outfit["trousers"])
    boot_top = outfit.get("boot_top", 0.4)
    boots = (region == R["foot"]) | ((region == R["calf"]) & (y < boot_top))
    put(boots, outfit["boots"])
    put(boots & (np.abs(y - boot_top) < 0.018), tuple(np.array(outfit["boots"]) * 1.35))
    darken(boots & (y < 0.03), 0.45)
    # the tabard, front and back, with its stripe
    if outfit.get("tabard") is not None:
        panel = (body | legs) & (np.abs(x) < 0.16) & (y > 0.6) & (y < 1.42) & (np.abs(z) > 0.02)
        put(panel, outfit["tabard"])
        edge = panel & ((np.abs(np.abs(x) - 0.16) < 0.012) | (np.abs(y - 0.6) < 0.012))
        darken(edge, 0.3)
        if outfit.get("stripe") is not None:
            put(panel & (np.abs(x) < 0.035), outfit["stripe"])
    # the belt and its buckle
    belt = body & (np.abs(y - 0.995) < 0.03)
    put(belt, outfit["belt"])
    put(belt & (np.abs(x) < 0.028) & (z > 0), (0.7, 0.55, 0.25))
    return np.clip(img, 0, 1)


def main():
    os.makedirs(OUT, exist_ok=True)
    cache = {}

    for name, outfit in OUTFITS.items():
        kind = outfit["body"]
        if kind not in cache:
            gltf = os.path.join(BASE, "Superhero_%s_FullBody.gltf" % ("Male" if kind == "male" else "Female"))
            pos, uv, regions, tris = read_gltf(gltf)
            cache[kind] = rasterise(pos, uv, regions, tris)
        where, region = cache[kind]
        skin_file = {
            ("male", "Dark"): "T_Superhero_Male_Dark.png", ("male", "Ligh"): "T_Superhero_Male_Ligh.png",
            ("female", "Light"): "T_Superhero_Female_Light_BaseColor.png", ("female", "Dark"): "T_Superhero_Female_Dark_BaseColor.png",
        }[(kind, outfit["skin"])]
        skin = np.asarray(Image.open(os.path.join(BASE, skin_file)).convert("RGB").resize((SIZE, SIZE)), dtype=np.float64) / 255.0
        img = paint(outfit, where, region, skin)
        Image.fromarray((img * 255).astype(np.uint8)).save(os.path.join(OUT, "T_%s.png" % name))
        print("painted", name)


if __name__ == "__main__":
    main()
