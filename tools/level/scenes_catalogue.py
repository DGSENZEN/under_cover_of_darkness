"""The Zócalo's scenes as data (docs/superpowers/specs/2026-10-10-zocalo-scenes-design.md):
each a moment with a reason to be where it is, its props, its stand-ins
posed mid-action (stations for the NPCs to come), what they hold, its
effects and any chalk on the ground. dress_scenes.py finds the places and
stages them.

A scene's frame: its origin at its site, +Z its front (toward the street or
whoever watches), +X to its right, metres; a part's `turn` (degrees) is
from the scene's facing (a figure at turn 0 faces the scene's front, at 180
its back). Parts:
  pieces   (piece, (x, z), turn[, y])         y over the ground (a figure on a soapbox)
  figures  (pose, (x, z), turn, role[, y])
  holds    (piece, figure index, hand, grip)  carried at that figure's hand,
                                              `grip` (m) up the piece from its foot
  emitters (effect, (x, y, z))                Ambient.gd's effects
  decals   (texture, (x, z), size)            painted on the ground
`sites` are the kinds of place it may stand (dress_scenes.KINDS), `zones`
(when given) the zones those places must be in.
"""

from dataclasses import dataclass, field


@dataclass
class Recipe:
    name: str
    sites: tuple
    when: str            # "day", "night", "both"
    story: str
    pieces: list = field(default_factory=list)
    figures: list = field(default_factory=list)
    emitters: list = field(default_factory=list)
    holds: list = field(default_factory=list)
    decals: list = field(default_factory=list)
    spacing: float = 80.0
    landmark: str = None
    variant_of: str = None
    zones: tuple = None


def _to(at, target):
    """The turn (degrees) that faces a part at `at` toward `target`, both in the scene's frame."""
    import math
    return round(math.degrees(math.atan2(target[0] - at[0], target[1] - at[1])) % 360.0, 1)


def _ring(centre, radius, count, start=0.0, spread=360.0):
    """`count` points round `centre` facing it (pose positions and turns)."""
    import math
    out = []

    for k in range(count):
        a = math.radians(start + spread * k / max(count - (0 if spread >= 360 else 1), 1))
        x, z = centre[0] + radius * math.sin(a), centre[1] + radius * math.cos(a)
        out.append(((round(x, 2), round(z, 2)), round(math.degrees(a) + 180.0, 1)))

    return out


