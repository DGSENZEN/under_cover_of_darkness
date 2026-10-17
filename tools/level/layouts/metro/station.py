"""Layer 1, the working station (the Metro Underground spec, section 3.2):
Line 2's two side platforms either side of the track (floor -14, the track
bed 1.2 m down), a stairwell up from each into the ticket hall stacked over
them (floor -8), corridors west and east to a crossing each, and from the
crossings a corridor to each of the Zócalo's four kiosks, ending in a long
stair up to a landing under the kiosk (floor -3) where the Zócalo begins.
West along the track, a siding.

The spine (spec, section 8): the arrival on the north platform, up its
stairwell, across the hall, west and north to the kiosk at (-90, -98)."""

from plan import rect

PLATFORM = -14.0
TRACK = -15.2
HALL = -8.0
# The landings under the kiosks; the Zócalo's own stair comes down to them (Part 2).
LANDING = -3.0
# Every stacked space keeps this much slab between them (m).
SLAB = 0.5
# Platforms and track: their ceiling a slab under the hall's floor.
PLATFORM_HEIGHT = HALL - SLAB - PLATFORM
TRACK_HEIGHT = HALL - SLAB - TRACK
CORRIDOR_HEIGHT = 3.5
# The kiosks' centres on the plaza (the Zócalo plan's).
KIOSK = (90.0, 98.0)


def lay(P):
    # The platforms either side of the track; the track open to both along
    # their whole length, a stair down at one end of each.
    P.space("platform_n", rect(-50, -14, 50, -7), floor=PLATFORM, height=PLATFORM_HEIGHT, layer=1,
            openings=[{"to": "track", "at": (0, -7), "width": 100, "height": PLATFORM_HEIGHT},
                      {"to": "stairs_n", "at": (-2, -14)}])
    P.space("track", rect(-50, -7, 50, 7), floor=TRACK, height=TRACK_HEIGHT, layer=1,
            openings=[{"to": "platform_n", "at": (0, -7), "width": 100, "height": PLATFORM_HEIGHT},
                      {"to": "platform_s", "at": (0, 7), "width": 100, "height": PLATFORM_HEIGHT},
                      {"to": "siding", "at": (-50, 0)}, {"to": "temple_tunnel", "at": (50, 0)}])
    P.space("platform_s", rect(-50, 7, 50, 14), floor=PLATFORM, height=PLATFORM_HEIGHT, layer=1,
            openings=[{"to": "track", "at": (0, 7), "width": 100, "height": PLATFORM_HEIGHT},
                      {"to": "stairs_s", "at": (2, 14)}])
    P.route("track_steps_n", "stair", [(46, PLATFORM, -7.3), (46, TRACK, -4.6)])
    P.route("track_steps_s", "stair", [(-46, PLATFORM, 7.3), (-46, TRACK, 4.6)])

    # West along the track, the siding.
    P.space("siding", rect(-130, -8, -70, 8), floor=TRACK, height=TRACK_HEIGHT, layer=1,
            openings=[{"to": "track", "at": (-70, 0)}])
    P.route("siding_tunnel", "tunnel", [(-50, TRACK, 0), (-70, TRACK, 0)], between=("track", "siding"))

    # A stairwell off each platform up into the hall.
    for side, sz in (("n", -1), ("s", 1)):
        x0 = -8 if sz < 0 else 0
        stair_x = x0 + (2 if sz < 0 else 6)
        door_x = x0 + (6 if sz < 0 else 2)
        P.space("stairs_" + side, rect(x0, sz * 14, x0 + 8, sz * 30), floor=PLATFORM, height=HALL + 5.0 - PLATFORM,
                layer=1, openings=[{"to": "platform_" + side, "at": (door_x, sz * 14)},
                                   {"to": "hall", "at": (stair_x, sz * 14)}])
        P.route("stairs_%s_flight" % side, "stair", [(stair_x, PLATFORM, sz * 28.5), (stair_x, HALL, sz * 14.0)])

    # The ticket hall over the platforms.
    P.space("hall", rect(-30, -14, 30, 14), floor=HALL, height=5.0, layer=1,
            openings=[{"to": "stairs_n", "at": (-6, -14)}, {"to": "stairs_s", "at": (6, 14)},
                      {"to": "corridor_w", "at": (-30, 0), "width": 4.0}, {"to": "corridor_e", "at": (30, 0), "width": 4.0},
                      {"to": "market_stairs", "at": (-10, 14)}])

    for side, sx in (("w", -1), ("e", 1)):
        P.space("corridor_" + side, rect(sx * 30, -3, sx * 85, 3), floor=HALL, height=CORRIDOR_HEIGHT, layer=1,
                openings=[{"to": "hall", "at": (sx * 30, 0), "width": 4.0}, {"to": "cross_" + side, "at": (sx * 85, 0), "width": 4.0}])
        P.space("cross_" + side, rect(sx * 85, -6, sx * 95, 6), floor=HALL, height=4.0, layer=1,
                openings=[{"to": "corridor_" + side, "at": (sx * 85, 0), "width": 4.0},
                          {"to": "corridor_n" + side, "at": (sx * 90, -6)},
                          {"to": "corridor_s" + side, "at": (sx * 90, 6)}])

    # From each crossing to its kiosk: a corridor, a stairwell, the landing.
    for corner, sx, sz in (("nw", -1, -1), ("ne", 1, -1), ("sw", -1, 1), ("se", 1, 1)):
        x = sx * KIOSK[0]
        cross = "cross_" + corner[1]
        corridor, stairs, landing = "corridor_" + corner, "exit_stairs_" + corner, "kiosk_landing_" + corner
        extra = []

        # (The market's lanes come up into the two south corridors.)
        if corner == "sw":
            extra = [{"to": "lane_sw", "at": (x + 3, 62.5)}]
        elif corner == "se":
            # (The gallery's door no taller than the gallery under it; service.GALLERY_DOOR.)
            extra = [{"to": "light_gallery", "at": (x - 3, 17), "height": 2.5}, {"to": "lane_se", "at": (x - 3, 72.5)}]

        P.space(corridor, rect(x - 3, sz * 6, x + 3, sz * 80), floor=HALL, height=CORRIDOR_HEIGHT, layer=1,
                openings=[{"to": cross, "at": (x, sz * 6)}, {"to": stairs, "at": (x, sz * 80)}] + extra)
        P.space(stairs, rect(x - 3, sz * 80, x + 3, sz * 95), floor=HALL, height=-0.2 - HALL, layer=1,
                openings=[{"to": corridor, "at": (x, sz * 80)}, {"to": landing, "at": (x, sz * 95)}])
        P.route(stairs + "_flight", "stair", [(x, HALL, sz * 81.5), (x, LANDING, sz * 95.0)])
        P.space(landing, rect(x - 4, sz * 95, x + 4, sz * 102), floor=LANDING, height=2.8, layer=1,
                openings=[{"to": stairs, "at": (x, sz * 95)}])
