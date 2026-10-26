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


func _ready() -> void:
	_shell()
	_shell_dressing()
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
		SetKit.place(dressing, meshes["reveal_" + name], look, "reveal_" + name, Vector3.ZERO, 0.0, false)

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
	return SetKit.place(dressing, meshes[kind], look, kind, at, -side * PI / 2.0, false)


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
