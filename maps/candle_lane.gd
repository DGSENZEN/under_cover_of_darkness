extends "res://maps/underground_lab.gd"
## The candle lane (docs/superpowers/specs/2026-10-23-candle-lane-design.md): the Underground corridor bay run out to the
## Metro's lane between the Pasaje and the chapel, the librarian's shop opening off its south side. The bay's frame: x
## along the lane, z across it (BACK_WALL its north wall, FAR_WALL its south), the floor at 0; plan (x, y) is
## (x + 12.8, z + 74.35), its floor −11. Built to be judged on its own (standalone: with a stub of the Pasaje at its mouth
## and a glimpse of the chapel through its doorway), then set whole into maps/metro, where the map's own spaces meet it.

const LIBRARY := preload("res://maps/library_lab.tscn")
const WatchingEyes := preload("res://scripts/Visual/WatchingEyes.gd")
const WispsScript := preload("res://scripts/Visual/Wisps.gd")
const Silhouette := preload("res://scripts/Visual/Silhouette.gd")
const ShadeCrowd := preload("res://scripts/Visual/ShadeCrowd.gd")
const DriftingPagesScript := preload("res://scripts/Visual/DriftingPages.gd")
## Where the lane's middle is in the plan; how far the corridor runs each way from it (m: 28 tile modules, 7 vault spans).
const PLAN_ORIGIN := Vector3(12.8, -11.0, 74.35)
const LANE_HALF := 16.8
## The shop's front along the far wall (x from, to; plan x 15 to 23); where the shop's room stands (its front 2 cm proud
## of the wall's tiles, so their faces never share a plane), turned to face the lane.
const SHOP_FRONT := Vector2(2.2, 10.2)
const SHOP_AT := Vector3(6.2, 0.0, FAR_WALL + 0.38)
## The chapel's doorway in the east end: its width, its height, its middle across the lane (plan y 74.55: its frame's
## outer edges on the end tiles' joints, so no panel beside it is lost to the opening).
const DOOR := Vector2(3.0, 2.8)
const DOOR_Z := 0.2
## The stubs beyond the ends (standalone only): how far the Pasaje's floor runs past the mouth, how wide it is across,
## how far the chapel's floor runs in through the doorway.
const PASAJE_STUB := Vector2(10.0, 18.0)
const CHAPEL_STUB := 3.0
## The lane's own pieces (tools/eclipse/candle_lane.py): the chapel's doorway frame, the votive ledges, the milagros
## board and the mouth's portal (built where they stand in the lane), the Pasaje's puesto, the station's sign, the
## way's arrows; the ledges' wicks.
const LANE_KIT := "res://assets/eclipse/kit/candle_lane.glb"
## The landmarks (tools/eclipse/lane_landmarks.py; docs/superpowers/plans/2026-10-25-lane-landmarks.md): what makes her
## stall and his shop read from the Pasaje. Her garland ties on at her riser and hangs from the south wall's hook (its
## span, the axis it sways about: at most GARLAND_SWAY on the draught).
const LANDMARKS_KIT := "res://assets/eclipse/kit/lane_landmarks.glb"
const GARLAND_TIE := Vector3(1.57, 3.32, -0.04)
const GARLAND_HOOK := Vector3(1.95, 3.42, 4.45)
const GARLAND_SWAY := deg_to_rad(3.0)
## Her tin heart's hook, at the end of its bracket off her stall's west front post; how far it turns on it either way;
## the wick of her votive under it, in its tin cup on the same post (lane_landmarks.py's CANDLE_WICK), which lights it.
const MILAGRO_HOOK := Vector3(-1.35, 3.0, 0.45)
const MILAGRO_TURN := deg_to_rad(25.0)
const MILAGRO_WICK := Vector3(-1.55, 2.515, 0.12)
## His red lantern over the arch (lane_landmarks.py's red_lantern): its glass's middle, his shade's red, its light
## [energy, reach (m)]. The lane's only red light (hue 350-10°).
const LANTERN_AT := Vector3(6.2, 3.085, 3.9)
const LANTERN_RED := Color("e63833")
const LANTERN_LIGHT := Vector2(1.2, 6.0)
## His threshold's lectern (lane_landmarks.py's LECTERN_REST, LECTERN_TILT): its rest's top middle and its tip toward the
## walk; on it the chained book's hinge along its spine, its chain's fixed ring and the staple on its cover (each on
## the rest: across, back up its slope, up off its top).
const LECTERN_REST := Vector3(3.9, 1.095, 3.98)
const LECTERN_TILT := deg_to_rad(20.0)
const BOOK_HINGE := [Vector3(-0.15, -0.11, 0.066), Vector3(-0.15, 0.11, 0.066)]
const BOOK_CHAIN_ANCHOR := Vector3(0.25, -0.05, -0.05)
const BOOK_STAPLE := Vector3(0.155, -0.06, 0.066)
## Where loose pages lift out of his arch (its foot), and where her copal pools under the vault over her pitch.
const PAGES_FROM := Vector3(6.2, 0.1, 4.2)
const COPAL_POOL := Vector3(0.0, 3.45, -0.8)
const LANE_WICKS := "res://assets/eclipse/source/candle_lane_wicks.json"
## How far the end wall's opening reaches inside the doorway's frame (m, each side and over it): the wall's cut faces
## buried in the stone, the way through still the frame's 3 m.
const DOOR_INSET := 0.05
## How far along a ledge the wicks sharing one flame system (and its one light) run (m).
const CANDLE_RUN := 1.5
## The station's sign under the vault: how far in from the mouth.
const SIGN_IN := 0.9
## The way's arrows on the walls, at ARROW_Y: [piece, x along the lane, its wall (-1 the back, 1 the far), where it
## points]. (On the far wall a plate is turned round, so arrow_east points west.)
const ARROWS := [["arrow_east", -14.2, -1, "east"], ["arrow_west", 14.6, -1, "west"], ["arrow_east", -1.2, 1, "west"]]
const ARROW_Y := 2.05
## The Pasaje stub's puestos, either side of the mouth (their fronts' middles out from the mouth, facing into the
## Pasaje); how far up and down it from the mouth's middle its lit backdrops close it (clear of the puestos' ends);
## their light.
const PUESTOS := [Vector3(-1.4, 0.0, -4.0), Vector3(-1.4, 0.0, 6.2)]
const BACKDROP := 7.0
const PASAJE_GLOW := Color(1.0, 0.55, 0.42)
## The chapel's glimpse: its warm light 2 m in past the doorway's wall, its backdrop at the stub's end, its width.
const CHAPEL_GLOW := Color(1.0, 0.66, 0.36)
const CHAPEL_IN := 2.0
const CHAPEL_WIDTH := 6.0
## The lane crowded (after the first look): candles massed on the floor where the ledges ran out of room, and under
## her niche and the milagros board; marigolds; papel picado before the chapel; the pipes' works off their mains; the
## air line's hoods at the walls' feet (the ánimas come and go by them); the old culvert the nahual looks out of.
## [piece, where, turned]: masses and buckets with their backs to their wall, the works and culvert on its face.
const DRESSING := [
	["candle_mass_a", Vector3(12.8, 0.0, BACK_WALL + 0.53), 0.0],
	["candle_mass_b", Vector3(12.0, 0.0, FAR_WALL - 0.36), PI],
	["candle_mass_b", Vector3(16.42, 0.0, 3.1), -PI / 2.0],
	["candle_mass_b", Vector3(-10.0, 0.0, BACK_WALL + 0.36), 0.0],
	["flower_bucket", Vector3(13.65, 0.0, BACK_WALL + 0.2), 0.0],
	["flower_bucket", Vector3(16.3, 0.0, 2.5), 0.0],
	["flower_bucket", Vector3(-10.6, 0.0, BACK_WALL + 0.2), 0.0],
	["picado_strings", Vector3.ZERO, 0.0],
	["gas_meter", Vector3(-6.6, 0.0, BACK_WALL), 0.0],
	["main_gauge", Vector3(9.1, 0.0, BACK_WALL), 0.0],
	["air_branch", Vector3(-13.8, 0.0, FAR_WALL), PI],
	["air_branch", Vector3(0.9, 0.0, FAR_WALL), PI],
	["culvert", Vector3(-5.0, 0.0, FAR_WALL), PI],
]
## The ánimas' other ways up, by the vents: [the vent's foot on its wall, which way out of the wall (+1 the back
## wall's, -1 the far's), how far its face stands out, its slots' heights, how many come by it, their sizes, their
## tempers (Animas.gd), how far they go]. The hood by the mouth: little ones, mostly shy; the hood mid-lane: hungry
## for the candles; the old grille: big lurkers that keep to it.
const VENT_SOULS := [
	[Vector3(-13.8, 0.0, FAR_WALL), -1.0, 0.16, [0.2, 0.3], 6, Vector2(0.45, 0.75), {"shy": 3.0, "beggar": 1.0}, 4.0],
	[Vector3(0.9, 0.0, FAR_WALL), -1.0, 0.16, [0.2, 0.3], 4, Vector2(0.8, 1.15), {"hungry": 2.0, "beggar": 1.0}, 6.0],
	[Vector3(VENT_X, 0.0, BACK_WALL), 1.0, 0.05, [0.25, 0.36], 3, Vector2(1.2, 1.5), {"lurker": 1.0}, 2.0],
]
## The nahual's haunts in the lane (x, y, z, its turn: lying out from its wall, its head toward the lane's middle):
## by the bench (where the bay has it), beside the culvert it comes and goes by, on the north wall's foot between her
## niche and the gas meter, by the hood at the mouth.
const HAUNTS := [Vector4(-6.6, 0.0, 4.35, PI / 2.0), Vector4(-4.1, 0.0, 4.3, PI / 2.0), Vector4(-7.7, 0.0, BACK_WALL + 0.25, -PI / 2.0),
	Vector4(-15.3, 0.0, 4.3, PI / 2.0)]
