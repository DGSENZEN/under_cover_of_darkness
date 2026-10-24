extends RefCounted
## A body burst (Guard._gib): pieces of it flung out, blood thrown about and
## stained over the floor and walls round it. Stand-ins made in house (dark
## red blocks and rounds) until the gore pieces are modelled with the user.
## The pieces settle, sleep, and are gone in time; there are never more than
## MAX_LIVE at once (the oldest go first).

const Fx := preload("res://scripts/Visual/Fx.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")

const MAX_LIVE := 60
## Seconds a piece lies before it shrinks away (the last FADE of them).
const LIFE := 20.0
const FADE := 1.0
## How far round the burst blood is stained (metres), and how many stains.
const STAIN_REACH := 3.0
const STAINS := 6
## Where pieces fly, in turn: a fixed spread about the push, so a burst is
## the same each time.
const SPREAD := [
	Vector3(0.0, 0.6, 0.0), Vector3(0.7, 0.4, 0.2), Vector3(-0.7, 0.4, 0.2), Vector3(0.4, 0.9, -0.3),
	Vector3(-0.4, 0.9, -0.3), Vector3(0.9, 0.1, -0.5), Vector3(-0.9, 0.1, -0.5), Vector3(0.2, 0.3, 0.8),
	Vector3(-0.2, 0.3, 0.8), Vector3(0.0, 1.0, 0.4), Vector3(0.6, 0.7, 0.6), Vector3(-0.6, 0.7, 0.6),
]
## Where blood is stained, as directions from the burst (down and round).
const STAIN_WAYS := [
	Vector3(0, -1, 0), Vector3(0.6, -0.8, 0), Vector3(-0.6, -0.8, 0),
	Vector3(0, -0.8, 0.6), Vector3(0, -0.8, -0.6), Vector3(0.7, -0.3, 0.7),
]

static var _live: Array = []
## The pieces a burst throws (meshes), and their look. Empty, they are made
## (stand-ins: lumps of flesh, wet); the user's modelled pieces replace them
## by setting this list, with no other change.
static var piece_meshes: Array[Mesh] = []
static var piece_material: Material = null
## How many stand-in lumps there are.
const LUMPS := 5


## Bursts `pieces` pieces from `at`, flung along `push` and the spread, with
## blood thrown and stained round about. Returns the pieces.
static func burst(context: Node, at: Vector3, push: Vector3, pieces := 10) -> Array[RigidBody3D]:
	var made: Array[RigidBody3D] = []

	if context == null or not context.is_inside_tree():
		return made

	var world: Node = context.get_tree().current_scene if context.get_tree().current_scene != null else context.get_tree().root

	for i in pieces:
		var piece := _piece(i)
		world.add_child(piece)
		var way: Vector3 = SPREAD[i % SPREAD.size()]
		piece.global_position = at + way * 0.2
		piece.reset_physics_interpolation()
		piece.linear_velocity = push * 0.6 + way * 3.5
		piece.angular_velocity = way.cross(Vector3.UP) * 8.0 + Vector3(0.0, 2.0, 0.0)
		_keep(piece, context.get_tree())
		made.append(piece)

	Fx.blood(context, at, push.normalized() if push.length() > 0.01 else Vector3.UP, 2.5)
	Sfx.play(context, &"flesh_heavy", at, 2.0, 0.8)
	Sfx.play(context, &"bone_crack", at, 0.0, 0.9)
	_stain_round(context, at)
	return made


static func live_count() -> int:
	_live = _live.filter(func(ref): return ref.get_ref() != null and is_instance_valid(ref.get_ref()) and not (ref.get_ref() as Node).is_queued_for_deletion())
	return _live.size()


static func clear() -> void:
	for ref in _live:
		var piece: Node = ref.get_ref()

		if piece != null and is_instance_valid(piece):
			piece.queue_free()

	_live.clear()


static func _piece(i: int) -> RigidBody3D:
	if piece_meshes.is_empty():
		piece_meshes = _lumps()

	if piece_material == null:
		piece_material = _wet()

	var mesh: Mesh = piece_meshes[i % piece_meshes.size()]
	var piece := RigidBody3D.new()
	piece.name = "Gore"
	piece.collision_layer = 0
	piece.collision_mask = 1
	piece.mass = 0.4 + 0.1 * float(i % 12)
	piece.can_sleep = true
	var shape := CollisionShape3D.new()
	var ball := SphereShape3D.new()
	ball.radius = maxf(mesh.get_aabb().size.length() * 0.3, 0.02)
	shape.shape = ball
	piece.add_child(shape)
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = piece_material
	piece.add_child(visual)
	return piece


## The stand-in pieces: LUMPS lumps of flesh, each a ball pushed out by a
## fixed noise and squashed its own way, 6 to 12 cm.
static func _lumps() -> Array[Mesh]:
	var made: Array[Mesh] = []
	var noise := FastNoiseLite.new()
	noise.seed = 23
	noise.frequency = 9.0

	for k in LUMPS:
		var ball := SphereMesh.new()
		ball.radius = 0.5
		ball.height = 1.0
		ball.radial_segments = 12
		ball.rings = 8
		var arrays := ball.get_mesh_arrays()
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var size := 0.06 + 0.015 * float(k)
		var squash := Vector3(1.0 + 0.3 * float(k % 2), 0.7 + 0.15 * float(k % 3), 1.0 - 0.1 * float(k % 2))

		for v in points.size():
			var p := points[v]
			var push := 1.0 + 0.35 * noise.get_noise_3d(p.x + float(k), p.y, p.z)
			points[v] = p * push * squash * size

		arrays[Mesh.ARRAY_VERTEX] = points
		arrays[Mesh.ARRAY_NORMAL] = null
		arrays[Mesh.ARRAY_TANGENT] = null
		var st := SurfaceTool.new()
		st.create_from_arrays(arrays)
		st.generate_normals()
		made.append(st.commit())

	return made


## Wet: dark red, glossy, a rim where it turns away.
static func _wet() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("#4A0A08")
	m.roughness = 0.18
	m.metallic_specular = 0.7
	m.rim_enabled = true
	m.rim = 0.4
	return m


## Counted, the oldest let go past MAX_LIVE, and gone after LIFE (its own
## tween: it goes with the piece if the piece goes first).
static func _keep(piece: RigidBody3D, _tree: SceneTree) -> void:
	live_count()
	_live.append(weakref(piece))

	while _live.size() > MAX_LIVE:
		var oldest: Node = _live.pop_front().get_ref()

		if oldest != null and is_instance_valid(oldest):
			oldest.queue_free()

	var fade := piece.create_tween()
	fade.tween_interval(LIFE - FADE)
	fade.tween_property(piece, "scale", Vector3.ONE * 0.01, FADE)
	fade.tween_callback(piece.queue_free)


## Blood on what is round the burst: floor and walls within STAIN_REACH.
static func _stain_round(context: Node, at: Vector3) -> void:
	var space := (context as Node3D).get_world_3d().direct_space_state if context is Node3D else null

	if space == null:
		return

	for way in STAIN_WAYS:
		var query := PhysicsRayQueryParameters3D.create(at, at + (way as Vector3).normalized() * STAIN_REACH, 1)
		var hit := space.intersect_ray(query)

		if not hit.is_empty():
			Fx.stain(context, hit["position"], hit.get("normal", Vector3.UP), 0.5, "blood")
