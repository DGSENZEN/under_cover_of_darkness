"""The city's own clothes for the shades (tools/textures/silhouettes.py), beyond the lane's (dressing.py): the
1920s capital's modern people and its street trades (docs/superpowers/refs/mexico_city/bible.md, "Street trades
double as gameplay roles"; the pelona, the clerk, the Light Company's linemen, the gendarme, the newsboy, the water
carrier, the porter, the organ grinder, the sereno), and what the Pasaje's stallkeepers wear and hold. Like
dressing.py's, each is built round a posed body's bones, only its outline counting; what is worn on the head sits in
the head's own frame (however it is bowed or turned).
"""

import math

import bmesh
import bpy
from mathutils import Vector

import dressing
from dressing import _loft, _ring, _rod


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


# --- old and young, and the church in hiding -----------------------------------------------------------------

def _ball(name, centre, r, n=10):
    """A small ball."""
    return _loft(name, [_ring(centre + Vector((0, 0, r * math.cos(a))), max(r * math.sin(a), 0.001),
                              max(r * math.sin(a), 0.001), n) for a in [math.pi * k / 6 for k in range(7)]])


def cane(bones):
    """A walking stick from the reaching hand to the floor a little ahead, its crook in the fist."""
    side = dressing._reaching(bones)
    at, _ = dressing._grip(bones, side)
    _rod("cane", at, Vector((at.x, at.y - 0.12, 0.0)), 0.012)
    crook = [at + Vector((0, 0.05 * math.sin(a), 0.03 + 0.03 * math.cos(a))) for a in [math.pi * k / 6 for k in range(7)]]
    for a, b in zip(crook, crook[1:]):
        _rod("cane_crook", a, b, 0.011, 6)


def headscarf(bones):
    """A scarf over the hair, knotted at the nape, its ends hanging."""
    f = _head(bones)
    _loft("headscarf", [_round(f, 0.012, -0.01, 0.03, 0.03), _round(f, -0.02, -0.01, 0.1, 0.112),
                        _round(f, -0.08, -0.025, 0.112, 0.112), _round(f, -0.14, -0.06, 0.1, 0.075),
                        _round(f, -0.2, -0.1, 0.035, 0.03)])


def baby(bones):
    """A baby swaddled in a shawl held to the chest in the folded arms, its head at the shoulder."""
    hands = (bones["hand_l"][0] + bones["hand_r"][0]) / 2
    shoulder = bones["spine_03"][1]
    low = hands + Vector((0, -0.07, -0.02))
    high = Vector((shoulder.x, shoulder.y - 0.12, shoulder.z + 0.02))
    way = (high - low).normalized()
    _loft("baby", [_ring(low + (high - low) * f, r, r * 0.85, 16, way) for f, r in
                   ((-0.05, 0.03), (0.05, 0.08), (0.45, 0.095), (0.8, 0.07), (0.92, 0.04))])
    _ball("baby_head", high + way * 0.06 + Vector((0, -0.02, 0)), 0.075)


def frock_coat(bones):
    """A long dark coat buttoned to the throat, to the knee: a priest's, out of his cassock."""
    dressing.coat(bones, hem=bones["calf_l"][0].z - 0.02, off=(0.07, 0.09), flare=(0.02, 0.05), wide=(0.2, 0.23),
                  name="frock_coat", collar=True)


def rosary(bones):
    """A rosary dangling from the reaching hand: its loop of beads, its pendant, its cross."""
    side = dressing._reaching(bones)
    at, _ = dressing._grip(bones, side)
    for k in range(9):
        a = math.pi * k / 8
        _ball("bead", at + Vector((0, 0.045 * math.cos(a), -0.12 * math.sin(a))), 0.011, 6)
    tail = at + Vector((0, 0, -0.12))
    for k in range(1, 4):
        _ball("bead", tail + Vector((0, 0, -0.03 * k)), 0.011, 6)
    cross = tail + Vector((0, 0, -0.15))
    _rod("cross", cross + Vector((0, 0, 0.04)), cross - Vector((0, 0, 0.05)), 0.006, 6)
    _rod("cross", cross + Vector((0, -0.03, 0.01)), cross + Vector((0, 0.03, 0.01)), 0.006, 6)