## Where its eyes look out of the culvert while it is away: in the dark a hand behind the bars (tools/eclipse/
## candle_lane.py CULVERT, CULVERT_DARK).
const CULVERT_EYES := Vector3(-5.0, 0.34, FAR_WALL - 0.29)
## The lane's standing people (scripts/Visual/Silhouette.gd), each side-on to the way, facing along the lane: [pose
## or loop, where (bay frame, at the foot), its face toward the lane's middle (+1 from the north side, -1 from the
## south), mirrored (to face the other way), a loop (moving) or a still]. At the end of her counter, a woman
## bargaining with her hands and a man shifting his weight, waiting his turn; before the chapel, a woman and a man
## kneeling toward its doorway, still. (The crowd at the mouth walks: ROUTES.)
const PEOPLE := [
	["talk_bargaining", Vector3(0.65, 0.0, 0.1), 1.0, false, true],
	["idle_waiting", Vector3(1.85, 0.0, 0.15), 1.0, false, true],
	["kneeling_a", Vector3(14.3, 0.0, -0.75), 1.0, true, false],
	["kneeling_b", Vector3(13.5, 0.0, 2.95), -1.0, false, false],
]
## The crowd's routes (scripts/Visual/ShadeCrowd.gd; bay frame, on the floor): [name, points, every (s, least and most
## between one setting out and the next), keep (how much of it one walks before it may come apart), along (the
## chance one forms partway along)]. Thick across the Pasaje beyond the mouth, both ways; now and then into the lane
## and on through the chapel's doorway; now and then back out, some formed along the way.
const ROUTES := [
	["pasaje_south", [Vector3(-18.4, 0.0, 9.5), Vector3(-18.4, 0.0, -7.5)], Vector2(2.0, 4.0), Vector2(0.5, 1.0), 0.3],
	["pasaje_north", [Vector3(-19.7, 0.0, -7.5), Vector3(-19.7, 0.0, 9.5)], Vector2(2.0, 4.0), Vector2(0.5, 1.0), 0.3],
	["into_lane", [Vector3(-18.0, 0.0, 2.6), Vector3(-15.5, 0.0, 1.7), Vector3(-6.0, 0.0, 1.6), Vector3(4.0, 0.0, 1.4),
		Vector3(12.0, 0.0, 1.0), Vector3(16.4, 0.0, 0.2), Vector3(19.4, 0.0, 0.2)], Vector2(5.0, 11.0), Vector2(0.2, 1.0), 0.0],
	["out_of_lane", [Vector3(19.4, 0.0, 0.4), Vector3(16.4, 0.0, 0.4), Vector3(12.0, 0.0, 1.2), Vector3(4.0, 0.0, 1.0),
		Vector3(-6.0, 0.0, 1.0), Vector3(-15.5, 0.0, 0.8), Vector3(-18.0, 0.0, -0.6)], Vector2(6.0, 12.0), Vector2(0.3, 1.0), 0.5],
]
## The walk's pockets of loud and quiet (the spec's walk, chapel to mouth): [name, loud, plan x from, to, and where
## each of its sounds will be (bay frame), named for what will sound there]. Sound is marked, silent, until the
## user's recordings come.
const POCKETS := [
	["chapel", false, 23.0, 29.6, {"murmured_prayer": Vector3(14.0, 1.1, 1.1), "votives_crackle": Vector3(12.5, 1.1, -2.0)}],
	["arch", false, 15.0, 23.0, {"shop_hush": Vector3(6.2, 1.5, 4.2)}],
	["stall", true, 8.3, 15.0, {"bargaining": Vector3(0.9, 1.5, 0.2), "cart_call": Vector3(-3.0, 1.4, 2.6),
		"her_radio": Vector3(-0.5, 1.7, -1.6)}],
	["niche", false, 0.8, 8.3, {"niche_stillness": Vector3(-10.0, 1.4, -2.0)}],
	["mouth", true, -4.0, 0.8, {"pasaje_crowd": Vector3(-16.0, 1.6, 1.1), "vendors_calling": Vector3(-17.5, 1.6, -3.5),
		"train_floor": Vector3(-14.5, 0.1, 1.1)}],
]
## The pockets' light: the bay's sodium work lamps dimmed and drawn in to her stall (energy, reach; their bounce's
## energy), her neon's glow (colour, energy, reach), the Pasaje's neon spilling into the mouth (where, colour, energy,
## reach), the shop's book-light spilling out of his arch (where, colour, energy, reach).
const WORK_DIM := Vector3(1.1, 6.0, 0.4)
# (Her neon a magenta of ~328°, a touch cooler than it was: his lantern's red, ~2°, is her neighbour's, and the two
# read apart; cooler still and it turned her garland pink.)
const STALL_NEON := [Color(1.0, 0.28, 0.66), 1.6, 4.5]
const MOUTH_NEON := [Vector3(-17.3, 2.4, 1.1), Color(0.25, 0.85, 0.9), 2.3, 5.5]
const ARCH_SPILL := [Vector3(6.2, 1.9, FAR_WALL - 0.3), Color(1.0, 0.68, 0.38), 0.7, 4.5]
## The Virgin's niche's candles here, as a share of the bay's: quieter than her stall from the mouth.
const NICHE_DIM := 0.35
## How brightly the backdrops glow (the Pasaje's, the chapel's): dim as the lane's own light, never a lit screen.
const BACKDROP_GLOW := Vector2(0.035, 0.03)
## How much of the stubs' lights the fog takes up.
const STUB_HAZE := 0.15
## Set into the Metro, how far its walls' and vault's ends stand in behind the map's walls (m): the map's are faces on
## the plan's lines, the Pasaje's at the mouth, the chapel's behind the east end wall.
const SEAM := 0.01
## The shades one talks to (the talk and quests spec, section 6; data/dialogue/*.dialogue). The librarian at his high
## desk, in the shop's own frame: behind the desk's corner by the chained book, on his chalk ward's rim (inside it,
## behind the desk, is his stool between two of its candles), clear of the stool, the candles and the cage; turned
## toward the arch's middle. (His shadow, LibraryShadow, keeps to the wall cases' fronts, 2 m and more from him.)
const ShadeScript := preload("res://scripts/Interaction/Shade.gd")
const LIBRARIAN_AT := Vector3(-1.1, 0.0, -5.07)
const LIBRARIAN_LOOKS := Vector3(0.0, 0.0, 0.4)
## The curandera in her own stall (the bay's hero stall on the north wall, tools/eclipse/stall.py), behind its
## counter as a stallkeeper stands: in her aisle between the counter's back and the shelves, under the bulb, the
## censer on the counter before her; clear of the counter, the shelves, her stool by the far end of it and her
## grandchild's top on the floor (her capsule 0.35 m round, 0.2 m off the counter and as much off the shelves' price
## cards); turned out across the lane. A nameless curandera of the type alone (her name the user's to write) before
## the far wall's votive ledges east of the shop, between runs of their flames, clear of the walk down the lane's
## middle, turned toward a point on it, toward the mouth.
const CURANDERA_AT := Vector3(0.0, 0.0, -1.15)
const CURANDERA_LOOKS := Vector3(0.0, 0.0, 2.5)
const MARKET_CURANDERA_AT := Vector3(14.7, 0.0, 3.65)
const MARKET_CURANDERA_LOOKS := Vector3(10.0, 0.0, 0.5)
const MARKET_CURANDERA := "<<a market curandera>>"

