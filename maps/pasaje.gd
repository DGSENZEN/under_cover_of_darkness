extends Node3D
## The Pasaje's middle stretch (docs/superpowers/specs/2026-10-26-pasaje-market-design.md; plan
## docs/superpowers/plans/2026-10-26-pasaje-market.md): the Metro's market spine round the herb market's mouth and the
## candle lane's, a night market under a vault. Judged on its own (its stubs past its openings and ends), or set into
## maps/metro at PLAN_ORIGIN (no stubs: the map's spaces meet it).
##
## Its frame is the plan's moved to PLAN_ORIGIN: x across the street (the west wall at -HALF_W, the east at +HALF_W),
## z along it (the stretch from -HALF_L, plan z 55, to +HALF_L, plan z 95), y up from the floor.

const RetroScript := preload("res://scripts/Visual/Retro.gd")
const PLAYER := preload("res://Player.tscn")
const Painterly := preload("res://scripts/Visual/Painterly.gd")
const Layers := preload("res://scripts/Visual/Layers.gd")

const PLAN_ORIGIN := Vector3(-9.0, -11.0, 75.0)
const HALF_W := 5.0
const HALF_L := 20.0
const HEIGHT := 4.5
## Its side openings: [wall side (-1 west, 1 east), z from, z to, how tall]. The herb market's as the greybox cuts it
## (4 x 3 m); the candle lane's mouth its whole height (the lane's 4 m).
const OPENINGS := {"herb_market": [-1, -3.0, 1.0, 3.0], "candle_lane": [1, -3.0, 3.9, 4.0]}
## Its walls' thickness, built inside the street's edges (west of it is the herb market's space); how far short of
## the map's planes its walls, floor and ceiling end (the greybox's faces lie on those lines); how far its stubs run.
const WALL := 0.3
const SEAM := 0.01
const STUB := 4.0

const SHELL_KIT := "res://assets/eclipse/kit/pasaje_shell.glb"
const FLOOR_KIT := "res://assets/eclipse/kit/underground_floor.glb"
const SERVICES_KIT := "res://assets/eclipse/kit/underground_services.glb"
## The shell kit's measures (tools/eclipse/pasaje_shell.py): a wall panel's width, the tiles' depth off the wall; the
## ceiling's spans and their thickness; the floor's rows of the Metro's 1.2 m modules, its side strips, its end joints.
const PANEL := 1.2
const FACE := 0.067
const SPANS := 10
const THICK := 0.04
const MODULE := 1.2
const SIDE := 0.5
const MODULES := 7
const ROWS := 33
const JOINT := 0.19
## The mains (their centres' heights; the tray's rungs'; the swags' hooks'): on the west wall the water, the gas and
## the tray, over the herb market's mouth; on the east the fire main and the air line, which turn into the wall short
## of the lane's mouth (their last lengths TURN_IN long) and out of it TURN_OUT_AT beyond it (TURN_OUT long), and
## the heavy cables swagged on hooks, their runs ending on a hook either side of it.
const WATER_Y := 3.6
const GAS_Y := 3.3
const TRAY_Y := 3.95
const FIRE_Y := 3.4
const AIR_Y := 3.05
const HOOK_Y := 4.0
const TURN_IN := 0.67
const TURN_OUT := 3.76
const TURN_OUT_AT := 4.23

const STALLS_KIT := "res://assets/eclipse/kit/pasaje_stalls.glb"
const FURNITURE_KIT := "res://assets/eclipse/kit/underground_furniture.glb"
## The stalls by trade (the design's middle stretch): [name, trade, wall side (-1 west, 1 east), its middle's z, its
## width, its frame (pipe/booth/lean_to and its cover; cart: the tamale cart under a lean-to's tarp; barrow: the fruit
## barrow under a pipe frame's canvas; tortas: the card's stall), its neon]. Round the lane's mouth on the east the
## trades her trade draws (candles, copal, milagros, saints), the copal stall beside the mouth under the mouth's teal;
## round the herb market's mouth on the west what spills out of it (herbs and roots, chiles, flowers); food between;
## a radio repairer on the Company's power, a lottery seller in the crowd, a tinsmith for the milagros and lanterns.
const STALLS := [
	["tamales", "tamales", 1, -16.2, 1.6, "cart", Color(1.0, 0.76, 0.28)],
	["radios", "radio repairs", 1, -12.6, 1.6, "pipe_tin", Color(0.64, 0.28, 1.0)],
	["candles", "candles", 1, -8.9, 2.8, "booth_canvas", Color(0.28, 1.0, 0.28)],
	["copal", "copal and incense", 1, -4.75, 2.2, "pipe_tarp", Color(0.25, 0.85, 0.9)],
	["milagros", "milagros", 1, 5.4, 1.6, "pipe_canvas", Color(0.88, 0.28, 1.0)],
	["saints", "saints and prints", 1, 8.9, 2.2, "booth_tin", Color(1.0, 0.94, 0.28)],
	["atole", "atole and coffee", 1, 13.1, 2.2, "lean_to_tarp", Color(1.0, 0.58, 0.28)],
	["sweets", "sweets", 1, 17.6, 2.2, "pipe_canvas", Color(1.0, 0.28, 1.0)],
	["tortas", "tortas", -1, -15.6, 2.2, "tortas", Color(0.28, 0.58, 1.0)],
	["fruit", "fruit", -1, -11.6, 1.6, "barrow", Color(0.58, 1.0, 0.28)],
	["lottery", "lottery tickets", -1, -8.4, 1.6, "lean_to_tin", Color(0.46, 0.28, 1.0)],
	["herbs", "herbs and roots", -1, -5.25, 2.8, "lean_to_tarp", Color(0.28, 1.0, 0.52)],
	["chiles", "dried chiles", -1, 2.9, 2.2, "pipe_canvas", Color(1.0, 0.52, 0.28)],
	["flowers", "flowers", -1, 6.5, 1.6, "booth_tin", Color(0.76, 0.28, 1.0)],
	["coffee", "coffee", -1, 11.6, 2.2, "lean_to_tin", Color(1.0, 0.88, 0.28)],
	["tinsmith", "tin and lanterns", -1, 16.2, 2.8, "booth_canvas", Color(0.28, 0.4, 1.0)],
]
## The neon box's face in the stall's frame (out from the tiles, its middle's height), and its light's reach.
const NEON_AT := Vector3(0.0, 2.57, 1.42)
const NEON_RANGE := 3.0

