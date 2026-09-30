"""The harbour of the city on the rock, laid out sector by sector
(tools/level/layouts/city_harbour.py calls each module's lay()). Its anchors
(the city spec, section 6, and the harbour plan's table): Godot's axes, x
east, y up, z south, metres; the sea at y 0, the quays' tops at 2.5.

The city wall runs round the harbour's back: along the Ribeira (z WALL_RIB),
up its west side beside the Guindais stair, north of the Terreiro's west
arcade (x WALL_C), behind the Terreiro (z WALL_D) with the Sea Gate in it,
down the shipyard's west side (x WALL_F, a postern to the customs house),
along the water before the shipyard (z SEA_WALL, the Nasrid water gate), up
its east side (x WALL_E). Outside it: the quays, the Ribeira's houses, the
Terreiro and the customs house, the mole; inside: the shipyard and the city.
"""

import math

QUAY = 2.5
WALL = 12.0
WALK = QUAY + WALL
DEPTH = 2.4

# The Ribeira: 13 bays of 6 m from RIB_X0, its arcade's front at z -6, the
# houses to z -20, the wall behind them.
RIB_X0 = -178.0
RIB_BAYS = 13
ARCADE_FRONT = -6.0
WALL_RIB = -21.2

# The Guindais stair beside the west wall, climbing north from the quay.
WALL_W = -179.2
STAIR_X = -184.5
STAIR_FOOT = (-8.0, QUAY)
STAIR_FLIGHTS = 14

# The Terreiro: its floor over x TER_X, z TER_Z at the quays' height; its
# arcades (8 m deep) west, north and east; the Sea Gate at its back.
TER_X = (-98.0, -12.0)
TER_Z = (-72.0, 0.0)
WALL_C = -99.2
WALL_D = -73.2
GATE_X = -55.0
TOWERS_X = (-62.0, -48.0)

# The customs house (outside the wall, on the quay), the shipyard's west
# wall with its postern, the sea wall and the naves inside it.
CUSTOMS = (-10.0, 14.0, -34.0, -6.0)
WALL_F = 15.2
SEA_WALL = -7.2
NAVE = 8.4
NAVE_X0 = 16.4
NAVES = 12
NAVE_Z0 = -8.4
NAVE_BAYS = 7
SLIP_NAVE = 6
GALLEY_NAVE = 3
WALL_E = 151.2

# The mole: from its root down to where it bends, round to its head.
MOLE_X = 165.0
MOLE_BEND = 140.0
MOLE_HEAD = (92.0, 203.0)

# The fort at the harbour's mouth, the chain between it and the golden
# tower.
FORT = (-75.0, 205.0)
CHAIN_Z = 204.0

# The carrack alongside the sea wall's quay: its mainmast at x CARRACK_X.
CARRACK_X = 40.0
CARRACK_Z = 4.8
MAINYARD_Y = 18.0

# The smugglers' cave in the east cliff.
CAVE_MOUTH = (226.0, 55.0)
BLOWHOLE = (232.0, 0.0)


def nave_x(i):
    """The west edge of nave i (0 .. NAVES), x."""
    return NAVE_X0 + i * NAVE


def nave_z(j):
    """The bay line j (0 at the sea wall, NAVE_BAYS at the naves' north
    end), z."""
    return NAVE_Z0 - j * NAVE


def stair_y(z):
    """The Guindais stair's height at z (its foot at the quay, 2 m a flight
    of 6 m with its landing, on up past its top)."""
    run = STAIR_FOOT[0] - z
    return QUAY + max(0.0, run) / 6.0 * 2.0


def rib_x(i):
    """The middle of the Ribeira's bay i."""
    return RIB_X0 + 3.0 + 6.0 * i


def mole_path():
    """The mole's line: [(x, z)] from its root to its head."""
    return [(MOLE_X, 0.0), (MOLE_X, MOLE_BEND), MOLE_HEAD]


def wall_run(L, a, b, sector, y=QUAY, height=12, outward=1.0, ground=None):
    """City wall from a to b ((x, z), straight along x or z) in 6 m runs, a 3
    m run to finish; its outer face (+z of the piece) to the right of a -> b
    (outward 1) or the left (-1); each piece at y, or at ground(x, z) (a
    wall climbing a slope)."""
    dx, dz = b[0] - a[0], b[1] - a[1]
    length = math.hypot(dx, dz)
    ux, uz = dx / length, dz / length
    yaw = math.degrees(math.atan2(-dz, dx)) + (0.0 if outward > 0 else 180.0)
    done = 0.0
    names = []

    while done < length - 0.5:
        size = 6.0 if length - done >= 5.5 else 3.0
        mid = done + size / 2.0
        x, z = a[0] + ux * mid, a[1] + uz * mid
        names.append(L.put("city_wall_%d_%d" % (height, int(size)), (x, y if ground is None else ground(x, z), z), yaw, sector))
        done += size

    return names


def along(a, b, step):
    """Points every `step` along a -> b (their middles) and the yaw that runs
    a piece's x along it with its +z to its right-hand side."""
    dx, dz = b[0] - a[0], b[1] - a[1]
    length = math.hypot(dx, dz)
    count = max(1, int(round(length / step)))
    yaw = math.degrees(math.atan2(-dz, dx))
    return [(a[0] + dx * (i + 0.5) / count, a[1] + dz * (i + 0.5) / count) for i in range(count)], yaw