## Judged on its own (the stubs at its ends), or set into maps/metro (no stubs: the map's spaces meet it).
@export var standalone := true

var shop: Node3D
var chapel_door: Node3D
var stub: Node3D
var door_frame: MeshInstance3D
var ledges: Array[MeshInstance3D] = []
var masses: Array[MeshInstance3D] = []
var milagros: MeshInstance3D
var mouth_sign: MeshInstance3D
var mouth_portal: MeshInstance3D
var arrows: Array[MeshInstance3D] = []
## The flames (Vfx "candles": a run of a ledge's wicks or a floor mass's each, each its light), and every wick on the
## ledges.
var candles: Array[Node3D] = []
var candle_wicks: Array[Vector3] = []
## The ánimas that come up by the vents (VENT_SOULS), each source its own.
var vent_souls: Array[Node3D] = []
## The nahual's eyes in the culvert (scripts/Visual/WatchingEyes.gd).
var culvert_eyes: Node3D
## The ánimas' warmth slipping out of their ways up into the candles' flames (scripts/Visual/Wisps.gd).
var wisps: Node3D
## Its people, shades standing (PEOPLE), and its crowd coming and going (ROUTES).
var people: Array[MeshInstance3D] = []
var crowd_of_shades: Node3D
## The walk's pockets (POCKETS): {name, loud, x (plan x range), emitters (silent, named for their sound), lights}.
var pockets: Array[Dictionary] = []
## The landmarks placed, by piece (garland, milagro_heart, milagro_bracket, ...).
var landmarks := {}
## What her tin heart turns on: the bracket's hook. Her votive's flame under it (Vfx "candles").
var milagro_pivot: Node3D
var milagro_flame: Node3D
## His lantern's light (LANTERN_RED), sagging with the lane's lights when a train draws on the line.
var lantern_light: OmniLight3D
## The book chained to the lectern at his threshold (its own, not his desk's).
var threshold_book: ChainedBook
## Loose pages lifted out of his arch on the draught; her copal pooled under the vault (Vfx "copal_pool").
var pages: Node3D
var copal_haze: Node3D
## His lantern's red glass; the glows that dim with the lights as they sag (her copal's, the glass's), at their full.
var red_glass: StandardMaterial3D
var _glows := {}
## The shades one talks to: "librarian", "curandera", "market_curandera".
var shades := {}