const WARES_KIT := "res://assets/eclipse/kit/pasaje_wares.glb"
## Each stall's wares in its frame (x along the wall, y up, z out from the tiles): [piece, where its foot stands (or
## its hook hangs)]. On the counter (its top 0.92, its middle 1.15 out), on the booth's shelf (1.535, 0.18 out), under
## the counter's ends, on the barrow's tray (0.74), hung from the beam (1.95) or the front rail (2.03).
const WARES := {
	"tamales": [["tamales_basket", Vector3(0.6, 0.0, 0.25)], ["tamales_crate", Vector3(-0.6, 0.0, 0.25)]],
	"radios": [["radios_sets", Vector3(-0.33, 0.92, 1.15)], ["radios_parts", Vector3(0.12, 0.0, 1.15)]],
	"candles": [["candles_rack", Vector3(-0.6, 0.92, 1.12)], ["candles_bundles", Vector3(0.45, 0.92, 1.15)]],
	"copal": [["copal_censers", Vector3(-0.5, 0.92, 1.15)], ["copal_baskets", Vector3(0.25, 0.92, 1.15)]],
	"milagros": [["milagros_board", Vector3(-0.35, 0.92, 1.25)], ["milagros_tray", Vector3(0.12, 0.92, 1.2)]],
	"saints": [["saints_prints", Vector3(-0.2, 1.535, 0.21)], ["saints_frames", Vector3(0.0, 0.92, 1.15)]],
	"atole": [["atole_urn", Vector3(-0.6, 0.92, 1.12)], ["atole_cups", Vector3(0.1, 0.92, 1.15)]],
	"sweets": [["sweets_trays", Vector3(-0.55, 0.92, 1.15)], ["sweets_jars", Vector3(0.3, 0.92, 1.15)]],
	"tortas": [["tortas_board", Vector3(-0.5, 1.26, 1.19)], ["tortas_jars", Vector3(-0.68, 0.0, 1.15)]],
	"fruit": [["fruit_pile", Vector3(0.13, 0.74, 0.65)], ["fruit_crates", Vector3(-0.1, 0.0, 1.35)]],
	"lottery": [["lottery_board", Vector3(-0.2, 0.92, 1.2)], ["lottery_stool", Vector3(0.15, 0.0, 1.15)]],
	"herbs": [["herbs_bundles", Vector3(-0.2, 1.95, 1.4)], ["herbs_sacks", Vector3(-0.85, 0.0, 1.15)],
		["herbs_sacks", Vector3(-0.1, 0.92, 1.15)]],
	"chiles": [["chiles_ristras", Vector3(-0.2, 2.03, 1.36)], ["chiles_baskets", Vector3(-0.2, 0.92, 1.15)]],
	"flowers": [["flowers_buckets", Vector3(-0.3, 0.92, 1.15)], ["flowers_bunches", Vector3(-0.2, 1.535, 0.18)]],
	"coffee": [["coffee_pot", Vector3(-0.55, 0.92, 1.1)], ["coffee_sacks", Vector3(0.25, 0.0, 1.15)]],
	"tinsmith": [["tinsmith_lanterns", Vector3(-0.3, 1.74, 1.38)], ["tinsmith_sheets", Vector3(0.3, 0.92, 1.15)]],
}
## The stalls a bare bulb hangs over (the food, and those that work by its light): from the cover over the counter's
## middle. With the sixteen neons, the set's twenty-four lights.
const BULBS := ["tamales", "tortas", "atole", "coffee", "fruit", "herbs", "candles", "radios"]
const BULB_AT := Vector3(-0.175, 2.17, 1.15)
const BULB_COLOUR := Color(1.0, 0.72, 0.42)
const OVERHEAD_KIT := "res://assets/eclipse/kit/pasaje_overhead.glb"
## The direction signs on rods from the girders' bottoms (GIRDER_FOOT): [board, x, the girder's z]. None under the
## canopy (it would hide them).
const GIRDER_SIGNS := [["sign_board_a", -1.5, -11.994], ["sign_board_c", 2.2, -7.996], ["sign_board_b", 1.2, -3.998],
	["sign_board_a", -0.8, 7.996], ["sign_board_c", 1.4, 11.994]]
const GIRDER_FOOT := 4.18
const ROD := 0.75
## The cables and the bulb strings slung across, each between two girders (z).
const CABLES := [-13.9, -6.1, 2.1, 9.8]
const STRINGS := [-17.0, -9.8, -2.0, 5.9, 12.85]
## The gantry under the canopy (z), the hooks along its beam (x), their height; its signs the shallow board.
const GANTRY_Z := 18.3
const GANTRY_HOOKS := [-2.0, 0.0, 2.0]
const GANTRY_HOOK_Y := 2.86
## The bills and graffiti: the sheets the graffiti are cut from (GRAFFITI_GRID x GRAFFITI_GRID, and the bigger
## pieces'); the bills' sheet (tools/textures/pasaje_bills.py: BILL_COLS x BILL_ROWS, laid out as BILL_KINDS), a
## bill's paper's top edge above its image's middle (a share of its size), a stack's width along the wall, the curl
## (the overhead kit's bill_curl) its length; how far clear of the stalls and the openings they keep, the shortest
## alcove that takes them.
const GRAFFITI := "pasaje_graffiti.png"
const GRAFFITI_B := "pasaje_graffiti_b.png"
const GRAFFITI_GRID := 4
const BILLS := "pasaje_bills.png"
const BILL_COLS := 4
const BILL_ROWS := 3
const BILL_KINDS := ["missing", "nahual_reward", "curandero", "exorcist", "cabaret", "lucha_night", "company_notice",
	"loteria", "wanted_spirit", "fiesta", "tatters", "tatters"]
const BILL_TOP := 0.42
## Each kind's size on the wall (its image's side, m): the night's posters and the Company's notices big, handbills
## less, the curandero's card small.
const BILL_SIZES := {"missing": 0.85, "nahual_reward": 0.9, "curandero": 0.5, "exorcist": 0.85, "cabaret": 1.1,
	"lucha_night": 1.1, "company_notice": 1.05, "loteria": 0.9, "wanted_spirit": 0.85, "fiesta": 1.05}
## The rows of one poster pasted side by side in the south's long alcoves: how many at most, their height.
const ROW_MOST := 5
const ROW_HEIGHT := 1.55
const STACK_WIDE := 1.0
const CURL_LENGTH := 0.18
## How far a bill's paper stands off the tiles, and each newer one off the one before (m).
const PAPER_OFF := 0.004
const PAPER_STEP := 0.002
const MARK_CLEAR := 0.15
const OPENING_CLEAR := 0.35
const ALCOVE_LEAST := 0.6
## How far a piece of wall paint may run past its alcove behind the stalls either side.
const SPILL := 0.5
## The wards: the sheet they are drawn from (its cells: the chalk circle, the threshold's arc, the salt line, the
## wall's ward sigil), the kinds of candle stood in them.
const WARDS := "pasaje_wards.png"
const WARD_CELLS := ["circle", "arc", "salt", "ward"]
const STUBS := ["candle_stub_a", "candle_stub_b", "candle_stub_c"]
## How far a ward circle's candles stand out on its ring (its image's ring at this share of its size).
const RING := 0.47
## The marks of what happened: the sheet and its normal map (its cells: the scorch, the gouges, the hand, the spiral
## cracks); where each lies and how big. The scorch on the west wall behind the north circle; the spiral on the
## floor beside it; the gouges at the lane's mouth, this share along it, `GOUGE_SIZE` across and along the drag; the
## hand under the canopy at (z, height), tilted.
const MARKS_SHEET := "pasaje_marks.png"
const MARKS_NORMAL := "pasaje_marks_n.png"
const MARK_CELLS := ["scorch", "gouges", "hand", "spiral"]
const SCORCH_Z := -18.1
const SCORCH_SIZE := 2.6
const SPIRAL_AT := Vector3(-1.05, 0.0, -17.55)
const SPIRAL_SIZE := 1.7
const GOUGE_ALONG := 0.62
const GOUGE_SIZE := Vector2(1.3, 2.0)
const HAND_SIDE := -1
const HAND_AT := Vector2(18.6, 2.3)
const HAND_SIZE := 1.3
const HAND_TILT := 0.14
## How far a sign swings at most (radians) and at what draught it does (m/s).
const SWING := deg_to_rad(4.0)
const SWING_FULL := 1.0
## The food's steam: [stall, its Vfx preset, where it leaves (the stall's frame)].
const STEAM := [["tamales", "pot_steam", Vector3(0.15, 1.51, 0.8)], ["tortas", "steam", Vector3(0.25, 1.02, 1.15)],
	["atole", "pot_steam", Vector3(-0.6, 1.54, 1.12)], ["coffee", "pot_steam", Vector3(-0.55, 1.28, 1.1)]]

@export var standalone := true
## Set into a larger map: its player is the map's.
var host_player: Node3D
var player: CharacterBody3D
## The corridor's draught (Vector3, m/s); set into the Metro, the candle lane's draught_now. Its swinging pieces
## take only its strength.
var draught: Callable = func(): return Vector3(0.35, 0.0, 0.0)
## The structural boxes (floor, walls, lintels, ceiling): the shell's collision.
var shell: Array[Node3D] = []
## Standalone only: the floors past its openings and ends, and the dark cards closing them.
var stub: Node3D
var world: WorldEnvironment
## The shell's dressing (none of it solid: the boxes stay the collision): the tile panels, fills and lintels on the
## walls; the mains on them; the ceiling's spans and girders; the floor's modules, strips and joints.
var dressing: Node3D
var wall_panels: Array[MeshInstance3D] = []
var services: Array[MeshInstance3D] = []
var ceiling: Array[MeshInstance3D] = []
var floor_tiles: Array[MeshInstance3D] = []
## The kits not found (the shell stays plain where they are missing).
var missing: Array[String] = []
## The stalls by name: each a root on its wall at its place, its pieces in the stall's frame (x along the wall, the
## tiles at z 0, the street toward +z).
var stalls := {}
## The set's own lights: the neons' and the bulbs'.
var lights: Array[Light3D] = []
## The food's steam (Vfx systems), leaning on the draught.
var steam: Array[Node3D] = []
## What hangs over the street (its meshes), and the signs' pivots, each swinging about its hook on the draught.
var overhead: Array[MeshInstance3D] = []
var hanging: Array[Node3D] = []
var _swing_clock := 0.0
## The posters and the graffiti decals on the walls.
var marks: Array[Node3D] = []
## The stacks of bills, each its generations.
var bill_stacks: Array[Node3D] = []
## The wards by their spot: each a root holding its chalk and salt, its candles, their flames.
var wards := {}
## The marks of what happened, by their kind (the scorch, the spiral, the gouges, the hand): each its decal.
var happened := {}


