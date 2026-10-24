extends Node3D
## Chronology's projection (docs/superpowers/specs/2026-10-17-librarian-shop-design.md: "clock hands and astrolabe
## rings turning, sand falling upward, a page that ages and un-ages"), drawn the Deadlock way on our own meshes
## (vfx_mesh.gdshader: banded colour, eroded edges, a rim): over an opened chronology study, an astrolabe of three
## rings turning each on its own axis (the outer one ticked with the hours), a clock's two hands on a hub at its
## heart, sand climbing from the pages through a waist into the rings, and a ghost leaf caught mid-turn at the
## gutter that yellows and crumbles, then grows young again, the hands running backward while it does. It stands upright in the room whatever the pages' pitch, scaled to the room above.

const MeshVfx := preload("res://scripts/Visual/MeshVfx.gd")
const Layers := preload("res://scripts/Visual/Layers.gd")

const AMBER := Color("e5ae48")
## The room it is built for above the pages (m); the astrolabe's middle (over the right-hand page, its sweep within
## the run of board kept clear for the book, clear of the leaf turning at the gutter), its rings' radii and tubes,
## its hands' lengths and widths, its outer ring's ticks (inward, as a dial's hours).
const ROOM := 0.33
const HEART := Vector3(0.0, 0.19, 0.0)
const RADII := [0.1, 0.078, 0.058]
const TUBES := [0.0062, 0.0052, 0.0044]
const HANDS := [0.045, 0.07]
const HAND_WIDTHS := [0.013, 0.0095]
const TICKS := 12
## How fast the minute hand sweeps (rad/s; the hour hand a twelfth of it); each ring's axis and pace.
const SWEEP := 1.5
const TURNS := [[Vector3.RIGHT, 0.55], [Vector3.BACK, -0.42], [Vector3(0.3, 1.0, 0.2), 0.8]]
## The sand: how many grains, how large, how long one takes to climb.
const GRAINS := 36
const GRAIN := 0.0048
const CLIMB := 2.6
## The leaf: its size, where it turns (the gutter, from the right-hand page's middle), how long it takes to age and
## grow young again.
const PAGE := Vector2(0.15, 0.2)
const GUTTER := Vector3(-0.13, 0.04, 0.0)
const AGE_CYCLE := 7.0

var kind := &"chronology"
var rings: Array[MeshInstance3D] = []
var hands: Array[MeshInstance3D] = []
var grains: MultiMeshInstance3D
var page: MeshInstance3D
## 0 the page new, 1 crumbling.
var age := 0.0
## Where each grain is (its frame in the family's), as last laid (a headless MultiMesh reads back nothing).
var sand: Array[Transform3D] = []

var _seed := 0.0
var _looks: Array[ShaderMaterial] = []
var _page_look: ShaderMaterial
var _hand_angle := 0.0
var _last_time := -1.0


func build(seed: float) -> void:
	_seed = seed
	name = "chronology"
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	visible = false

	for k in RADII.size():
		var look := _look(0.14, 0.18, k)
		var ring := _part("ring_%d" % k, _torus(RADII[k], TUBES[k]), look)
		ring.position = HEART
		rings.append(ring)
	# The hours ticked round the outer ring, turning with it.
	var ticks := _part("ticks", _ticks(RADII[0] - TUBES[0], TICKS, -0.012, 0.005), rings[0].mesh.surface_get_material(0))
	ticks.reparent(rings[0], false)

	var hand_look := _look(0.03, 0.0, 3)
	for k in HANDS.size():
		var hand := _part("hand_%d" % k, _needle(HANDS[k], HAND_WIDTHS[k]), hand_look)
		hand.position = HEART
		hands.append(hand)
	var hub := _part("hub", _torus(0.011, 0.005, 16, 6), hand_look)
	hub.position = HEART
	hub.rotation = Vector3(PI / 2.0, 0.0, 0.0)

	var grain_look := _look(0.0, 0.0, 6)
	var pool := MultiMesh.new()
	pool.transform_format = MultiMesh.TRANSFORM_3D
	pool.mesh = _grain()
	pool.mesh.surface_set_material(0, grain_look)
	pool.instance_count = GRAINS
	grains = MultiMeshInstance3D.new()
	grains.name = "sand"
	grains.multimesh = pool
	grains.layers = Layers.FX
	grains.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	grains.custom_aabb = AABB(Vector3(HEART.x - 0.07, 0.0, -0.07), Vector3(0.14, HEART.y + 0.02, 0.14))
	add_child(grains)

	_page_look = _look(0.1, 0.35, 7)
	page = _part("ghost_page", _leaf(PAGE), _page_look)


