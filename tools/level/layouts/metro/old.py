"""Layer 3, the old passages (the Metro Underground spec, sections 3.2 and
8): older is deeper. Colonial vaults under the platforms (floor -21), the
old cistern climbing to the market, the north drain to the rebuilt crypt
under the cathedral (the Zócalo crypt's footprint), the Templo Mayor's
nested shells and the pawnshop's vault off the crypt; east along the track,
the tunnel the boring cut round an invented temple (floor -22)."""

from plan import rect

from metro.market import MARKET
from metro.station import TRACK

OLD = -21.0
TEMPLE = -22.0


def lay(P):
    P.space("vaults", rect(-40, -24, 40, 24), floor=OLD, height=3.5, layer=3,
            openings=[{"to": "cistern", "at": (-30, 24)}, {"to": "drain_n", "at": (0, -24)}])
    P.space("cistern", rect(-44, 24, -20, 52), floor=OLD, height=16.0, layer=3,
            openings=[{"to": "vaults", "at": (-30, 24)}, {"to": "cistern_lane", "at": (-20, 43)}])
    P.route("cistern_flight", "stair", [(-42, OLD, 43), (-20, MARKET, 43)])
    P.space("drain_n", rect(-4, -160, 4, -24), floor=OLD, height=4.0, layer=3,
            openings=[{"to": "vaults", "at": (0, -24)}, {"to": "vent_shaft", "at": (4, -97)},
                      {"to": "crypt", "at": (0, -160)}])

    # Under the cathedral, where the Zócalo plan had it.
    P.space("crypt", rect(-50, -250, 10, -160), floor=OLD, height=5.0, layer=3,
            openings=[{"to": "drain_n", "at": (0, -160)}, {"to": "templo_shells", "at": (10, -200)},
                      {"to": "pawn_vault", "at": (-50, -180)}])
    P.space("templo_shells", rect(70, -215, 140, -155), floor=-26.0, height=12.0, layer=3,
            openings=[{"to": "crypt", "at": (70, -200)}])
    P.space("pawn_vault", rect(-115, -205, -95, -155), floor=OLD, height=4.0, interior=True, layer=3,
            openings=[{"to": "crypt", "at": (-95, -180)}])
    P.route("tunnel_crypt_shells", "tunnel", [(10, OLD, -200), (70, -26.0, -200)], between=("crypt", "templo_shells"))
    P.route("tunnel_crypt_vault", "tunnel", [(-50, OLD, -180), (-95, OLD, -180)], between=("crypt", "pawn_vault"))

    # East along the track, the temple in the tunnel.
    P.space("temple_tunnel", rect(75, -15, 135, 15), floor=TEMPLE, height=-8.5 - TEMPLE, layer=3,
            openings=[{"to": "track", "at": (75, 0)}, {"to": "light_gallery", "at": (77, 15)},
                      {"to": "niche", "at": (110, -15)}])
    P.route("temple_tunnel_way", "tunnel", [(50, TRACK, 0), (75, TEMPLE, 0)], between=("track", "temple_tunnel"))