func _ready() -> void:
	_shell()
	_shell_dressing()
	_stalls()
	_wares()
	_overhead()
	_marks()
	_wards()
	_happened()
	if standalone:
		_environment()
		_stubs()
	if host_player != null:
		player = host_player
	else:
		player = PLAYER.instantiate()
		player.debug_traversal = false
		add_child(player)
		player.position = Vector3(0.0, 1.05, -18.0)


func _process(delta: float) -> void:
	var wind: Vector3 = draught.call()
	for system in steam:
		Vfx.blow(system, wind)
	# The signs swing about their hooks as hard as the draught blows, each at its own pace.
	_swing_clock += delta
	var reach := SWING * clampf(wind.length() / SWING_FULL, 0.0, 1.0)
	for k in hanging.size():
		hanging[k].rotation.x = reach * sin(_swing_clock * (1.7 + 0.23 * k) + 1.3 * k)


## The structural shell: the floor slab, the two walls cut round their openings (lintels over them), the ceiling.
func _shell() -> void:
	var z0 := -HALF_L + SEAM
	var z1 := HALF_L - SEAM
	var x0 := -HALF_W + SEAM
	var x1 := HALF_W - SEAM
	shell.append(_box(Vector3(x0, -0.3, z0), Vector3(x1, 0.0, z1), "floor"))
	shell.append(_box(Vector3(x0, HEIGHT, z0), Vector3(x1, HEIGHT + 0.25, z1), "ceiling"))
	for side: int in [-1, 1]:
		var inner: float = side * (HALF_W - WALL)
		var outer: float = side * (HALF_W - SEAM)
		var lo := minf(inner, outer)
		var hi := maxf(inner, outer)
		var cut: Array = []
		for name in OPENINGS:
			if OPENINGS[name][0] == side:
				cut = OPENINGS[name]
		var wall := "wall_%s" % ("west" if side < 0 else "east")
		if cut.is_empty():
			shell.append(_box(Vector3(lo, 0.0, z0), Vector3(hi, HEIGHT, z1), wall))
			continue
		shell.append(_box(Vector3(lo, 0.0, z0), Vector3(hi, HEIGHT, cut[1]), wall + "_a"))
		shell.append(_box(Vector3(lo, 0.0, cut[2]), Vector3(hi, HEIGHT, z1), wall + "_b"))
		shell.append(_box(Vector3(lo, cut[3], cut[1]), Vector3(hi, HEIGHT, cut[2]), wall + "_lintel"))


## The shell dressed in the Company's tile, as the corridor is: the walls tiled up to the ceiling in panels, a fill
## finishing each run against its opening, plaster over the openings and cement reveals round them; the ceiling's
## plaster in spans, an iron girder under each joint; the floor in the Metro's modules between a strip along each wall,
## a joint at each end; the mains along both walls.
func _shell_dressing() -> void:
	dressing = Node3D.new()
	dressing.name = "dressing"
	add_child(dressing)
	if not ResourceLoader.exists(SHELL_KIT):
		missing.append(SHELL_KIT)
		return
	var meshes := SetKit.kit(SHELL_KIT)
	var look := Painterly.material(SetKit.painted(["pasaje_shell.png", "pasaje_shell_base.png"]), &"bespoke")

	# The walls: each run panels from the stretch's end, its fill against the opening; the panels worn by the
	# openings' traffic and here and there by the years.
	for side: int in [-1, 1]:
		for run in _wall_runs(side):
			var a: float = run[0]
			var b: float = run[1]
			var count := int(floor((b - a) / PANEL + 0.001))
			var fill := b - a - count * PANEL
			var at_end := absf(b - (HALF_L - SEAM)) < 0.001
			var z := a + fill if at_end else a
			for k in count:
				var by_opening := (k == 0 and at_end) or (k == count - 1 and not at_end)
				var kind := "wall_worn" if by_opening or _hash(side * 7.0 + z) > 0.8 else "wall"
				wall_panels.append(_wall_piece(meshes, look, kind, side, z, PANEL))
				z += PANEL
			if fill > 0.001:
				var kind := "wall_fill_%d" % roundi(fill * 100.0)
				wall_panels.append(_wall_piece(meshes, look, kind, side, a if at_end else b - fill, fill))
	for name in OPENINGS:
		var spec: Array = OPENINGS[name]
		wall_panels.append(_wall_piece(meshes, look, "lintel_" + name, spec[0], spec[1], spec[2] - spec[1]))
		# (Its sill takes the salt laid across it.)
		SetKit.place(dressing, meshes["reveal_" + name], look, "reveal_" + name, Vector3.ZERO, 0.0, false).layers = \
			Layers.WORLD | Layers.PAINTED_FLOOR

	_ceiling(meshes)
	_floor(meshes, look)
	_services(meshes, look)


## The runs of one wall between the stretch's ends and its openings: [z from, z to].
func _wall_runs(side: int) -> Array:
	var runs := []
	var z := -HALF_L + SEAM
	for name in OPENINGS:
		if OPENINGS[name][0] == side:
			runs.append([z, OPENINGS[name][1]])
			z = OPENINGS[name][2]
	runs.append([z, HALF_L - SEAM])
	return runs


## A wall piece (its run along its +x, its face out of the wall toward the street) on the `side` wall covering z from
## `low` to `low` + `width`; the west wall's turned to run toward -z.
func _wall_piece(meshes: Dictionary, look: Material, kind: String, side: int, low: float, width: float) -> MeshInstance3D:
	var x := side * (HALF_W - WALL)
	var at := Vector3(x, 0.0, low + width if side < 0 else low)
	var piece := SetKit.place(dressing, meshes[kind], look, kind, at, -side * PI / 2.0, false)
	# (The wall paint lands on it.)
	piece.layers = Layers.WORLD | Layers.PAINTED_WALL
	return piece


## The ceiling: its plaster in spans, each turned one way or the other against repetition, its underside under the
## ceiling's box; under each joint between them, a girder.
func _ceiling(meshes: Dictionary) -> void:
	var plaster := Painterly.material(SetKit.painted(["pasaje_shell.png", "pasaje_shell_base.png"]), &"bespoke")
	# (As the corridor's vault: a warm bounce off the lit floor below, its shadows not tinted cool.)
	plaster.set_shader_parameter("ambient_ground", Color(0.52, 0.38, 0.26))
	plaster.set_shader_parameter("ambient_sky", Color(0.46, 0.36, 0.27))
	plaster.set_shader_parameter("ambient_amount", 0.26)
	plaster.set_shader_parameter("shadow_cool", Vector3(0.95, 0.9, 0.92))
	plaster.set_shader_parameter("rim_colour", Color(0.5, 0.38, 0.27))
	var span := 2.0 * (HALF_L - SEAM) / SPANS
	var under := HEIGHT - THICK
	for k in SPANS:
		var z := -HALF_L + SEAM + span * k
		var turned := k % 2 == 1
		var at := Vector3(0.0, under, z if turned else z + span)
		ceiling.append(SetKit.place(dressing, meshes["ceiling_span"], plaster, "ceiling_span", at, PI if turned else 0.0, false))
		if k > 0:
			ceiling.append(SetKit.place(dressing, meshes["girder"], plaster, "girder", Vector3(0.0, under, z), 0.0, false))


