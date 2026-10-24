"""Clothes for the base bodies' silhouettes (tools/textures/librarian_shadow.py, tools/textures/silhouettes.py):
shapes built round a posed body's bones, only their outline counting, rendered black with the body. Each takes the
bones as {name: (head, tail)} in the world, already standing on the floor.

The librarian's dress is the default of each: his greatcoat, sleeves, boots and wide felt hat. The candle lane's
people wear the city's: men's jackets and trousers, fedoras and straw sombreros; women's long skirts and rebozos drawn
over the head, a market basket on the arm.
"""

import math

import bmesh
import bpy
from mathutils import Vector

# The coat: its hem's height (m, of the base body's 1.81), how far it stands off the body front and back, how much
# its skirt flares by the hem (front, back) and how wide it hangs; its sleeves' radius at the shoulder and the cuff.
HEM = 0.4
COAT_OFF = (0.1, 0.12)
FLARE = (0.04, 0.1)
COAT_WIDE = (0.21, 0.27)
SLEEVE = (0.075, 0.062)
# How far the skirt may draw in from one ring to the next going down (m).
DRAPE = 0.006
# The hat: its brim's radius and how far it tips forward (degrees), its crown's radius and height.
BRIM = 0.215
BRIM_TIP = 8.0
CROWN = (0.096, 0.105)
# Other hats: a fedora's (brim, tip, crown), a straw sombrero's.
FEDORA = (0.165, 5.0, (0.09, 0.11))
SOMBRERO = (0.3, 3.0, (0.095, 0.17))
# A woman's long skirt: its hem (m), how far it stands off the legs front and back, its flare, how wide it hangs.
SKIRT_HEM = 0.05
SKIRT_OFF = (0.08, 0.1)
SKIRT_FLARE = (0.06, 0.1)
SKIRT_WIDE = (0.18, 0.28)
# A man's jacket: where it ends (m, on a man standing, his pelvis 0.97 up).
JACKET_HEM = 0.8
# Trousers round each leg (at the hip, the knee, the ankle).
TROUSERS = (0.095, 0.07, 0.06)


def _ring(centre, rx, ry, n=32, z_axis=None):
    """A horizontal ellipse round `centre` (x across, y along the body), or one square to `z_axis`."""
    pts = []
    if z_axis is None:
        for k in range(n):
            a = 2 * math.pi * k / n
            pts.append(Vector((centre.x + rx * math.cos(a), centre.y + ry * math.sin(a), centre.z)))
        return pts
    z = z_axis.normalized()
    u = z.cross(Vector((1, 0, 0)) if abs(z.x) < 0.9 else Vector((0, 1, 0))).normalized()
    v = z.cross(u)
    return [centre + u * rx * math.cos(2 * math.pi * k / n) + v * ry * math.sin(2 * math.pi * k / n) for k in range(n)]


def _loft(name, rings):
    """A closed solid through `rings` (each the same count), capped at both ends."""
    bm = bmesh.new()
    loops = [[bm.verts.new(p) for p in ring] for ring in rings]
    n = len(rings[0])
    for a, b in zip(loops, loops[1:]):
        for k in range(n):
            bm.faces.new([a[k], a[(k + 1) % n], b[(k + 1) % n], b[k]])
    bm.faces.new(loops[0][::-1])
    bm.faces.new(loops[-1])
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def _on_leg(bones, side, z):
    """Where the leg on `side` is at height `z` (its thigh's or calf's line), along y; below a lifted leg's lowest
    point, that point's (so the coat keeps over both legs as a foot swings up behind)."""
    for part in ("thigh_" + side, "calf_" + side):
        a, b = bones[part]
        if min(a.z, b.z) <= z <= max(a.z, b.z) and abs(a.z - b.z) > 1e-6:
            return a.y + (b.y - a.y) * (z - a.z) / (b.z - a.z)
    points = [p for part in ("thigh_" + side, "calf_" + side) for p in bones[part]]
    lowest = min(points, key=lambda p: p.z)
    return lowest.y if z < lowest.z else None


def _skirt(bones, rings, waist, hem, off, flare, wide, drape, steps=10):
    """A skirt's rings from the waist down to `hem`, over both legs, opening over the forward leg and trailing
    behind.
    (Cloth falls from what holds it out: going down, the skirt never draws in by more than `drape` a ring, so a knee
    swung forward holds it out below the knee rather than cutting it back.)"""
    was = None
    for k in range(1, steps + 1):
        z = waist + (hem - waist) * k / steps
        f = k / steps
        ys = [y for y in (_on_leg(bones, "l", z), _on_leg(bones, "r", z)) if y is not None]
        if not ys:
            ys = [was[0] + off[0], was[1] - off[1]] if was is not None else [bones["pelvis"][0].y]
        front = min(ys) - off[0] - flare[0] * f
        back = max(ys) + off[1] + flare[1] * f * f
        if was is not None:
            front = min(front, was[0] + drape)
            back = max(back, was[1] - drape)
        was = (front, back)
        rings.append(_ring(Vector((0.0, (front + back) / 2, z)), wide[0] + (wide[1] - wide[0]) * f, (back - front) / 2))
    return rings


