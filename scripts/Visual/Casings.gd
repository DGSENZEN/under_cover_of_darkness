extends RefCounted
## Spent brass falling from the revolver's loading gate as it opens for a
## reload: one casing for each spent chamber, a moment apart, tinkling on
## what they land on. They lie a while and shrink away; never more than
## MAX_LIVE at once (the oldest go first).

const Sfx := preload("res://scripts/Audio/Sfx.gd")

const MAX_LIVE := 24
## Seconds a casing lies before it is gone (shrinking over the last FADE).
const LIFE := 10.0
const FADE := 0.5
## Seconds between one casing and the next.
const APART := 0.08
## A casing: 9 mm across, 30 mm long.
const RADIUS := 0.0045
const LENGTH := 0.03

static var _live: Array = []
static var _brass: StandardMaterial3D


## `count` casings from `at`, a moment apart, thrown a little along `out`.
static func drop(context: Node, at: Vector3, out: Vector3, count: int) -> void:
	if context == null or not context.is_inside_tree() or count <= 0:
		return

	var tree := context.get_tree()

	for i in count:
		if i == 0:
			_one(tree, at, out, i)
		else:
			tree.create_timer(APART * i, false, true).timeout.connect(_one.bind(tree, at, out, i))


static func live_count() -> int:
	_live = _live.filter(func(ref): return ref.get_ref() != null and is_instance_valid(ref.get_ref()) and not (ref.get_ref() as Node).is_queued_for_deletion())
	return _live.size()


static func _one(tree: SceneTree, at: Vector3, out: Vector3, i: int) -> void:
	var world: Node = tree.current_scene if tree.current_scene != null else tree.root
	var casing := RigidBody3D.new()
	casing.name = "Casing"
	casing.collision_layer = 0
	casing.collision_mask = 1
	casing.mass = 0.012
	casing.contact_monitor = true
	casing.max_contacts_reported = 1
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = RADIUS
	cylinder.height = LENGTH
	shape.shape = cylinder
	casing.add_child(shape)
	var visual := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = RADIUS
	mesh.bottom_radius = RADIUS
	mesh.height = LENGTH
	mesh.radial_segments = 8
	mesh.rings = 1
	visual.mesh = mesh
	visual.material_override = _brass_look()
	casing.add_child(visual)
	world.add_child(casing)
	# A fixed spread, so a reload falls the same each time.
	var spread := Vector3(0.05 * float(i % 3 - 1), 0.0, 0.04 * float((i + 1) % 3 - 1))
	casing.global_position = at + spread
	casing.rotation = Vector3(PI * 0.5, 0.3 * i, 0.0)
	casing.reset_physics_interpolation()
	casing.linear_velocity = out.normalized() * 0.8 + Vector3.DOWN * 0.5 + spread * 4.0
	casing.angular_velocity = Vector3(6.0, 2.0 * i, 3.0)
	casing.body_entered.connect(_tinkle.bind(casing), CONNECT_ONE_SHOT)
	_keep(casing)


static func _tinkle(_with: Node, casing: RigidBody3D) -> void:
	if is_instance_valid(casing):
		Sfx.play(casing, &"coins", casing.global_position, -14.0, 2.2)


static func _keep(casing: RigidBody3D) -> void:
	live_count()
	_live.append(weakref(casing))

	while _live.size() > MAX_LIVE:
		var oldest: Node = _live.pop_front().get_ref()

		if oldest != null and is_instance_valid(oldest):
			oldest.queue_free()

	var fade := casing.create_tween()
	fade.tween_interval(LIFE - FADE)
	fade.tween_property(casing, "scale", Vector3.ONE * 0.01, FADE)
	fade.tween_callback(casing.queue_free)


static func _brass_look() -> StandardMaterial3D:
	if _brass == null:
		_brass = StandardMaterial3D.new()
		_brass.albedo_color = Color(0.72, 0.55, 0.26)
		_brass.metallic = 0.85
		_brass.roughness = 0.35

	return _brass
