"""Silhouettes to pick from for the ravenous ánimas: three forms, three takes on each,
as solid shapes at full size and small, as they read at fight distance. Souls no one
lit a candle for, withered and past begging, their fire nearly out. Picks are recorded
here and in docs/superpowers/specs/2026-11-01-ravenous-animas-design.md.

    /Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup \\
        --python tools/monsters/anima_silhouettes.py -- <repo root>

Saves docs/superpowers/refs/hunt/anima_silhouettes.png.

The user's picks: Hands A, Face B, Torso A.
"""

import math
import os
import sys

import bpy
from mathutils import Vector

ROOT = sys.argv[sys.argv.index("--") + 1]
OUT = os.path.join(ROOT, "docs/superpowers/refs/hunt/anima_silhouettes.png")
INK = (0.012, 0.01, 0.012, 1.0)
PAPER = (0.62, 0.57, 0.48, 1.0)
CELL = Vector((7.2, 5.2))


def material(name, colour):
    made = bpy.data.materials.new(name)
    made.use_nodes = True
    nodes = made.node_tree.nodes
    nodes.clear()
    emit = nodes.new("ShaderNodeEmission")
    emit.inputs[0].default_value = colour
    done = nodes.new("ShaderNodeOutputMaterial")
    made.node_tree.links.new(emit.outputs[0], done.inputs[0])
    return made


INK_LOOK = material("ink", INK)
PAPER_LOOK = material("paper", PAPER)
GUIDE_LOOK = material("guide", (0.42, 0.38, 0.32, 1.0))


class Sheet:
    """Draws in one frame: an offset and a scale over everything drawn."""

    def __init__(self):
        self.origin = Vector((0.0, 0.0))
        self.size = 1.0

    def place(self, p):
        return self.origin + Vector(p) * self.size

    def polygon(self, points, look, depth):
        verts = [(p.x, p.y, depth) for p in points]
        mesh = bpy.data.meshes.new("shape")
        mesh.from_pydata(verts, [], [list(range(len(verts)))])
        mesh.materials.append(look)
        thing = bpy.data.objects.new("shape", mesh)
        bpy.context.scene.collection.objects.link(thing)

    def blob(self, at, rx, ry=None, turn=0.0, look=None, depth=0.0):
        ry = rx if ry is None else ry
        look = look or INK_LOOK
        points = []

        for i in range(28):
            a = math.tau * i / 28
            p = Vector((math.cos(a) * rx, math.sin(a) * ry))
            p.rotate(_turn(turn))
            points.append(self.place(Vector(at) + p))

        self.polygon(points, look, depth)

    def hole(self, at, rx, ry=None, turn=0.0):
        self.blob(at, rx, ry, turn, PAPER_LOOK, 0.2)

    def stroke(self, points, widths, look=None, depth=0.0):
        """A tapered, curved limb through `points`, `widths` from start to end."""
        look = look or INK_LOOK
        path = _smooth([Vector(p) for p in points])
        count = len(path)

        for i in range(count - 1):
            u = i / (count - 1)
            v = (i + 1) / (count - 1)
            a = path[i]
            b = path[i + 1]
            side = Vector((-(b - a).y, (b - a).x))

            if side.length < 1e-5:
                continue

            side.normalize()
            wa = _along(widths, u) * 0.5
            wb = _along(widths, v) * 0.5
            self.polygon([self.place(a + side * wa), self.place(b + side * wb), self.place(b - side * wb), self.place(a - side * wa)], look, depth)
            self.blob(b, wb, None, 0.0, look, depth)

    def finger(self, base, knuckle, tip, width=0.17):
        self.stroke([base, knuckle, tip], [width, width * 0.8, width * 0.22])

    def wisps(self, at, way, length=1.6, count=4, width=0.26):
        """Burnt-out fire: a few thin licks trailing off, thick to nothing."""
        for i in range(count):
            lift = (i - (count - 1) * 0.5) * 0.26
            wave = 0.3 if i % 2 else -0.3
            end = Vector(at) + Vector(way) * length * (0.65 + 0.35 * ((i * 37) % 10) / 10.0)
            mid = (Vector(at) + end) * 0.5 + Vector((0.0, lift + wave))
            self.stroke([at, mid, end + Vector((0.0, lift * 1.6))], [width, width * 0.5, 0.01])

    def candle(self, at, height=0.5, lean=0.0):
        """A dead stub: no flame, a bent wick."""
        top = Vector(at) + Vector((lean, height))
        self.stroke([at, top], [0.2, 0.17])
        self.stroke([top, top + Vector((0.06, 0.12)), top + Vector((0.14, 0.1))], [0.035, 0.03, 0.015])