def coat(bones, hem=HEM, off=COAT_OFF, flare=FLARE, wide=COAT_WIDE, drape=DRAPE, name="coat", collar=True):
    """A coat: its body round the spine, its skirt from the waist to the hem over both legs, opening over the
    forward leg and trailing behind, its collar turned up (or lying flat). (A jacket is one with its hem high.)"""
    waist = bones["pelvis"][0].z + 0.02
    rings = []
    # The body, from the waist to the shoulders, round the spine's line.
    spine = [bones["pelvis"][0], bones["spine_01"][1], bones["spine_02"][1], bones["spine_03"][1]]
    for k, p in enumerate(spine):
        t = k / (len(spine) - 1)
        rings.append(_ring(Vector((p.x, p.y + 0.01, p.z if k else waist)), 0.2 + 0.04 * t, 0.13 + 0.01 * t))
    # Over the shoulders, rounding in to the neck.
    top = bones["spine_03"][1]
    neck = bones["neck_01"][0]
    rings.append(_ring(Vector((top.x, top.y + 0.02, top.z + 0.04)), 0.21, 0.1))
    rings.append(_ring(Vector((neck.x, neck.y + 0.02, neck.z + 0.02)), 0.11, 0.1))
    # (Its collar turned up round the neck, higher at the back: the coat's own top, so no ledge where they meet.)
    if collar:
        rings.append(_ring(Vector((neck.x, neck.y + 0.035, neck.z + 0.09)), 0.085, 0.08))
    rings.reverse()
    _skirt(bones, rings, waist, hem, off, flare, wide, drape)
    _loft(name, rings)


def jacket(bones):
    """A man's jacket: the coat cut off at the hip."""
    # (Ending at the hips wherever they are: standing, or low on a kneeling man.)
    hem = bones["pelvis"][0].z - (0.97 - JACKET_HEM)
    coat(bones, hem=hem, off=(0.06, 0.07), flare=(0.01, 0.02), wide=(0.2, 0.21), name="jacket", collar=False)


def skirt(bones, hem=SKIRT_HEM, off=SKIRT_OFF, flare=SKIRT_FLARE, wide=SKIRT_WIDE):
    """A woman's long skirt from the waist to the ankles, gathered at the waist."""
    pelvis = bones["pelvis"][0]
    waist = pelvis.z + 0.06
    rings = [_ring(Vector((pelvis.x, pelvis.y + 0.01, waist + 0.04)), 0.15, 0.11),
             _ring(Vector((pelvis.x, pelvis.y + 0.01, waist)), 0.17, 0.12)]
    _skirt(bones, rings, waist, hem, off, flare, wide, DRAPE)
    _loft("skirt", rings)


def sleeves(bones, size=SLEEVE):
    """Sleeves along each arm, wider than it, to the wrist."""
    for side in ("l", "r"):
        shoulder, elbow = bones["upperarm_" + side]
        wrist = bones["lowerarm_" + side][1]
        axis_up, axis_low = elbow - shoulder, wrist - elbow
        _loft("sleeve_" + side, [_ring(shoulder, size[0], size[0], 12, axis_up),
                                 _ring(elbow, (size[0] + size[1]) / 2, (size[0] + size[1]) / 2, 12, axis_up),
                                 _ring(elbow, (size[0] + size[1]) / 2, (size[0] + size[1]) / 2, 12, axis_low),
                                 _ring(wrist - axis_low.normalized() * 0.01, size[1], size[1], 12, axis_low)])


def trousers(bones, size=TROUSERS):
    """Trousers round each leg, from the hip to the ankle, a little loose."""
    for side in ("l", "r"):
        hip, knee = bones["thigh_" + side]
        ankle = bones["calf_" + side][1]
        up, low = knee - hip, ankle - knee
        _loft("leg_" + side, [_ring(hip + Vector((0, 0, 0.04)), size[0], size[0], 12, up),
                              _ring(knee, size[1], size[1], 12, up), _ring(knee, size[1], size[1], 12, low),
                              _ring(ankle - low.normalized() * 0.03, size[2], size[2], 12, low)])


def boots(bones):
    """Boots: a shaft up the shin, the foot from heel to toe."""
    for side in ("l", "r"):
        ankle = bones["calf_" + side][1]
        shin = bones["calf_" + side][0] + (ankle - bones["calf_" + side][0]) * 0.6
        ball = bones["foot_" + side][1]
        toe = bones["ball_" + side][1]
        _loft("shaft_" + side, [_ring(shin, 0.047, 0.047, 24, ankle - shin), _ring(ankle, 0.045, 0.045, 24, ankle - shin)])
        # (The foot along its own way, heel to toe, its sole on the foot's line.)
        along = (toe - ankle).normalized()
        heel = ankle - along * 0.04
        _loft("foot_" + side, [_ring(heel + Vector((0, 0, -0.04)), 0.038, 0.028, 24, along),
                               _ring(ankle + Vector((0, 0, -0.028)), 0.045, 0.044, 24, along),
                               _ring(ball + Vector((0, 0, 0.012)), 0.043, 0.025, 24, along),
                               _ring(toe - along * 0.02 + Vector((0, 0, 0.011)), 0.026, 0.017, 24, along)])


