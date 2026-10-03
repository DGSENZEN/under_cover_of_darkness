"""A stand-in old town (the old town's spec, section 3A), until plan B1 builds
the district: its ground at the massing's terraces, the Sea Gate's square
sunk to the quays' height behind the gate, the city wall and the Sea Gate it
shares with the harbour (edges.py), and the four gates' arrivals and the
exits back to the harbour. No guards."""

import edges
import terrain
from lay import Layout

import city_harbour
import city_massing
from harbour import GATE_X, QUAY, WALK, WALL_E, WALL_W, STAIR_X, stair_y

# The ground: x X0..X1, z Z0 (north) .. Z1 (the wall behind the Terreiro), a
# vertex every CELL m.
X0, X1, Z0, Z1, CELL = -180.0, 150.0, -380.0, -73.0, 5.0
# The Sea Gate's square behind the gate (x, x, z, z), at the quays' height;
# the gate passage's footprint, where the ground is left out (the passage's
# own floor is its floor).
SQUARE = (-75.0, -35.0, -115.0, -91.0)
PASSAGE = (-58.0, -52.0, -91.0, -75.0)
# A height no ground has: its quads are left out.
HOLE = -100.0


def _inside(x, z, box):
    return box[0] <= x <= box[1] and box[2] <= z <= box[3]


def height(x, z):
    """The stand-in's ground at (x, z): the massing's terraces, the square at
    the quays' height, HOLE over the gate passage."""
    if _inside(x, z, PASSAGE):
        return HOLE

    if _inside(x, z, SQUARE):
        return QUAY

    return city_massing._town(x, z)


def _slot(x, y, z, slope):
    return "rock" if slope > 30.0 else "calcada"


# The gates (the plan's table): the arrival a player coming from the harbour
# stands at (position, yaw), and the exit back (centre, size) with the
# harbour's arrival it leads to.
GATES = {
    "sea_gate": ((GATE_X, QUAY, -98.0), 0.0, (GATE_X, QUAY + 1.2, -80.0), [4.0, 2.4, 2.0]),
    "wall_walk": ((148.0, height(148.0, -78.0), -78.0), 0.0, (WALL_E, WALK + 1.2, -73.0), [3.0, 2.4, 2.0]),
    "guindais": ((-172.0, height(-172.0, -91.0), -91.0), -90.0, (-177.0, height(-177.0, -91.0) + 1.2, -91.0), [2.0, 2.4, 3.0]),
    "west_wall": ((WALL_W, stair_y(-119.9) + 12.0, -119.9), 0.0, (WALL_W, stair_y(-114.0) + 13.2, -114.0), [3.0, 3.0, 3.0]),
}


def layout():
    L = Layout("old_town")
    L.terrain(terrain.grid("ground", "ground", X0, Z0, X1, Z1, CELL, height, _slot, surface="stone",
                           keep=lambda ys: min(ys) > HOLE + 1.0))

    L.pieces.extend(edges.shared_edge(city_harbour.layout()))

    for gate, (at, yaw, out, size) in GATES.items():
        L.mark("from_harbour_" + gate, "arrival", at, yaw, "ground")
        L.mark("to_harbour_" + gate, "exit", out, 0.0, "ground", size=size, label="the harbour", to="harbour",
               arrive="from_old_town_" + gate)

    L.mark("old_town_start", "spawn", (GATE_X, QUAY, -105.0), 0.0, "ground")
    return L.data()