## The floor: rows of the Metro's modules (worn where the openings' traffic and the street's middle tread them),
## each turned one way or the other, between a strip along each wall; a joint at each end. The plain slab under it
## hidden (it stays the floor's collision).
func _floor(meshes: Dictionary, look: Material) -> void:
	if not ResourceLoader.exists(FLOOR_KIT):
		missing.append(FLOOR_KIT)
		return
	var modules := SetKit.kit(FLOOR_KIT)
	var tiles := Painterly.material(SetKit.painted(["underground_floor.png", "underground_floor_base.png"]), &"bespoke")
	var inside := HALF_W - WALL
	for r in ROWS:
		var z := -HALF_L + SEAM + JOINT + MODULE * r
		for i in MODULES:
			var x := -inside + SIDE + MODULE * i
			var trodden := (i == 3 and _hash(z * 3.1) > 0.6) or _by_opening(i, z)
			var kind := "floor_field_worn" if trodden else "floor_field"
			var turned := _hash(x * 12.9898 + z * 78.233) > 0.5
			var at := Vector3(x + MODULE, 0.0, z) if turned else Vector3(x, 0.0, z + MODULE)
			floor_tiles.append(SetKit.place(dressing, modules[kind], tiles, kind, at, PI if turned else 0.0, false))
		floor_tiles.append(SetKit.place(dressing, meshes["floor_side"], look, "floor_side", Vector3(-inside, 0.0, z + MODULE), 0.0, false))
		floor_tiles.append(SetKit.place(dressing, meshes["floor_side"], look, "floor_side", Vector3(inside, 0.0, z), PI, false))
	# (Each joint's lip reaches under the next stretch's floor.)
	floor_tiles.append(SetKit.place(dressing, meshes["floor_joint"], look, "floor_joint", Vector3(0.0, 0.0, -HALF_L + SEAM), PI, false))
	floor_tiles.append(SetKit.place(dressing, meshes["floor_joint"], look, "floor_joint", Vector3(0.0, 0.0, HALF_L - SEAM), 0.0, false))
	# (The chalk and salt laid on it land on it.)
	for tile in floor_tiles:
		tile.layers = Layers.WORLD | Layers.PAINTED_FLOOR
	shell[0].visible = false


## Whether module column `i` of the row from `z` lies in an opening's mouth, beside its wall.
func _by_opening(i: int, z: float) -> bool:
	for name in OPENINGS:
		var spec: Array = OPENINGS[name]
		var column := 0 if spec[0] < 0 else MODULES - 1
		if i == column and z + MODULE > spec[1] and z < spec[2]:
			return true
	return false


## The mains. West: the water main, the gas line below it and the Company's tray above, the length of the stretch
## over the herb market's mouth, a cable let loose from the tray there (where the herb sellers' power was tapped).
## East: the fire main (its gate valve in it) and the air line, into the wall short of the lane's mouth and out again
## beyond it; the heavy cables swagged on hooks either side.
func _services(meshes: Dictionary, shell_look: Material) -> void:
	if not ResourceLoader.exists(SERVICES_KIT):
		missing.append(SERVICES_KIT)
		return
	var kit := SetKit.kit(SERVICES_KIT)
	var look := Painterly.material(SetKit.painted(["underground_services.png", "underground_services_base.png"]), &"bespoke")
	for k in 10:
		var low := HALF_L - SEAM - 4.0 * (k + 1)
		_main(kit, look, "pipe_green_4", "water", -1, low, WATER_Y)
		_main(kit, look, "pipe_ochre_4", "gas", -1, low, GAS_Y)
		_main(kit, look, "cable_tray_4_spill" if k == 5 else "cable_tray_4", "tray", -1, low, TRAY_Y)
	var mouth: Array = OPENINGS["candle_lane"]
	for k in 4:
		var low := -HALF_L + SEAM + 4.0 * k
		_main(kit, look, "pipe_red_valve" if k == 1 else "pipe_red_4", "fire", 1, low, FIRE_Y)
		_main(kit, look, "pipe_blue_4", "air", 1, low, AIR_Y)
	var turn_at := -HALF_L + SEAM + 16.0
	# (Their turns into the wall are the shell kit's, painted on its atlas.)
	_main(meshes, shell_look, "fire_turn_in", "fire", 1, turn_at, FIRE_Y)
	_main(meshes, shell_look, "air_turn_in", "air", 1, turn_at, AIR_Y)
	_main(meshes, shell_look, "fire_turn_out", "fire", 1, TURN_OUT_AT, FIRE_Y)
	_main(meshes, shell_look, "air_turn_out", "air", 1, TURN_OUT_AT, AIR_Y)
	for k in 3:
		var low := TURN_OUT_AT + TURN_OUT + 4.0 * k
		_main(kit, look, "pipe_red_4", "fire", 1, low, FIRE_Y)
		_main(kit, look, "pipe_blue_4", "air", 1, low, AIR_Y)
	for hook in [-19.5, -16.5, -13.5, -10.5, -7.5, 4.5, 7.5, 10.5, 13.5, 16.5]:
		_main(kit, look, "cable_swag", "swag", 1, hook, HOOK_Y)
	for hook in [mouth[1] - 1.5, 19.5]:
		_main(kit, look, "cable_hook", "swag", 1, hook, HOOK_Y)


## A length of a main (run along its +x, out from the wall's tiles) on the `side` wall from z `low`, at `height`;
## marked with the main it is part of. (The west wall's, turned to run toward -z, are all four-metre lengths.)
func _main(kit: Dictionary, look: Material, kind: String, main: String, side: int, low: float,
		height: float) -> MeshInstance3D:
	var x := side * (HALF_W - WALL - FACE)
	var at := Vector3(x, height, low + 4.0 if side < 0 else low)
	var piece := SetKit.place(dressing, kit[kind], look, kind, at, -side * PI / 2.0, false)
	piece.set_meta("main", main)
	services.append(piece)
	return piece


## The stalls: each put together from the stalls kit in its frame against its wall, solid where it stands (its frame,
## counter and cart; the floor left open under the counters), under its own neon.
func _stalls() -> void:
	if not ResourceLoader.exists(STALLS_KIT):
		missing.append(STALLS_KIT)
		return
	var kit := SetKit.kit(STALLS_KIT)
	var look := Painterly.material(SetKit.painted(["pasaje_stalls.png", "pasaje_stalls_base.png"]), &"bespoke")
	var furniture := SetKit.kit(FURNITURE_KIT) if ResourceLoader.exists(FURNITURE_KIT) else {}
	var cart_look := Painterly.material(SetKit.painted(["underground_furniture.png", "underground_furniture_base.png"]), &"bespoke")
	for k in STALLS.size():
		var spec: Array = STALLS[k]
		var side: int = spec[2]
		var root := Node3D.new()
		root.name = spec[0]
		root.set_meta("trade", spec[1])
		add_child(root)
		root.position = Vector3(side * (HALF_W - WALL - FACE), 0.0, spec[3])
		root.rotation.y = -side * PI / 2.0
		var width: float = spec[4]
		var tenths := roundi(width * 10.0)
		var frame: String = spec[5]
		var pieces := []
		match frame:
			"cart":
				pieces = [["lean_to_%d" % tenths, true], ["awning_tarp_%d" % tenths, false]]
				if furniture.has("tamale_cart"):
					SetKit.place(root, furniture["tamale_cart"], cart_look, "tamale_cart", Vector3(0.0, 0.0, 0.8), 0.0, true)
			"barrow":
				pieces = [["pipe_frame_%d" % tenths, true], ["awning_canvas_%d" % tenths, false], ["barrow", true]]
			"tortas":
				pieces = [["pipe_frame_%d" % tenths, true], ["awning_canvas_%d" % tenths, false],
					["counter_%d" % tenths, true], ["vitrina", false], ["plancha", false]]
			_:
				var cover := frame.get_slice("_", frame.get_slice_count("_") - 1)
				var family := frame.trim_suffix("_" + cover)
				family = "pipe_frame" if family == "pipe" else family
				pieces = [[family + "_%d" % tenths, true], ["awning_%s_%d" % [cover, tenths], false],
					["counter_%d" % tenths, true]]
		for piece in pieces:
			SetKit.place(root, kit[piece[0]], look, piece[0], Vector3.ZERO, 0.0, piece[1], true)
		_neon(root, kit, look, width, spec[6], k)
		stalls[spec[0]] = root


## A stall's neon over its cover: the box (its face blank) and its tube, lit by a NeonSign of the stall's colour.
func _neon(root: Node3D, kit: Dictionary, look: Material, width: float, colour: Color, k: int) -> void:
	var size := 9 if width < 2.0 else 13
	SetKit.place(root, kit["neon_box_%d" % size], look, "neon_box", Vector3.ZERO, 0.0, false)
	var neon := NeonSign.new()
	neon.name = "neon"
	neon.colour = colour
	neon.seed = 31 + k
	neon.light_energy = 0.5
	neon.light_range = NEON_RANGE
	SetKit.place(neon, kit["neon_tube_%d" % size], look, "neon_tube", Vector3.ZERO, 0.0, false)
	var glow := OmniLight3D.new()
	glow.name = "light"
	neon.add_child(glow)
	glow.position = NEON_AT + Vector3(0.0, 0.0, 0.35)
	root.add_child(neon)
	lights.append(glow)