## Where it stands (the pages' top middle, the book's heading), how present (0 gone to 1), the room above it.
func set_state(presence: float, clearance: float, time: float, at: Vector3, heading: float) -> void:
	visible = presence > 0.001
	if not visible:
		return
	var fit := clampf(clearance / ROOM, 0.4, 1.0) * lerpf(0.6, 1.0, presence)
	global_transform = Transform3D(Basis(Vector3.UP, heading).scaled(Vector3.ONE * fit), at)
	var dt := 0.0 if _last_time < 0.0 else clampf(time - _last_time, 0.0, 0.1)
	_last_time = time

	for look in _looks:
		look.set_shader_parameter("opacity", presence)
		look.set_shader_parameter("erosion", lerpf(0.95, float(look.get_meta("erosion")), presence))

	# The page ages and grows young again; while it grows young the hands run backward.
	var phase := time * TAU / AGE_CYCLE + _seed
	age = 0.5 - 0.5 * cos(phase)
	var running := 1.0 if sin(phase) >= 0.0 else -1.0
	_hand_angle += running * SWEEP * dt
	hands[0].rotation = Vector3(0.0, 0.0, _hand_angle / 12.0)
	hands[1].rotation = Vector3(0.0, 0.0, _hand_angle)

	for k in rings.size():
		var turn: Array = TURNS[k]
		rings[k].quaternion = Quaternion((turn[0] as Vector3).normalized(), time * float(turn[1]) + _seed + k)

	var young := Color(0.98, 0.95, 0.86)
	var old := Color(0.42, 0.27, 0.12)
	_page_look.set_shader_parameter("core", young.lerp(AMBER, age * 0.6))
	_page_look.set_shader_parameter("body", Color(0.9, 0.82, 0.6).lerp(old, age))
	_page_look.set_shader_parameter("edge", Color(0.5, 0.36, 0.16).lerp(Color(0.08, 0.04, 0.02), age))
	_page_look.set_shader_parameter("erosion", lerpf(0.95, lerpf(0.08, 0.5, age), presence))
	# (Caught mid-turn at the gutter, falling back toward the left-hand page and rising again: never upright, so
	# never into the astrolabe's sweep.)
	page.position = GUTTER
	page.rotation = Vector3(0.0, 0.0, deg_to_rad(115.0 + 15.0 * sin(time * 0.6 + _seed)))

	sand.resize(GRAINS)
	for i in GRAINS:
		sand[i] = _grain_at(i, time)
		grains.multimesh.set_instance_transform(i, sand[i])


## One grain on its climb: from the pages, in through a waist, out into the rings, where it is spent.
func _grain_at(i: int, time: float) -> Transform3D:
	var t := fposmod(time / CLIMB + float(i) / GRAINS + _seed * 0.1, 1.0)
	var round_at := float(i) * 2.399 + _seed
	var y := t * HEART.y
	var waist := 0.006 + 0.03 * absf(t - 0.5) * 2.0 * (1.0 - t * 0.4)
	var at := Vector3(HEART.x + cos(round_at + t * 3.0) * waist, y, sin(round_at + t * 3.0) * waist)
	var size := GRAIN * sin(t * PI)
	return Transform3D(Basis(Vector3.UP, round_at + t * 6.0).scaled(Vector3.ONE * maxf(size, 0.0001)), at)


func _look(erosion: float, tail: float, k: int) -> ShaderMaterial:
	var look := MeshVfx.look(Color(1.0, 0.94, 0.76), AMBER, Color(0.3, 0.17, 0.05), 2.0, erosion, 0.4, _seed + k)
	look.set_shader_parameter("tail_eat", tail)
	look.set_shader_parameter("churn", 0.0)
	look.set_meta("erosion", erosion)
	_looks.append(look)
	return look


func _part(label: String, mesh: ArrayMesh, look: ShaderMaterial) -> MeshInstance3D:
	mesh.surface_set_material(0, look)
	var part := MeshInstance3D.new()
	part.name = label
	part.mesh = mesh
	part.layers = Layers.FX
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(part)
	return part


