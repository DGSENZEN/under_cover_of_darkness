"""The coast's rock, plants and life (kit_coast; docs/superpowers/refs/
coast_life.md): rubble at the east cliff's foot with boulders on it and a
block undercut at the waterline, tors along its top, gorse pruned into
cushions at its edge and grown into bushes behind, stone pines in the
shelter and maritime pines leaning from the sea, sea fennel at the edge and
on the rubble; the west spit's rock in blocks down to the water; and the
harbour's life: gulls on the Ribeira's ridges and the quay's edge, nets
drying on the cave's beach and the spit, washing across the fronts, the
tavern's bush under the arcade, smoke from the chimneys."""

import math
import random

import kit_iberian as ki
import kit_recipes
import terrain

from . import ARCADE_FRONT, BLOWHOLE, QUAY, rib_x
from .ground import COAST, MOUTH, SPIT, _ripple, headland, inland, spit, west_bank
from .ribeira import HOUSES, ROOF_HOUSE

# Where nothing is put: the cave's mouth and beach, the blowhole's shaft, the
# mole's root (and the way from the thief's boat), the fort.
CLEAR = [((226.0, 55.0), 12.0), ((230.0, 18.0), 16.0), (BLOWHOLE, 9.0), ((170.0, -8.0), 22.0), ((-75.0, 205.0), 26.0)]
RUBBLE = (-9.0, -2.0)


def _clear(x, z, room=0.0):
    return all(math.hypot(x - c[0], z - c[1]) > r + room for c, r in CLEAR)


def _coast_points(step, rng, segments=None):
    """Points along the east coast every `step` m (each nudged), with the
    way out to sea there (a unit (x, z)), skipping the cave's mouth."""
    out = []

    for i, (a, b) in enumerate(zip(COAST, COAST[1:])):
        if i == MOUTH[0] or (segments is not None and i not in segments):
            continue

        dx, dz = b[0] - a[0], b[1] - a[1]
        length = math.hypot(dx, dz)
        sea = (dz / length, -dx / length)
        t = rng.uniform(0.0, step)

        while t < length:
            out.append((a[0] + dx * t / length, a[1] + dz * t / length, sea))
            t += step * rng.uniform(0.75, 1.25)

    return out


def rubble(x, z):
    """The rubble at the east cliff's foot: from just over high water at
    the cliff down under the sea a few metres out; nothing (far under)
    elsewhere."""
    d = inland(x, z)

    if not (RUBBLE[0] - 0.5 < d < RUBBLE[1] + 0.5) or x < 186.0 or not _clear(x, z, -4.0):
        return -60.0

    t = min(1.0, max(0.0, (RUBBLE[1] - d) / (RUBBLE[1] - RUBBLE[0])))
    return 0.9 - 3.6 * t ** 1.4 + _ripple(x * 2.3, z * 2.1, 0.3)


def _rocks(L, rng):
    # The rubble, and on it boulders, a big one here and there, a ledge or
    # an undercut block at the waterline.
    L.terrain(terrain.grid("cliff_rubble", "cave", 180.0, -14.0, 300.0, 124.0, 1.5, rubble, "rock_shore", surface="stone",
                           keep=lambda ys: min(ys) > -20.0))

    for x, z, sea in _coast_points(11.0, rng):
        if not _clear(x, z, 4.0) or x < 188.0:
            continue

        roll = rng.random()
        out = rng.uniform(3.5, 6.0)
        px, pz = x + sea[0] * out, z + sea[1] * out
        yaw = math.degrees(math.atan2(sea[0], sea[1])) + rng.uniform(-25.0, 25.0)

        if roll < 0.12:
            L.put("notch_rock", (round(x + sea[0] * 3.0, 2), -0.4, round(z + sea[1] * 3.0, 2)), round(yaw, 1), "cave")
        elif roll < 0.25:
            L.put("ledge_b", (round(px, 2), round(rubble(px, pz) - 0.2, 2), round(pz, 2)), round(yaw, 1), "cave")
        elif roll < 0.42:
            L.put("boulder_big", (round(px, 2), round(rubble(px, pz), 2), round(pz, 2)), round(yaw, 1), "cave")
        else:
            name = rng.choice(["boulders_a", "boulders_b", "boulders_c"])
            L.put(name, (round(px, 2), round(rubble(px, pz) + 0.1, 2), round(pz, 2)), round(yaw, 1), "cave")

    # Tors along the top, back from the edge.
    for x, z, sea in _coast_points(15.0, rng):
        back = rng.uniform(7.0, 16.0)
        px, pz = x - sea[0] * back, z - sea[1] * back

        if _clear(px, pz, 4.0):
            L.put(rng.choice(["tor_a", "tor_b", "tor_c", "ledge_a"]), (round(px, 2), round(headland(px, pz), 2), round(pz, 2)),
                  round(rng.uniform(0.0, 360.0), 1), "cave")

    # The west spit: ledges and boulders down its sides to the water, a tor
    # or two off its crest.
    (ax, az), (bx, bz) = SPIT
    length = math.hypot(bx - ax, bz - az)
    along = ((bx - ax) / length, (bz - az) / length)
    side = (along[1], -along[0])
    t = 12.0

    while t < length - 30.0:
        for s in (-1.0, 1.0):
            for _ in range(8):
                off = rng.uniform(5.0, 13.0)
                px, pz = ax + along[0] * t + side[0] * s * off, az + along[1] * t + side[1] * s * off
                y = spit(px, pz)

                if -0.6 < y < 1.6 and _clear(px, pz, 4.0):
                    break
            else:
                continue

            name = rng.choice(["ledge_a", "ledge_b", "boulders_a", "boulders_c", "boulder_big", "notch_rock"])
            L.put(name, (round(px, 2), round(y - 0.3, 2), round(pz, 2)), round(math.degrees(math.atan2(side[0] * s, side[1] * s)) + rng.uniform(-30, 30), 1),
                  "fort")

        if rng.random() < 0.5:
            off = rng.choice((-1.0, 1.0)) * rng.uniform(4.0, 6.0)
            px, pz = ax + along[0] * t + side[0] * off, az + along[1] * t + side[1] * off

            if _clear(px, pz, 6.0):
                L.put(rng.choice(["tor_b", "tor_c"]), (round(px, 2), round(spit(px, pz), 2), round(pz, 2)), round(rng.uniform(0, 360), 1), "fort")

        t += rng.uniform(14.0, 22.0)


