"""Checks the open level .blend against the rules (rules.py) and the kit
against the metrics; exits 1 naming each problem.

    Blender -b assets/level/source/<level>.blend --python tools/level/check.py [-- stage2]
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import common  # noqa: E402
import read  # noqa: E402
import rules  # noqa: E402


def check(stage="stage1"):
    data = read.read()
    found = rules.kit_problems() + rules.problems(data, stage)

    for problem in found:
        print("level: problem: " + problem)

    print("level: %s: %d pieces, %d markers, %d problems" % (data["level"], len(data["pieces"]), len(data["markers"]), len(found)))
    return data, found


if __name__ == "__main__":
    args = common.argv()
    _, problems = check(args[0] if args else "stage1")

    if problems:
        sys.exit(1)