## A ring lying flat (round y), `radius` across its middle, `tube` thick; u round its tube, v round the ring (so
## its noise runs round it and its tail eats a gap that turns with it).
static func _torus(radius: float, tube: float, segments := 56, sides := 8) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in segments:
		for k in sides:
			var corners := []
			var uvs := []
			for c in [[i, k], [i + 1, k], [i + 1, k + 1], [i, k + 1]]:
				var a: float = TAU * c[0] / segments
				var b: float = TAU * c[1] / sides
				var middle := Vector3(cos(a), 0.0, sin(a)) * radius
				corners.append(middle + (Vector3(cos(a), 0.0, sin(a)) * cos(b) + Vector3.UP * sin(b)) * tube)
				uvs.append(Vector2(float(c[1]) / sides, float(c[0]) / segments))
			MeshVfx._quad(st, corners, uvs)
	st.generate_normals()
	return st.commit()


## The hours round a ring lying flat: `count` short diamond bars from `radius`, `length` long (inward if negative).
static func _ticks(radius: float, count: int, length: float, width: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in count:
		var a := TAU * i / count
		var out := Vector3(cos(a), 0.0, sin(a))
		var side := Vector3(-sin(a), 0.0, cos(a))
		var v := float(i) / count
		for k in 4:
			var b0 := TAU * k / 4.0
			var b1 := TAU * (k + 1) / 4.0
			var c0 := (side * cos(b0) + Vector3.UP * sin(b0)) * width * 0.5
			var c1 := (side * cos(b1) + Vector3.UP * sin(b1)) * width * 0.5
			MeshVfx._quad(st, [out * radius + c0, out * (radius + length), out * (radius + length), out * radius + c1],
				[Vector2(float(k) / 4.0, v), Vector2(float(k) / 4.0, v), Vector2(float(k + 1) / 4.0, v), Vector2(float(k + 1) / 4.0, v)])
	st.generate_normals()
	return st.commit()


## A clock hand: a diamond-sectioned needle from its pivot up +y to its tip, `width` at its broadest (a third of
## the way out), a short tail behind the pivot; v from the tail to the tip.
static func _needle(length: float, width: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stations := [[-0.18, 0.4], [0.0, 0.7], [0.33, 1.0], [1.0, 0.0]]
	for i in stations.size() - 1:
		var a: Array = stations[i]
		var b: Array = stations[i + 1]
		for k in 4:
			var corners := []
			var uvs := []
			for c in [[a, k], [b, k], [b, k + 1], [a, k + 1]]:
				var s: Array = c[0]
				var turn: float = TAU * c[1] / 4.0
				var half := width * 0.5 * float(s[1])
				corners.append(Vector3(cos(turn) * half, float(s[0]) * length, sin(turn) * half * 0.35))
				uvs.append(Vector2(float(c[1]) / 4.0, (float(s[0]) + 0.18) / 1.18))
			MeshVfx._quad(st, corners, uvs)
	st.generate_normals()
	return st.commit()


## A sand grain: a small octahedron, a unit across.
static func _grain() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring := [Vector3.RIGHT, Vector3.FORWARD, Vector3.LEFT, Vector3.BACK]
	for i in 4:
		for face in [[Vector3.UP, ring[i], ring[(i + 1) % 4]], [Vector3.DOWN, ring[(i + 1) % 4], ring[i]]]:
			for j in 3:
				st.set_uv(Vector2(float(j) / 2.0, 0.3))
				st.add_vertex(face[j])
	st.generate_normals()
	return st.commit()


## The ghost leaf: `size` (across x from its turning edge at x 0, along z), curling a little toward its free edge;
## u along it, v across it from the turning edge (so the tail eats its free edge first, as an old page crumbles).
static func _leaf(size: Vector2, rows := 8) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in rows:
		var corners := []
		var uvs := []
		for c in [[0, i], [0, i + 1], [1, i + 1], [1, i]]:
			var across := float(c[1]) / rows
			var curl := 0.018 * across * across
			corners.append(Vector3(across * size.x, curl, (float(c[0]) - 0.5) * size.y))
			uvs.append(Vector2(float(c[0]), across))
		MeshVfx._quad(st, corners, uvs)
	st.generate_normals()
	return st.commit()
