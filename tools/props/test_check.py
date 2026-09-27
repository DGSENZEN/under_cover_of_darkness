"""The props pipeline's own check tests, run inside Blender:

    tools/props/props.sh test

The wall torch builds and passes every rule; a copy of its recipe broken one
way at a time fails exactly that rule.
"""

import copy
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build  # noqa: E402
import check  # noqa: E402
import recipes  # noqa: E402


def broken(**changes):
    recipe = copy.deepcopy(recipes.FIXTURES["wall_torch"])
    recipe.update(changes)
    return recipe


class CheckTest(unittest.TestCase):
    def test_wall_torch_builds_clean(self):
        build.build_fixture("wall_torch", recipes.FIXTURES["wall_torch"])
        self.assertEqual(check.check("wall_torch", recipes.FIXTURES["wall_torch"]), [])

    def test_budget(self):
        recipe = broken(budget=50)
        build.build_fixture("wall_torch", recipe)
        self.assertEqual(check.check("wall_torch", recipe), ["budget"])

    def test_sockets(self):
        recipe = broken()
        del recipe["sockets"]["corona"]
        build.build_fixture("wall_torch", recipe)
        self.assertEqual(check.check("wall_torch", recipe), ["sockets"])

    def test_slots(self):
        recipe = broken()
        recipe["parts"][0]["slot"] = "gold"
        build.build_fixture("wall_torch", recipe)
        self.assertEqual(check.check("wall_torch", recipe), ["slots"])

    def test_density(self):
        recipe = broken()
        objects = build.build_fixture("wall_torch", recipe)
        plate = objects[recipe["parts"][0]["name"]]

        # Grown tenfold after it was unwrapped: its texels spread thin.
        for vertex in plate.data.vertices:
            vertex.co *= 10.0

        self.assertEqual(check.check("wall_torch", recipe), ["density"])


if __name__ == "__main__":
    result = unittest.main(argv=["test_check"], exit=False).result
    sys.exit(0 if result.wasSuccessful() else 1)
