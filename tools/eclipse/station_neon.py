"""The Zócalo station's neon (docs/superpowers/specs/2026-10-31-station-machinery-design.md; plan
docs/superpowers/plans/2026-10-31-station-machinery.md, Task 2): the symbols the station's signs carry in tube, and the
Light Company's crowned blade sign.

The symbols stand in for words (the user writes those): an arrow (straight ahead), a marigold, an eye, a skull, a
serpent, a hand with an eye in its palm. Each is tube only (slot `neon`, drawn by Neon's shader in game), in the plane
y = 0 facing -y, centred on the origin, fitting a hanging board's face (0.32 m square).

The blade sign: the Company's crowned vertical (Deadlock's blade signs as reference): a stepped foot, an iron board
framed in brass, its blank face both sides (the user's words), a stepped deco crown. Its neon (outline_blade, a symbol)
hangs in front of each face. Frame: standing on z = 0, centred on x = 0 and y = 0, its faces toward -y and +y.

    Blender -b --factory-startup --python tools/eclipse/station_neon.py
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import common  # noqa: E402
from underground_shapes import box, pipe, smooth_object, turned  # noqa: E402

NAME = "station_neon"
ATLAS = 2048
SLOTS = ["neon", "iron", "brass", "sign", "steel"]

# A tube's radius (m), its loops' points.
TUBE_R = 0.012
ROUND = 20

# The blade: its board (m: half-width, half-depth, foot, top), its face (m: half-width, foot, top, how far proud of the
# board), the brass frame round the face (m: width, how far proud), the stepped foot and crown (m: half-width, from,
# to), the face's middle (for the ray that finds it).
BOARD = (0.25, 0.05, 0.15, 1.65)
FACE = (0.19, 0.24, 1.56, 0.035)
FRAME = (0.04, 0.07)
# (Its foot narrow enough to stand on a turnstile pylon's crown, 0.22 × 0.44: m half along x, half along y, from, to.)
FOOT = [(0.1, 0.2, 0.0, 0.06), (0.08, 0.12, 0.06, 0.15)]
CROWN = [(0.3, 1.65, 1.75), (0.22, 1.75, 1.85), (0.14, 1.85, 1.95)]
FACE_AT = 0.5
# The neon's own hanging board (it replaces the shell's sign_board where neon hangs: m wide, tall, thick), hung on two
# rods this far under the ceiling (its top); its blank face both sides (m: wide, tall, round the board's middle, how
# far proud of the board), the brass frame round it (m: width, how far proud); the tubes hang in front of the frame.
NEON_BOARD = (2.4, 0.62, 0.06)
NEON_DROP = 0.6
NEON_FACE = (2.3, 0.54)
NEON_FACE_PROUD = 0.035
NEON_FRAME = (0.04, 0.07)
# The neon outline round a blade's face (m: half-width, foot, top), its peak stepped like the crown.
OUTLINE = (0.165, 0.28, 1.52)


def _loop(m, points):
    pipe(m, [(x, 0.0, z) for x, z in points], TUBE_R, 8, "neon", closed=True)


def _line(m, points):
    pipe(m, [(x, 0.0, z) for x, z in points], TUBE_R, 8, "neon")


def _ring(cx, cz, rx, rz=None, n=ROUND):
    rz = rx if rz is None else rz
    return [(cx + rx * math.cos(2 * math.pi * k / n), cz + rz * math.sin(2 * math.pi * k / n)) for k in range(n)]


def symbol_arrow(m):
    _line(m, [(0.0, -0.15), (0.0, 0.13)])
    _line(m, [(-0.09, 0.05), (0.0, 0.145), (0.09, 0.05)])


def symbol_marigold(m):
    _loop(m, _ring(0.0, 0.0, 0.04, n=16))
    # (Seven petals, each round enough at its tip that the tube never pinches.)
    for k in range(7):
        a = 2 * math.pi * k / 7
        c, s = math.cos(a), math.sin(a)
        petal = [(0.105 * c + 0.045 * math.cos(t) * c - 0.03 * math.sin(t) * s,
                  0.105 * s + 0.045 * math.cos(t) * s + 0.03 * math.sin(t) * c)
                 for t in (2 * math.pi * j / 14 for j in range(14))]
        _loop(m, petal)


def symbol_eye(m):
    xs = [-0.15 + 0.3 * k / 12 for k in range(13)]
    upper = [(x, 0.08 * (1 - (x / 0.15) ** 2)) for x in xs]
    lower = [(x, -0.07 * (1 - (x / 0.15) ** 2)) for x in reversed(xs[1:-1])]
    _loop(m, upper + lower)
    _loop(m, _ring(0.0, 0.0, 0.045, n=16))


def symbol_skull(m):
    cranium = [(0.12 * math.cos(a), 0.03 + 0.12 * math.sin(a))
               for a in (math.radians(-35 + 250 * k / 14) for k in range(15))]
    jaw = [(-0.085, -0.075), (-0.06, -0.13), (0.06, -0.13), (0.085, -0.075)]
    _loop(m, cranium + jaw)
    for x in (-0.048, 0.048):
        _loop(m, _ring(x, 0.01, 0.03, n=12))
    _line(m, [(-0.016, -0.045), (0.0, -0.07), (0.016, -0.045)])


def symbol_serpent(m):
    body = [(-0.14 + 0.24 * k / 16, 0.07 * math.sin(math.pi * (0.24 * k / 16) / 0.12)) for k in range(17)]
    _line(m, body)
    hx, hz = 0.125, body[-1][1]
    _loop(m, _ring(hx, hz, 0.026, 0.02, n=12))
    _line(m, [(hx + 0.026, hz), (0.16, hz + 0.012)])


def symbol_hand(m):
    # (The palm round its eye, four fingers up from it, the thumb out: the folk hand that wards the evil eye.)
    _loop(m, _ring(0.03, -0.065, 0.085, 0.075, n=20))
    _loop(m, _ring(0.03, -0.065, 0.028, n=12))
    for x, top in ((-0.03, 0.1), (0.01, 0.15), (0.05, 0.15), (0.09, 0.11)):
        _line(m, [(x, 0.0), (x, top)])
    _line(m, [(-0.05, -0.04), (-0.12, 0.02)])


def outline_blade(m):
    # (Round the face, its top stepped up in the middle as the crown is: Deadlock's crowned vertical in tube.)
    w, z0, z1 = OUTLINE
    _loop(m, [(-w, z0), (w, z0), (w, z1 - 0.12), (w * 0.6, z1 - 0.12), (w * 0.6, z1 - 0.06), (w * 0.3, z1 - 0.06),
              (w * 0.3, z1), (-w * 0.3, z1), (-w * 0.3, z1 - 0.06), (-w * 0.6, z1 - 0.06), (-w * 0.6, z1 - 0.12),
              (-w, z1 - 0.12)])


def neon_board(m):
    """The neon's hanging board: rods from the ceiling, an iron board, its blank face both sides (the user's words
    between the arrow and the symbol), framed in brass."""
    w, h, t = NEON_BOARD
    top, bottom = -NEON_DROP, -NEON_DROP - h
    mid = (top + bottom) / 2
    for x in (-w / 2 + 0.3, w / 2 - 0.3):
        pipe(m, [(x, 0.0, 0.0), (x, 0.0, top - 0.02)], 0.014, 6, "steel")
    box(m, (-w / 2, -t / 2, bottom), (w / 2, t / 2, top), "iron", r=0.012)
    fw, fh = NEON_FACE
    fr, out = NEON_FRAME
    for side in (-1, 1):
        y0, y1 = sorted((side * t / 2, side * (t / 2 + NEON_FACE_PROUD)))
        box(m, (-fw / 2, y0, mid - fh / 2), (fw / 2, y1, mid + fh / 2), "sign", r=0.0)
        y0, y1 = sorted((side * t / 2, side * (t / 2 + out)))
        x0, x1, z0, z1 = -fw / 2, fw / 2, mid - fh / 2, mid + fh / 2
        for a, b in (((x0 - fr, z0 - fr), (x1 + fr, z0)), ((x0 - fr, z1), (x1 + fr, z1 + fr)), ((x0 - fr, z0), (x0, z1)),
                     ((x1, z0), (x1 + fr, z1))):
            box(m, (a[0], y0, a[1]), (b[0], y1, b[1]), "brass", r=0.0)


def blade_company(m):
    hw, hd, b0, b1 = BOARD
    for hx, hy, z0, z1 in FOOT:
        box(m, (-hx, -hy, z0), (hx, hy, z1), "iron", r=0.01)
    box(m, (-hw, -hd, b0), (hw, hd, b1), "iron", r=0.015)
    fw, f0, f1, proud = FACE
    w, out = FRAME
    for side in (-1, 1):
        y0, y1 = sorted((side * hd, side * (hd + proud)))
        box(m, (-fw, y0, f0), (fw, y1, f1), "sign", r=0.0)
        y0, y1 = sorted((side * hd, side * (hd + out)))
        for a, b in (((-fw - w, f0 - w), (fw + w, f0)), ((-fw - w, f1), (fw + w, f1 + w)),
                     ((-fw - w, f0), (-fw, f1)), ((fw, f0), (fw + w, f1))):
            box(m, (a[0], y0, a[1]), (b[0], y1, b[1]), "brass", r=0.0)
    for half, z0, z1 in CROWN:
        box(m, (-half, -hd - 0.02, z0), (half, hd + 0.02, z1), "brass" if z0 == CROWN[0][1] else "iron", r=0.012)


PIECES = [("symbol_arrow", symbol_arrow), ("symbol_marigold", symbol_marigold), ("symbol_eye", symbol_eye),
          ("symbol_skull", symbol_skull), ("symbol_serpent", symbol_serpent), ("symbol_hand", symbol_hand),
          ("outline_blade", outline_blade), ("blade_company", blade_company), ("neon_board", neon_board)]

BUDGET = {n: 6000 for n, _ in PIECES}
SLIVER = {n: 0.004 for n, _ in PIECES}


def build():
    common.reset()
    for name, f in PIECES:
        smooth_object(name, f)


def main():
    build()
    common.export_piece(NAME, ATLAS, SLOTS, out=common.ROOT / "assets" / "eclipse" / "kit", sets_each=True,
                        budget=max(BUDGET.values()), sliver=min(SLIVER.values()), pack_margin=0.0015)


if __name__ == "__main__":
    main()