func _ready() -> void:
	half_run = LANE_HALF
	# (Set into the Metro: the map's player and light, none of the bay's own.)
	embedded = not standalone
	# The walk's order (plan x: the stall at 12.8 where the bay has it, the curandera behind its counter; her cart
	# beside it toward the market; the niche near the mouth on the north wall, across from the bench, the nahual lying
	# by the bench; the fire main's hydrant on the far wall clear of them all).
	places["cart"] = Vector3(-3.0, 0.0, 2.6)
	places["niche"] = Vector3(-10.0, 0.0, BACK_WALL)
	places["niche_yaw"] = 0.0
	places["bench"] = Vector3(-8.9, 0.0, FAR_WALL)
	places["nahual"] = Vector3(-6.6, 0.0, 4.35)
	super._ready()
	_shop_front()
	_east_end()
	_west_end()
	_lane_pieces()
	_landmarks()
	_vent_souls()
	_nahual_ways()
	_people()
	_hush()
	_pockets()
	_stubs()
	if embedded:
		_fit_into_plan()
	shop = LIBRARY.instantiate()
	shop.name = "Library"
	shop.standalone = false
	shop.player = player
	shop.transform = Transform3D(Basis(Vector3.UP, PI), SHOP_AT)
	add_child(shop)
	inspection_sections.append(shop)
	_shades()


## The shades one talks to (Shade.gd), where LIBRARIAN_AT and the curanderas' places say. Each is an inspection
## section of its own: the form light (F2) leaves its smoke as it is.
func _shades() -> void:
	shades["librarian"] = _shade("librarian", "", "", shop.transform * LIBRARIAN_AT, shop.transform * LIBRARIAN_LOOKS)
	shades["curandera"] = _shade("curandera", "", "", CURANDERA_AT, CURANDERA_LOOKS)
	shades["market_curandera"] = _shade("", "curandera", MARKET_CURANDERA, MARKET_CURANDERA_AT, MARKET_CURANDERA_LOOKS)


## A shade of `character` (or of the type `type_id` alone, called `display_name`), standing at `at` turned toward
## `looks` (both in the lane's frame).
func _shade(character: String, type_id: String, display_name: String, at: Vector3, looks: Vector3) -> Node3D:
	var shade: StaticBody3D = ShadeScript.new()
	shade.character = character
	shade.type_id = type_id
	shade.display_name = display_name
	shade.name = "shade_%s" % (character if character != "" else type_id + "_type")
	add_child(shade)
	shade.position = at
	var to := looks - at
	shade.rotation.y = atan2(-to.x, -to.z)
	inspection_sections.append(shade)
	return shade


## The inspection keys reach the shop through the lane (its white form light kept off: the lane's lights the set).
func set_work_lights(on: bool) -> void:
	super.set_work_lights(on)
	if is_instance_valid(shop):
		shop.set_work_lights(on)


func set_form(on: bool) -> void:
	super.set_form(on)
	if is_instance_valid(shop):
		shop.set_form(on)
		shop.form_light.visible = false


func set_decals(on: bool) -> void:
	super.set_decals(on)
	if is_instance_valid(shop):
		shop.set_decals(on)


## The vents' ánimas fear what the drain's fear and gather where they gather (the dark train, the procession).
func _process(delta: float) -> void:
	super._process(delta)
	_sway(landmarks.get("garland"), GARLAND_TIE, GARLAND_HOOK, GARLAND_SWAY)
	# (Her copal's and his glass's glows follow the lights' sag, as her bulb's.)
	if bulb != null and _full.get(bulb, 0.0) > 0.0:
		var sag: float = bulb.light_energy / _full[bulb]
		for glow in _glows:
			if glow is FogMaterial:
				glow.emission = _glows[glow] * sag
			else:
				glow.emission_energy_multiplier = _glows[glow] * sag
	# (Her heart turns slowly on its hook, two slow swings over each other.)
	if milagro_pivot != null:
		milagro_pivot.rotation.y = MILAGRO_TURN * (0.6 * sin(_clock * 0.31) + 0.4 * sin(_clock * 0.73 + 2.0))
	for souls in vent_souls:
		souls.hush = animas.hush if animas != null else 0.0
		souls.gather = animas.gather if animas != null else null


## The ánimas up by the vents (VENT_SOULS): each source at its vent's face, out of its wall, making for the lane's
## candles (the drain's, the ledges', the masses').
func _vent_souls() -> void:
	var hands: Array[Mesh] = []
	if ResourceLoader.exists(UNCANNY_KIT):
		var kit := _kit(UNCANNY_KIT)
		hands = [kit["anima_hand_reach"], kit["anima_hand_claw"]] as Array[Mesh]
	var lit := PackedVector3Array(animas.candles) if animas != null else PackedVector3Array()
	for flames in candles:
		lit.append(flames.global_position)
	for k in VENT_SOULS.size():
		var vent: Array = VENT_SOULS[k]
		var souls: Node3D = AnimasScript.new()
		souls.name = "vent_animas_%d" % k
		souls.hand_meshes = hands
		souls.colour = Color("b8f04a")
		souls.seed = 41 + 17 * k
		souls.flee_from = player
		souls.mouth = "wall"
		souls.lanes = PackedFloat32Array(vent[3])
		souls.count = vent[4]
		souls.want_out = maxi(1, int(vent[4]) - 1)
		souls.sizes = vent[5]
		souls.tempers = vent[6]
		souls.tether = vent[7]
		souls.candles = lit
		add_child(souls)
		souls.position = vent[0] + Vector3(0.0, 0.0, float(vent[1]) * float(vent[2]))
		souls.rotation.y = 0.0 if vent[1] > 0.0 else PI
		vent_souls.append(souls)

	# Their warmth, now and then, out of where they come up and into the flames.
	wisps = WispsScript.new()
	wisps.name = "wisps"
	var ways_up := PackedVector3Array()
	if animas != null:
		ways_up.append(animas.global_position + Vector3(0.0, 0.05, 0.0))
	for souls in vent_souls:
		ways_up.append(souls.to_global(Vector3(0.0, 0.25, 0.05)))
	wisps.sources = ways_up
	var flames := PackedVector3Array()
	for flame in candles:
		flames.append(flame.global_position)
	wisps.targets = flames
	add_child(wisps)


## The nahual given the lane's haunts, and its eyes in the culvert for while it is away between them.
func _nahual_ways() -> void:
	if nahual == null:
		return
	var haunts: Array[Vector4] = []
	haunts.assign(HAUNTS)
	nahual.haunts = haunts
	culvert_eyes = WatchingEyes.new()
	culvert_eyes.name = "culvert_eyes"
	culvert_eyes.nahual = nahual
	culvert_eyes.watched = player
	add_child(culvert_eyes)
	culvert_eyes.position = CULVERT_EYES


