"""Faces of two pieces lying in one plane (overlap.py): pure Python.

    python3 tools/level/test_overlap.py
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import overlap  # noqa: E402

UP = (0.0, 0.0, 1.0)
DOWN = (0.0, 0.0, -1.0)
SOUTH = (0.0, 1.0, 0.0)


def quad(owner, x0, y0, x1, y1, z=0.0, normal=UP):
    return {"owner": owner, "normal": normal, "points": [(x0, y0, z), (x1, y0, z), (x1, y1, z), (x0, y1, z)]}


def wall(owner, x0, x1, z0, z1, y=0.0):
    return {"owner": owner, "normal": SOUTH, "points": [(x0, y, z0), (x1, y, z0), (x1, y, z1), (x0, y, z1)]}


class Fights(unittest.TestCase):
    def test_two_pieces_overlapping_in_one_plane_fight_and_the_earlier_gives_way(self):
        fights = overlap.fights([quad(3, 0, 0, 4, 4), quad(7, 2, 2, 6, 6)])
        self.assertEqual(len(fights), 1)
        loser, winner, area = fights[0]
        self.assertEqual((loser, winner), (0, 1))
        self.assertAlmostEqual(area, 4.0, places=3)

    def test_the_later_piece_wins_whichever_comes_first_in_the_list(self):
        fights = overlap.fights([quad(9, 0, 0, 4, 4), quad(2, 2, 2, 6, 6)])
        self.assertEqual(fights[0][:2], (1, 0))

    def test_walls_overlapping_along_a_run_fight(self):
        fights = overlap.fights([wall(1, 0, 4, 0, 3), wall(2, 3, 5, 0, 3)])
        self.assertEqual(len(fights), 1)
        self.assertAlmostEqual(fights[0][2], 3.0, places=3)

    def test_faces_back_to_back_do_not_fight(self):
        self.assertEqual(overlap.fights([quad(1, 0, 0, 4, 4), quad(2, 0, 0, 4, 4, normal=DOWN)]), [])

    def test_faces_side_by_side_sharing_an_edge_do_not_fight(self):
        self.assertEqual(overlap.fights([quad(1, 0, 0, 4, 4), quad(2, 4, 0, 8, 4)]), [])

    def test_faces_of_one_piece_do_not_fight(self):
        self.assertEqual(overlap.fights([quad(1, 0, 0, 4, 4), quad(1, 2, 2, 6, 6)]), [])

    def test_planes_a_centimetre_apart_do_not_fight(self):
        self.assertEqual(overlap.fights([quad(1, 0, 0, 4, 4), quad(2, 0, 0, 4, 4, z=0.01)]), [])

    def test_planes_within_the_tolerance_fight(self):
        self.assertEqual(len(overlap.fights([quad(1, 0, 0, 4, 4), quad(2, 0, 0, 4, 4, z=0.003)])), 1)

    def test_a_triangle_overlapping_a_quad_fights_by_their_shared_area(self):
        tri = {"owner": 2, "normal": UP, "points": [(0, 0, 0), (2, 0, 0), (0, 2, 0)]}
        fights = overlap.fights([quad(1, 0, 0, 4, 4), tri])
        self.assertAlmostEqual(fights[0][2], 2.0, places=3)


class Recess(unittest.TestCase):
    def test_the_loser_is_pushed_back_behind_the_winner_and_they_fight_no_more(self):
        faces = [quad(1, 0, 0, 4, 4), quad(2, 2, 2, 6, 6)]
        moved = overlap.recessed(faces)
        self.assertEqual(overlap.fights(moved), [])
        # The earlier piece's face went back (down, away from its face's way);
        # the later one's stayed.
        self.assertTrue(all(abs(p[2] + overlap.RECESS) < 1e-9 for p in moved[0]["points"]))
        self.assertEqual(moved[1]["points"], faces[1]["points"])

    def test_three_pieces_stacked_in_one_plane_end_up_layered_latest_in_front(self):
        faces = [quad(1, 0, 0, 4, 4), quad(2, 1, 1, 5, 5), quad(3, 2, 2, 6, 6)]
        moved = overlap.recessed(faces)
        self.assertEqual(overlap.fights(moved), [])
        depth = [moved[i]["points"][0][2] for i in range(3)]
        self.assertLess(depth[0], depth[1])
        self.assertLess(depth[1], depth[2])
        self.assertEqual(depth[2], 0.0)

    def test_nothing_fighting_is_left_as_it_is(self):
        faces = [quad(1, 0, 0, 4, 4), quad(2, 4, 0, 8, 4)]
        self.assertEqual(overlap.recessed(faces), faces)

    def test_the_recess_clears_the_tolerance(self):
        self.assertGreater(overlap.RECESS, overlap.TOLERANCE * 1.5)


if __name__ == "__main__":
    unittest.main()
