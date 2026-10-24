"""The Light Company's service ways (the Metro Underground spec, sections 2
and 3.1): its pipes are the city's power and heat, threaded through all
three layers. A gallery off the temple tunnel, reached up the pipe run, back
to the south-east corridor; the vent shaft from the north drain up to the
grate under the plaza; the squatter's loft over the storeroom; the offering
niche high in the temple tunnel. Each climb is a ladder (a pipe run, rungs)."""

from plan import rect

from metro.market import MARKET
from metro.old import OLD, TEMPLE
from metro.station import HALL

# The gallery under the corridors: its door into the temple tunnel a full
# height under the tunnel's ceiling (-8.5).
GALLERY = -12.0
# The gallery's door into the corridor: from the corridor's floor up to the
# gallery's ceiling (-5.5), so no gap opens above the gallery's roof.
GALLERY_DOOR = 2.5


def lay(P):
    # Up the pipe run from the temple tunnel to the gallery, and on to the
    # south-east corridor.
    P.space("light_gallery", rect(66, 15, 87, 19), floor=GALLERY, height=HALL + 2.5 - GALLERY, layer=2,
            openings=[{"to": "temple_tunnel", "at": (77, 15)},
                      {"to": "corridor_se", "at": (87, 17), "height": GALLERY_DOOR}])
    P.route("pipe_run_gallery", "climb", [(76, TEMPLE, 14.7), (76, GALLERY, 15.3)])
    P.route("light_gallery_flight", "stair", [(87, HALL, 17), (77, GALLERY, 17)])

    # The vent shaft off the north drain, up to the grate under the plaza.
    P.space("vent_shaft", rect(4, -100, 10, -94), floor=OLD, height=20.0, layer=3,
            openings=[{"to": "drain_n", "at": (4, -97)}, {"to": "grate_room", "at": (10, -97)}])
    P.route("vent_shaft_rungs", "climb", [(9.7, OLD, -97), (10.3, -9.0, -97)])
    P.space("grate_room", rect(10, -100, 16, -94), floor=-9.0, height=8.0, layer=2,
            openings=[{"to": "vent_shaft", "at": (10, -97)}])

    # The squatter's loft over the storeroom.
    P.space("loft", rect(-66, 156, -54, 162), floor=-7.0, height=3.0, layer=2,
            openings=[{"to": "storeroom", "at": (-60, 156)}])
    P.route("loft_ladder", "climb", [(-60, MARKET, 155.7), (-60, -7.0, 156.3)])

    # The offering niche high in the temple tunnel's north wall.
    P.space("niche", rect(105, -21, 115, -15), floor=-17.0, height=4.0, layer=3,
            openings=[{"to": "temple_tunnel", "at": (110, -15)}])
    P.route("niche_pipes", "climb", [(110, TEMPLE, -14.7), (110, -17.0, -15.3)])