## Each stall's wares where they stand; a bare bulb over the counters that want one, lit; the food steaming.
func _wares() -> void:
	if not ResourceLoader.exists(WARES_KIT) or stalls.is_empty():
		missing.append(WARES_KIT)
		return
	var kit := SetKit.kit(WARES_KIT)
	var look := Painterly.material(SetKit.painted(["pasaje_wares.png", "pasaje_wares_base.png"]), &"bespoke")
	for name in WARES:
		for ware in WARES[name]:
			SetKit.place(stalls[name], kit[ware[0]], look, ware[0], ware[1], 0.0, false)
	var lit := StandardMaterial3D.new()
	lit.albedo_color = BULB_COLOUR
	lit.emission_enabled = true
	lit.emission = BULB_COLOUR
	lit.emission_energy_multiplier = 3.0
	for name in BULBS:
		var root: Node3D = stalls[name]
		var at := BULB_AT if root.find_children("counter*", "MeshInstance3D", true, false).size() > 0 \
			else Vector3(0.0, BULB_AT.y, BULB_AT.z)
		var bulb := SetKit.place(root, kit["bulb"], look, "bulb", at, 0.0, false)
		# (Its glass glowing; its socket and cord painted.)
		for i in bulb.mesh.get_surface_count():
			var slot: Material = bulb.mesh.surface_get_material(i)
			if slot != null and slot.resource_name.begins_with("glass"):
				bulb.set_surface_override_material(i, lit)
		var light := OmniLight3D.new()
		light.name = "bulb_light"
		light.light_color = BULB_COLOUR
		light.light_energy = 0.9
		light.omni_range = 3.2
		light.shadow_enabled = false
		root.add_child(light)
		light.position = at + Vector3(0.0, -0.26, 0.0)
		lights.append(light)
	for spec in STEAM:
		var system := Vfx.system(spec[1])
		system.name = "steam"
		stalls[spec[0]].add_child(system)
		system.position = spec[2]
		Vfx.emit(system, true)
		steam.append(system)


## What the market hung over its street: direction signs on rods from the girders, cables and bulb strings slung
## across, and at its south end the canopy with the gantry of signs under it.
func _overhead() -> void:
	if not ResourceLoader.exists(OVERHEAD_KIT):
		missing.append(OVERHEAD_KIT)
		return
	var kit := SetKit.kit(OVERHEAD_KIT)
	var look := Painterly.material(SetKit.painted(["pasaje_overhead.png", "pasaje_overhead_base.png"]), &"bespoke")
	var lit := StandardMaterial3D.new()
	lit.albedo_color = BULB_COLOUR
	lit.emission_enabled = true
	lit.emission = BULB_COLOUR
	lit.emission_energy_multiplier = 3.0
	var root := Node3D.new()
	root.name = "overhead"
	add_child(root)
	for spec in GIRDER_SIGNS:
		overhead.append(SetKit.place(root, kit["drop_rod"], look, "drop_rod", Vector3(spec[1], GIRDER_FOOT, spec[2]), 0.0, false))
		_hung_sign(root, kit, look, spec[0], Vector3(spec[1], GIRDER_FOOT - ROD, spec[2]))
	for z in CABLES:
		overhead.append(SetKit.place(root, kit["cable_bundle"], look, "cable_bundle", Vector3(0.0, 0.0, z), 0.0, false))
	for z in STRINGS:
		var string := SetKit.place(root, kit["bulb_string"], look, "bulb_string", Vector3(0.0, 0.0, z), 0.0, false)
		# (Its bulbs glowing; no lights of their own, the set's light budget spent on the stalls.)
		for i in string.mesh.get_surface_count():
			var slot: Material = string.mesh.surface_get_material(i)
			if slot != null and slot.resource_name.begins_with("glass"):
				string.set_surface_override_material(i, lit)
		overhead.append(string)
	overhead.append(SetKit.place(root, kit["canopy"], look, "canopy", Vector3.ZERO, 0.0, false))
	overhead.append(SetKit.place(root, kit["gantry"], look, "gantry", Vector3(0.0, 0.0, GANTRY_Z), 0.0, false))
	for x in GANTRY_HOOKS:
		_hung_sign(root, kit, look, "sign_board_b", Vector3(x, GANTRY_HOOK_Y, GANTRY_Z))


## Bills pasted and paint sprayed in the alcoves the stalls leave on the walls, where people stop and nobody keeps the
## wall clean, each by its cause, in three bands up the wall (so they layer, not collide):
## - by the lane's mouth and the herb market's, and at the south end the canopy guards, ward sigils, where the
##   uncanny comes close; calaveras by her trades (candles, saints), the eye against the evil eye by the copal and
##   the herbs, the moon by the herbs; at the north end, where the Company's notices go up, its roundel crossed out;
## - bills in the middle band, a stack to an alcove pasted over the years (_bill_stack), deeper toward the south end;
## - throw-ups low across the long alcoves, burners in the south's; tags high, more toward the south, where the crowd
##   is thickest;
## - the sacred heart by her trades (milagros, saints, candles), the luchador's mask by the radio repairer and the
##   lottery seller, a sugar skull by the flowers and the sweets; at the north end the Company's buff over old tags; a
##   crew's roll-call in the south;
## - along the top of the walls, two murals: the feathered serpent's coils on the west wall, an alebrije on the east.
func _marks() -> void:
	if not ResourceLoader.exists(OVERHEAD_KIT):
		return
	var kit := SetKit.kit(OVERHEAD_KIT)
	var look := Painterly.material(SetKit.painted(["pasaje_overhead.png", "pasaje_overhead_base.png"]), &"bespoke")
	var cells := _paints()
	var bills := {}
	var bill_cells := _sheet_cells(BILLS, BILL_COLS, BILL_ROWS)
	for i in bill_cells.size():
		bills.get_or_add(BILL_KINDS[i], []).append(bill_cells[i])
	var root := Node3D.new()
	root.name = "marks"
	add_child(root)
	var k := 0
	for side: int in [-1, 1]:
		for alcove in _alcoves(side):
			var a: float = alcove[0]
			var b: float = alcove[1]
			var middle := 0.5 * (a + b)
			var south := (middle + HALF_L) / (2.0 * HALF_L)
			# Each band's free run along the alcove: [where its next piece may start]. The paint runs on past the
			# alcove behind the stalls either side (it lands on the wall only).
			var bands := {"low": a - SPILL, "mid": a + 0.05, "high": a - SPILL}
			var spray := func(kind: String, band: String, size: float, height: float) -> void:
				if cells.is_empty() or bands[band] + size > b + SPILL:
					return
				var z: float = bands[band] + size / 2.0
				bands[band] += size * 0.85
				marks.append(_graffito(root, _paint_of(cells, kind, k), kind, side, z, height, size))

			# What the place calls for.
			var by_lane: bool = side > 0 and absf(middle - 0.45) < 10.5
			var by_herbs: bool = side < 0 and absf(middle + 1.0) < 10.0
			if by_lane or by_herbs or middle > 15.0:
				spray.call("sigil", "high", 1.2, 2.05)
			if side > 0 and ((middle > -11.7 and middle < -6.0) or (middle > 6.3 and middle < 11.9)):
				spray.call("calavera", "low", 0.75, 0.75)
			if (side > 0 and middle > -7.5 and middle < -5.9) or (side < 0 and middle > -7.5 and middle < -6.7):
				spray.call("eye", "high", 0.7, 2.1)
			if side < 0 and middle > 4.0 and middle < 5.6:
				spray.call("moon", "high", 0.75, 2.05)
			if middle < -16.0:
				spray.call("roundel", "high", 0.9, 2.0)
			if side > 0 and ((middle > 4.4 and middle < 7.7) or (middle > -11.7 and middle < -10.4)):
				spray.call("heart", "high", 1.0, 2.1)
			if (side > 0 and middle > -15.4 and middle < -13.5) or (side < 0 and middle > -10.6 and middle < -9.3):
				spray.call("lucha", "high", 0.8, 2.05)
			if (side < 0 and middle > 7.4 and middle < 10.4) or (side > 0 and middle > 18.8):
				spray.call("sugar_skull", "mid", 0.95, 1.6)
			if middle < -15.0:
				spray.call("buff", "low", 1.5, 1.0)
			if side < 0 and middle > 12.8 and middle < 14.7:
				spray.call("rollcall", "high", 1.2, 2.0)

			# The bills, a stack of them pasted over the years.
			if bands["mid"] + STACK_WIDE < b + SPILL * 0.5:
				_bill_stack(root, kit, look, bills, side, bands["mid"] + STACK_WIDE / 2.0, middle, south, k)
				bands["mid"] += STACK_WIDE
			# In the south, where the nights are advertised, one poster pasted again and again along the wall.
			if south > 0.5 and b - a >= 1.4:
				var night: String = ["fiesta", "lucha_night", "cabaret"][k % 3]
				var size: float = BILL_SIZES[night] * 0.85
				for i in ROW_MOST:
					var z: float = bands["mid"] + size * 0.48
					if z + size * 0.48 > b + SPILL:
						break
					marks.append(_billed(root, bills[night][0], night, side, z, ROW_HEIGHT + 0.04 * sin(i * 1.9), size,
						(_hash(k * 5.3 + i) - 0.5) * 0.06, 10 + i))
					bands["mid"] = z + size * 0.48

			# The throw-ups and the tags.
			if south > 0.3 and b - a >= (1.0 if south > 0.5 else 1.4):
				spray.call("burner" if south > 0.55 else "throwup", "low", 1.6 + 0.4 * _hash(k * 2.3), 0.95)
			for i in int(0.5 + 3.2 * south * south):
				spray.call("tag", "high", 1.1 + 0.4 * _hash(k * 1.7 + i), 2.15 - 0.08 * i)
			if south > 0.7:
				spray.call("tag", "mid", 1.0, 1.85)
			if south > 0.55:
				spray.call("tag", "low", 1.1, 0.55)
			k += 1

	# Along the top of the wall over the stalls, out of a hand's reach but not a ladder's: the two murals, and tags and
	# throw-ups the length of the stretch round them, closer together toward the south.
	for mural in MURALS:
		marks.append(_graffito(root, _paint_of(cells, mural[0], 0), mural[0], mural[1], mural[2], 2.72, mural[3]))
	for side: int in [-1, 1]:
		var z := -HALF_L + 0.6
		while z < HALF_L - 0.6:
			var south := (z + HALF_L) / (2.0 * HALF_L)
			var size := 1.0 + 0.5 * _hash(z * 2.1 + side) + 0.3 * south
			var kind := "throwup" if _hash(z * 1.3 - side) > 0.7 else "tag"
			var middle := z + size / 2.0
			var on_mural := MURALS.any(func(m): return m[1] == side and absf(m[2] - middle) < (m[3] + size) / 2.0)
			if middle + size / 2.0 < HALF_L and not on_mural and not _by_opening_z(side, middle, 0.3 + size / 2.0):
				marks.append(_graffito(root, _paint_of(cells, kind, k), kind, side, middle, 2.72, size))
				k += 1
			z += size + lerpf(3.6, 0.3, south) * (0.6 + 0.8 * _hash(z * 0.7 + side * 3.0))