def _planting(L, rng):
    # Gorse in cushions along the cliff's edge, sea fennel among them.
    for x, z, sea in _coast_points(2.8, rng):
        back = rng.uniform(1.6, 4.0)
        px, pz = x - sea[0] * back, z - sea[1] * back

        if _clear(px, pz, 2.0):
            name = "fennel_clump" if rng.random() < 0.25 else "gorse_cushion"
            L.put(name, (round(px, 2), round(headland(px, pz) - 0.05, 2), round(pz, 2)), round(rng.uniform(0, 360), 1), "cave")

    # Behind the edge, gorse grown into bushes and grass between, thicker
    # inland.
    placed = []

    while len(placed) < 150:
        px, pz = rng.uniform(186.0, 296.0), rng.uniform(-55.0, 112.0)
        d = inland(px, pz)

        if not (7.0 < d < 60.0) or not _clear(px, pz, 3.0) or any(math.hypot(px - qx, pz - qz) < 4.0 for qx, qz in placed):
            continue

        if rng.random() > min(1.0, 0.3 + d / 40.0):
            continue

        placed.append((px, pz))
        name = "gorse_bush" if rng.random() < 0.55 else "grass_tuft"
        L.put(name, (round(px, 2), round(headland(px, pz) - 0.05, 2), round(pz, 2)), round(rng.uniform(0, 360), 1), "cave")

    # Outcrops out on the top: tors, a ledge, boulders in the heath.
    outcrops = []

    while len(outcrops) < 9:
        px, pz = rng.uniform(190.0, 296.0), rng.uniform(-6.0, 116.0)

        if 18.0 < inland(px, pz) < 90.0 and _clear(px, pz, 6.0) and all(math.hypot(px - qx, pz - qz) > 18.0 for qx, qz in outcrops):
            outcrops.append((px, pz))
            L.put(rng.choice(["tor_a", "tor_b", "tor_c", "ledge_a", "boulders_a", "boulders_b"]), (round(px, 2), round(headland(px, pz), 2), round(pz, 2)),
                  round(rng.uniform(0.0, 360.0), 1), "cave")

    # Maritime pines leaning from the sea near the edge; stone pines in the
    # shelter behind.
    for x, z, sea in _coast_points(38.0, rng):
        back = rng.uniform(14.0, 24.0)
        px, pz = x - sea[0] * back, z - sea[1] * back

        if _clear(px, pz, 6.0):
            L.put("pine_maritime", (round(px, 2), round(headland(px, pz) - 0.1, 2), round(pz, 2)),
                  round(math.degrees(math.atan2(-sea[0], -sea[1])), 1), "cave")

    pines = []

    while len(pines) < 5:
        px, pz = rng.uniform(155.0, 290.0), rng.uniform(-8.0, 112.0)

        if 22.0 < inland(px, pz) < 90.0 and _clear(px, pz, 6.0) and all(math.hypot(px - qx, pz - qz) > 16.0 for qx, qz in pines):
            pines.append((px, pz))
            L.put("pine_stone", (round(px, 2), round(headland(px, pz) - 0.1, 2), round(pz, 2)), round(rng.uniform(0, 360), 1), "cave")

    # A fig out of the rock at the edge, leaning over the sea.
    (ax, az), (bx, bz) = COAST[1], COAST[2]
    x, z = (ax + bx) / 2.0, (az + bz) / 2.0
    sea = ((bz - az) / math.hypot(bx - ax, bz - az), -(bx - ax) / math.hypot(bx - ax, bz - az))
    L.put("fig_wall", (round(x - sea[0] * 2.5, 2), round(headland(x - sea[0] * 2.5, z - sea[1] * 2.5) - 0.1, 2), round(z - sea[1] * 2.5, 2)),
          round(math.degrees(math.atan2(sea[0], sea[1])), 1), "cave")

    # The river's west bank: maritime pines and gorse along its top, leaning
    # over the river; fennel and grass on its ledges.
    for z in range(-134, -14, 7):
        px, pz = rng.uniform(-259.0, -253.0), z + rng.uniform(-2.0, 2.0)
        y = west_bank(px, pz)

        if y > 40.0:
            name = "pine_maritime" if z % 4 == 0 and rng.random() < 0.6 else rng.choice(["gorse_bush", "gorse_cushion", "grass_tuft"])
            L.put(name, (round(px, 2), round(y - 0.1, 2), round(pz, 2)), 90.0 + rng.uniform(-25.0, 25.0), "river")

        for _ in range(3):
            lx, lz = rng.uniform(-252.0, -237.0), z + rng.uniform(-3.0, 3.0)
            ly = west_bank(lx, lz)

            if 2.0 < ly < 40.0 and abs(west_bank(lx + 0.6, lz) - ly) < 0.4 and abs(west_bank(lx - 0.6, lz) - ly) < 0.4:
                L.put(rng.choice(["fennel_clump", "grass_tuft", "gorse_cushion"]), (round(lx, 2), round(ly - 0.05, 2), round(lz, 2)),
                      round(rng.uniform(0, 360), 1), "river")
                break

    # Sea fennel on the rubble over high water.
    for x, z, sea in _coast_points(9.0, rng):
        px, pz = x + sea[0] * 2.6, z + sea[1] * 2.6
        y = rubble(px, pz)

        if y > 1.5 and _clear(px, pz, 2.0):
            L.put("fennel_clump", (round(px, 2), round(y - 0.05, 2), round(pz, 2)), round(rng.uniform(0, 360), 1), "cave")