def _turn(radians):
    from mathutils import Matrix

    return Matrix.Rotation(radians, 2)


def _along(widths, u):
    at = u * (len(widths) - 1)
    i = min(int(at), len(widths) - 2)
    return widths[i] + (widths[i + 1] - widths[i]) * (at - i)


def _smooth(points, per=9):
    if len(points) < 3:
        return [points[0].lerp(points[-1], i / per) for i in range(per + 1)]

    out = []
    padded = [points[0]] + points + [points[-1]]

    for k in range(1, len(padded) - 2):
        p0, p1, p2, p3 = padded[k - 1], padded[k], padded[k + 1], padded[k + 2]

        for i in range(per):
            t = i / per
            out.append(0.5 * ((2 * p1) + (p2 - p0) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (3 * p1 - p0 - 3 * p2 + p3) * t * t * t))

    out.append(points[-1])
    return out


# Anatomy: everything is jointed and bony. A round blob and a smooth curve read as a
# cartoon bug; a knuckle, a tendon and a hollow read as something that was a person.


def bone(s, points, widths):
    """Straight segments between swollen joints."""
    pts = [Vector(p) for p in points]

    for i in range(len(pts) - 1):
        a = pts[i]
        b = pts[i + 1]
        side = Vector((-(b - a).y, (b - a).x))

        if side.length < 1e-5:
            continue

        side.normalize()
        waist = min(widths[i], widths[i + 1]) * 0.36
        mid = (a + b) * 0.5
        s.polygon([s.place(a + side * widths[i] * 0.5), s.place(mid + side * waist), s.place(b + side * widths[i + 1] * 0.5),
            s.place(b - side * widths[i + 1] * 0.5), s.place(mid - side * waist), s.place(a - side * widths[i] * 0.5)], INK_LOOK, 0.0)

        if widths[i + 1] > 0.03:
            s.blob(b, widths[i + 1] * 0.5)

    if widths[0] > 0.03:
        s.blob(pts[0], widths[0] * 0.5)


def shape(s, points, look=None, depth=0.0):
    s.polygon([s.place(Vector(p)) for p in points], look or INK_LOOK, depth)


def cut(s, points):
    shape(s, points, PAPER_LOOK, 0.2)


def hand(s, wrist, angle, size=1.0, spread=1.0, curl=0.0, mirror=1.0, long=1.0):
    """A withered hand from wrist to hooked nail: narrow wrist, tendons, swollen
    knuckles, overlong fingers. Fingers along `angle` (radians, 0 up); `curl` bends each
    joint on toward the thumb side."""

    def place(local):
        p = Vector((local[0] * mirror, local[1])) * size
        p.rotate(_turn(-angle))
        return Vector(wrist) + p

    # The back of the hand: four tendons fanned from the wrist, webbed.
    knuckles = [(-0.33, 0.86), (-0.11, 0.98), (0.11, 0.96), (0.32, 0.82)]
    shape(s, [place(p) for p in [(-0.13, 0.0), (-0.3, 0.42), (-0.4, 0.86), (-0.11, 1.03), (0.11, 1.01), (0.39, 0.82), (0.3, 0.38), (0.13, 0.0)]])
    lengths = [1.0, 1.2, 1.15, 0.86]

    for i in range(4):
        base = knuckles[i]
        turn = (-0.3 + i * 0.2) * spread
        at = Vector(base)
        points = [place(at)]
        widths = [0.17 * size, 0.135 * size, 0.1 * size, 0.012 * size]
        segs = [0.44, 0.32, 0.27]

        for k in range(3):
            way = Vector((0.0, segs[k] * lengths[i] * long))
            way.rotate(_turn(-(turn + curl * (k + 1) * 0.55)))
            at = at + way
            points.append(place(at))

        bone(s, points, widths)

    # The thumb, low and wide.
    at = Vector((0.3, 0.26))
    points = [place(at)]

    for k, seg in enumerate([0.42, 0.34, 0.24]):
        way = Vector((0.0, seg * long))
        way.rotate(_turn(-(1.05 * spread - curl * (k + 1) * 0.5)))
        at = at + way
        points.append(place(at))

    bone(s, points, [0.17 * size, 0.125 * size, 0.09 * size, 0.012 * size])