## The wards, where the uncanny comes close and the market keeps it out:
## - at the candle lane's mouth (her trade's), salt poured across its sill, candles burning at both its jambs;
## - at the herb market's mouth, salt across its sill, the ward sigil painted on the wall either side, candles at its
##   jambs;
## - at the stretch's north end, facing the dark stretch beyond, a chalk circle round a rite, candles on its points;
## - under the canopy at the south end, a smaller circle, its candles;
## - in the alcove between the candle-seller's booth and the copal stall, under the sigil on the wall there, the arc
##   chalked out from the wall, candles in its rings, marigolds laid in it.
func _wards() -> void:
	if not ResourceLoader.exists(WARES_KIT):
		return
	var kit := SetKit.kit(WARES_KIT)
	var look := Painterly.material(SetKit.painted(["pasaje_wares.png", "pasaje_wares_base.png"]), &"bespoke")
	var cells := _sheet_cells(WARDS, 2)
	if cells.is_empty():
		return
	var lane: Array = OPENINGS["candle_lane"]
	var herbs: Array = OPENINGS["herb_market"]
	var face := HALF_W - WALL - FACE
	var sill := HALF_W - WALL / 2.0

	var at_lane := _ward_root("lane_threshold")
	_laid(at_lane, cells[2], Vector3(sill, 0.0, 0.5 * (lane[1] + lane[2])), Vector2(lane[2] - lane[1] - 0.1, 0.4), PI / 2.0)
	_candles_at(at_lane, kit, look, [Vector3(4.35, 0.0, lane[1] + 0.3), Vector3(4.35, 0.0, lane[2] - 0.3)], 4, 0.16)

	var at_herbs := _ward_root("herb_threshold")
	_laid(at_herbs, cells[2], Vector3(-sill, 0.0, 0.5 * (herbs[1] + herbs[2])), Vector2(herbs[2] - herbs[1] - 0.1, 0.4), PI / 2.0)
	for z in [herbs[1] - 0.5, herbs[2] + 0.45]:
		var sigil := _graffito(at_herbs, cells[3], "ward", -1, z, 2.0, 0.5)
		sigil.name = "ward_sigil"
	_candles_at(at_herbs, kit, look, [Vector3(-4.35, 0.0, herbs[1] + 0.3), Vector3(-4.35, 0.0, herbs[2] - 0.3)], 4, 0.16)

	for spec in [["north_circle", Vector3(-2.6, 0.0, -18.6), 2.0, 7], ["canopy_circle", Vector3(2.0, 0.0, 19.15), 1.5, 5]]:
		var root := _ward_root(spec[0])
		var size: float = spec[2]
		_laid(root, cells[0], spec[1], Vector2(size, size), 0.0)
		var points: Array[Vector3] = []
		for k in spec[3]:
			var a: float = TAU * k / spec[3] - PI / 2.0
			points.append(spec[1] + Vector3(cos(a), 0.0, sin(a)) * size * RING)
		_candles_at(root, kit, look, points, 1, 0.0)

	# The arc against the east wall: its image's top at the wall, its candles in the five rings round its rim.
	var alcove := _ward_root("copal_alcove")
	var size := 1.2
	var z_mid := -6.7
	_laid(alcove, cells[1], Vector3(face - size / 2.0, 0.0, z_mid), Vector2(size, size), 0.0, Vector3(-1.0, 0.0, 0.0))
	var rings: Array[Vector3] = []
	for k in 5:
		var a := PI * k / 4.0
		var u := 0.5 + 0.449 * cos(a)
		var v := 0.08 + 0.449 * sin(a)
		rings.append(Vector3(face - v * size, 0.0, z_mid + (u - 0.5) * size))
	_candles_at(alcove, kit, look, rings, 1, 0.0)
	SetKit.place(alcove, kit["flowers_bunches"], look, "marigolds", Vector3(face - 0.3 * size, 0.0, z_mid), PI / 2.0, false)


