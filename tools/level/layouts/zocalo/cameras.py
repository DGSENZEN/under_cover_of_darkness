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
]


def lay(P):
    for name, at, look in CAMERAS:
        P.landmark("camera_" + name, "camera", at, look_at=list(look))