def _life(L, rng):
    # Gulls on the Ribeira's ridges and the quay's edge.
    lift = kit_recipes.ROOF_THICK / math.cos(math.radians(ki.PITCH))
    rise = ki.FRONT * math.tan(math.radians(ki.PITCH))

    for i in (1, 4, 5, 9, 12):
        eaves = kit_recipes.PIECES[HOUSES[i]]["eaves"]
        x = rib_x(i) + rng.uniform(-2.0, 2.0)
        L.put("gull" if i % 2 else "gull_sitting", (round(x, 2), round(QUAY + eaves + lift + rise + 0.1, 2), ARCADE_FRONT - 7.0 + rng.uniform(-0.3, 0.3)),
              round(rng.choice((90.0, -90.0)) + rng.uniform(-20, 20), 1), "ribeira")

    for x in (-171.0, -133.5, -97.0):
        L.put("gull", (x, QUAY, -0.35), round(rng.uniform(140.0, 220.0), 1), "ribeira")

    # Nets drying on the cave's beach and the spit's end by the fort.
    L.put("net_poles", (233.0, 1.2, 27.5), 80.0, "cave")
    L.put("net_poles", (-98.0, round(spit(-98.0, 170.0), 2), 170.0), 30.0, "fort")

    # Washing across the fronts of the houses without balconies on their
    # lower storeys; the tavern's bush under the arcade.
    for i, storey in ((0, 1), (1, 2), (7, 3), (8, 1), (12, 2)):
        if i == ROOF_HOUSE:
            continue

        L.put("laundry_2", (rib_x(i), round(QUAY + ki.GROUND + storey * ki.STOREY + 2.9, 2), ARCADE_FRONT + (ki.FACE - ki.FRONT)), 0.0, "ribeira")

    L.put("tavern_bush", (rib_x(3) + 3.0, QUAY + 3.3, ARCADE_FRONT), 0.0, "ribeira")

    # Smoke from the chimneys of a few houses.
    for i in (2, 4, 8, 11):
        spec = ki.CASAS[HOUSES[i]]
        eaves = kit_recipes.PIECES[HOUSES[i]]["eaves"]
        top = QUAY + eaves + rise + 1.0 + 0.6
        L.mark("smoke_%d" % i, "smoke", (round(rib_x(i) + spec["chimney"] * 1.8, 2), round(top, 2), ARCADE_FRONT - 7.0 - ki.FRONT + 1.5), 0.0,
               "ribeira")


def lay(L):
    rng = random.Random(2026)
    _rocks(L, rng)
    _planting(L, rng)
    _life(L, rng)
