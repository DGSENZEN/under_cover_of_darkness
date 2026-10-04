"""The old town (its spec, sections 4-6; plan B1a): its ground of five
quarters (ground.py, from town.TERRACES), the city wall and the Sea Gate it
shares with the harbour (edges.py), the four gates' arrivals and the exits
back to the harbour, and every lot of the lot plan (town/) placed: its
house, its doors' markers, its climbs as ladders, a bed kept for the
townsfolk where it is lived in. Each quarter's own streets, stairs and ways
are its module's (Tasks 14-18)."""

import edges
import geo
import kit_recipes as kit
from lay import Layout

import city_harbour
import town
from harbour import GATE_X, QUAY, WALK, WALL_E, WALL_W, stair_y
from old_town import baixa, ground, judiaria, stairs

height = town.height

# The gates (plan A's table): the arrival a player coming from the harbour
# stands at (position, yaw), and the exit back (centre, size) with the
# harbour's arrival it leads to.
GATES = {
    "sea_gate": ((GATE_X, QUAY, -98.0), 0.0, (GATE_X, QUAY + 1.2, -80.0), [4.0, 2.4, 2.0]),
    "wall_walk": ((148.0, height(148.0, -78.0), -78.0), 0.0, (WALL_E, WALK + 1.2, -73.0), [3.0, 2.4, 2.0]),
    "guindais": ((-172.0, height(-172.0, -91.0), -91.0), -90.0, (-177.0, height(-177.0, -91.0) + 1.2, -91.0), [2.0, 2.4, 3.0]),
    "west_wall": ((WALL_W, stair_y(-119.9) + 12.0, -119.9), 0.0, (WALL_W, stair_y(-114.0) + 13.2, -114.0), [3.0, 3.0, 3.0]),
}


def place(L, lot):
    """A lot's house, its live doors' markers (each where its recipe says,
    turned with it), its climbs, and (lived in) a bed kept for the
    townsfolk; the piece's name."""
    key = town.design_key(lot)
    recipe = kit.PIECES[key]
    sector = lot.sector or town.sector_of(lot.x, lot.z)
    at = (lot.x, lot.y, lot.z)
    name = L.put(key, at, lot.yaw, sector, name=lot.name, climbs=True)
    basis = geo.rotation(lot.yaw)

    for i, d in enumerate(recipe.get("doors", [])):
        where = geo.add(list(at), geo.apply(basis, d[0:3]))
        size = {"width": d[4], "height": d[5]} if len(d) > 5 else {}

        # (A door its recipe calls a gate is iron, seen through.)
        if len(d) > 6:
            size["kind"] = d[6]

        L.mark("%s_door_%d" % (lot.name, i + 1), "door", where, lot.yaw + d[3], sector, **size)

    if lot.lived and recipe.get("rooms_at"):
        bed = geo.add(list(at), geo.apply(basis, recipe["rooms_at"][-1]))
        L.mark("%s_home" % lot.name, "home", bed, lot.yaw, sector)

    return name


def layout():
    L = Layout("old_town")
    ground.lay(L)
    L.pieces.extend(edges.shared_edge(city_harbour.layout()))

    for gate, (at, yaw, out, size) in GATES.items():
        sector = town.sector_of(at[0], at[2])
        L.mark("from_harbour_" + gate, "arrival", at, yaw, sector)
        L.mark("to_harbour_" + gate, "exit", out, 0.0, sector, size=size, label="the harbour", to="harbour", arrive="from_old_town_" + gate)

    L.mark("old_town_start", "spawn", (GATE_X, QUAY, -105.0), 0.0, town.sector_of(GATE_X, -105.0))
    # (The way back to the harbour: from the arrival on the square through
    # the Sea Gate's passage to its exit.)
    arrival = GATES["sea_gate"][0]

    for i, z in enumerate((arrival[2], -91.0, GATES["sea_gate"][2][2] - 1.5)):
        L.mark("sea_gate_way_%d" % (i + 1), "route_check", (GATE_X, QUAY, z), 0.0, "wall", route="sea_gate_way", order=i + 1, move="walk",
               way="public")

    for lot in town.all_lots():
        place(L, lot)

    # The quarters' own streets, stairs and ways (over their lots).
    baixa.lay(L)
    stairs.lay(L)
    judiaria.lay(L)
    return L.data()
