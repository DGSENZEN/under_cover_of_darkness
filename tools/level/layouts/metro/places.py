"""Where things happen (the Metro Underground spec, sections 2 and 6): the
arrival, the four exits under the Zócalo's kiosks, the station's signs, the
character places (staged with placeholder figures until talking is built;
the user writes every word), the scenes, each with its cause in the world's
events, and the puesto bays in clusters, never evenly spaced.

Landmarks are (x, y, z): y is the floor they stand on."""

from metro.market import MARKET
from metro.old import OLD, TEMPLE
from metro.service import GALLERY
from metro.station import HALL, KIOSK, LANDING, PLATFORM, TRACK

# Signs: (x, y, z, says). Only the station's three words; the user paints them.
SIGNS = [
    (-2, PLATFORM, -12.5, "Salida"), (2, PLATFORM, 12.5, "Salida"),
    (-6, HALL, -11.5, "Andén"), (6, HALL, 11.5, "Andén"),
    (-26, HALL, 0, "Salida"), (26, HALL, 0, "Salida"), (-10, HALL, 11.5, "Correspondencia"),
    (-90, HALL, 0, "Salida"), (90, HALL, 0, "Salida"),
    (-90, HALL, 56, "Salida"), (90, HALL, 66, "Salida"),
    (-9, MARKET, 144, "Correspondencia"),
]

# Character places: (name, x, y, z, who).
PLACES = [
    ("ticket_booth", 14, HALL, -10, "ticket_seller"),
    ("news_stand", -60, HALL, -2, "newspaper_seller"),
    ("stranded_car_cab", -112, TRACK, 3, "motorman"),
    ("herb_counter", -36, MARKET, 84, "stall_keeper"),
    ("chapel_corner", 40, MARKET, 80, "shrine_keeper"),
    ("fonda_stove", 56, MARKET, 114, "cook"),
    ("loft_bed", -62, -7.0, 159, "squatter"),
    ("gallery_valves", 70, GALLERY, 17, "lineman"),
    ("busker_step", -5, MARKET, 38, "busker"),
    ("crypt_lantern", -40, OLD, -240, "sacristan"),
    ("vault_desk", -105, OLD, -160, "pawn_clerk"),
    ("dig_camp", 128, TEMPLE, 10, "digger"),
]

# Scenes: (name, x, y, z, cause).
SCENES = [
    ("jammed_turnstiles", 0, HALL, -4,
     "the Light Company's surge on the Eclipse's first night fused the turnstiles open; nobody has paid since"),
    ("layered_posters", -90, HALL, -40,
     "seventy years of bills pasted over each other along the exit; the Eclipse's notices are the newest layer"),
    ("stalls_swallow_exit", -90, HALL, 84,
     "the puesteros crept up from the Pasaje until the south-west exit stair became half market"),
    ("motorman_ofrenda", 44, PLATFORM, -12,
     "an ofrenda for the motorman lost the night the lines stopped"),
    ("seeping_track", -40, TRACK, 0,
     "the colonial drain under the track overflows when it rains; the rails stand in water"),
    ("steam_main", 60, HALL, 0,
     "the Light Company's heating main breathes through a cracked joint"),
    ("stranded_car", -100, TRACK, -2,
     "a car left on the siding the night the lines stopped; the motorman never left it"),
    ("opossum_nest", 68, GALLERY, 18,
     "opossums nest on the Light Company's warm heating pipes"),
    ("copal_saints", 36, MARKET, 66,
     "the shrine keeper burns copal for the saints painted beside the station's signage"),
    ("cistern_harvest", -24, MARKET, 64,
     "the curanderas sell what the seepage grows in the old cistern below: fungus, roots, pale herbs"),
    ("bricked_correspondencia", -9, MARKET, 172,
     "the way to Pino Suárez was bricked up when the Eclipse tore the city; its Correspondencia sign still points in"),
    ("causeway_wall", 2, MARKET, 154,
     "digging the Pasaje cut through the old causeway's wall; its stones stand in the square's side"),
    ("drowned_saints", 0, OLD, -60,
     "saints thrown into the drain in the Reform, washed down with the seepage"),
    ("grate_light", 13, -9.0, -97,
     "the plaza's vent grate: the Eclipse's light and pigeon feathers fall through it"),
    ("fungus_shelves", -34, OLD, 30,
     "the cistern is warm from the Light Company's pipes and damp from seepage: fungus grows in shelves"),
    ("bone_wall", -20, OLD, -200,
     "the crypt's ossuary rebuilt when the cathedral sank; skulls set in the walls by parish"),
    ("nested_temples", 105, -26.0, -185,
     "each temple built over the last; the shells stand one inside another"),
    ("sealed_pledges", -105, OLD, -190,
     "the pawnshop's flood vault, sealed with the pledges inside"),
    ("temple_in_tunnel", 105, TEMPLE, 0,
     "the tunnel boring struck the wind god's round platform, so the engineers took the tunnel round it"),
    ("vaults_underfoot", 0, OLD, 0,
     "the colonial vaults the station was poured over; the track's drains drip into them"),
]

# Puesto bays: (x, y, z, sells) in clusters along the Pasaje and in the halls
# off it (design notes for the stall sets; no words in the game).
PUESTOS = [
    (-5.5, MARKET, 39, "tortas"), (-5.5, MARKET, 41.5, "aguas frescas"),
    (-12.5, MARKET, 52, "candles"), (-12.5, MARKET, 54.5, "saints"), (-12.5, MARKET, 57, "charms"),
    (-5.5, MARKET, 64, "records"), (-5.5, MARKET, 67, "gloves"),
    (-12.5, MARKET, 86, "herbs"),
    (-5.5, MARKET, 96, "toys"), (-5.5, MARKET, 98.5, "sweets"), (-5.5, MARKET, 101, "perfume"),
    (-12.5, MARKET, 108, "shoes"), (-12.5, MARKET, 111, "mending"),
    (-5.5, MARKET, 130, "tamales"), (-12.5, MARKET, 133, "keys"),
    (-5.5, MARKET, 145, "lottery"),
    (-40, MARKET, 70, "herbs"), (-40, MARKET, 73, "herbs"), (-30, MARKET, 88, "eggs and limpias"),
    (-18, MARKET, 80, "copal"),
    (40, MARKET, 112, "pozole"), (40, MARKET, 116, "tacos"), (58, MARKET, 132, "café de olla"),
    (-88.5, HALL, 88, "umbrellas"), (-91.5, HALL, 90, "batteries for lamps"),
]


def lay(P):
    P.landmark("arrival", "arrival", (0, PLATFORM, -9), track="north")

    for corner, sx, sz in (("nw", -1, -1), ("ne", 1, -1), ("sw", -1, 1), ("se", 1, 1)):
        P.landmark("exit_" + corner, "exit_zocalo", (sx * KIOSK[0], LANDING, sz * KIOSK[1]), kiosk=corner)

    # The crypt's way up to the cathedral, built with the Zócalo's gates (Part 2).
    P.landmark("cathedral_stair", "exit_cathedral", (-20, OLD, -247), to="cathedral")

    for i, (x, y, z, says) in enumerate(SIGNS):
        P.landmark("sign_%02d" % i, "sign", (x, y, z), says=says)

    for name, x, y, z, who in PLACES:
        P.landmark(name, "character_place", (x, y, z), who=who)

    for name, x, y, z, cause in SCENES:
        P.landmark(name, "scene", (x, y, z), scene=name, cause=cause)

    for i, (x, y, z, sells) in enumerate(PUESTOS):
        P.landmark("puesto_%02d" % i, "puesto", (x, y, z), sells=sells)