def habit(bones):
    """A nun's habit: long, full, to the floor."""
    dressing.coat(bones, hem=0.03, off=(0.08, 0.1), flare=(0.05, 0.1), wide=(0.2, 0.28), name="habit", collar=False)
    dressing.sleeves(bones, size=(0.085, 0.095))


def veil(bones):
    """A nun's veil: stiff over the brow, falling behind the head down the back."""
    f = _head(bones)
    neck = bones["neck_01"][0]
    top = bones["spine_03"][1]
    mid = bones["spine_02"][1]
    _loft("veil", [_round(f, 0.022, 0.0, 0.04, 0.05), _round(f, 0.01, 0.01, 0.115, 0.13),
                   _round(f, -0.07, -0.02, 0.125, 0.14),
                   _ring(Vector((neck.x, neck.y + 0.05, neck.z)), 0.16, 0.13, 24),
                   _ring(Vector((top.x, top.y + 0.07, top.z - 0.02)), 0.24, 0.13, 24),
                   _ring(Vector((mid.x, mid.y + 0.1, mid.z - 0.12)), 0.22, 0.09, 24)])


def saint(bones):
    """A saint's figure carried before the chest in procession: its little platform on the hands, its robe, its head,
    its crown of rays."""
    hands = (bones["hand_l"][0] + bones["hand_r"][0]) / 2
    foot = hands + Vector((0, -0.06, 0.02))
    _slab("saint_base", foot, Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)), 0.18, 0.18, 0.05)
    _loft("saint", [_ring(foot + Vector((0, 0, z)), r, r * 0.8, 16) for z, r in
                    ((0.025, 0.07), (0.15, 0.06), (0.3, 0.045), (0.36, 0.04))])
    head = foot + Vector((0, 0, 0.41))
    _ball("saint_head", head, 0.035)
    for k in range(9):
        a = math.pi * (0.1 + 0.8 * k / 8)
        _rod("saint_ray", head + Vector((0, 0.03 * math.cos(a), 0.03 * math.sin(a))),
             head + Vector((0, 0.11 * math.cos(a), 0.11 * math.sin(a))), 0.005, 6)


# --- the uncanny ----------------------------------------------------------------------------------------------
# Each from the city's own folklore (docs/superpowers/refs/mexico_city/bible.md): the nahual's ways, the lechuza, the
# curandero, susto, the seance salons, the chaneque, and the tall man who walks with the crowd.

def _muzzle(f, du, df, rs, ru, n=20):
    """A ring square to the face's way, `df` toward it and `du` down from the skull's top, `rs` across, `ru` up."""
    top, side, face, up = f
    centre = top + up * du + face * df
    return [centre + side * rs * math.cos(2 * math.pi * k / n) + up * ru * math.sin(2 * math.pi * k / n)
            for k in range(n)]


def _ear(name, f, at_side, du, df, tip_du, tip_df, r):
    top, side, face, up = f
    base = top + side * at_side + up * du + face * df
    tip = top + side * at_side * 1.2 + up * tip_du + face * tip_df
    _loft(name, [_ring(base, r, r * 0.6, 10, tip - base), _ring(tip, 0.003, 0.003, 10, tip - base)])


def coyote_head(bones):
    """A nahual half turned: a coyote's head over the man's, its long muzzle, its tall ears."""
    f = _head(bones)
    _loft("coyote", [_muzzle(f, -0.1, d, rs, ru) for d, rs, ru in
                     ((-0.13, 0.04, 0.05), (-0.09, 0.1, 0.11), (-0.02, 0.115, 0.12), (0.05, 0.11, 0.11),
                      (0.11, 0.075, 0.075), (0.18, 0.045, 0.05), (0.25, 0.025, 0.03))])
    for s in (-1, 1):
        _ear("coyote_ear", f, s * 0.055, -0.02, -0.04, 0.13, -0.07, 0.04)