## The people stood in their places (PEOPLE), their faces to the lane's middle.
func _people() -> void:
	for spec: Array in PEOPLE:
		var person: MeshInstance3D = Silhouette.make_loop(spec[0], spec[3]) if spec[4] else Silhouette.make(spec[0], spec[3])
		if person == null:
			missing.append(Silhouette.LOOPS_SHEET if spec[4] else Silhouette.SHEET)
			return
		add_child(person)
		person.position = spec[1]
		person.rotation.y = 0.0 if spec[2] > 0.0 else PI
		people.append(person)
	# The crowd coming and going, and its surge when the dark train has passed.
	crowd_of_shades = ShadeCrowd.new()
	crowd_of_shades.name = "shade_crowd"
	for route: Array in ROUTES:
		crowd_of_shades.routes.append({"name": route[0], "points": PackedVector3Array(route[1]), "every": route[2],
			"keep": route[3], "along": route[4]})
	crowd_of_shades.walked_into_by = player
	add_child(crowd_of_shades)
	if dark_train != null:
		dark_train.peaked.connect(crowd_of_shades.surge)


## The bay's sounds silenced here (all judged bad, Oct 17; the lane's are marked and wait for the user's recordings):
## its players emptied, its sound-only crowd stilled, nothing arming one again. (Before the shop comes in: its sounds
## are its own. The ánimas' voices are kept: the user's pick, Oct 24.)
func _hush() -> void:
	hushed = true
	if crowd != null:
		crowd.process_mode = Node.PROCESS_MODE_DISABLED
	var voices := []
	for souls: Node3D in find_children("*", "Node3D", true, false).filter(func(n): return n.get_script() == AnimasScript):
		voices.append_array(souls.voices)
	for sound: Node in find_children("*", "AudioStreamPlayer", true, false) + find_children("*", "AudioStreamPlayer3D", true, false):
		if sound in voices:
			continue
		sound.call("stop")
		sound.set("autoplay", false)
		sound.set("stream", null)


## The walk's pockets (POCKETS): each with its emitters, silent, where its sounds will be.
func _pockets() -> void:
	for spec: Array in POCKETS:
		var emitters: Array[AudioStreamPlayer3D] = []
		for sound: String in spec[4]:
			var emitter := AudioStreamPlayer3D.new()
			emitter.name = "sound_%s" % sound
			emitter.set_meta("pocket", spec[0])
			add_child(emitter)
			emitter.position = spec[4][sound]
			emitters.append(emitter)
		pockets.append({"name": spec[0], "loud": spec[1], "x": Vector2(spec[2], spec[3]), "emitters": emitters,
			"lights": []})
	_pocket_lights()


## The pockets made with light: the bay's even sodium drawn in to her stall, her neon glowing, the Pasaje's neon
## at the mouth, his book-light at the arch; the chapel and the niche left to their candles.
func _pocket_lights() -> void:
	var by_name := {}
	for p in pockets:
		by_name[p["name"]] = p
	for lamp in work_lights:
		lamp.light_energy = WORK_DIM.x
		lamp.omni_range = WORK_DIM.y
		by_name["stall"]["lights"].append(lamp)
	for up in bounce_lights:
		up.light_energy = WORK_DIM.z
	# (The train's brownout dims each from its full: their full is this now.)
	for light in work_lights + bounce_lights:
		if _full.has(light):
			_full[light] = light.light_energy
	# (Her neon sets its own light each frame from its flicker: its strength and reach set on the sign.)
	if neon != null and neon.light != null:
		neon.light.light_color = STALL_NEON[0]
		neon.light_energy = STALL_NEON[1]
		neon.light_range = STALL_NEON[2]
		neon.light.omni_range = STALL_NEON[2]
		by_name["stall"]["lights"].append(neon.light)
	for spill in [["pasaje_neon", MOUTH_NEON, "mouth"], ["arch_spill", ARCH_SPILL, "arch"]]:
		var light := OmniLight3D.new()
		light.name = spill[0]
		light.light_color = spill[1][1]
		light.light_energy = spill[1][2]
		light.omni_range = spill[1][3]
		light.shadow_enabled = false
		# (Not on the blank station sign a metre over it: its teal washed the sign into the mouth's brightest thing.)
		light.light_cull_mask &= ~Layers.SPILL_SHY
		add_child(light)
		light.position = spill[1][0]
		by_name[spill[2]]["lights"].append(light)
	if mouth_sign != null:
		mouth_sign.layers = Layers.SPILL_SHY
	# The Virgin's niche quieter than her stall: its candles burn lower here (the train's guttering scales from this).
	if niche_flames != null and "energy" in niche_flames:
		niche_flames.energy = Vfx.CANDLES_ENERGY * NICHE_DIM
		niche_flames.set_meta("full", niche_flames.energy)
	for flames in candles:
		var x := plan_point(flames.position).x
		for p in pockets:
			if x >= p["x"].x and x < p["x"].y:
				p["lights"].append(flames)
	if niche_flames != null:
		by_name["niche"]["lights"].append(niche_flames)


## A point in the lane's frame, in the plan's (x, floor height, y).
func plan_point(bay: Vector3) -> Vector3:
	return bay + PLAN_ORIGIN


## The far wall opened for the shop's front: its tile panels wholly behind the front gone (the two at its ends stay,
## half behind it), its backing wall cut across the front (the shopfront is solid itself).
func _shop_front() -> void:
	for panel: MeshInstance3D in wall_panels.duplicate():
		var box := panel.transform * panel.get_aabb()
		if box.position.z > FAR_WALL - 0.05 and box.position.x >= SHOP_FRONT.x - 0.01 and box.end.x <= SHOP_FRONT.y + 0.01:
			wall_panels.erase(panel)
			panel.free()
	_cut("far_wall", Vector3(-half_run, 0.0, FAR_WALL + WALL_FACE), Vector3(half_run, HEIGHT, FAR_WALL + WALL_FACE + WALL),
		SHOP_FRONT.x, SHOP_FRONT.y)
	# (And what the bay hung on that stretch of wall: its name tablet, its bills, its splashes.)
	for n: Node in get_children():
		var at := (n as Node3D).position if n is Node3D else Vector3.INF
		if (n is Decal or String(n.name).begins_with("name_tablet")) and at.z > FAR_WALL - 0.3 \
				and at.x > SHOP_FRONT.x - 0.3 and at.x < SHOP_FRONT.y + 0.3:
			if n is MeshInstance3D:
				wall_panels.erase(n)
			if n is Decal:
				decals.erase(n)
			n.free()