def forearm(s, elbow, wrist, width=0.3):
    """Two bones with the skin shrunk between: a slit shows the gap."""
    e = Vector(elbow)
    w = Vector(wrist)
    bone(s, [e, w], [width, width * 0.62])
    side = Vector((-(w - e).y, (w - e).x)).normalized()
    a = e.lerp(w, 0.22)
    b = e.lerp(w, 0.78)
    mid = (a + b) * 0.5
    cut(s, [a, mid + side * width * 0.1, b, mid - side * width * 0.1])


def ribs(s, top, count, gap, width, lean=0.0, narrow=0.9):
    """Slits curving round a starved chest, one side."""
    for i in range(count):
        y = top[1] - i * gap
        w = width * (narrow ** i)
        x = top[0]
        cut(s, [(x, y), (x + w * 0.5, y + 0.04 + lean), (x + w, y - 0.03 + lean), (x + w * 0.5, y - 0.08 + lean)])


def socket(s, at, side, size=1.0):
    """A sunken, slanting eye pit."""
    x, y = at
    cut(s, [(x - side * 0.2 * size, y + 0.1 * size), (x + side * 0.22 * size, y + 0.02 * size), (x + side * 0.16 * size, y - 0.16 * size), (x - side * 0.14 * size, y - 0.1 * size)])


# The hands


def hands_a(s):
    """A hand up on its fingertips, the back of it toward you, walking: the arm it was
    torn from dragged behind, guttering."""
    hand(s, (0.0, 2.72), math.pi, 1.5, 1.25, -0.12, 1.0, 1.05)
    forearm(s, (-1.5, 3.55), (0.0, 2.72), 0.42)
    s.wisps((-1.5, 3.55), (-1.0, -0.25), 1.3, 4, 0.2)


def hands_b(s):
    """Hand over hand, one reached ahead and clawed into the floor, the other hauling,
    the two arms knotted together at the elbow."""
    hand(s, (1.2, 1.15), math.radians(112), 1.25, 1.0, 0.16)
    hand(s, (-1.1, 1.45), math.radians(205), 1.15, 1.15, -0.05, -1.0)
    forearm(s, (0.05, 2.05), (1.2, 1.15), 0.4)
    forearm(s, (0.05, 2.05), (-1.1, 1.45), 0.38)
    s.blob((0.05, 2.05), 0.3, 0.24)
    s.wisps((0.0, 2.2), (-0.15, 1.0), 1.4, 4, 0.22)


def hands_c(s):
    """Reared up to take you: an open hand as tall as a child, fingers hooked over you,
    the thin arm trailing away along the floor."""
    hand(s, (-0.35, 1.45), math.radians(14), 1.72, 1.2, 0.22, 1.0, 1.0)
    forearm(s, (-1.45, 0.25), (-0.35, 1.45), 0.46)
    s.wisps((-1.45, 0.25), (-1.0, -0.02), 1.3, 4, 0.2)


# The face