## The marks of what happened, each where it happened. At the north end, where the rite went wrong: the wall behind
## its circle scorched by the fire that stood at its foot, and the floor beside the circle cracked in a spiral out
## from where something struck. At the candle lane's mouth: four claws dug into the floor and dragged out into the
## street. Under the canopy at the south end: a soot hand too big to be a person's pressed on the west wall, a little
## askew. The gouges and cracks cut into the tile (their normal maps).
func _happened() -> void:
	var cells := _sheet_cells(MARKS_SHEET, 2)
	var normals := _sheet_cells(MARKS_NORMAL, 2)
	if cells.is_empty():
		return
	var root := Node3D.new()
	root.name = "happened"
	add_child(root)
	var lane: Array = OPENINGS["candle_lane"]

	# (The scorch's fire stood at its image's source, 0.86 down it: at the wall's foot.)
	var scorch := _graffito(root, cells[0], "scorch", -1, SCORCH_Z, 0.1 + SCORCH_SIZE * (0.86 - 0.5), SCORCH_SIZE)
	happened["scorch"] = scorch

	var spiral := _laid(root, cells[3], SPIRAL_AT, Vector2(SPIRAL_SIZE, SPIRAL_SIZE), 0.6)
	spiral.name = "spiral"
	happened["spiral"] = spiral

	# (Its image's top, where the claws bit, toward the lane: dragged west out of it.)
	var gouges := _laid(root, cells[1], Vector3(HALF_W - WALL - FACE - GOUGE_SIZE.y / 2.0 - 0.05, 0.0,
		lane[1] + GOUGE_ALONG * (lane[2] - lane[1])), GOUGE_SIZE, 0.0, Vector3(1.0, 0.0, -0.18))
	gouges.name = "gouges"
	happened["gouges"] = gouges

	var hand := _graffito(root, cells[2], "hand", HAND_SIDE, HAND_AT.x, HAND_AT.y, HAND_SIZE)
	hand.basis = hand.basis * Basis(Vector3.UP, HAND_TILT)
	happened["hand"] = hand
	# (The scorch and the hand drawn over the older paint they lie on; the hand, the newest thing on its wall, over the
	# bills pasted there too.)
	scorch.sorting_offset = 1.0
	hand.sorting_offset = 1.0
	hand.cull_mask = Layers.PAINTED_WALL | Layers.PASTED

	for kind in ["gouges", "spiral"]:
		var mark: Decal = happened[kind]
		mark.texture_normal = normals[MARK_CELLS.find(kind)] if normals.size() == MARK_CELLS.size() else null
	for kind in happened:
		happened[kind].set_meta("kind", kind)


## A ward's root, kept by its spot's name.
func _ward_root(spot: String) -> Node3D:
	var root := Node3D.new()
	root.name = spot
	add_child(root)
	wards[spot] = root
	return root


## Chalk or salt laid on the floor (or a sill) at `at`, `size` across (x) and along (z) its image, turned `yaw` (or
## its image's top toward `top`): on the floor's own tiles and sills only.
func _laid(root: Node3D, cell: Texture2D, at: Vector3, size: Vector2, yaw: float, top := Vector3.ZERO) -> Decal:
	var laid := Decal.new()
	laid.name = "laid"
	laid.texture_albedo = cell
	laid.size = Vector3(size.x, 0.3, size.y)
	laid.normal_fade = 0.6
	laid.cull_mask = Layers.PAINTED_FLOOR
	root.add_child(laid)
	laid.position = at
	if top != Vector3.ZERO:
		# (Its image's down, local Z, away from `top`.)
		var down := -top.normalized()
		laid.basis = Basis(Vector3.UP.cross(down), Vector3.UP, down)
	else:
		laid.rotation.y = yaw
	return laid


## Candles stood at each of `places` on the floor (`per` to a place, clustered `spread` round it), burnt to their
## own heights, their flames on their wicks, one light among them.
func _candles_at(root: Node3D, kit: Dictionary, look: Material, places: Array, per: int, spread: float) -> void:
	var wicks := []
	var middle := Vector3.ZERO
	var k := 0
	for place: Vector3 in places:
		for i in per:
			var a := TAU * i / maxf(per, 1) + 0.7 * k
			var at := place + Vector3(cos(a), 0.0, sin(a)) * spread * (0.4 + 0.6 * _hash(k * 1.3 + i))
			var kind: String = STUBS[(k + i) % STUBS.size()]
			var stub := SetKit.place(root, kit[kind], look, "candle_stub", at, _hash(k + i * 2.1) * TAU, false)
			var top: float = stub.get_aabb().end.y
			var wick := to_global(at + Vector3(0.0, top + 0.004, 0.0))
			wicks.append([wick.x, wick.y, wick.z])
			middle += wick
		k += 1
	middle /= wicks.size()
	var flames := Vfx.system("candles")
	flames.name = "flames"
	root.add_child(flames)
	Vfx.place(flames, middle, {"wicks": wicks})
	Vfx.emit(flames, true)
	for light: OmniLight3D in flames.find_children("*", "OmniLight3D", false, false):
		lights.append(light)


## A painted sheet cut into its square cells (`cols` across, `rows` down, rows the same as cols if not given), each its
## own texture (a decal draws a whole texture).
func _sheet_cells(file: String, cols: int, rows := 0) -> Array[Texture2D]:
	var cells: Array[Texture2D] = []
	var sheet := SetKit.painted([file], SetKit.ATLAS_DIR, true)
	if sheet == null:
		return cells
	var image := sheet.get_image()
	if image.is_compressed():
		image.decompress()
	var size := image.get_width() / cols
	for j in (rows if rows > 0 else cols):
		for i in cols:
			# (Its mipmaps made: a material sampling it through mipmaps (the retro look's) reads black without them.)
			var cell := image.get_region(Rect2i(i * size, j * size, size, size))
			cell.generate_mipmaps()
			cells.append(ImageTexture.create_from_image(cell))
	return cells


## A stack of bills pasted over the years at `z` on the `side` wall: the tatters of older bills torn back, two and
## more newer bills over them, each over the one before and a little askew, the newest perhaps peeling at its top;
## which bills by where the stack is (`middle`, `south` its share toward the south end) and what goes on there.
func _bill_stack(root: Node3D, kit: Dictionary, look: Material, bills: Dictionary, side: int, z: float, middle: float,
		south: float, k: int) -> void:
	var stack := Node3D.new()
	stack.name = "bills"
	root.add_child(stack, true)
	bill_stacks.append(stack)
	var height := 1.4 + 0.15 * _hash(k * 2.9)
	var under := _billed(stack, bills["tatters"][k % 2], "tatters", side, z, height, 1.15, (_hash(k) - 0.5) * 0.1, 0)
	marks.append(under)
	var wants := _bills_wanted(side, middle)
	var top: MeshInstance3D = null
	var top_kind := ""
	for i in 2 + int(2.2 * south):
		var kind: String = wants[(k + i) % wants.size()]
		var shift := Vector2((_hash(k * 1.7 + i) - 0.5) * 0.36, (_hash(k * 2.3 + i) - 0.5) * 0.24)
		var size: float = BILL_SIZES[kind] + 0.1 * _hash(k + i * 0.7)
		top = _billed(stack, bills[kind][0], kind, side, z + shift.x, height + shift.y, size,
			(_hash(k * 3.1 + i) - 0.5) * 0.14, i + 1)
		top_kind = kind
		marks.append(top)
	# (The newest, if it is newsprint, come away from the wall in the damp at its top edge.)
	if top != null and top_kind in ["missing", "exorcist", "company_notice", "wanted_spirit"] and _hash(k * 4.1) > 0.35:
		# (Its paper's top edge, BILL_TOP of its image under its middle; the curl run along the wall from there, its
		# middle over the bill's.)
		var edge := top.position + Vector3(0.0, (top.mesh as QuadMesh).size.y * BILL_TOP, 0.0)
		var at := Vector3(top.position.x, edge.y, edge.z - side * CURL_LENGTH / 2.0)
		SetKit.place(stack, kit["bill_curl"], look, "bill_curl", at, -side * PI / 2.0, false)


## The bills a stack on the `side` wall at `middle` is pasted with (each kind its paper, left empty for the user's bill
## of that kind), by what goes on there: the missing and the wanted
## spirit by the dark north and her lane; the reward for a lost nahual by the herb market and the lane (the nahual's
## ways); the curandero's card by the herbs and the copal; the exorcist's by the north end; the Company's notice at
## the north end; the lotería by the lottery seller; the cabaret, the lucha and the fiesta in the south, the night's.
func _bills_wanted(side: int, middle: float) -> Array:
	var wants := []
	if middle < -12.0:
		wants += ["company_notice", "missing", "exorcist", "wanted_spirit"]
	elif middle < 9.0:
		wants += ["nahual_reward", "wanted_spirit", "curandero"] if side > 0 else ["curandero", "nahual_reward", "missing"]
	if side < 0 and middle > -11.0 and middle < -8.0:
		wants += ["loteria"]
	if middle > 6.0:
		wants += ["cabaret", "lucha_night", "fiesta", "loteria"]
	return wants