## Set into the Metro: the walls, tiles and vault that run to the mouth, and the east end wall and vault where the
## chapel begins behind them, ended SEAM short, so no face of theirs meets a face of the map's walls.
func _fit_into_plan() -> void:
	var west := -half_run
	var east := half_run + WALL_FACE + WALL
	for mesh: MeshInstance3D in get_children().filter(func(n): return n is MeshInstance3D):
		if not (mesh.mesh is BoxMesh or mesh in wall_panels):
			continue
		var box := mesh.transform * mesh.get_aabb()
		var lo := box.position.x
		var hi := box.end.x
		var to_lo := west + SEAM if lo < west + 0.001 else lo
		var to_hi := east - SEAM if hi > east - 0.001 else hi
		if to_lo == lo and to_hi == hi:
			continue
		if mesh.mesh is BoxMesh:
			(mesh.mesh as BoxMesh).size.x = to_hi - to_lo
			mesh.position.x = (to_lo + to_hi) / 2.0
			for shape: CollisionShape3D in mesh.find_children("*", "CollisionShape3D", true, false):
				(shape.shape as BoxShape3D).size.x = to_hi - to_lo
		else:
			# (A tile panel drawn in a hair, from its other end.)
			var keep := hi if to_lo != lo else lo
			var by := (to_hi - to_lo) / (hi - lo)
			mesh.transform = Transform3D(Basis.from_scale(Vector3(by, 1.0, 1.0)), Vector3(keep * (1.0 - by), 0.0, 0.0)) \
				* mesh.transform


## The landmarks (LANDMARKS_KIT), each where its kit built it (none solid: over every head): her garland across the
## walk; her tin heart's bracket, and the heart hung on its hook (built about its ring, it turns there).
func _landmarks() -> void:
	if not ResourceLoader.exists(LANDMARKS_KIT):
		missing.append(LANDMARKS_KIT)
		return
	var meshes := _kit(LANDMARKS_KIT)
	var look := Painterly.material(_painted(["lane_landmarks.png", "lane_landmarks_base.png"]), &"bespoke")
	for kind in ["garland", "garland_fixings", "milagro_bracket", "red_lantern"]:
		landmarks[kind] = _place(meshes[kind], look, kind, Vector3.ZERO, 0.0, false)
	# His lantern's glass, red and lit from within, and its light.
	var lantern: MeshInstance3D = landmarks["red_lantern"]
	for i in lantern.mesh.get_surface_count():
		var slot: Material = lantern.mesh.surface_get_material(i)
		if slot != null and slot.resource_name == "glass_red":
			red_glass = _red_glass()
			lantern.set_surface_override_material(i, red_glass)
	lantern_light = OmniLight3D.new()
	lantern_light.name = "lantern_light"
	lantern_light.light_color = LANTERN_RED
	lantern_light.light_energy = LANTERN_LIGHT.x
	lantern_light.omni_range = LANTERN_LIGHT.y
	# (It stops at the wall: no red cast through it on the shop's floor and shelves.)
	lantern_light.shadow_enabled = true
	add_child(lantern_light)
	lantern_light.position = LANTERN_AT
	_full[lantern_light] = LANTERN_LIGHT.x
	# His threshold: the lectern and the barrow stand (solid), the book on the lectern, its cover straining at its chain.
	for kind in ["lectern", "book_barrow"]:
		landmarks[kind] = _place(meshes[kind], look, kind, Vector3.ZERO, 0.0, true)
	for kind in ["lectern_book_block", "lectern_book_cover", "lectern_book_chain"]:
		landmarks[kind] = _place(meshes[kind], look, kind, Vector3.ZERO, 0.0, false)
	threshold_book = ChainedBook.new()
	threshold_book.name = "threshold_book"
	threshold_book.seed = 77
	threshold_book.cover = landmarks["lectern_book_cover"]
	threshold_book.block = landmarks["lectern_book_block"]
	threshold_book.hinge_a = to_global(_on_rest(BOOK_HINGE[0]))
	threshold_book.hinge_b = to_global(_on_rest(BOOK_HINGE[1]))
	threshold_book.chain = landmarks["lectern_book_chain"]
	threshold_book.chain_anchor = to_global(_on_rest(BOOK_CHAIN_ANCHOR))
	threshold_book.staple = to_global(_on_rest(BOOK_STAPLE))
	add_child(threshold_book)
	# Loose pages lifted out of his arch on the lane's draught; her copal pooled under the vault, lit by her bulb.
	pages = DriftingPagesScript.new()
	pages.name = "pages"
	pages.from = PAGES_FROM
	pages.end_x = half_run
	pages.wind = draught_now
	add_child(pages)
	# (The form light leaves them as they are: an effect, its own look.)
	inspection_sections.append(pages)
	copal_haze = Vfx.system("copal_pool")
	copal_haze.name = "copal_haze"
	add_child(copal_haze)
	Vfx.place(copal_haze, to_global(COPAL_POOL))
	Vfx.emit(copal_haze, true)
	# (Her copal's glow is her bulb's light in it, and his glass's the lamp behind it: they sag as the lights do.)
	for fog: FogVolume in copal_haze.find_children("*", "FogVolume", true, false):
		_glows[fog.material] = (fog.material as FogMaterial).emission
	if red_glass != null:
		_glows[red_glass] = red_glass.emission_energy_multiplier
	milagro_pivot = Node3D.new()
	milagro_pivot.name = "milagro_pivot"
	add_child(milagro_pivot)
	milagro_pivot.position = MILAGRO_HOOK
	var heart := _place(meshes["milagro_heart"], look, "milagro_heart", Vector3.ZERO, 0.0, false)
	heart.reparent(milagro_pivot, false)
	heart.transform = Transform3D.IDENTITY
	landmarks["milagro_heart"] = heart
	# Her votive for those she healed, burning under it: its light is what the tin catches.
	var wick := to_global(MILAGRO_WICK)
	milagro_flame = Vfx.system("candles")
	milagro_flame.name = "milagro_flame"
	add_child(milagro_flame)
	Vfx.place(milagro_flame, wick, {"wicks": [[wick.x, wick.y, wick.z]]})
	Vfx.emit(milagro_flame, true)


## A point on his lectern's rest (across, back up its slope, up off its top), in the lane's frame.
func _on_rest(p: Vector3) -> Vector3:
	return LECTERN_REST + Vector3(p.x, p.y * sin(LECTERN_TILT) + p.z * cos(LECTERN_TILT),
		p.y * cos(LECTERN_TILT) - p.z * sin(LECTERN_TILT))


