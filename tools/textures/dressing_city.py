"""The city's own clothes for the shades (tools/textures/silhouettes.py), beyond the lane's (dressing.py): the
1920s capital's modern people and its street trades (docs/superpowers/refs/mexico_city/bible.md, "Street trades
double as gameplay roles"; the pelona, the clerk, the Light Company's linemen, the gendarme, the newsboy, the water
carrier, the porter, the organ grinder, the sereno), and what the Pasaje's stallkeepers wear and hold. Like
dressing.py's, each is built round a posed body's bones, only its outline counting; what is worn on the head sits in
the head's own frame (however it is bowed or turned).
"""

import math

from mathutils import Vector

import dressing
from dressing import _loft, _ring, _rod

# A child's body: the man's, at this scale (a newsboy of twelve or so).
CHILD = 0.78


def _head(bones):
    """The skull's top and the head's own axes: (top, side, face, up)."""
    up, face = dressing.head_frame()
    return dressing.skull_top(bones), face.cross(up), face, up


def _round(frame, du, df, rs, rf, n=24):
    """A ring round the head `du` down its up (negative) and `df` toward its face from the skull's top, `rs` wide
    across and `rf` front to back."""
    top, side, face, up = frame
    centre = top + up * du + face * df
    return [centre + side * rs * math.cos(2 * math.pi * k / n) + face * rf * math.sin(2 * math.pi * k / n)
            for k in range(n)]


def _slab(name, centre, across, along, up, w, d, h):
    """A box round `centre`, `w` across, `d` along, `h` up its own axes."""
    def face(z):
        return [centre + up * z + across * x + along * y
                for x, y in ((-w / 2, -d / 2), (w / 2, -d / 2), (w / 2, d / 2), (-w / 2, d / 2))]

    return _loft(name, [face(-h / 2), face(h / 2)])


# --- on the head ---------------------------------------------------------------------------------------------

def bob(bones):
    """Hair bobbed short at the jaw, the face open: the pelona's."""
    f = _head(bones)
    _loft("bob", [_round(f, 0.006, -0.01, 0.03, 0.03), _round(f, -0.03, -0.008, 0.088, 0.1),
                  _round(f, -0.08, -0.012, 0.102, 0.108), _round(f, -0.13, -0.03, 0.104, 0.085),
                  _round(f, -0.175, -0.04, 0.098, 0.06)])


def bun(bones):
    """Hair drawn back into a knot at the nape."""
    f = _head(bones)
    _loft("hair", [_round(f, 0.004, -0.01, 0.03, 0.03), _round(f, -0.04, -0.012, 0.09, 0.1),
                   _round(f, -0.09, -0.03, 0.095, 0.085)])
    _loft("bun", [_round(f, -0.07, -0.13, 0.03, 0.03), _round(f, -0.1, -0.15, 0.05, 0.045),
                  _round(f, -0.13, -0.13, 0.03, 0.03)])


def cloche(bones):
    """A cloche pulled down close over the brows, its narrow brim flaring a little at the nape."""
    f = _head(bones)
    _loft("cloche", [_round(f, 0.014, -0.008, 0.03, 0.03), _round(f, -0.02, -0.006, 0.094, 0.104),
                     _round(f, -0.06, -0.006, 0.104, 0.114), _round(f, -0.098, -0.012, 0.112, 0.122),
                     _round(f, -0.108, -0.014, 0.124, 0.136)])


def _peak(name, f, du, reach):
    """A cap's peak out over the brow."""
    top, side, face, up = f
    _loft(name, [_round(f, du - 0.004, 0.085, 0.07, reach), _round(f, du + 0.004, 0.08, 0.068, reach * 0.9)])


def flat_cap(bones):
    """A flat cap: its crown pulled forward over its peak."""
    f = _head(bones)
    _loft("cap", [_round(f, -0.05, -0.004, 0.094, 0.104), _round(f, -0.012, 0.004, 0.102, 0.114),
                  _round(f, 0.014, 0.022, 0.1, 0.124), _round(f, 0.026, 0.03, 0.07, 0.09)])
    _peak("cap_peak", f, -0.048, 0.05)


