"""What the Zócalo's two bridges share (street_canal.md): their frame, the
deck's line and the stations it is built through. Blender axes: X across
the canal (its walls' faces at x +-CANAL_WIDTH/2, the quays beyond), Y
along it (the deck +-BRIDGE_WIDTH/2 wide), Z up from the street; the origin
on the canal's middle line at street level.
"""

import math

from street_dims import BRIDGE_LENGTH, CANAL_WIDTH, WALL_THICK

HALF = BRIDGE_LENGTH / 2
SPAN = CANAL_WIDTH / 2
# Behind the canal's walls (|x| past SPAN + WALL_THICK) a bridge keeps above
# this, clear of the canal walkway's ceiling (-0.1) under the south quay.
QUAY_FOOT = -0.05
# Stations: four over each quay, sixteen across the canal.
QUAY_STEPS = 4
SPAN_STEPS = 16


def stations():
    """Across the bridge: over each quay, at the canal walls' backs, across the canal."""
    back = SPAN + WALL_THICK
    quay = [-HALF + (HALF - back) * k / QUAY_STEPS for k in range(QUAY_STEPS)] + [-back]
    span = [-SPAN + 2 * SPAN * k / SPAN_STEPS for k in range(SPAN_STEPS + 1)]
    return quay + span + [-x for x in reversed(quay)]


def deck(x, crown):
    """The deck's top at x: flush with the quays at its ends, `crown` over
    the canal's middle, a parabola between (never steeper than 2 crown / HALF)."""
    return crown * (1.0 - (x / HALF) ** 2)


def soffit(x, spring, crown):
    """A segmental arch across the canal, springing at the walls' faces
    (+-SPAN) at `spring`, its crown at `crown`."""
    rise = crown - spring
    radius = (SPAN ** 2 + rise ** 2) / (2 * rise)
    return crown - radius + math.sqrt(radius ** 2 - x ** 2)