## His lantern's old darkroom glass: red, half see-through, lit from within.
func _red_glass() -> StandardMaterial3D:
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass.albedo_color = Color(LANTERN_RED, 0.6)
	glass.emission_enabled = true
	glass.emission = LANTERN_RED
	glass.emission_energy_multiplier = 1.6
	glass.roughness = 0.15
	return glass


## A hung piece swaying about the line from `from` to `to` (the lane's frame), at most `most` radians, as far as the
## draught blows (its full sway at the train's).
func _sway(piece: MeshInstance3D, from: Vector3, to: Vector3, most: float) -> void:
	if piece == null:
		return
	var blow := clampf(draught_now().length() / (DRAUGHT.length() * 5.0), 0.0, 1.0)
	var angle := most * (0.35 + 0.65 * blow) * sin(_clock * 0.9) * (0.7 + 0.3 * sin(_clock * 0.37 + 1.3))
	var turn := Basis((to - from).normalized(), angle)
	piece.transform = Transform3D(turn, from - turn * from)


## The east end: its tiles over the doorway gone, its wall rebuilt round the chapel's doorway.
func _east_end() -> void:
	var lo := DOOR_Z - DOOR.x / 2.0
	var hi := DOOR_Z + DOOR.x / 2.0
	for panel: MeshInstance3D in wall_panels.duplicate():
		var box := panel.transform * panel.get_aabb()
		if box.position.x > half_run - 0.05 and box.end.z > lo + 0.01 and box.position.z < hi - 0.01:
			wall_panels.erase(panel)
			panel.free()
	var x := half_run + WALL_FACE
	var end := get_node_or_null("end_%d" % x)
	if end != null:
		end.free()
	var tile := _flat(TILE)
	_box(Vector3(x, 0.0, BACK_WALL - WALL), Vector3(x + WALL, HEIGHT, lo - DOOR_INSET), tile, "east_end_north")
	_box(Vector3(x, 0.0, hi + DOOR_INSET), Vector3(x + WALL, HEIGHT, FAR_WALL + WALL), tile, "east_end_south")
	_box(Vector3(x, DOOR.y + DOOR_INSET, lo - DOOR_INSET), Vector3(x + WALL, HEIGHT, hi + DOOR_INSET), tile, "east_end_lintel")
	chapel_door = Node3D.new()
	chapel_door.name = "chapel_door"
	add_child(chapel_door)
	chapel_door.position = Vector3(x + WALL / 2.0, 0.0, DOOR_Z)


## The west end: open its whole width and height on the Pasaje.
func _west_end() -> void:
	for panel: MeshInstance3D in wall_panels.duplicate():
		if (panel.transform * panel.get_aabb()).end.x < -half_run + 0.05:
			wall_panels.erase(panel)
			panel.free()
	var end := get_node_or_null("end_%d" % (-half_run - WALL_FACE - WALL))
	if end != null:
		end.free()


## The lane's own pieces: the chapel's doorway framed, the votive ledges and their flames, the milagros board by the
## doorway, the portal round the mouth (the services run into it), the station's sign over the mouth, the way's arrows.
## (Not solid: the walls and floor are.)
func _lane_pieces() -> void:
	if not ResourceLoader.exists(LANE_KIT):
		missing.append(LANE_KIT)
		return
	var meshes := _kit(LANE_KIT)
	var look := Painterly.material(_painted(["candle_lane.png", "candle_lane_base.png"]), &"bespoke")
	door_frame = _place(meshes["chapel_door"], look, "chapel_door", Vector3.ZERO, 0.0, false)
	door_frame.name = "door_frame"
	for kind in ["votive_north", "votive_south"]:
		ledges.append(_place(meshes[kind], look, kind, Vector3.ZERO, 0.0, false))
	milagros = _place(meshes["milagros_board"], look, "milagros_board", Vector3.ZERO, 0.0, false)
	mouth_portal = _place(meshes["mouth_portal"], look, "mouth_portal", Vector3.ZERO, 0.0, false)
	mouth_sign = _place(meshes["enamel_sign"], look, "enamel_sign", Vector3(-half_run + SIGN_IN, HEIGHT, (BACK_WALL + FAR_WALL) / 2.0),
		PI / 2.0, false)
	for arrow: Array in ARROWS:
		var wall: float = BACK_WALL if arrow[2] < 0 else FAR_WALL
		var plate := _place(meshes[arrow[0]], look, arrow[0], Vector3(arrow[1], ARROW_Y, wall), 0.0 if arrow[2] < 0 else PI, false)
		plate.name = "arrow_%d" % arrows.size()
		plate.set_meta("points", arrow[3])
		arrows.append(plate)
	for dressed: Array in DRESSING:
		var piece := _place(meshes[dressed[0]], look, dressed[0], dressed[1], dressed[2], false)
		if String(dressed[0]).begins_with("candle_mass"):
			masses.append(piece)
	_candles()


## The candles lit: the ledges' wicks in runs of CANDLE_RUN along each ledge, each floor mass's all together; a flame
## system (and its light) to a run or a mass.
func _candles() -> void:
	if not FileAccess.file_exists(LANE_WICKS):
		missing.append(LANE_WICKS)
		return
	var all_wicks: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LANE_WICKS))
	var runs := {}
	for ledge in ledges:
		for w in all_wicks.get(String(ledge.get_meta("kind")), []):
			var at: Vector3 = ledge.global_transform * Vector3(w[0], w[1], w[2])
			candle_wicks.append(at)
			var key := "%s%d" % ["far" if w[2] > 1.0 else "back", floori(w[0] / CANDLE_RUN)]
			runs.get_or_add(key, []).append(at)
	for mass in masses:
		for w in all_wicks.get(String(mass.get_meta("kind")), []):
			runs.get_or_add(String(mass.name), []).append(mass.global_transform * Vector3(w[0], w[1], w[2]))
	for key: String in runs:
		var middle := Vector3.ZERO
		var wicks := []
		for at: Vector3 in runs[key]:
			middle += at / runs[key].size()
			wicks.append([at.x, at.y, at.z])
		var flames := Vfx.system("candles")
		flames.name = "votives_%s" % key
		add_child(flames)
		Vfx.place(flames, middle, {"wicks": wicks})
		Vfx.emit(flames, true)
		candles.append(flames)