def hat(bones, crown, brim=BRIM, tip_deg=BRIM_TIP, crown_size=CROWN):
    """A brimmed hat tipped a little forward, set on the top of the head (`crown`): the brim dipping at its front and
    back, the crown pinched toward its top. (By default the librarian's wide felt.)"""
    head = bones["Head"][1]
    at = Vector((head.x, head.y + 0.01, crown - 0.075))
    tip = math.radians(tip_deg)
    up = Vector((0, -math.sin(tip), math.cos(tip)))

    def tipped(p):
        # (Tipped forward about the hat's band: its front down.)
        d = p - at
        return at + Vector((d.x, d.y * math.cos(tip) - d.z * math.sin(tip), d.y * math.sin(tip) + d.z * math.cos(tip)))

    rings = []
    for k, (r, z) in enumerate([(brim, -0.012), (brim, 0.0)]):
        ring = []
        for j in range(24):
            a = 2 * math.pi * j / 24
            # (Its brim curls down at the front and back, up at the sides.)
            dip = -0.022 * abs(math.sin(a)) + 0.008 * abs(math.cos(a))
            ring.append(tipped(at + Vector((r * math.cos(a), r * math.sin(a), z + dip))))
        rings.append(ring)
    _loft("brim", rings)
    rx, h = crown_size
    _loft("crown", [[tipped(p) for p in _ring(at + Vector((0, 0, -0.005)), rx, rx * 0.92, 24)],
                    [tipped(p) for p in _ring(at + Vector((0, 0, h * 0.6)), rx * 0.97, rx * 0.86, 24)],
                    [tipped(p) for p in _ring(at + Vector((0, 0, h * 0.92)), rx * 0.82, rx * 0.66, 24)],
                    [tipped(p) for p in _ring(at + Vector((0, 0, h)), rx * 0.55, rx * 0.4, 24)]])
    return up


def rebozo(bones, crown):
    """A rebozo drawn over the head and round the shoulders, its ends hanging down the back to the hips."""
    head0, head1 = bones["Head"]
    neck = bones["neck_01"][0]
    top = bones["spine_03"][1]
    mid = bones["spine_02"][1]
    pelvis = bones["pelvis"][0]
    # (Its hood's middle a little behind the head's, so the face looks out of its front edge.)
    along = head1.y - head0.y
    rings = [_ring(Vector((head1.x, head1.y + 0.02, crown + 0.02)), 0.05, 0.06, 24),
             _ring(Vector((head1.x, head1.y + 0.025, crown - 0.05)), 0.115, 0.13, 24),
             _ring(Vector((head0.x, head0.y + 0.03 + along * 0.3, head0.z + 0.04)), 0.12, 0.13, 24),
             _ring(Vector((neck.x, neck.y + 0.03, neck.z)), 0.15, 0.13, 24),
             # (Falling from the neck over the shoulders, drawn across the chest.)
             _ring(Vector((neck.x, neck.y + 0.025, (neck.z + top.z) / 2 + 0.02)), 0.2, 0.14, 24),
             _ring(Vector((top.x, top.y + 0.02, top.z + 0.01)), 0.25, 0.16, 24),
             _ring(Vector((mid.x, mid.y + 0.02, mid.z)), 0.25, 0.165, 24),
             _ring(Vector((pelvis.x, pelvis.y + 0.1, pelvis.z + 0.12)), 0.19, 0.07, 24),
             _ring(Vector((pelvis.x, pelvis.y + 0.12, pelvis.z - 0.06)), 0.14, 0.04, 24)]
    _loft("rebozo", rings)


def crate(bones):
    """A crate carried before the body in both hands, its foot on their palms."""
    hands = (bones["hand_l"][0] + bones["hand_r"][0]) / 2
    at = hands + Vector((0, 0, 0.13))

    def square(z):
        return [at + Vector((x, y, z)) for x, y in ((-0.2, -0.17), (0.2, -0.17), (0.2, 0.17), (-0.2, 0.17))]

    _loft("crate", [square(-0.14), square(0.16)])


def basket(bones, side="l"):
    """A market basket hung in the crook of the arm on `side`."""
    elbow, wrist = bones["lowerarm_" + side]
    at = elbow + (wrist - elbow) * 0.4 - Vector((0, 0, 0.13))
    _loft("basket", [_ring(at + Vector((0, 0, -0.1)), 0.11, 0.08, 24), _ring(at + Vector((0, 0, -0.04)), 0.15, 0.11, 24),
                     _ring(at + Vector((0, 0, 0.06)), 0.17, 0.12, 24)])
    # Its handle, up over the forearm.
    handle = [_ring(at + Vector((0, 0, 0.06)) + Vector((0, 0.1 * math.cos(a), 0.02 + 0.13 * math.sin(a))), 0.012, 0.012, 8,
                    Vector((0, -math.sin(a), math.cos(a)))) for a in [math.pi * k / 8 for k in range(9)]]
    _loft("basket_handle", handle)