def jaguar_head(bones):
    """A nahual half turned: a jaguar's head over the woman's, round, its muzzle short and broad, its ears small."""
    f = _head(bones)
    _loft("jaguar", [_muzzle(f, -0.11, d, rs, ru) for d, rs, ru in
                     ((-0.13, 0.05, 0.06), (-0.08, 0.12, 0.125), (0.0, 0.13, 0.13), (0.07, 0.11, 0.1),
                      (0.13, 0.085, 0.08), (0.19, 0.06, 0.055), (0.22, 0.035, 0.035))])
    for s in (-1, 1):
        _ear("jaguar_ear", f, s * 0.08, 0.0, -0.05, 0.08, -0.07, 0.05)


def tail(bones):
    """A cat's long tail hanging from under her hem behind, its tip curled up."""
    pelvis = bones["pelvis"][0]
    path = [Vector((pelvis.x, pelvis.y + 0.12 + 0.3 * math.sin(t * 1.4), pelvis.z - 0.1 - 0.75 * t + 0.35 * t ** 4))
            for t in [k / 12 for k in range(13)]]
    rings = []
    for k, at in enumerate(path):
        way = (path[min(k + 1, len(path) - 1)] - path[max(k - 1, 0)]).normalized()
        r = 0.032 - 0.0018 * k
        rings.append(_ring(at, r, r, 10, way))
    _loft("tail", rings)


def claws(bones):
    """Claws come through the fingers of both hands: four to a hand, long and hooked."""
    for side in ("l", "r"):
        wrist, knuckle = bones["hand_" + side]
        way = (knuckle - wrist).normalized()
        across = way.cross(Vector((0, 0, 1)))
        across = across.normalized() if across.length > 1e-3 else Vector((1, 0, 0))
        for k in range(4):
            root = knuckle + way * 0.04 + across * (k - 1.5) * 0.018
            bend = (way + Vector((0, 0, -0.6))).normalized()
            _loft("claw", [_ring(root, 0.008, 0.008, 6, way), _ring(root + way * 0.07, 0.006, 0.006, 6, way),
                           _ring(root + way * 0.11 + bend * 0.05, 0.001, 0.001, 6, bend)])


def owl_head(bones):
    """The lechuza: an owl's head over the woman's, round and big, its ear tufts up, its beak hooked."""
    f = _head(bones)
    _loft("owl", [_muzzle(f, -0.1, d, rs, ru) for d, rs, ru in
                  ((-0.14, 0.05, 0.06), (-0.1, 0.12, 0.13), (-0.02, 0.14, 0.14), (0.06, 0.13, 0.12),
                   (0.11, 0.08, 0.075), (0.125, 0.03, 0.03))])
    # (Its tufts low and swept back, a horned owl's, not a cat's ears.)
    for s in (-1, 1):
        _ear("owl_tuft", f, s * 0.08, -0.02, -0.04, 0.05, -0.13, 0.025)
    top, side, face, up = f
    beak = top + up * -0.12 + face * 0.115
    _loft("beak", [_ring(beak, 0.032, 0.032, 8, face), _ring(beak + face * 0.06 - up * 0.02, 0.016, 0.016, 8, face),
                   _ring(beak + face * 0.075 - up * 0.08, 0.002, 0.002, 8, face)])


def _panel(name, outline, thick=0.012):
    """A flat shape in the side's plane (y-z), `outline` its points round, a little thick across (x)."""
    bm = bmesh.new()
    across = Vector((thick / 2, 0, 0))
    front = [bm.verts.new(p - across) for p in outline]
    back = [bm.verts.new(p + across) for p in outline]
    bm.faces.new(front[::-1])
    bm.faces.new(back)
    n = len(front)
    for k in range(n):
        bm.faces.new([front[k], front[(k + 1) % n], back[(k + 1) % n], back[k]])
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def wings(bones):
    """Her rebozo half wings: from the shoulders down the back to the knees, its hem gone to feathers."""
    top = bones["spine_03"][1]
    pelvis = bones["pelvis"][0]
    knee = min(bones["calf_l"][0].z, bones["calf_r"][0].z)
    shoulder = Vector((top.x, top.y + 0.02, top.z + 0.06))
    outline = [shoulder, shoulder + Vector((0, 0.2, 0.02)), Vector((0, pelvis.y + 0.34, pelvis.z + 0.1))]
    # (The feathers along its hem, from behind the knees up to the elbow.)
    tips = 7
    start = Vector((0, pelvis.y + 0.3, knee - 0.06))
    end = Vector((0, top.y - 0.05, pelvis.z + 0.12))
    for k in range(tips + 1):
        t = k / tips
        at = start + (end - start) * t
        outline.append(at)
        if k < tips:
            nxt = start + (end - start) * (k + 1) / tips
            outline.append((at + nxt) / 2 + Vector((0, 0.03, 0.06)))
    for x in (top.x - 0.24, top.x + 0.24):
        _panel("wing", [Vector((x, p.y, p.z)) for p in outline])