## A bill pasted on the `side` wall's tiles, its middle at (z, height), `size` across, rolled `roll` (radians) in the
## wall's plane, `order` its place in its stack: a sheet of paper (its image cut out by its alpha, its torn edge) a
## few millimetres proud of the tiles, each newer one over the one before (paper hides the tiles' joints, as paint
## laid on them does not).
func _billed(root: Node3D, cell: Texture2D, kind: String, side: int, z: float, height: float, size: float, roll: float,
		order: int) -> MeshInstance3D:
	var sheet := MeshInstance3D.new()
	sheet.name = kind
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	sheet.mesh = quad
	var paper := StandardMaterial3D.new()
	paper.albedo_texture = cell
	paper.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	paper.alpha_scissor_threshold = 0.5
	paper.roughness = 0.92
	sheet.material_override = paper
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# (Paper on the wall: what soot that came after lies on, the giant hand's.)
	sheet.layers = Layers.WORLD | Layers.PASTED
	sheet.set_meta("kind", "bill")
	sheet.set_meta("bill_kind", kind)
	sheet.set_meta("order", order)
	root.add_child(sheet)
	sheet.position = Vector3(side * (HALF_W - WALL - FACE - PAPER_OFF - PAPER_STEP * order), height, z)
	sheet.rotation = Vector3(0.0, -side * PI / 2.0, roll)
	return sheet


## Whether `z` on the `side` wall lies within `margin` of one of its openings.
func _by_opening_z(side: int, z: float, margin: float) -> bool:
	for name in OPENINGS:
		var o: Array = OPENINGS[name]
		if o[0] == side and z > o[1] - margin and z < o[2] + margin:
			return true
	return false


## The kind of mark each cell of the graffiti sheet holds (tools/textures/pasaje_graffiti.py's KINDS).
const GRAFFITI_KINDS := ["tag", "tag", "tag", "tag", "throwup", "throwup", "throwup", "throwup", "sigil", "sigil",
	"sigil", "calavera", "eye", "moon", "roundel", "tag"]


## The kind of piece each cell of the second sheet holds (pasaje_graffiti.py's PIECES).
const PIECE_KINDS := ["burner", "burner", "heart", "serpent", "alebrije", "lucha", "sugar_skull", "buff", "rollcall"]
## The murals along the top of the walls: [kind, wall side, its middle's z, its size].
const MURALS := [["serpent", -1, 9.4, 2.4], ["alebrije", 1, 14.4, 2.0]]


## Both graffiti sheets cut into their cells: {kind: [its cells]}.
func _paints() -> Dictionary:
	var paints := {}
	for sheet in [[GRAFFITI, GRAFFITI_GRID, GRAFFITI_KINDS], [GRAFFITI_B, 3, PIECE_KINDS]]:
		var cells := _sheet_cells(sheet[0], sheet[1])
		for i in cells.size():
			paints.get_or_add(sheet[2][i], []).append(cells[i])
	return paints


## A cell holding `kind`, the `n`th of them round.
func _paint_of(paints: Dictionary, kind: String, n: int) -> Texture2D:
	var of: Array = paints[kind]
	return of[n % of.size()]


## The free runs of the `side` wall: [z from, z to], clear of its stalls and openings, ALCOVE_LEAST long or longer.
func _alcoves(side: int) -> Array:
	var taken := []
	for name in stalls:
		var box := AABB()
		var first := true
		for mesh: MeshInstance3D in stalls[name].find_children("*", "MeshInstance3D", true, false):
			var part: AABB = global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
			box = part if first else box.merge(part)
			first = false
		if not first and signf(box.get_center().x) == side:
			taken.append([box.position.z - MARK_CLEAR, box.end.z + MARK_CLEAR])
	for name in OPENINGS:
		if OPENINGS[name][0] == side:
			taken.append([OPENINGS[name][1] - OPENING_CLEAR, OPENINGS[name][2] + OPENING_CLEAR])
	taken.sort_custom(func(p, q): return p[0] < q[0])
	var free := []
	var z := -HALF_L + 0.2
	for span in taken:
		if span[0] - z >= ALCOVE_LEAST:
			free.append([z, span[0]])
		z = maxf(z, span[1])
	if HALF_L - 0.2 - z >= ALCOVE_LEAST:
		free.append([z, HALF_L - 0.2])
	return free


## A graffito of `kind` sprayed on the `side` wall's tiles, its middle at (z, height), `size` across.
func _graffito(root: Node3D, cell: Texture2D, kind: String, side: int, z: float, height: float, size: float) -> Decal:
	var mark := Decal.new()
	mark.name = kind
	mark.set_meta("kind", kind)
	mark.texture_albedo = cell
	mark.size = Vector3(size, 0.3, size)
	mark.normal_fade = 0.6
	# (On the wall's own tiles and plaster only: not the stalls, pipes or bills in front of it.)
	mark.cull_mask = Layers.PAINTED_WALL
	# (Projected into the wall along its -Y, its image upright: its Z down the wall.)
	var into := Vector3(-side, 0.0, 0.0)
	var down := Vector3(0.0, -1.0, 0.0)
	mark.basis = Basis(into.cross(down), into, down)
	root.add_child(mark)
	mark.position = Vector3(side * (HALF_W - WALL - FACE), height, z)
	return mark


## A sign hung from its pivot at `at`, which swings it.
func _hung_sign(root: Node3D, kit: Dictionary, look: Material, board: String, at: Vector3) -> void:
	var pivot := Node3D.new()
	pivot.name = "sign_pivot"
	root.add_child(pivot, true)
	pivot.position = at
	overhead.append(SetKit.place(pivot, kit[board], look, board, Vector3.ZERO, 0.0, false))
	hanging.append(pivot)


## A steady hash in [0, 1) of `v`.
func _hash(v: float) -> float:
	return fposmod(sin(v * 12.9898) * 43758.5453, 1.0)


## Standalone: floors past each opening and each end, each closed by a dark card, so it can be walked and judged alone.
func _stubs() -> void:
	stub = Node3D.new()
	stub.name = "stub"
	add_child(stub)
	var aprons := [[Vector3(-HALF_W - STUB, -0.3, -3.0), Vector3(-HALF_W, 0.0, 1.0)],
		[Vector3(HALF_W, -0.3, -3.0), Vector3(HALF_W + STUB, 0.0, 3.9)],
		[Vector3(-HALF_W, -0.3, -HALF_L - STUB), Vector3(HALF_W, 0.0, -HALF_L)],
		[Vector3(-HALF_W, -0.3, HALF_L), Vector3(HALF_W, 0.0, HALF_L + STUB)]]
	for i in aprons.size():
		var floor_box := _box(aprons[i][0], aprons[i][1], "stub_floor_%d" % i)
		floor_box.reparent(stub)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.02, 0.02, 0.025)
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for card in [[Vector3(-HALF_W - STUB, 0.0, -1.0), Vector2(4.0, 3.0), PI / 2.0],
			[Vector3(HALF_W + STUB, 0.0, 0.45), Vector2(6.9, 4.0), -PI / 2.0],
			[Vector3(0.0, 0.0, -HALF_L - STUB), Vector2(10.0, HEIGHT), 0.0],
			[Vector3(0.0, 0.0, HALF_L + STUB), Vector2(10.0, HEIGHT), PI]]:
		var quad := MeshInstance3D.new()
		var mesh := QuadMesh.new()
		mesh.size = card[1]
		mesh.material = dark
		quad.mesh = mesh
		stub.add_child(quad)
		quad.position = card[0] + Vector3(0.0, (card[1] as Vector2).y / 2.0, 0.0)
		quad.rotation.y = card[2]


## Its own night under the vault, as the candle lane's bay has (standalone only: the Metro lights itself).
func _environment() -> void:
	var environment := RetroScript.night_environment(Color(0.36, 0.44, 0.58), 0.28)
	environment.volumetric_fog_density = 0.02
	world = WorldEnvironment.new()
	world.environment = environment
	add_child(world)


## A solid box from `lo` to `hi` (its frame), plain until the shell is dressed.
func _box(lo: Vector3, hi: Vector3, kind: String) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = kind
	var box := BoxMesh.new()
	box.size = hi - lo
	var plain := StandardMaterial3D.new()
	plain.albedo_color = Color(0.32, 0.31, 0.29)
	box.material = plain
	mesh.mesh = box
	mesh.set_meta("built", true)
	add_child(mesh)
	mesh.position = (lo + hi) / 2.0
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var solid := BoxShape3D.new()
	solid.size = hi - lo
	shape.shape = solid
	body.add_child(shape)
	mesh.add_child(body)
	return mesh