def face_a(s):
    """A long dried face in a scream, the jaw dragged down past where a jaw goes, and
    its own hands clawing at its cheeks."""
    shape(s, [(-0.62, 4.2), (0.0, 4.5), (0.62, 4.2), (0.86, 3.6), (0.7, 2.95), (0.46, 2.55), (0.5, 1.75), (0.3, 1.0), (0.0, 0.82), (-0.3, 1.0), (-0.5, 1.75), (-0.46, 2.55), (-0.7, 2.95), (-0.86, 3.6)])
    socket(s, (-0.34, 3.5), -1.0, 1.1)
    socket(s, (0.34, 3.5), 1.0, 1.1)
    cut(s, [(0.0, 3.28), (0.1, 2.92), (-0.1, 2.92)])
    cut(s, [(-0.26, 2.62), (0.26, 2.62), (0.31, 1.75), (0.14, 1.12), (-0.14, 1.12), (-0.31, 1.75)])

    for side in (-1.0, 1.0):
        forearm(s, (side * 2.15, 1.05), (side * 1.42, 2.1), 0.3)
        hand(s, (side * 1.42, 2.1), math.radians(-side * 42), 0.82, 0.9, side * -0.32, side, 0.98)

    s.wisps((0.0, 0.9), (0.0, -1.0), 0.72, 4, 0.14)


def face_b(s):
    """Two great hands first, thrust at you, and behind and between them a small dried
    face that is only sockets and a dropped mouth."""
    shape(s, [(-0.55, 3.75), (0.0, 4.02), (0.55, 3.75), (0.72, 3.25), (0.55, 2.72), (0.34, 2.4), (0.3, 1.82), (0.0, 1.55), (-0.3, 1.82), (-0.34, 2.4), (-0.55, 2.72), (-0.72, 3.25)])
    socket(s, (-0.3, 3.22), -1.0, 0.95)
    socket(s, (0.3, 3.22), 1.0, 0.95)
    cut(s, [(-0.17, 2.56), (0.17, 2.56), (0.19, 2.1), (0.0, 1.78), (-0.19, 2.1)])

    for side in (-1.0, 1.0):
        forearm(s, (side * 0.6, 2.75), (side * 1.42, 1.72), 0.34)
        hand(s, (side * 1.42, 1.72), math.radians(side * 142), 1.22, 1.15, side * 0.12, -side, 0.98)

    s.wisps((0.0, 1.55), (0.0, -1.0), 1.2, 4, 0.16)


def face_c(s):
    """In profile, thrown at you: brow, a beak of a nose, a hollow cheek, the jaw swung
    open, hair and fire streaming behind, a hand flung out ahead of the bite."""
    shape(s, [(-1.2, 3.1), (-0.95, 3.8), (-0.3, 4.15), (0.42, 4.02), (0.72, 3.62), (0.68, 3.32), (1.08, 2.86), (0.72, 2.75), (0.56, 2.42), (0.1, 2.5), (-0.28, 2.22), (-0.72, 2.3)])
    shape(s, [(-0.55, 2.42), (-0.2, 2.02), (0.2, 1.42), (0.86, 1.1), (0.98, 1.26), (0.5, 1.72), (0.12, 2.3)])
    cut(s, [(0.54, 3.5), (0.08, 3.62), (-0.02, 3.32), (0.34, 3.2)])
    cut(s, [(-0.42, 3.05), (-0.02, 2.92), (-0.14, 2.56), (-0.48, 2.62)])

    for i, offset in enumerate((0.55, 0.2, -0.15, -0.5)):
        s.stroke([(-1.05, 3.1 + offset), (-1.9, 3.3 + offset * 1.2), (-2.9 + i * 0.25, 3.05 + offset * 1.7)], [0.2, 0.12, 0.01])

    forearm(s, (0.55, 1.75), (1.6, 1.7), 0.3)
    hand(s, (1.6, 1.7), math.radians(82), 1.05, 1.2, 0.12)


# The torso


def spine(s, points):
    for at, size in points:
        s.blob(at, size, size * 1.15)


