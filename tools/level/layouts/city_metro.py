"""The Metro Underground (docs/superpowers/specs/2026-10-16-metro-underground-
design.md): its own map under the Zócalo, its plan at the Zócalo's x and z
(the exits under the kiosks, the crypt under the cathedral). No street, no
brink: plan_check's UNDERGROUND_RULES, reach from the arrival. Its sheets
are drawn one per depth band (BANDS), since its spaces stack; it carries
the waypoints of the walks maps/metro's suite takes (metro/walk.py). Each part in
layouts/metro/.

The layout as it stands was approved by the user on 2026-10-16 (the Metro
Underground part 1 plan, Task 16): the sheets and the greybox walk. Its
models come in sets (Part 3), in the order it dictates."""

import json
import os
import sys
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))   # tools/level: plan_check

from plan import Plan  # noqa: E402

from metro import market, old, places, service, station, walk  # noqa: E402

PARTS = [station, market, service, old, places]
# The depth bands drawn as sheets (plan_draw.py): (lowest floor, highest
# floor, label), floors in (lowest, highest].
# Where the suite's walks into the deeper layers end (landmarks).
WALKS = {"market": ["herb_counter"], "old": ["temple_in_tunnel"]}
BANDS = [(-10.5, 0.0, "hall"), (-13.0, -10.5, "market"), (-16.0, -13.0, "platforms"), (-40.0, -16.0, "old")]


def plan():
    P = Plan("metro")

    for part in PARTS:
        part.lay(P)

    data = P.data()
    data["bands"] = [list(b) for b in BANDS]
    # The walks maps/metro's suite takes, as waypoints: the spine (the
    # arrival to the nearest exit), and from the arrival into the market
    # and down into the old passages.
    data["walks"] = {}

    for name, goals in (("spine", [m["name"] for m in data["landmarks"] if m["kind"] == "exit_zocalo"]),
                        ("market", WALKS["market"]), ("old", WALKS["old"])):
        found = walk.shortest(data, "arrival", goals)
        data["walks"][name] = walk.waypoints(data, found) if found else []

    return data


if __name__ == "__main__":
    import plan_check

    problems = plan_check.check(plan(), plan_check.UNDERGROUND_RULES)

    for p in problems:
        print("metro plan:", p)

    if problems:
        sys.exit(1)

    out = Path(sys.argv[1])
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(plan(), indent=1))
    print("metro plan ->", out)