def kepi(bones):
    """The gendarme's kepi: stiff, its flat top leaning back, its peak down over the eyes."""
    f = _head(bones)
    _loft("kepi", [_round(f, -0.055, 0.0, 0.094, 0.104), _round(f, 0.03, -0.014, 0.088, 0.096),
                   _round(f, 0.045, -0.018, 0.086, 0.094), _round(f, 0.047, -0.018, 0.03, 0.03)])
    _peak("kepi_peak", f, -0.058, 0.045)


def bowler(bones):
    """A bowler: its crown a dome, its narrow brim rolled up at the sides."""
    dressing.hat(bones, 0.0, brim=0.13, tip_deg=3.0, crown_size=(0.088, 0.085), seat=True, lift=(0.012, 0.022, 0.03))


def hood(bones):
    """The sereno's hood up over his head, its peak behind."""
    f = _head(bones)
    _loft("hood", [_round(f, 0.03, -0.1, 0.02, 0.02), _round(f, 0.02, -0.05, 0.08, 0.1),
                   _round(f, -0.02, -0.03, 0.115, 0.13), _round(f, -0.09, -0.035, 0.125, 0.135),
                   _round(f, -0.17, -0.05, 0.13, 0.13)])


# --- on the body ---------------------------------------------------------------------------------------------

def _knee(bones):
    return min(bones["calf_l"][0].z, bones["calf_r"][0].z)


def dress(bones):
    """A drop-waisted dress to just below the knee."""
    dressing.coat(bones, hem=_knee(bones) - 0.06, off=(0.05, 0.06), flare=(0.03, 0.04), wide=(0.17, 0.21),
                  name="dress", collar=False)


def narrow_skirt(bones):
    """A long skirt hanging straighter, for a woman standing at her work."""
    dressing.skirt(bones, flare=(0.04, 0.05), wide=(0.18, 0.23))


def vest(bones):
    """A waistcoat over the shirt, to the hip."""
    dressing.coat(bones, hem=bones["pelvis"][0].z - 0.06, off=(0.04, 0.05), flare=(0.0, 0.0), wide=(0.19, 0.2),
                  name="vest", collar=False)


def shirt_sleeves(bones):
    """Shirt sleeves rolled to the forearm."""
    for side in ("l", "r"):
        shoulder, elbow = bones["upperarm_" + side]
        wrist = bones["lowerarm_" + side][1]
        up, low = elbow - shoulder, wrist - elbow
        _loft("shirt_" + side, [_ring(shoulder, 0.07, 0.07, 12, up), _ring(elbow, 0.064, 0.064, 12, up),
                                _ring(elbow, 0.064, 0.064, 12, low), _ring(elbow + low * 0.4, 0.06, 0.06, 12, low)])


def shawl(bones):
    """A shawl round the shoulders, its ends hanging down the front."""
    neck = bones["neck_01"][0]
    top = bones["spine_03"][1]
    mid = bones["spine_02"][1]
    _loft("shawl", [_ring(Vector((neck.x, neck.y + 0.03, neck.z)), 0.14, 0.12, 24),
                    _ring(Vector((top.x, top.y + 0.02, top.z + 0.01)), 0.26, 0.16, 24),
                    _ring(Vector((mid.x, mid.y + 0.01, mid.z)), 0.25, 0.165, 24),
                    _ring(Vector((mid.x, mid.y - 0.02, mid.z - 0.12)), 0.2, 0.15, 24)])


def capelet(bones):
    """A short cape over the shoulders, to the elbows: the sereno's, over his greatcoat."""
    neck = bones["neck_01"][0]
    top = bones["spine_03"][1]
    mid = bones["spine_02"][1]
    _loft("capelet", [_ring(Vector((neck.x, neck.y + 0.03, neck.z + 0.02)), 0.14, 0.13, 24),
                      _ring(Vector((top.x, top.y + 0.02, top.z + 0.02)), 0.3, 0.19, 24),
                      _ring(Vector((mid.x, mid.y + 0.02, mid.z - 0.04)), 0.33, 0.21, 24)])


def greatcoat(bones):
    """A long greatcoat to the shins."""
    dressing.coat(bones, hem=0.3, off=(0.1, 0.12), flare=(0.04, 0.1), wide=(0.21, 0.27), name="greatcoat")