def torso_a(s):
    """Dragging itself flat along the floor on its forearms like the drowning do, the
    knobs of its spine up, its head low and hung forward, its fire where its legs were."""
    shape(s, [(-2.0, 0.85), (-1.5, 1.42), (-0.7, 1.72), (0.15, 1.95), (0.72, 1.72), (0.82, 1.18), (0.32, 0.8), (-0.6, 0.72), (-1.4, 0.6)])
    spine(s, [((-1.5, 1.45), 0.08), ((-1.15, 1.6), 0.09), ((-0.8, 1.74), 0.1), ((-0.45, 1.84), 0.11), ((-0.1, 1.96), 0.12)])
    ribs(s, (-1.05, 1.3), 1, 0.0, 0.0)

    for i in range(5):
        x = -1.25 + i * 0.36
        cut(s, [(x, 1.32 + i * 0.05), (x + 0.1, 1.28 + i * 0.05), (x + 0.2, 0.86), (x + 0.1, 0.86)])

    shape(s, [(0.6, 1.72), (1.12, 1.82), (1.52, 1.5), (1.5, 1.05), (1.25, 0.82), (1.15, 0.4), (0.8, 0.5), (0.85, 1.0), (0.55, 1.2)])
    socket(s, (1.2, 1.38), 1.0, 0.8)
    cut(s, [(1.27, 0.98), (1.02, 1.0), (0.97, 0.66), (1.13, 0.62)])
    bone(s, [(0.25, 1.7), (1.5, 2.72), (2.15, 0.82)], [0.46, 0.32, 0.17])
    hand(s, (2.15, 0.82), math.radians(115), 0.95, 1.1, 0.42, 1.0, 0.95)
    bone(s, [(-0.35, 1.55), (-0.05, 2.45), (0.42, 0.5)], [0.36, 0.24, 0.13])
    s.wisps((-2.0, 0.85), (-1.0, -0.12), 1.05, 5, 0.3)
    s.candle((-1.0, 1.72), 0.42, -0.1)
    s.candle((-0.42, 1.9), 0.3, 0.06)


def torso_b(s):
    """A gaunt yoke of shoulders high on crutch-long arms, the head hung below them on a
    bent neck, dead candles stuck along its back by those who tried to keep it down."""
    shape(s, [(-1.6, 3.42), (-0.55, 3.85), (0.55, 3.85), (1.6, 3.42), (1.32, 3.02), (0.72, 2.75), (0.62, 1.82), (0.3, 1.25), (-0.3, 1.25), (-0.62, 1.82), (-0.72, 2.75), (-1.32, 3.02)])
    cut(s, [(-0.1, 3.38), (-1.05, 3.32), (-0.68, 3.14), (-0.1, 3.14)])
    cut(s, [(0.1, 3.38), (1.05, 3.32), (0.68, 3.14), (0.1, 3.14)])

    for i in range(4):
        y = 2.72 - i * 0.3
        w = 0.5 - i * 0.05
        for side in (-1.0, 1.0):
            cut(s, [(side * 0.08, y + 0.06), (side * w, y - 0.03), (side * w, y - 0.14), (side * 0.08, y - 0.06)])

    shape(s, [(-0.4, 3.05), (0.4, 3.05), (0.5, 2.72), (0.38, 2.28), (0.2, 2.0), (-0.2, 2.0), (-0.38, 2.28), (-0.5, 2.72)], INK_LOOK, 0.3)
    shape(s, [(-0.26, 2.62), (-0.03, 2.54), (-0.05, 2.38), (-0.22, 2.42)], PAPER_LOOK, 0.4)
    shape(s, [(0.26, 2.62), (0.03, 2.54), (0.05, 2.38), (0.22, 2.42)], PAPER_LOOK, 0.4)
    shape(s, [(-0.12, 2.24), (0.12, 2.24), (0.09, 2.06), (-0.09, 2.06)], PAPER_LOOK, 0.4)

    for side in (-1.0, 1.0):
        bone(s, [(side * 1.45, 3.34), (side * 2.32, 2.3), (side * 2.08, 0.95)], [0.48, 0.34, 0.2])
        hand(s, (side * 2.08, 0.95), math.radians(180 - side * 8), 0.9, 1.3, side * -0.05, -side, 0.98)

    s.candle((-1.05, 3.62), 0.5, -0.14)
    s.candle((-0.3, 3.8), 0.36, 0.03)
    s.candle((0.42, 3.8), 0.58, 0.1)
    s.wisps((0.0, 1.3), (0.05, -1.0), 1.1, 5, 0.22)


