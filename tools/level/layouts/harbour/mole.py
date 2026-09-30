"""The mole: from the quay's east end south, round to its head, its parapet
to the sea and boulders at its foot; the golden tower on its head (after
Seville's Torre del Oro), the windlass in its room, the ladder up to its
terrace; the chain across the harbour's mouth to the fort."""

import math

from . import CHAIN_Z, FORT, MOLE_BEND, MOLE_HEAD, MOLE_X, along

HEAD_RADIUS = 12.0
TOP = 3.5
STAGES = (18.0, 9.0)


def head_yaw():
    """The yaw that turns the head's landward gap (and the tower's door and
    ladder: their -z) toward where the mole comes in."""
    angle = math.degrees(math.atan2(MOLE_BEND - MOLE_HEAD[1], MOLE_X - MOLE_HEAD[0]))
    return 270.0 - (angle % 360.0)


def lay(L):
    # (Walked from its far end back, each piece's +z, its parapet, lies to
    # the sea.)
    points, yaw = along((MOLE_X, MOLE_BEND), (MOLE_X, 0.0), 8.0)

    for x, z in points:
        L.put("mole_8", (x, 0.0, z), yaw, "mole")

    dx, dz = MOLE_X - MOLE_HEAD[0], MOLE_BEND - MOLE_HEAD[1]
    length = math.hypot(dx, dz)
    start = (MOLE_HEAD[0] + dx / length * (HEAD_RADIUS - 1.0), MOLE_HEAD[1] + dz / length * (HEAD_RADIUS - 1.0))
    points, yaw = along(start, (MOLE_X, MOLE_BEND), 8.0)

    for x, z in points:
        L.put("mole_8", (x, 0.0, z), yaw, "mole")

    turn = head_yaw()
    L.put("mole_head", (MOLE_HEAD[0], 0.0, MOLE_HEAD[1]), turn, "mole")
    L.put("gold_stage_1", (MOLE_HEAD[0], TOP, MOLE_HEAD[1]), turn, "mole", climbs=True)
    L.put("gold_stage_2", (MOLE_HEAD[0], TOP + STAGES[0], MOLE_HEAD[1]), turn, "mole")
    L.put("gold_stage_3", (MOLE_HEAD[0], TOP + STAGES[0] + STAGES[1], MOLE_HEAD[1]), turn, "mole")
    L.put("windlass", (MOLE_HEAD[0], TOP, MOLE_HEAD[1]), turn + 90.0, "mole")

    # The chain from the tower's foot to the fort's bastion.
    x = MOLE_HEAD[0] - 8.0 - 6.0

    while x > FORT[0] + 15.0 + 6.0:
        L.put("chain_span_12", (x, 0.0, CHAIN_Z), 0.0, "mole")
        x -= 12.0