## Standalone, a stub of the Pasaje past the mouth (its floor, its east wall either side of the mouth with a puesto
## against each, lit backdrops closing it up and down, a far wall) and a glimpse of the chapel through its doorway (its
## floor, walls and ceiling, a warm light 2 m in, a backdrop where it ends), so the lane can be walked and judged
## alone. Set into the map, none of it is built.
func _stubs() -> void:
	stub = Node3D.new()
	stub.name = "stub"
	add_child(stub)
	if not standalone:
		stub.visible = false
		return
	var floor_look := _flat(FLOOR)
	var tile := _flat(TILE)
	var middle := (BACK_WALL + FAR_WALL) / 2.0
	var mouth := -half_run
	var chapel := half_run + WALL_FACE + WALL
	var side_z := Vector2(DOOR_Z - CHAPEL_WIDTH / 2.0, DOOR_Z + CHAPEL_WIDTH / 2.0)
	var boxes := [
		["stub_floor_0", Vector3(mouth - PASAJE_STUB.x, -0.2, middle - PASAJE_STUB.y / 2.0), Vector3(mouth, 0.0, middle + PASAJE_STUB.y / 2.0), floor_look],
		["stub_floor_1", Vector3(half_run, -0.2, side_z.x), Vector3(chapel + CHAPEL_STUB, 0.0, side_z.y), floor_look],
		["stub_wall_north", Vector3(mouth - WALL, 0.0, middle - PASAJE_STUB.y / 2.0), Vector3(mouth, HEIGHT, BACK_WALL - WALL_FACE - WALL), tile],
		["stub_wall_south", Vector3(mouth - WALL, 0.0, FAR_WALL + WALL_FACE + WALL), Vector3(mouth, HEIGHT, middle + PASAJE_STUB.y / 2.0), tile],
		["stub_wall_west", Vector3(mouth - PASAJE_STUB.x - WALL, 0.0, middle - PASAJE_STUB.y / 2.0), Vector3(mouth - PASAJE_STUB.x, HEIGHT, middle + PASAJE_STUB.y / 2.0), tile],
		["stub_ceiling", Vector3(mouth - PASAJE_STUB.x - WALL, HEIGHT, middle - PASAJE_STUB.y / 2.0), Vector3(mouth - WALL_FACE - WALL, HEIGHT + 0.2, middle + PASAJE_STUB.y / 2.0), tile],
		["chapel_wall_north", Vector3(chapel, 0.0, side_z.x - WALL), Vector3(chapel + CHAPEL_STUB, HEIGHT + 0.5, side_z.x), tile],
		["chapel_wall_south", Vector3(chapel, 0.0, side_z.y), Vector3(chapel + CHAPEL_STUB, HEIGHT + 0.5, side_z.y + WALL), tile],
		["chapel_ceiling", Vector3(chapel, HEIGHT + 0.5, side_z.x - WALL), Vector3(chapel + CHAPEL_STUB, HEIGHT + 0.7, side_z.y + WALL), tile]]
	for b: Array in boxes:
		_box(b[1], b[2], b[3], b[0])
		get_node(NodePath(b[0])).reparent(stub)

	if ResourceLoader.exists(LANE_KIT):
		var puesto: Mesh = _kit(LANE_KIT)["puesto"]
		var look := Painterly.material(_painted(["candle_lane.png", "candle_lane_base.png"]), &"bespoke")
		for i in PUESTOS.size():
			# (Turned to face into the Pasaje, its back to the wall beside the mouth.)
			var stall_at: Vector3 = PUESTOS[i]
			var piece := _place(puesto, look, "puesto", Vector3(mouth + stall_at.x, 0.0, stall_at.z), -PI / 2.0, false)
			piece.name = "puesto_%s" % ["north", "south"][i]
			piece.reparent(stub)

	# The Pasaje's lit reaches up and down it, and the chapel's candlelit far wall: glowing cards, each with its light.
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var card := _backdrop("backdrop_%s" % ["north", "south"][i], Vector2(PASAJE_STUB.x, HEIGHT), PASAJE_GLOW, BACKDROP_GLOW.x)
		card.position = Vector3(mouth - PASAJE_STUB.x / 2.0, HEIGHT / 2.0, middle + side * BACKDROP)
		card.rotation.y = 0.0 if side < 0 else PI
		_glow("pasaje_glow_%d" % i, Vector3(mouth - PASAJE_STUB.x / 2.0, 2.6, middle + side * (BACKDROP - 1.2)), PASAJE_GLOW, 1.4, 7.0)
	var far := _backdrop("chapel_backdrop", Vector2(CHAPEL_WIDTH, HEIGHT + 0.5), CHAPEL_GLOW, BACKDROP_GLOW.y)
	far.position = Vector3(chapel + CHAPEL_STUB - 0.02, (HEIGHT + 0.5) / 2.0, DOOR_Z)
	far.rotation.y = -PI / 2.0
	_glow("chapel_glow", Vector3(chapel + CHAPEL_IN, 1.7, DOOR_Z), CHAPEL_GLOW, 1.6, 5.5)


## A card at a stub's end glowing with what lies beyond it: dark at the floor and the vault, lit between (stalls'
## lamps and neon up the Pasaje; candles round the chapel's altar). Faces +z until turned.
func _backdrop(node_name: String, size: Vector2, colour: Color, energy: float) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = size
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.45, 0.75, 1.0])
	fade.colors = PackedColorArray([Color(0.05, 0.05, 0.05), Color.WHITE, Color(0.45, 0.45, 0.45), Color.BLACK])
	var glow := GradientTexture2D.new()
	glow.gradient = fade
	glow.fill_from = Vector2(0.5, 1.0)
	glow.fill_to = Vector2(0.5, 0.0)
	var look := StandardMaterial3D.new()
	look.albedo_color = Color.BLACK
	look.emission_enabled = true
	look.emission_texture = glow
	look.emission = colour
	look.emission_energy_multiplier = energy
	look.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = look
	var card := MeshInstance3D.new()
	card.name = node_name
	card.mesh = quad
	stub.add_child(card)
	return card


func _glow(node_name: String, at: Vector3, colour: Color, energy: float, reach: float) -> void:
	var light := OmniLight3D.new()
	light.name = node_name
	light.light_color = colour
	light.light_energy = energy
	light.omni_range = reach
	# (A breath of haze about it, no more: at the fog's full share it fills the doorway like a lit sheet.)
	light.light_volumetric_fog_energy = STUB_HAZE
	stub.add_child(light)
	light.position = at


## A box built by _box (`name`, from `lo` to `hi`) rebuilt as two, cut away along x between `from` and `to`.
func _cut(name: String, lo: Vector3, hi: Vector3, from: float, to: float) -> void:
	var old := get_node_or_null(name)
	if old == null:
		return
	var look: Material = (old as MeshInstance3D).mesh.surface_get_material(0)
	old.free()
	_box(lo, Vector3(from, hi.y, hi.z), look, name + "_a")
	_box(Vector3(to, lo.y, lo.z), hi, look, name + "_b")
