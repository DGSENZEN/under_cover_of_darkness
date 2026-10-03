"""What two districts share (the old town's spec, section 3A): the city wall
and the Sea Gate between the harbour and the old town, laid at full detail
into both levels by the same layout code, since the player arrives right
beside them. Proxies leave them out (each district draws its own)."""

import copy

# The pieces of the wall between the harbour and the old town: its runs and
# corners, the postern, the Sea Gate's front and passage, its drum towers,
# the wall stair. (Not the passage's closing wall: the harbour shuts the
# passage at its city end, the old town opens it.)
# The passages through the shared edge (x0, z0, x1, z1): the harbour shuts
# each at the city's end, the old town opens it; a proxy draws nothing that
# stands in one (it would shut the passage in the other district's map).
PASSAGES = [(-58.0, -92.0, -52.0, -74.0)]

SHARED_EDGE = ("city_wall_12_3", "city_wall_12_6", "city_wall_12_corner", "city_wall_12_postern", "gate_front", "gate_passage_16",
               "tower_drum_8", "wall_stair_12")


def shared_edge(data):
    """Return list[dict]: copies of the pieces of `data` whose kind is in
    SHARED_EDGE, their sector "wall"; `data` is left as it was."""
    out = []

    for p in data["pieces"]:
        if p["piece"] in SHARED_EDGE:
            piece = copy.deepcopy(p)
            piece["sector"] = "wall"
            out.append(piece)

    return out
