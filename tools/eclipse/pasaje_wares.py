"""The Pasaje's wares (docs/superpowers/specs/2026-10-26-pasaje-market-design.md; plan
docs/superpowers/plans/2026-10-26-pasaje-market.md, Task 5): each trade's goods, named for it (<trade>_<what>), and
the bare bulb hung over a counter. maps/pasaje.gd sets them on the counters, shelves, barrow and floor of the stalls
(tools/eclipse/pasaje_stalls.py) and hangs the hung ones from their rails.

Each piece is built about its own foot: x along the stall, -y toward the street, z up from what it stands on (z = 0);
a hung piece (HUNG) hangs from its hook at its origin, everything below it.

    Blender -b --factory-startup --python tools/eclipse/pasaje_wares.py
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import common  # noqa: E402
import underground_shapes  # noqa: E402
from underground_shapes import box, pipe, smooth_object, stud, turned  # noqa: E402

NAME = "pasaje_wares"
ATLAS = 4096
SLOTS = ["wood", "tin", "steel", "iron", "brass", "clay", "cloth", "burlap", "paper", "herb", "herb_dry", "chile",
         "marigold", "wax", "wax_white", "wax_red", "bread", "corn", "glass", "print_saint", "palm", "silver",
         "velvet_purple", "lacquer_black", "enamel", "rubber", "glass_bulb"]

rng = random.Random(1932)

TRADES = ("tamales", "radios", "candles", "copal", "milagros", "saints", "atole", "sweets", "tortas", "fruit",
          "lottery", "herbs", "chiles", "flowers", "coffee", "tinsmith")
HUNG = {"herbs_bundles", "chiles_ristras", "tinsmith_lanterns", "bulb"}
# Where the steam leaves each steaming piece (its mouth, about its foot).
MOUTHS = {"atole_urn": (0.0, 0.0, 0.62), "coffee_pot": (0.0, 0.0, 0.36)}


# --- shapes --------------------------------------------------------------------------------------

def ball(m, x, y, z, r, slot, sides=8):
    """A round thing (a fruit, a flower's head, a sweet) about (x, y, z)."""
    turned(m, [(r * 0.3, -r * 0.95), (r * 0.8, -r * 0.6), (r, 0.0), (r * 0.8, r * 0.6), (r * 0.3, r * 0.95)], sides,
           slot, at=(x, y, z), twist=rng.uniform(0, 1))


def cyl(m, x, y, z, r, h, slot, sides=10):
    turned(m, [(r, z), (r, z + h)], sides, slot, at=(x, y, 0.0))


def crate(m, x0, x1, y0, y1, h, fill, fill_h):
    """A slatted crate, `fill` heaped in it to `fill_h` (its foot well over the crate's floor)."""
    t = 0.032
    box(m, (x0, y0, 0.0), (x1, y1, 0.035), "wood", r=0.0)
    for ya, yb in ((y0, y0 + t), (y1 - t, y1)):
        for z0, z1 in ((0.035, h * 0.45), (h * 0.55, h)):
            box(m, (x0, ya, z0), (x1, yb, z1), "wood", r=0.0)
    for xa, xb in ((x0, x0 + t), (x1 - t, x1)):
        box(m, (xa, y0 + t, 0.035), (xb, y1 - t, h), "wood", r=0.0)
    if fill:
        box(m, (x0 + t + 0.012, y0 + t + 0.012, 0.07), (x1 - t - 0.012, y1 - t - 0.012, fill_h), fill, r=0.0)


def basket(m, x, y, r, h, slot="palm"):
    turned(m, [(r * 0.8, 0.0), (r, h * 0.7), (r * 1.06, h)], 12, slot, at=(x, y, 0.0), jitter=0.03)


def sack(m, x, y, r, h, heap=None):
    """An open sack, its top rolled down; `heap` (a slot) mounded in its mouth."""
    turned(m, [(r * 0.85, 0.0), (r, h * 0.3), (r * 0.95, h * 0.8), (r * 1.05, h)], 10, "burlap", at=(x, y, 0.0),
           jitter=0.08, twist=rng.uniform(0, 1))
    if heap:
        turned(m, [(r * 0.98, h), (r * 0.8, h + 0.05), (r * 0.4, h + 0.09), (r * 0.1, h + 0.1)], 10, heap, at=(x, y, 0.0),
               jitter=0.1)


def jar(m, x, y, r, h, fill):
    """A glass jar, `fill` inside it (set well in from the glass), a tin lid."""
    cyl(m, x, y, 0.0, r, h, "glass", 12)
    turned(m, [(r - 0.035, 0.04), (r - 0.035, h - 0.05)], 10, fill, at=(x, y, 0.0))
    cyl(m, x, y, h, r + 0.006, 0.03, "tin", 12)


# --- the food ------------------------------------------------------------------------------------

def _tamale(m, x, y, z, a):
    box(m, (x - 0.06, y - 0.025, z - 0.015), (x + 0.06, y + 0.025, z + 0.015), "corn", r=0.0, turn=(0.0, 0.15, a))


def tamales_basket(m):
    """A basket of tamales under a cloth, a few in their husks laid on top."""
    basket(m, 0.0, 0.0, 0.22, 0.2)
    turned(m, [(0.24, 0.2), (0.2, 0.25), (0.1, 0.28), (0.03, 0.29)], 12, "cloth", at=(0.0, 0.0, 0.0), jitter=0.05)
    for k in range(4):
        a = k * 1.6
        _tamale(m, 0.07 * math.cos(a), 0.07 * math.sin(a), 0.29, a)


def tamales_crate(m):
    """A crate of dried corn husks for wrapping."""
    crate(m, -0.25, 0.25, -0.18, 0.18, 0.24, "corn", 0.26)


def tortas_board(m):
    """The bolillos on their board, ready to split."""
    box(m, (-0.25, -0.16, 0.0), (0.25, 0.16, 0.035), "wood", r=0.0)
    for k in range(5):
        x = -0.16 + 0.08 * k
        y = rng.uniform(-0.06, 0.06)
        turned(m, [(0.012, -0.08), (0.03, -0.065), (0.036, 0.0), (0.03, 0.065), (0.012, 0.08)], 8, "bread",
               at=(x, y, 0.035 + 0.034), lean=math.pi / 2, towards=0.0)


def tortas_jars(m):
    """Jars of chiles en escabeche."""
    for k in range(3):
        jar(m, -0.18 + 0.18 * k, 0.0, 0.075, 0.2, "chile")


def atole_urn(m):
    """The aluminium urn of atole on its burner, its tap at the front."""
    cyl(m, 0.0, 0.0, 0.0, 0.2, 0.08, "iron", 12)
    turned(m, [(0.17, 0.08), (0.19, 0.12), (0.19, 0.52), (0.16, 0.56)], 14, "silver", at=(0.0, 0.0, 0.0))
    turned(m, [(0.165, 0.56), (0.12, 0.6), (0.03, 0.62)], 12, "silver", at=(0.0, 0.0, 0.0))
    pipe(m, [(0.0, -0.17, 0.18), (0.0, -0.25, 0.18), (0.0, -0.25, 0.14)], 0.015, 6, "brass")


def atole_cups(m):
    """Stacks of clay jarritos."""
    for k, x in enumerate((-0.12, 0.0, 0.12)):
        n = 3 + k % 2
        profile = [(0.03, 0.0)]
        for i in range(n):
            profile += [(0.045, 0.07 * (i + 1)), (0.032, 0.07 * (i + 1))] if i < n - 1 else [(0.045, 0.07 * (i + 1))]
        turned(m, profile, 10, "clay", at=(x, rng.uniform(-0.03, 0.03), 0.0))


def coffee_pot(m):
    """The enamel coffee pot on its burner."""
    cyl(m, 0.0, 0.0, 0.0, 0.15, 0.07, "iron", 12)
    turned(m, [(0.12, 0.07), (0.14, 0.12), (0.12, 0.3), (0.07, 0.34), (0.04, 0.36)], 12, "enamel", at=(0.0, 0.0, 0.0))
    pipe(m, [(0.0, -0.11, 0.14), (0.0, -0.2, 0.26), (0.0, -0.22, 0.29)], 0.016, 6, "enamel")
    pipe(m, [(0.0, 0.11, 0.26), (0.0, 0.19, 0.24), (0.0, 0.18, 0.14), (0.0, 0.12, 0.12)], 0.012, 6, "lacquer_black")


def coffee_sacks(m):
    """Sacks of beans under the counter's end."""
    sack(m, -0.17, 0.0, 0.16, 0.4, "lacquer_black")
    sack(m, 0.17, 0.05, 0.15, 0.36, "lacquer_black")


def fruit_pile(m):
    """Oranges mounded on the barrow, limes at one end."""
    for i in range(6):
        for j in range(3):
            ball(m, -0.45 + 0.13 * i, -0.13 + 0.13 * j, 0.057, 0.06, "herb" if i > 4 else "marigold")
    for i in range(5):
        for j in range(2):
            ball(m, -0.39 + 0.13 * i, -0.065 + 0.13 * j, 0.147, 0.06, "herb" if i > 3 else "marigold")


def fruit_crates(m):
    """Two crates stacked by the barrow, mangoes in the top one."""
    crate(m, -0.24, 0.24, -0.17, 0.17, 0.26, None, 0.0)
    box(m, (-0.2, -0.13, 0.26), (0.2, 0.13, 0.3), "wood", r=0.0)
    for i in range(3):
        for j in range(2):
            ball(m, -0.13 + 0.13 * i, -0.06 + 0.12 * j, 0.36, 0.06, "marigold")


# --- her trades and the others ---------------------------------------------------------------------

def candles_rack(m):
    """A stepped rack of veladoras, three rows."""
    for k in range(3):
        box(m, (-0.45, -0.3 + 0.12 * k, 0.0), (0.45, -0.18 + 0.12 * k, 0.1 * (k + 1)), "wood", r=0.0)
        for i in range(6):
            cyl(m, -0.375 + 0.15 * i, -0.24 + 0.12 * k, 0.1 * (k + 1), 0.032, 0.2, "wax_white" if (i + k) % 3 else "wax_red", 8)


def candles_bundles(m):
    """Tapers laid in two rows on the counter, each row a little askew."""
    for b in range(2):
        for k in range(6):
            y = -0.17 + 0.034 * k + 0.2 * b
            shift = rng.uniform(-0.03, 0.03)
            pipe(m, [(-0.2 + shift, y, 0.011), (0.2 + shift, y, 0.011)], 0.012, 6, "wax_white" if b else "wax")


def copal_censers(m):
    """Clay sahumadores: a cup on a stem on a foot."""
    for x in (-0.2, 0.0, 0.2):
        turned(m, [(0.07, 0.0), (0.06, 0.02), (0.025, 0.04), (0.025, 0.12), (0.06, 0.14), (0.085, 0.2), (0.08, 0.21)], 10,
               "clay", at=(x, rng.uniform(-0.04, 0.04), 0.0))


def copal_baskets(m):
    """Small baskets of copal resin."""
    for x in (-0.14, 0.14):
        basket(m, x, 0.0, 0.11, 0.1)
        turned(m, [(0.11, 0.1), (0.08, 0.14), (0.03, 0.16)], 10, "wax", at=(x, 0.0, 0.0), jitter=0.15)


def milagros_board(m):
    """A velvet board on a stand, tin milagros pinned to it."""
    box(m, (-0.3, -0.02, 0.0), (0.3, 0.02, 0.6), "velvet_purple", r=0.0)
    pipe(m, [(0.0, 0.02, 0.5), (0.0, 0.25, 0.012)], 0.012, 6, "wood")
    for i in range(5):
        for j in range(4):
            stud(m, (-0.22 + 0.11 * i, -0.02, 0.1 + 0.13 * j), math.pi / 2, 0.0, slot="tin", r=0.022)


def milagros_tray(m):
    """A tray of loose milagros."""
    box(m, (-0.2, -0.14, 0.0), (0.2, 0.14, 0.035), "wood", r=0.0)
    for i in range(6):
        for j in range(4):
            stud(m, (-0.15 + 0.06 * i + rng.uniform(-0.01, 0.01), -0.09 + 0.06 * j, 0.035), 0.0, 0.0, slot="tin", r=0.02)


def _framed(m, x, w, h, lean_back=0.0):
    """A framed print standing on its foot, a strut behind it."""
    b, deep = 0.04, 0.035
    box(m, (x - w / 2, -deep, 0.0), (x + w / 2, 0.02, b), "wood", r=0.0)
    box(m, (x - w / 2, -deep, h - b), (x + w / 2, 0.02, h), "wood", r=0.0)
    for xa, xb in ((x - w / 2, x - w / 2 + b), (x + w / 2 - b, x + w / 2)):
        box(m, (xa, -deep, b), (xb, 0.02, h - b), "wood", r=0.0)
    box(m, (x - w / 2 + b, 0.0, b), (x + w / 2 - b, 0.02, h - b), "print_saint", r=0.0)
    pipe(m, [(x, 0.02, h * 0.7), (x, 0.02 + h * 0.4, 0.012)], 0.01, 6, "wood")


def saints_prints(m):
    """Framed prints of the saints stood along the counter."""
    _framed(m, -0.3, 0.26, 0.36)
    _framed(m, 0.0, 0.3, 0.44)
    _framed(m, 0.3, 0.24, 0.32)


def saints_frames(m):
    """A stack of empty frames."""
    for k in range(4):
        a = rng.uniform(-0.12, 0.12)
        box(m, (-0.18, -0.13, 0.04 * k), (0.18, 0.13, 0.04 * k + 0.035), "wood", r=0.0, turn=(0.0, 0.0, a))


def sweets_jars(m):
    """Big glass jars of sweets."""
    for k, fill in enumerate(("wax_red", "marigold", "herb")):
        jar(m, -0.2 + 0.2 * k, 0.0, 0.09, 0.26, fill)


def sweets_trays(m):
    """Trays of cocadas and alegrías in rows."""
    for t, slot in enumerate(("wax", "bread")):
        x0 = -0.42 + 0.44 * t
        box(m, (x0, -0.15, 0.0), (x0 + 0.38, 0.15, 0.035), "tin", r=0.0)
        for i in range(5):
            for j in range(4):
                box(m, (x0 + 0.02 + 0.07 * i, -0.13 + 0.065 * j, 0.035), (x0 + 0.07 + 0.07 * i, -0.08 + 0.065 * j, 0.075),
                    slot, r=0.0)


def radios_sets(m):
    """Cathedral radios waiting to be mended, their dials and knobs."""
    for x, s in ((-0.22, 1.0), (0.2, 0.85)):
        w, d, h = 0.3 * s, 0.2 * s, 0.26 * s
        box(m, (x - w / 2, -d / 2, 0.0), (x + w / 2, d / 2, h), "wood", r=0.0)
        turned(m, [(w / 2, -(d / 2 - 0.035)), (w / 2, d / 2 - 0.035)], 14, "wood", at=(x, 0.0, h), lean=math.pi / 2)
        for kx in (-w / 4, 0.0, w / 4):
            stud(m, (x + kx, -d / 2, 0.05), math.pi / 2, 0.0, slot="lacquer_black", r=0.018)


def radios_parts(m):
    """A tray of valves and a coil of wire."""
    box(m, (-0.2, -0.12, 0.0), (0.2, 0.12, 0.03), "tin", r=0.0)
    for i in range(3):
        for j in range(2):
            x, y = -0.15 + 0.07 * i, -0.05 + 0.1 * j
            cyl(m, x, y, 0.03, 0.022, 0.035, "steel", 8)
            turned(m, [(0.018, 0.065), (0.02, 0.1), (0.008, 0.12)], 8, "glass", at=(x, y, 0.0))
    pipe(m, [(0.11 + 0.06 * math.cos(2 * math.pi * k / 12), 0.06 * math.sin(2 * math.pi * k / 12), 0.042)
             for k in range(12)], 0.012, 6, "brass", closed=True)


def lottery_board(m):
    """The seller's board on its stand, tickets hung on strings across its front."""
    box(m, (-0.3, -0.02, 0.0), (0.3, 0.02, 0.7), "wood", r=0.0)
    pipe(m, [(0.0, 0.02, 0.6), (0.0, 0.3, 0.012)], 0.012, 6, "wood")
    for z in (0.62, 0.36):
        pipe(m, [(-0.28, -0.07, z), (0.28, -0.07, z)], 0.006, 4, "rubber")
        for i in range(6):
            x = -0.24 + 0.095 * i
            box(m, (x - 0.035, -0.072, z - 0.2), (x + 0.035, -0.06, z - 0.004), "paper", r=0.0)


def lottery_stool(m):
    """The seller's stool."""
    for a in (0.3, 2.4, 4.5):
        pipe(m, [(0.12 * math.cos(a), 0.12 * math.sin(a), 0.0), (0.06 * math.cos(a), 0.06 * math.sin(a), 0.42)], 0.016,
             6, "wood")
    cyl(m, 0.0, 0.0, 0.42, 0.16, 0.04, "wood", 12)


def tinsmith_lanterns(m):
    """Tin lanterns hung from the beam, each on its ring."""
    for x, drop in ((-0.4, 0.25), (0.0, 0.4), (0.4, 0.3)):
        pipe(m, [(x, 0.0, 0.0), (x, 0.0, -drop)], 0.006, 4, "steel")
        top = -drop
        turned(m, [(0.03, top - 0.02), (0.1, top - 0.06), (0.1, top - 0.26), (0.08, top - 0.3), (0.06, top - 0.32)], 8,
               "tin", at=(x, 0.0, 0.0))


def tinsmith_sheets(m):
    """Sheets of tin stacked, offset as they were dropped."""
    for k in range(3):
        box(m, (-0.3, -0.2, 0.035 * k), (0.3, 0.2, 0.035 * (k + 1) - 0.001), "tin", r=0.0,
            turn=(0.0, 0.0, rng.uniform(-0.1, 0.1)))


def herbs_bundles(m):
    """Dried bundles hung by their stems from the beam."""
    for k in range(6):
        x = -0.6 + 0.24 * k
        drop = rng.uniform(0.06, 0.14)
        pipe(m, [(x, 0.0, 0.0), (x, 0.0, -drop)], 0.006, 4, "rubber")
        turned(m, [(0.02, -drop), (0.05, -drop - 0.1), (0.08, -drop - 0.28), (0.04, -drop - 0.34)], 8, "herb_dry",
               at=(x, 0.0, 0.0), jitter=0.2, twist=rng.uniform(0, 1))


def herbs_sacks(m):
    """Open sacks of herbs and roots."""
    sack(m, -0.3, 0.0, 0.15, 0.36, "herb")
    sack(m, 0.0, 0.03, 0.16, 0.4, "herb_dry")
    sack(m, 0.3, -0.02, 0.14, 0.34, "herb")


def chiles_ristras(m):
    """Ristras of dried chiles on their cords."""
    for x in (-0.3, 0.0, 0.3):
        drop = rng.uniform(0.55, 0.75)
        pipe(m, [(x, 0.0, 0.0), (x, 0.0, -drop)], 0.006, 4, "rubber")
        for k in range(10):
            z = -0.08 - (drop - 0.1) * k / 9
            a = k * 2.2
            turned(m, [(0.018, 0.0), (0.012, -0.07), (0.004, -0.09)], 6, "chile",
                   at=(x + 0.02 * math.cos(a), 0.02 * math.sin(a), z), lean=0.5, towards=a)


def chiles_baskets(m):
    """Baskets heaped with dried chiles."""
    for x in (-0.18, 0.18):
        basket(m, x, 0.0, 0.15, 0.14)
        turned(m, [(0.15, 0.14), (0.11, 0.19), (0.04, 0.22)], 10, "chile", at=(x, 0.0, 0.0), jitter=0.15)


def flowers_buckets(m):
    """Tin buckets of marigolds and gladioli."""
    for k, (x, slot) in enumerate(((-0.25, "marigold"), (0.0, "wax_white"), (0.25, "marigold"))):
        turned(m, [(0.1, 0.0), (0.13, 0.3)], 12, "tin", at=(x, 0.0, 0.0))
        for i in range(7):
            a = 2 * math.pi * i / 7
            r = 0.07
            top = 0.42 + rng.uniform(0.0, 0.12)
            pipe(m, [(x + 0.03 * math.cos(a), 0.03 * math.sin(a), 0.29), (x + r * math.cos(a), r * math.sin(a), top)],
                 0.006, 4, "herb")
            ball(m, x + r * math.cos(a), r * math.sin(a), top + 0.03, 0.035, slot, 6)


def flowers_bunches(m):
    """Bunches laid on the counter, wrapped in paper cones."""
    for k in range(3):
        y = -0.12 + 0.12 * k
        turned(m, [(0.012, 0.0), (0.06, 0.24)], 8, "paper", at=(-0.12, y, 0.06), lean=math.pi / 2, towards=-math.pi / 2)
        for i in range(4):
            ball(m, 0.14 + rng.uniform(0.0, 0.04), y + rng.uniform(-0.035, 0.035), 0.06 + rng.uniform(-0.02, 0.03), 0.035,
                 "marigold", 6)


def bulb(m):
    """A bare bulb on its cord, its brass socket."""
    pipe(m, [(0.0, 0.0, 0.0), (0.0, 0.0, -0.16)], 0.006, 4, "rubber")
    cyl(m, 0.0, 0.0, -0.2, 0.018, 0.045, "brass", 8)
    turned(m, [(0.012, -0.2), (0.028, -0.215), (0.034, -0.245), (0.024, -0.27), (0.008, -0.278)], 10, "glass_bulb",
           at=(0.0, 0.0, 0.0))


PIECES = [("tamales_basket", tamales_basket), ("tamales_crate", tamales_crate), ("tortas_board", tortas_board),
          ("tortas_jars", tortas_jars), ("atole_urn", atole_urn), ("atole_cups", atole_cups), ("coffee_pot", coffee_pot),
          ("coffee_sacks", coffee_sacks), ("fruit_pile", fruit_pile), ("fruit_crates", fruit_crates),
          ("candles_rack", candles_rack), ("candles_bundles", candles_bundles), ("copal_censers", copal_censers),
          ("copal_baskets", copal_baskets), ("milagros_board", milagros_board), ("milagros_tray", milagros_tray),
          ("saints_prints", saints_prints), ("saints_frames", saints_frames), ("sweets_jars", sweets_jars),
          ("sweets_trays", sweets_trays), ("radios_sets", radios_sets), ("radios_parts", radios_parts),
          ("lottery_board", lottery_board), ("lottery_stool", lottery_stool), ("tinsmith_lanterns", tinsmith_lanterns),
          ("tinsmith_sheets", tinsmith_sheets), ("herbs_bundles", herbs_bundles), ("herbs_sacks", herbs_sacks),
          ("chiles_ristras", chiles_ristras), ("chiles_baskets", chiles_baskets), ("flowers_buckets", flowers_buckets),
          ("flowers_bunches", flowers_bunches), ("bulb", bulb)]

BUDGET = {name: 3000 for name, _ in PIECES}
SLIVER = {name: 0.004 for name in BUDGET}


def build():
    common.reset()
    underground_shapes.rng = rng
    rng.seed(1932)

    for name, f in PIECES:
        smooth_object(name, f)


def main():
    build()
    common.export_piece(NAME, ATLAS, SLOTS, out=common.ROOT / "assets" / "eclipse" / "kit", sets_each=True,
                        budget=max(BUDGET.values()), sliver=min(SLIVER.values()))


if __name__ == "__main__":
    main()