RECIPES = [
    # The landmarks, one each at their place.
    Recipe("god_devotion", ("god_ring",), "both",
           "El Secreto made the chained god the Zócalo's Patron, and the faithful keep it fed: they kneel at its "
           "offerings while a warden swings copal.",
           pieces=[("candles_drift", (-4.7, 1.2), 90), ("candles_drift", (4.7, 1.2), 270), ("petals_marigold", (0.0, 7.0), 0)],
           figures=[("fig_kneel_pray", xz, _to(xz, (0.0, 0.0)), "devotee")
                    for xz in ((-3.0, 3.6), (-3.5, 4.0), (3.0, 3.6), (3.5, 4.0), (-4.6, 2.9), (4.6, 2.9))]
           + [("fig_hold_lantern", (-4.9, 0.8), _to((-4.9, 0.8), (0.0, 4.0)), "warden of El Secreto")],
           holds=[("censer", 6, "right", 0.65)],
           emitters=[("copal", (0.0, 0.6, 4.2)), ("copal", (-5.1, 1.0, 1.2)), ("candles", (-4.7, 0.3, 1.2)),
                     ("candles", (4.7, 0.3, 1.2)), ("petals", (0.0, 0.0, 5.0))],
           landmark="god_ring"),
    Recipe("god_press", ("god_ring",), "day",
           "The papers never tire of the god: a press photographer at his tripod, two reporters calling questions, a "
           "gendarme keeping the cage.",
           pieces=[("camera_tripod", (-1.6, -4.5), _to((-1.6, -4.5), (0.0, 0.0)))],
           figures=[("fig_photographer", (-1.6, -5.2), _to((-1.6, -5.2), (0.0, 0.0)), "press photographer"),
                    ("fig_point", (0.4, -5.3), _to((0.4, -5.3), (0.0, 0.0)), "reporter"),
                    ("fig_dictate", (1.3, -4.9), _to((1.3, -4.9), (0.0, 0.0)), "reporter"),
                    ("fig_stand", (3.2, -4.0), _to((3.2, -4.0), (5.0, -9.0)), "gendarme")],
           landmark="god_ring"),
    Recipe("preacher", ("god_ring",), "day",
           "The Calles Law silenced the churches, so the priest preaches in the square, on a soapbox under the god "
           "he damns; a few listen, one heckles.",
           pieces=[("crate_soapbox", (-12.0, 0.0), 90)],
           figures=[("fig_barker", (-12.0, 0.0), 90, "priest", 0.35)]
           + [(pose, xz, _to(xz, (-12.0, 0.0)), role) for pose, xz, role in
              (("fig_queue", (-10.0, 1.4), "listener"), ("fig_stand", (-9.6, 0.0), "listener"),
               ("fig_mourner", (-10.0, -1.4), "listener"), ("fig_queue", (-9.0, 1.0), "listener"),
               ("fig_point", (-8.6, -1.2), "heckler"))],
           landmark="god_ring"),
    Recipe("evangelistas", ("evangelistas",), "day",
           "Under Santo Domingo's arcade the public letter-writers type for those who cannot: love, debts, petitions "
           "to the Inquisition's heirs.",
           pieces=[("typewriter_desk", (x, 0.0), 0) for x in (-4.5, -1.5, 1.5, 4.5)]
           + [("stool", (x, -0.65), 0) for x in (-4.5, -1.5, 1.5, 4.5)],
           figures=[("fig_type", (x, -0.65), 0, "evangelista") for x in (-4.5, -1.5, 1.5, 4.5)]
           + [("fig_dictate", (x + 0.2, 0.9), 180, "client") for x in (-4.5, -1.5, 1.5, 4.5)]
           + [("fig_queue", (6.6, 1.0), 220, "waiting"), ("fig_queue", (7.4, 1.4), 220, "waiting")],
           landmark="evangelistas"),
    Recipe("monster_wagon", ("market",), "both",
           "The canal came back and brought the ahuízotl with it: caught, tanked and shown for a centavo, its barker "
           "on his box, a ring of faces, a child held up to see.",
           pieces=[("wagon_monster", (0.0, -1.0), 0), ("crate_soapbox", (1.9, 0.6), 0), ("atole_pot", (-3.6, 1.2), 0)],
           figures=[("fig_barker", (1.9, 0.6), 340, "barker", 0.35), ("fig_stand", (-3.6, 0.5), 20, "atole seller")]
           + [(pose, xz, turn, "onlooker") for (xz, turn), pose in
              zip(_ring((0.0, 1.0), 2.7, 7, start=-70, spread=140),
                  ["fig_point", "fig_stand", "fig_queue", "fig_child_held", "fig_stand", "fig_point", "fig_child"])],
           emitters=[("steam", (-3.6, 0.75, 1.2))],
           landmark="market"),
    Recipe("market_hall", ("hall_door",), "day",
           "The market hall's doors: carts nose to tail either side, porters with baskets, shoppers, the dogs that "
           "follow the tamales.",
           pieces=[("cart_flower", (-4.4, -1.0), 90), ("cart_hand", (-7.4, -1.0), 90), ("cart_tamale", (4.4, -1.0), 270),
                   ("cart_ice", (7.4, -1.0), 270)],
           figures=[("fig_stand", (-4.4, -2.3), 0, "flower seller"), ("fig_stand", (-7.4, -2.3), 0, "seller"),
                    ("fig_stand", (4.4, -2.3), 0, "tamale seller"), ("fig_stand", (7.4, -2.3), 0, "ice seller"),
                    ("fig_carry_basket", (-1.5, 1.6), 10, "porter"), ("fig_carry_basket", (1.4, 1.2), 200, "porter"),
                    ("fig_walk", (-5.0, 1.4), 80, "shopper"), ("fig_walk", (5.6, 1.6), 270, "shopper"),
                    ("fig_queue", (3.4, 0.6), 160, "shopper"), ("dog_sniff", (-3.0, 0.9), 120, "dog")],
           holds=[("basket", 4, "right", 0.3), ("basket", 5, "right", 0.3)],
           emitters=[("steam", (4.2, 1.3, -1.0))],
           landmark="hall_door"),
    Recipe("market_hall_night", ("hall_door",), "night",
           "After dark the carts are covered and chained at the hall's doors; the watchman sleeps against the wall, "
           "his lantern by him.",
           pieces=[("cart_covered", (-4.4, -1.0), 90), ("cart_covered", (-7.4, -1.0), 90), ("cart_covered", (4.4, -1.0), 270),
                   ("lantern_set", (-1.7, -2.4), 0)],
           figures=[("fig_sleep_wall", (-2.6, -2.5), 0, "watchman"), ("dog_lie", (6.0, -2.2), 90, "dog")],
           landmark="hall_door", variant_of="market_hall"),
    Recipe("flower_row", ("market",), "day",
           "Before the hall the flower sellers stand together, cempasúchil heaped for the dead, buckets of it at "
           "their feet.",
           pieces=[("cart_flower", (x, -0.8), 90) for x in (-6.0, -3.0, 0.0, 3.0, 6.0)]
           + [("flowers_bucket", (x, 0.6), 0) for x in (-4.5, -1.5, 1.5, 4.5)] + [("baskets_stack", (7.8, 0.2), 0)],
           figures=[("fig_stand", (x, 1.3), 180, "flower seller") for x in (-6.0, 0.0, 6.0)]
           + [("fig_walk", (-2.6, 2.2), 90, "shopper")],
           emitters=[("petals", (0.0, 0.0, 0.5))],
           landmark="market_flowers"),
    Recipe("firewood_landing", ("landing",), "day",
           "Firewood comes up from the canal by canoe and is stacked on the quay; porters carry it up from the "
           "landing.",
           pieces=[("firewood_stack", (-1.6, -1.2), 0), ("firewood_stack", (0.0, -1.3), 10), ("cart_firewood", (3.4, 0.0), 90)],
           figures=[("fig_carry_basket", (0.9, 1.2), 0, "porter"), ("fig_carry_basket", (-0.8, 1.8), 350, "porter"),
                    ("fig_stand", (2.0, -1.0), 300, "wood seller")],
           holds=[("firewood_bundle", 0, "right", 0.2), ("firewood_bundle", 1, "right", 0.2)],
           landmark="landing"),

    # The scenes the director lays where they fit.
    Recipe("tamale_stop", ("tram_stop", "metro_mouth", "plaza_walk"), "both",
           "Where people wait, the tamalera waits for them: steam off the pot, a short queue, a dog hoping.",
           pieces=[("cart_tamale", (0.0, -0.6), 0)],
           figures=[("fig_stand", (0.9, -1.0), 20, "tamalera"), ("fig_queue", (1.7, 0.5), 270, "customer"),
                    ("fig_queue", (2.5, 0.6), 270, "customer"), ("fig_walk", (3.4, 0.3), 260, "customer"),
                    ("fig_carry_basket", (-1.2, 1.9), 150, "passer-by"), ("dog_sit", (-1.4, 0.9), 60, "dog")],
           holds=[("basket", 4, "right", 0.3)],
           emitters=[("steam", (-0.4, 1.3, 0.0))], spacing=60.0),
    Recipe("atole_corner", ("corner",), "night",
           "On a night corner a woman sells atole from her olla over the coals; men drink it standing, one sits on "
           "the kerb with his cup.",
           pieces=[("atole_pot", (0.0, 0.0), 0)],
           figures=[("fig_stand", (-0.7, -0.5), 40, "atole seller"), ("fig_queue", (0.9, 0.7), 225, "drinker"),
                    ("fig_lean_wall", (1.2, -0.5), 270, "drinker"), ("fig_sit_kerb", (-0.5, 1.4), 160, "drinker"),
                    ("fig_stand", (1.9, 0.6), 250, "drinker"), ("fig_point", (2.4, -0.4), 280, "drinker")],
           emitters=[("steam", (0.0, 0.75, 0.0)), ("coals", (0.0, 0.1, 0.0))], spacing=100.0),
    Recipe("newsboy", ("metro_mouth", "tram_stop", "plaza_walk"), "day",
           "A voceador shouts the evening's crimes at the Metro's mouth; readers stop for the paper (its pages the "
           "user's).",
           pieces=[("kiosk_news", (0.0, -1.0), 0)],
           figures=[("fig_point", (1.7, 0.9), 30, "voceador"), ("fig_stand", (-1.7, 0.9), 340, "reader"),
                    ("fig_stand", (-0.6, 1.8), 10, "reader"), ("fig_walk", (2.6, 2.0), 90, "passer-by")]),
    Recipe("shoeshine", ("arcade",), "day",
           "Under the arcade a bolero shines a customer's shoes; the customer reads (the paper is the user's); the "
           "next waits his turn.",
           pieces=[("shoeshine_stand", (0.0, 0.0), 0), ("chair", (0.9, -0.2), 0)],
           figures=[("fig_sit_chair", (0.9, -0.2), 0, "customer"), ("fig_crouch_inspect", (0.9, 0.9), 180, "bolero"),
                    ("fig_lean_wall", (-1.4, -0.3), 20, "waiting"), ("fig_walk", (2.6, 1.2), 270, "passer-by")],
           spacing=40.0),
    Recipe("organillero", ("plaza_edge", "plaza_walk", "frontage"), "day",
           "An organillero cranks his barrel organ; his partner holds out the cap; people stop to listen, a couple "
           "too long.",
           pieces=[("barrel_organ", (0.0, 0.0), 0)],
           figures=[("fig_stand", (0.8, -0.3), 330, "organillero"), ("fig_point", (-1.1, 0.7), 20, "collector")]
           + [(pose, xz, _to(xz, (0.0, 0.0)), "listener") for pose, xz in
              (("fig_queue", (-0.8, 2.4)), ("fig_stand", (0.4, 2.8)), ("fig_queue", (1.6, 2.2)), ("fig_child", (-1.7, 1.8)),
               ("fig_stand", (2.6, 1.4)), ("fig_mourner", (-2.6, 1.0)))],
           zones=("plaza", "madero")),
    Recipe("pajarito_suerte", ("plaza_edge", "plaza_walk", "frontage"), "day",
           "The canary picks a fortune from the box for a client; the fortune-teller sits behind; two girls wait "
           "their turn.",
           pieces=[("canary_box", (0.0, 0.0), 0), ("chair", (0.0, -0.7), 0)],
           figures=[("fig_sit_chair", (0.0, -0.7), 0, "fortune-teller"), ("fig_stand", (0.2, 0.9), 180, "client"),
                    ("fig_queue", (1.3, 1.3), 210, "waiting"), ("fig_child", (1.9, 1.0), 230, "waiting"),
                    ("fig_point", (-1.3, 1.4), 150, "onlooker")],
           zones=("plaza", "madero")),
    Recipe("curandera_limpia", ("street_mouth", "market", "plaza_walk"), "both",
           "A curandera sweeps a client with herbs and an egg in copal smoke, cleansing what the city put on them; "
           "others wait their turn.",
           pieces=[("basket", (1.3, -0.6), 0)],
           figures=[("fig_dictate", (0.6, 0.0), 270, "curandera"), ("fig_stand", (-0.4, 0.0), 90, "client"),
                    ("fig_queue", (-1.6, 1.3), 120, "waiting"), ("fig_child", (-2.2, 1.0), 110, "waiting"),
                    ("fig_mourner", (1.4, 1.5), 210, "waiting")],
           holds=[("censer", 0, "right", 0.65)],
           emitters=[("copal", (0.3, 1.0, 0.2))], spacing=120.0),
    Recipe("line_of_the_dead", ("plaza_corner", "church_steps"), "day",
           "The seeped telephone rings with the dead: the living queue with candles to hear them, one at the "
           "receiver now.",
           pieces=[("booth_line_of_dead", (0.0, -0.6), 0), ("candles_drift", (0.0, 5.2), 0)],
           figures=[("fig_stand", (0.0, 0.4), 180, "listener")]
           + [("fig_queue", (0.1 * (k % 2), 1.3 + 0.75 * k), 180, "mourner") for k in range(5)],
           emitters=[("mist", (0.0, 0.1, -0.6)), ("candles", (0.0, 0.3, 5.2))]),
    Recipe("line_of_the_dead_night", ("plaza_corner", "church_steps"), "night",
           "At night a medium sits at the seeped telephone and the mourners stand round her while she listens.",
           pieces=[("booth_line_of_dead", (0.0, -0.6), 0), ("chair", (0.0, 0.9), 180), ("candles_drift", (0.0, 3.3), 0)],
           figures=[("fig_sit_chair", (0.0, 0.9), 180, "medium")]
           + [(pose, xz, turn, "mourner") for (xz, turn), pose in
              zip(_ring((0.0, 1.3), 1.7, 5, start=-80, spread=160), ["fig_mourner"] * 5)],
           emitters=[("mist", (0.0, 0.1, -0.6)), ("candles", (0.0, 0.3, 3.3))],
           variant_of="line_of_the_dead"),
    Recipe("testimony", ("church_steps",), "day",
           "El Secreto takes testimony of what was seen: a queue at the booth, its clerk, relics crated and sealed.",
           pieces=[("booth_testimony", (0.0, -0.6), 0), ("crates_relics", (-3.4, -0.6), 90)],
           figures=[("fig_stand", (1.1, -0.6), 300, "clerk of El Secreto")]
           + [("fig_queue", (0.1 * (k % 2), 1.0 + 0.8 * k), 180, "witness") for k in range(4)]),
    Recipe("wake", ("frontage",), "night",
           "A wake on the pavement before a house: the coffin on two chairs, candles at the wall, mourners in two "
           "rows, an old woman sitting, the family's dog.",
           pieces=[("coffin_on_chairs", (0.0, 0.5), 90), ("candles_drift", (0.0, -0.4), 0), ("chair", (-2.3, 0.2), 0)],
           figures=[("fig_sit_chair", (-2.3, 0.2), 30, "widow")]
           + [("fig_mourner", (x, 1.7), 180, "mourner") for x in (-1.5, -0.5, 0.5, 1.5)]
           + [("fig_mourner", (x, 2.6), 180, "mourner") for x in (-1.0, 0.0, 1.0)] + [("dog_lie", (2.1, -0.1), 90, "dog")],
           emitters=[("candles", (0.0, 0.3, -0.4)), ("petals", (0.0, 0.0, 1.2))],
           zones=("side",)),
    Recipe("rail_accident", ("rails",), "day",
           "A tram took a fruit cart at the rails: the cart on its side, fruit everywhere, a chalk ring, a gendarme "
           "taking it down, people staring, the seller picking up what she can.",
           pieces=[("cart_overturned", (0.0, 0.0), 0), ("crates_spilled", (2.0, 1.5), 0)],
           figures=[("fig_dictate", (-2.6, 1.6), 40, "gendarme"), ("fig_point", (0.5, 3.2), 180, "onlooker"),
                    ("fig_stand", (1.6, 3.4), 190, "onlooker"), ("fig_child", (-0.6, 3.3), 170, "onlooker"),
                    ("fig_crouch_inspect", (3.2, 0.6), 270, "fruit seller"), ("fig_stand", (-1.6, 3.5), 160, "onlooker"),
                    ("fig_mourner", (2.8, 3.0), 200, "the seller's daughter"), ("fig_walk", (-3.4, 2.8), 90, "passer-by")],
           decals=[("chalk_ring", (0.3, 0.6), 4.5)]),
    Recipe("brazier_watch", ("dark_spot",), "night",
           "Where the Company let the lamps die, men keep a brazier going and watch the dark together.",
           pieces=[("brazier", (0.0, 0.0), 0), ("crate", (-1.2, -0.7), 0)],
           figures=[("fig_stand", (1.0, 0.2), 260, "watcher"), ("fig_stand", (0.1, 1.1), 180, "watcher"),
                    ("fig_lean_wall", (-0.9, 0.9), 140, "watcher"), ("fig_sit_chair", (-1.2, -0.7), 60, "watcher"),
                    ("dog_lie", (1.4, -1.1), 300, "dog")],
           emitters=[("brazier", (0.0, 0.9, 0.0))], spacing=150.0),
    Recipe("warden_inspection", ("claw_slab",), "night",
           "Wardens of El Secreto read the claw-scored stone under the dead lamp: one crouched over the scores with "
           "his lantern set down, one holding his up.",
           pieces=[("lantern_set", (1.0, 1.7), 0)],
           figures=[("fig_crouch_inspect", (0.2, 1.8), 180, "warden"), ("fig_hold_lantern", (-1.8, 1.5), 130, "warden")],
           holds=[("lantern_carried", 1, "right", 0.4)]),
    Recipe("idol_surfacing", ("subsidence",), "day",
           "Where the ground sank a god's head came up through the setts; El Secreto fenced it, and the city came "
           "to look: a sketch artist, a gendarme, gawkers, copal burning for it.",
           pieces=[("secreto_barrier", (0.0, 2.4), 0), ("stool", (2.7, 3.3), 0)],
           figures=[("fig_sit_chair", (2.7, 3.3), _to((2.7, 3.3), (0.0, 0.0)), "sketch artist"),
                    ("fig_stand", (-2.5, 3.0), _to((-2.5, 3.0), (0.0, 0.0)), "gendarme"),
                    ("fig_point", (-0.9, 3.6), 180, "gawker"), ("fig_stand", (0.5, 3.8), 175, "gawker"),
                    ("fig_child_held", (1.5, 4.2), 185, "gawker"), ("fig_kneel_pray", (-1.8, 4.0), 160, "devotee")],
           emitters=[("copal", (0.0, 0.4, 1.5))]),
    Recipe("idol_surfacing_night", ("subsidence",), "night",
           "At night one warden keeps the surfaced god, his lantern up, the copal still burning.",
           pieces=[("secreto_barrier", (0.0, 2.4), 0)],
           figures=[("fig_hold_lantern", (2.0, 3.1), _to((2.0, 3.1), (0.0, 0.0)), "warden")],
           holds=[("lantern_carried", 0, "right", 0.4)],
           emitters=[("copal", (0.0, 0.4, 1.5))],
           variant_of="idol_surfacing"),
    Recipe("hatch_watch", ("sealed_hatch",), "night",
           "Something under the sealed hatch knocks at night: two wardens keep it, one crouched at its chains.",
           pieces=[("lantern_set", (1.4, 1.2), 0)],
           figures=[("fig_hold_lantern", (-1.5, 1.2), 120, "warden"), ("fig_crouch_inspect", (0.5, 1.6), 190, "warden")],
           holds=[("lantern_carried", 0, "right", 0.4)]),
    Recipe("hatch_watch_day", ("sealed_hatch",), "day",
           "By day the wardens' chalk ring is left round the sealed hatch, and a dog sniffs at the edge of it.",
           figures=[("dog_sniff", (1.6, 1.4), 230, "dog")],
           decals=[("chalk_ring", (0.0, 0.0), 3.2)],
           variant_of="hatch_watch"),
    Recipe("cage_trap", ("dark_spot",), "night",
           "In a dark corner the trapper has caught a chaneque; he crouches by the cage, his boy holding the lantern.",
           pieces=[("cage_trap_chaneque", (0.0, -0.6), 0), ("cage_trap", (1.3, -0.6), 0), ("lantern_set", (-0.8, 0.5), 0)],
           figures=[("fig_crouch_inspect", (0.2, 1.0), 180, "trapper"), ("fig_hold_lantern", (-1.4, 1.3), 140, "trapper's boy")],
           holds=[("lantern_carried", 1, "right", 0.4)], spacing=150.0),
    Recipe("cage_trap_day", ("dark_spot",), "day",
           "By day the trap holds a lechuza, staring back at the children who came to peer at it; their mother "
           "calls them away.",
           pieces=[("cage_trap_lechuza", (0.0, -0.6), 0)],
           figures=[("fig_child", (0.4, 0.9), 190, "child"), ("fig_child", (-0.5, 1.0), 170, "child"),
                    ("fig_point", (-1.8, 2.0), 140, "mother")],
           variant_of="cage_trap"),
    Recipe("pulque_delivery", ("frontage",), "day",
           "Pulque barrels at a pulquería's door, one rolled in; a drunk asleep against the wall, his friend still "
           "standing, a dog by them.",
           pieces=[("pulque_barrels", (0.0, -0.3), 0)],
           figures=[("fig_push_cart", (1.3, 0.5), 270, "carter"), ("fig_sleep_wall", (-1.7, -0.6), 0, "drunk"),
                    ("fig_lean_wall", (-2.6, -0.5), 30, "drunk's friend"), ("dog_lie", (-2.5, 0.6), 60, "dog"),
                    ("fig_point", (2.6, 1.2), 230, "the pulquero")],
           zones=("side", "madero")),
    Recipe("curiosities", ("market", "plaza_edge", "plaza_walk"), "day",
           "A stand of curiosities: hands in jars, saints' bones, things the canal gave up; browsers lean in, a "
           "child is pulled back.",
           pieces=[("stand_curiosities", (0.0, -0.3), 0)],
           figures=[("fig_stand", (0.2, -1.0), 0, "seller"), ("fig_point", (-0.4, 0.9), 180, "browser"),
                    ("fig_stand", (0.6, 1.0), 200, "browser"), ("fig_child", (1.4, 0.8), 220, "child"),
                    ("fig_queue", (-1.4, 1.2), 140, "browser"), ("fig_walk", (2.6, 2.2), 270, "passer-by")]),
    Recipe("luchador_shrine", ("corner", "market"), "both",
           "A shrine to a dead luchador at a market corner; his fans kneel at it, candles lit, one stands with his "
           "mask in his hands.",
           pieces=[("shrine_luchador", (0.0, -0.2), 0)],
           figures=[("fig_kneel_pray", (-0.3, 0.8), 180, "devotee"), ("fig_kneel_pray", (0.4, 0.9), 170, "devotee"),
                    ("fig_kneel_pray", (-1.1, 1.0), 160, "devotee"), ("fig_mourner", (1.2, 1.4), 200, "fan"),
                    ("fig_child", (1.9, 1.0), 220, "fan"), ("fig_stand", (-1.9, 1.6), 150, "fan")],
           emitters=[("candles", (0.0, 0.3, 0.3))], zones=("hall", "side")),
    Recipe("spirit_photographer", ("plaza_edge", "plaza_walk"), "day",
           "A spirit photographer's booth: sit for him and the plate shows who stands behind you.",
           pieces=[("booth_photographer", (0.0, -0.8), 0), ("chair", (-0.3, -1.0), 0)],
           figures=[("fig_sit_chair", (-0.3, -1.0), 0, "sitter"), ("fig_photographer", (0.4, 0.9), 180, "photographer"),
                    ("fig_queue", (2.7, 0.9), 220, "waiting"), ("fig_mourner", (3.3, 1.5), 230, "waiting")]),
    Recipe("lottery", ("metro_mouth", "tram_stop", "plaza_edge", "plaza_walk", "frontage"), "day",
           "The lottery seller's kiosk and the sweets seller's beside it; buyers weigh a ticket, a child wants sweets.",
           pieces=[("kiosk_lottery", (-0.8, -0.4), 0), ("kiosk_sweets", (1.3, -0.4), 0)],
           figures=[("fig_dictate", (-0.8, 0.7), 340, "lottery seller"), ("fig_stand", (0.4, 1.3), 200, "buyer"),
                    ("fig_point", (1.4, 0.9), 180, "child's mother"), ("fig_child", (1.8, 0.7), 190, "child")],
           zones=("plaza", "madero", "hall")),
    Recipe("laundry", ("street_span",), "day",
           "Washing strung across a narrow street from wall to wall; two women with their baskets below it, talking.",
           pieces=[("laundry_line", (0.0, 0.0), -90)],
           figures=[("fig_carry_basket", (1.2, 1.0), 0, "washerwoman"), ("fig_dictate", (1.4, 2.2), 180, "neighbour")],
           holds=[("basket", 0, "right", 0.3)], spacing=60.0),
    Recipe("street_dogs", ("frontage",), "both",
           "Street dogs at a wall's foot: one asleep, one sitting, one nosing the gutter.",
           figures=[("dog_lie", (0.0, 0.4), 90, "dog"), ("dog_sit", (0.9, 0.7), 330, "dog"), ("dog_sniff", (-0.9, 1.0), 200, "dog")],
           spacing=60.0, zones=("side", "madero")),
]