def torso_c(s):
    """Caught in the lunge: one arm flung out to the end of a reach no arm should have,
    its open hand ahead of the rest, the head wrenched back, mouth open."""
    shape(s, [(-2.05, 1.2), (-1.7, 2.0), (-1.0, 2.62), (-0.2, 2.92), (0.25, 2.62), (0.1, 1.9), (-0.45, 1.25), (-1.25, 1.02)])
    spine(s, [((-1.68, 2.05), 0.08), ((-1.38, 2.34), 0.09), ((-1.04, 2.62), 0.1), ((-0.66, 2.82), 0.11)])

    for i in range(5):
        t = i * 0.3
        cut(s, [(-1.28 + t, 2.2 + t * 0.35), (-1.16 + t, 2.22 + t * 0.35), (-0.92 + t * 1.05, 1.52 + t * 0.3), (-1.04 + t * 1.05, 1.5 + t * 0.3)])

    shape(s, [(-0.2, 2.75), (-0.45, 3.32), (-0.15, 3.88), (0.42, 3.98), (0.82, 3.65), (0.72, 3.28), (0.95, 3.0), (0.62, 2.95), (0.72, 2.5), (0.36, 2.55), (0.18, 2.72)])
    socket(s, (0.42, 3.55), 1.0, 0.75)
    cut(s, [(0.74, 3.08), (0.28, 3.1), (0.4, 2.72), (0.6, 2.7)])
    bone(s, [(0.05, 2.45), (1.45, 2.6), (2.5, 2.15)], [0.46, 0.3, 0.17])
    hand(s, (2.5, 2.15), math.radians(100), 0.92, 1.25, 0.08)
    bone(s, [(-0.2, 1.6), (0.55, 0.92), (0.9, 0.3)], [0.36, 0.25, 0.14])
    hand(s, (0.9, 0.3), math.radians(100), 0.6, 1.2, 0.5)
    s.wisps((-2.0, 1.25), (-1.0, -0.42), 1.3, 5, 0.3)


ROWS = [("HANDS", [hands_a, hands_b, hands_c]), ("FACE", [face_a, face_b, face_c]), ("TORSO", [torso_a, torso_b, torso_c])]


def label(text, at, size):
    curve = bpy.data.curves.new("label", "FONT")
    curve.body = text
    curve.size = size
    curve.materials.append(GUIDE_LOOK)
    thing = bpy.data.objects.new("label", curve)
    thing.location = (at[0], at[1], 0.3)
    bpy.context.scene.collection.objects.link(thing)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    global INK_LOOK, PAPER_LOOK, GUIDE_LOOK
    INK_LOOK = material("ink", INK)
    PAPER_LOOK = material("paper", PAPER)
    GUIDE_LOOK = material("guide", (0.3, 0.27, 0.22, 1.0))
    scene = bpy.context.scene
    world = bpy.data.worlds.new("paper")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = PAPER
    scene.world = world
    scene.view_settings.view_transform = "Standard"
    scene.render.engine = "BLENDER_EEVEE"
    width = CELL.x * 3 + 1.2
    height = CELL.y * 3 + 0.4
    scene.render.resolution_x = 2100
    scene.render.resolution_y = int(2100 * height / width)
    scene.render.filepath = OUT
    sheet = Sheet()

    for row, (name, takes) in enumerate(ROWS):
        y = height - (row + 1) * CELL.y

        for column, draw in enumerate(takes):
            x = 1.2 + column * CELL.x + CELL.x * 0.5
            sheet.origin = Vector((x - 0.35, y + 0.42))
            sheet.size = 0.82
            draw(sheet)
            sheet.origin = Vector((x + CELL.x * 0.5 - 0.72, y + 0.28))
            sheet.size = 0.16
            draw(sheet)
            label("ABC"[column], (x - CELL.x * 0.5 + 0.1, y + CELL.y - 0.62), 0.5)

        label(name, (0.08, y + CELL.y * 0.5), 0.22)

    camera = bpy.data.cameras.new("look")
    camera.type = "ORTHO"
    camera.ortho_scale = width
    eye = bpy.data.objects.new("look", camera)
    eye.location = (width * 0.5, height * 0.5, 10.0)
    scene.collection.objects.link(eye)
    scene.camera = eye
    bpy.ops.render.render(write_still=True)


main()
