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


func _ready() -> void:
	_shell()
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
