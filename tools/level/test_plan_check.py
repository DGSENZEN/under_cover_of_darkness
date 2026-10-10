"""The plan's checks (plan_check.py), on a small town whose every element is
right, then broken one way at a time.

    python3 tools/level/test_plan_check.py
"""

import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "layouts"))

import plan  # noqa: E402
import plan_check  # noqa: E402
from plan import rect  # noqa: E402


def _town(brink=260.0, stair=True, events=plan.EVENT_KINDS):
    """A plaza ringed by streets; two houses east whose roofs a plank joins,
    a climb up to the first from the street; a well north with a stair down
    to a hall under the street; every event kind; a 520 m brink."""
    P = plan.Plan("town")
    P.brink(rect(-brink, -brink, brink, brink))
    P.ground("square", "plaza", rect(-40, -40, 40, 40))
    P.ground("north_street", "street", rect(-60, -60, 60, -40))
    P.ground("south_street", "street", rect(-60, 40, 60, 60))
    P.ground("west_street", "street", rect(-60, -40, -40, 40))
    P.ground("east_street", "street", rect(40, -40, 60, 40))
    P.ground("well_a", "well", rect(-10, -58, 10, -52), level=-8.0)
    P.plot("house_a", "house", rect(60, -40, 80, -20), storeys=2, height=9.0)
    P.plot("house_b", "house", rect(60, -20, 80, 0), storeys=2, height=9.0)
    P.route("plank_ab", "roof_link", [(75, 9, -25), (75, 9, -15)])
    P.route("climb_a", "climb", [(58, 0, -30), (62, 9, -30)])
    P.space("hall", rect(-10, -50, 10, -30), floor=-8.0, height=5.0, openings=[{"to": "well_a", "at": (0, -50)}])

    if stair:
        P.route("stair_a", "stair", [(0, 0, -59.5), (0, -8, -45)])

    P.landmark("way_in", "metro_entrance", (0, -55))
    P.tram([(-50, -50), (50, -50), (50, 50), (-50, 50)])
    places = {"subsidence": (0, 0), "water": (0, 50), "seepage": (-20, -20), "use": (20, 20)}

    for kind in events:
        P.event(kind, centre=places[kind], radius=60, strength=0.8)

    return P


class Checks(unittest.TestCase):
    def one_problem(self, P, *names):
        problems = plan_check.check(P.data())
        self.assertEqual(len(problems), 1, problems)

        for name in names:
            self.assertIn(name, problems[0])

        return problems[0]

    def test_clean_town_passes(self):
        self.assertEqual(plan_check.check(_town().data()), [])

    def test_overlapping_plots(self):
        P = _town()
        P.plot("house_c", "house", rect(60, -30, 70, -24), storeys=2, height=9.0, roof=False)
        self.assertIn("overlap", self.one_problem(P, "house_a", "house_c"))

    def test_plot_in_the_street(self):
        P = _town()
        P.plot("stall", "stall", rect(42, 0, 50, 10), storeys=1, height=3.0, roof=False)
        self.assertIn("east_street", self.one_problem(P, "stall"))

    def test_plot_faces_no_street(self):
        P = _town()
        P.plot("lonely", "house", rect(100, 100, 120, 120), storeys=2, height=9.0, roof=False)
        self.assertIn("faces no street", self.one_problem(P, "lonely"))

    def test_concave_plot_refused(self):
        P = _town()
        P.plot("ell", "house", [(60, 0), (80, 0), (80, 20), (70, 20), (70, 10), (60, 10)], storeys=2, height=9.0,
               roof=False)
        self.assertIn("not convex", self.one_problem(P, "ell"))

    def test_sunken_area_must_be_a_rectangle(self):
        P = _town()
        P.ground("pool", "canal", [(-30, 45), (-10, 45), (-20, 55)], level=-2.0)
        self.assertIn("rectangle", self.one_problem(P, "pool"))

    def test_route_end_must_rest_on_a_surface(self):
        P = _town()
        P.route("loose_plank", "roof_link", [(65, 9, -25), (65, 9.8, -15)])
        self.assertIn("dangles", self.one_problem(P, "loose_plank"))

    def test_roof_island_is_unreachable(self):
        P = _town()
        P.plot("house_c", "house", rect(60, 0, 80, 20), storeys=3, height=13.0)
        P.plot("house_d", "house", rect(60, 20, 80, 40), storeys=3, height=13.0)
        P.route("plank_cd", "roof_link", [(75, 13, 15), (75, 13, 25)])
        problems = plan_check.check(P.data())
        self.assertEqual(len(problems), 2, problems)
        self.assertTrue(any("house_c" in p and "reached" in p for p in problems))
        self.assertTrue(any("house_d" in p and "reached" in p for p in problems))

    def test_space_unreachable_without_its_stair(self):
        self.assertIn("reached", self.one_problem(_town(stair=False), "hall"))

    def test_map_too_small(self):
        self.assertIn("brink", self.one_problem(_town(brink=200.0), "town"))

    def test_outside_the_brink(self):
        P = _town()
        P.ground("far_road", "street", rect(255, 0, 275, 20))
        self.assertIn("outside the brink", self.one_problem(P, "far_road"))

    def test_missing_event_kind(self):
        kinds = tuple(k for k in plan.EVENT_KINDS if k != "seepage")
        self.assertIn("seepage", self.one_problem(_town(events=kinds), "seepage"))


class Surfaces(unittest.TestCase):
    def test_reach_from_the_street(self):
        reached = plan_check.reach(_town().data())
        self.assertTrue({"house_a", "house_b", "hall"} <= reached)

    def test_walkable_lists_roofs_at_their_top(self):
        roofs = {s["name"]: s["y"] for s in plan_check.walkable(_town().data())}
        self.assertEqual(roofs["house_a"], 9.0)
        self.assertEqual(roofs["hall"], -8.0)


if __name__ == "__main__":
    unittest.main()