def apron(bones):
    """A long apron tied at the waist, hanging from the belly over the forward knee to below it."""
    pelvis = bones["pelvis"][0]
    knee = min(bones["thigh_l"][1].y, bones["thigh_r"][1].y)
    top = Vector((pelvis.x, pelvis.y - 0.12, pelvis.z + 0.08))
    low = Vector((pelvis.x, knee - 0.065, _knee(bones) - 0.12))

    def edge(at, d):
        return [at + Vector((x, y, 0)) for x, y in ((-0.17, -d), (0.17, -d), (0.17, 0.0), (-0.17, 0.0))]

    _loft("apron", [edge(top, 0.04), edge(low, 0.035)])


def overalls(bones):
    """A lineman's overalls: loose legs and a bib up the chest."""
    dressing.trousers(bones, size=(0.105, 0.085, 0.08))
    pelvis = bones["pelvis"][0]
    chest = bones["spine_02"][1]
    _slab("bib", Vector((pelvis.x, chest.y - 0.11, (pelvis.z + chest.z) / 2 + 0.05)), Vector((1, 0, 0)),
          Vector((0, 1, 0)), Vector((0, 0, 1)), 0.26, 0.04, chest.z - pelvis.z + 0.1)


def belt(bones):
    """A belt round the tunic's waist."""
    pelvis = bones["pelvis"][0]
    _loft("belt", [_ring(Vector((pelvis.x, pelvis.y + 0.01, pelvis.z + 0.06)), 0.205, 0.145, 24),
                   _ring(Vector((pelvis.x, pelvis.y + 0.01, pelvis.z + 0.11)), 0.205, 0.145, 24)])


# --- carried -------------------------------------------------------------------------------------------------

def _other(bones):
    return "r" if dressing._reaching(bones) == "l" else "l"


def umbrella(bones):
    """A furled umbrella swung as a cane from the reaching hand, its crook in the fist, its ferrule ahead on the
    floor."""
    side = dressing._reaching(bones)
    at, _ = dressing._grip(bones, side)
    foot = Vector((at.x, at.y - 0.25, 0.0))
    way = (foot - at).normalized()
    _rod("umbrella", at, foot, 0.01)
    _loft("umbrella_furl", [_ring(at + way * (at - foot).length * f, r, r, 12, way)
                            for f, r in ((0.12, 0.012), (0.25, 0.036), (0.55, 0.04), (0.82, 0.016))])
    hook = [at + Vector((0, -0.04 * math.sin(a), 0.04 - 0.04 * math.cos(a))) * 1.0 for a in
            [math.pi * k / 6 for k in range(7)]]
    for a, b in zip(hook, hook[1:]):
        _rod("umbrella_crook", a + Vector((0, 0, 0.03)), b + Vector((0, 0, 0.03)), 0.009, 6)


def cable_coil(bones):
    """A coil of the Light Company's cable hung over the shoulder, hanging at the side: a hoop seen from the side."""
    side = _other(bones)
    shoulder = bones["upperarm_" + side][0]
    out = 1 if shoulder.x > bones["pelvis"][0].x else -1
    centre = Vector((shoulder.x + out * 0.2, shoulder.y + 0.02, shoulder.z - 0.22))
    hoop = [centre + Vector((0, 0.2 * math.sin(a), 0.24 * math.cos(a))) for a in [2 * math.pi * k / 24 for k in range(25)]]
    for a, b in zip(hoop, hoop[1:]):
        _rod("cable", a, b, 0.022, 8)


def baton(bones):
    """A gendarme's baton hung at the hip."""
    pelvis = bones["pelvis"][0]
    hip = Vector((pelvis.x + 0.2, pelvis.y + 0.02, pelvis.z + 0.05))
    _rod("baton", hip, hip + Vector((0.01, -0.12, -0.42)), 0.018)


def papers(bones):
    """A bundle of newspapers under the arm, one held up in the reaching hand, out ahead of his face."""
    side = dressing._reaching(bones)
    at, way = dressing._grip(bones, side)
    # (Stood up out of the fist, leaning out ahead, flat to the side: thin across.)
    lean = 0.25
    rise = Vector((0, -math.sin(lean), math.cos(lean)))
    _slab("paper", at + rise * 0.12, Vector((1, 0, 0)), Vector((0, math.cos(lean), math.sin(lean))), rise,
          0.012, 0.2, 0.26)
    other = _other(bones)
    elbow = bones["lowerarm_" + other][0]
    _slab("papers", Vector((elbow.x, elbow.y, elbow.z + 0.02)), Vector((1, 0, 0)), Vector((0, 1, 0)),
          Vector((0, 0, 1)), 0.1, 0.36, 0.12)


