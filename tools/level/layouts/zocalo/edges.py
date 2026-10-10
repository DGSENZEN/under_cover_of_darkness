"""Where the Zócalo ends at the void: 620 m east-west, 640 m north-south
(further north for Santo Domingo)."""

from plan import rect

BRINK = rect(-310, -340, 310, 300)


def lay(P):
    P.brink(BRINK)