def censer(bones):
    """The curandero's censer of copal swung on its chains from the reaching hand; a bundle of herbs in the other."""
    side = dressing._reaching(bones)
    at, _ = dressing._grip(bones, side)
    bowl = at + Vector((0, -0.06, -0.3))
    for dy in (-0.04, 0.04):
        _rod("censer_chain", at, bowl + Vector((0, dy, 0.04)), 0.003, 6)
    _loft("censer", [_ring(bowl + Vector((0, 0, z)), r, r, 12) for z, r in
                     ((-0.06, 0.03), (-0.04, 0.06), (0.0, 0.07), (0.04, 0.05), (0.06, 0.03))])
    other = "r" if side == "l" else "l"
    fist, way = dressing._grip(bones, other)
    for k in range(7):
        a = -0.5 + k / 6.0
        sprig = (way + Vector((0, a * 0.5, 0.5))).normalized()
        _rod("herbs", fist, fist + sprig * (0.18 + 0.03 * (k % 2)), 0.006, 6)


def ectoplasm(bones):
    """The medium's ectoplasm: poured out of her mouth in strands that part as they fall, pooling on the floor."""
    top, side, face, up = _head(bones)
    mouth = top + up * -0.15 + face * 0.1
    for k, (reach, sway, width) in enumerate(((0.26, 0.0, 0.045), (0.16, 0.04, 0.03), (0.34, -0.03, 0.028))):
        left, right = [], []
        steps = 14
        for j in range(steps + 1):
            t = j / steps
            y = mouth.y - reach * (t ** 0.6) + sway * math.sin(t * math.pi)
            z = mouth.z * (1 - t ** 1.4)
            # (Thin out of the mouth, swelling, wisping, then spread where it lies on the floor.)
            half = 0.006 + width * math.sin(t * math.pi * 0.9) * (0.7 + 0.3 * math.sin(j * 2.1 + k)) + 0.05 * t ** 6
            left.append(Vector((mouth.x, y - half, z)))
            right.append(Vector((mouth.x, y + half, z)))
        _panel("ectoplasm", left + right[::-1], 0.02 + 0.01 * k)


def big_hat(bones):
    """The chaneque's straw hat, far too big for it (drawn at a man's size, the hat twice as wide)."""
    dressing.hat(bones, 0.0, brim=0.5, tip_deg=4.0, crown_size=(0.13, 0.22), seat=True, lift=(0.06, 0.08, 0.09))


def long_fingers(bones):
    """The tall man's fingers, too long, hanging past his cuffs."""
    for side in ("l", "r"):
        wrist, knuckle = bones["hand_" + side]
        way = (knuckle - wrist).normalized()
        across = way.cross(Vector((1, 0, 0)))
        across = across.normalized() if across.length > 1e-3 else Vector((0, 1, 0))
        for k in range(4):
            root = knuckle + across * (k - 1.5) * 0.014
            _loft("finger", [_ring(root, 0.008, 0.008, 6, way), _ring(root + way * 0.17, 0.004, 0.004, 6, way)])


def evening_dress(bones):
    """A long evening dress, bare-armed: the medium's, for the salon."""
    dressing.coat(bones, hem=0.04, off=(0.05, 0.07), flare=(0.02, 0.06), wide=(0.17, 0.2), name="evening_dress",
                  collar=False)