def _tumpline(bones, load_top):
    """A tumpline: the strap from a load on the back over the forehead."""
    top, side, face, up = _head(bones)
    brow = top + up * -0.05 + face * 0.07
    _rod("tumpline", load_top, brow, 0.012, 6)
    _loft("tumpline_band", _round_list(_head(bones), -0.05))


def _round_list(f, du):
    return [_round(f, du - 0.008, 0.0, 0.1, 0.11), _round(f, du + 0.008, 0.0, 0.1, 0.11)]


def chochocol(bones):
    """The water carrier's great jar on his back, held by its strap over his forehead; a small jar hung before him."""
    back = bones["spine_02"][1]
    pelvis = bones["pelvis"][0]
    centre = Vector((back.x, back.y + 0.27, (back.z + pelvis.z) / 2 + 0.02))
    _loft("chochocol", [_ring(centre + Vector((0, 0, z)), r, r, 24) for z, r in
                        ((-0.3, 0.06), (-0.22, 0.17), (-0.05, 0.23), (0.12, 0.21), (0.24, 0.12), (0.3, 0.07),
                         (0.34, 0.08))])
    _tumpline(bones, centre + Vector((0, -0.08, 0.3)))
    hips = Vector((pelvis.x, pelvis.y - 0.22, pelvis.z - 0.12))
    _loft("cantaro", [_ring(hips + Vector((0, 0, z)), r, r, 20) for z, r in
                      ((-0.14, 0.05), (-0.08, 0.11), (0.04, 0.11), (0.1, 0.05), (0.13, 0.055))])
    _rod("cantaro_strap", hips + Vector((0, 0.03, 0.13)), bones["neck_01"][0] + Vector((0, -0.05, 0.0)), 0.008, 6)


def load(bones):
    """The porter's load lashed high on his back, held by the tumpline over his forehead: a crate, a smaller crate on
    it, a sack tied on top, one bundle."""
    back = bones["spine_02"][1]
    pelvis = bones["pelvis"][0]
    up = (back - pelvis).normalized()
    base = pelvis + Vector((0, 0.27, 0)) + up * 0.02
    _loft("load", [_ring(base + up * z, rx, ry, 16, up) for z, rx, ry in
                   ((0.0, 0.23, 0.2), (0.36, 0.24, 0.21), (0.4, 0.2, 0.16), (0.64, 0.2, 0.16), (0.68, 0.15, 0.12),
                    (0.78, 0.16, 0.13), (0.86, 0.06, 0.05))])
    _tumpline(bones, base + up * 0.5 - Vector((0, 0.15, 0)))


def organ(bones):
    """A barrel organ hung before the organ grinder on its strap, its foot on its single pole, its crank at its
    side under his reaching hand."""
    pelvis = bones["pelvis"][0]
    side = dressing._reaching(bones)
    at, _ = dressing._grip(bones, side)
    box = Vector((pelvis.x, pelvis.y - 0.3, pelvis.z + 0.02))
    _slab("organ", box, Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)), 0.44, 0.28, 0.4)
    _slab("organ_lid", box + Vector((0, 0, 0.22)), Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)), 0.46, 0.3, 0.04)
    _rod("organ_pole", box + Vector((0, 0, -0.2)), Vector((box.x, box.y, 0.0)), 0.016)
    _rod("organ_crank", Vector((box.x, box.y + 0.1, box.z + 0.05)), at, 0.012, 6)
    _rod("organ_strap", box + Vector((0, 0.1, 0.2)), bones["neck_01"][0] + Vector((0, 0.02, 0.0)), 0.01, 6)


def lantern(bones):
    """The sereno's lantern hung from his reaching hand."""
    side = dressing._reaching(bones)
    at, _ = dressing._grip(bones, side)
    hang = at + Vector((0, 0, -0.1))
    _rod("lantern_bail", at, hang, 0.005, 6)
    _loft("lantern", [_ring(hang + Vector((0, 0, z)), r, r, 8) for z, r in
                      ((-0.02, 0.04), (-0.04, 0.06), (-0.2, 0.06), (-0.22, 0.07), (-0.24, 0.05))])
