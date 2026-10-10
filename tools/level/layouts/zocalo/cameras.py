"""Where the stills and the frame-rate flight look from (developer
cameras, eye height 1.7 m unless on a roof or below ground)."""

CAMERAS = [
    ("plaza_south", (0, 1.7, 122), (0, 12, -200)),
    ("plaza_ne", (108, 1.7, -105), (-60, 6, 10)),
    ("cathedral_atrium", (-15, 1.7, -136), (-15, 22, -205)),
    ("madero", (-260, 1.7, -117), (-110, 6, -117)),
    ("santo_domingo", (-170, 1.7, -215), (-170, 8, -295)),
    ("canal", (-100, 1.7, 163), (100, -2, 173)),
    ("market", (-50, 1.7, 196), (0, 7, 240)),
    ("dig", (58, 1.7, -138), (105, 20, -185)),
    ("town_hall_roof", (-50, 15.7, 145), (0, 5, 0)),
    ("station_hall", (0, -6.3, 12), (0, -7, -15)),
    # The street and canal kit's places (its plan, Task 10).
    ("kerb_drop_south", (4, 1.7, 116), (0, 0, 108)),
    ("tram_curve_se", (100, 1.7, 112), (111, 0, 120)),
    ("landing_w", (-38, 1.7, 162), (-54, -1.5, 165)),
    ("bridge_stone", (-140, 1.7, 161), (-150, 0, 173)),
    ("bridge_steel", (162, -0.3, 171), (150, -0.5, 173)),
    ("hatches", (50, 1.9, 95), (55, 0.2, 98)),
]


def lay(P):
    for name, at, look in CAMERAS:
        P.landmark("camera_" + name, "camera", at, look_at=list(look))
