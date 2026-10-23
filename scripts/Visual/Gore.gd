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
	var piece := RigidBody3D.new()
	piece.name = "Gore"
	piece.collision_layer = 0
	piece.collision_mask = 1
	piece.mass = 0.4 + 0.1 * float(i % 12)
	piece.can_sleep = true
	var size := Vector3(0.12, 0.08, 0.1) * (0.7 + 0.08 * float(i % 5))
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	piece.add_child(shape)
	var visual := MeshInstance3D.new()

	if i % 3 == 0:
		var round := SphereMesh.new()
		round.radius = size.x * 0.5
		round.height = size.x
		round.radial_segments = 8
		round.rings = 4
		visual.mesh = round
	else:
		var block := BoxMesh.new()
		block.size = size
		visual.mesh = block

	var flesh := StandardMaterial3D.new()
	flesh.albedo_color = Color(0.32, 0.04, 0.04) if i % 2 == 0 else Color(0.45, 0.12, 0.1)
	flesh.roughness = 0.45
	visual.material_override = flesh
	piece.add_child(visual)
	return piece


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
