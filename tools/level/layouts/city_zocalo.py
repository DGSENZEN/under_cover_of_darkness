"""The Zócalo, the Eclipse city's hub (docs/superpowers/specs/
2026-10-10-zocalo-district-design.md): for now its plan (plan()), from which
its sheets (plan_draw.py) and greybox (greybox.py) are made; its kit layout
(layout()) fills in family by family. Each part in layouts/zocalo/."""

import json
import os
import sys
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))   # tools/level: geo, plan_check

from lay import Layout  # noqa: E402
from plan import Plan  # noqa: E402

from zocalo import cameras, east, edges, events, houses, north, plaza, roofs, south, station, west  # noqa: E402

PARTS = [edges, plaza, north, east, west, south, station, houses, roofs, events, cameras]


def plan():
    P = Plan("zocalo")

    for part in PARTS:
        part.lay(P)

    return P.data()


def layout():
    return Layout("zocalo").data()


if __name__ == "__main__":
    import plan_check

    problems = plan_check.check(plan())

    for p in problems:
        print("zocalo plan:", p)

    if problems:
        sys.exit(1)

    out = Path(sys.argv[1])
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(plan(), indent=1))
    print("zocalo plan ->", out)
