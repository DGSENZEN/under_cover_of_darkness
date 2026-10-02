extends Node3D
## Level-owned pools of ember, smoke, steam, and spark particles, created on first emission.
## One camera-facing MultiMesh per kind uses Layers.FX; lightgem cameras exclude it.
## Simulation uses scaled frame delta so slow motion also slows particles.

const Layers := preload("res://scripts/Visual/Layers.gd")
const SMOKE := preload("res://scripts/Visual/Lights/smoke.gdshader")

const MAX := {&"ember": 400, &"smoke": 300, &"steam": 80, &"spark": 120}
## Sizes are measured on this many lines (the Retro screen's grid).
const GRID_LINES := 360.0
const EMBER_HOT := Color("FFA040")
const EMBER_COOL := Color("C83010")

static var _world: Node = null
static var _rng := RandomNumberGenerator.new()
## kind -> how many were ever emitted (the suite counts a doused fire's winks).
static var _emitted := {}

var _pools := {}


## One kind's particles: arrays side by side, `count` of them alive.
class Pool:
	var kind: StringName
	var count := 0
	var pos := PackedVector3Array()
	var vel := PackedVector3Array()
	var age := PackedFloat32Array()
	var life := PackedFloat32Array()
	var size := PackedFloat32Array()
	var start_size := PackedFloat32Array()
	var alpha := PackedFloat32Array()
	var puff := PackedInt32Array()
	var tint := PackedColorArray()
	var draw: MultiMeshInstance3D

	func _init(p_kind: StringName, capacity: int) -> void:
		kind = p_kind

		for array in [pos, vel]:
			array.resize(capacity)

		for array in [age, life, size, start_size, alpha]:
			array.resize(capacity)

		puff.resize(capacity)
		tint.resize(capacity)

	func capacity() -> int:
		return pos.size()

	func remove(i: int) -> void:
		count -= 1

		if i == count:
			return

		pos[i] = pos[count]
		vel[i] = vel[count]
		age[i] = age[count]
		life[i] = life[count]
		size[i] = size[count]
		start_size[i] = start_size[count]
		alpha[i] = alpha[count]
		puff[i] = puff[count]
		tint[i] = tint[count]


# The API

## Emits count particles of kind (ember/smoke/steam/spark) at world at, with world wind and tint.
## size is optional world size; context selects the level-owned pool. Detached contexts/unknown kinds produce no particles.
## Nonpositive count spawns none; the emitted counter still adds count when the pool exists.
static func emit(context: Node, kind: StringName, at: Vector3, count: int, wind := Vector3.ZERO, tint := Color.WHITE, size := 0.0) -> void:
	var world := _world_for(context)

	if world == null or not world._pools.has(kind):
		return

	_emitted[kind] = int(_emitted.get(kind, 0)) + count

	for i in count:
		world._spawn(world._pools[kind], at, wind, tint, size)


static func emitted(kind: StringName) -> int:
	return int(_emitted.get(kind, 0))


static func live(kind: StringName) -> int:
	if _world == null or not is_instance_valid(_world) or not _world._pools.has(kind):
		return 0

	return _world._pools[kind].count


static func clear() -> void:
	if _world == null or not is_instance_valid(_world):
		return

	for kind in _world._pools:
		_world._pools[kind].count = 0
		_world._pools[kind].draw.multimesh.visible_instance_count = 0


static func world_node() -> Node:
	return _world if _world != null and is_instance_valid(_world) and not _world.is_queued_for_deletion() else null


## The dice, set (the suite repeats a particle exactly).
static func reseed(value: int) -> void:
	_rng.seed = value


static func _world_for(context: Node) -> Node:
	if context == null or not context.is_inside_tree():
		return null

	if _world != null and is_instance_valid(_world) and not _world.is_queued_for_deletion():
		if _world.is_inside_tree() or _joining(_world):
			return _world

		# Its level went before it could join it: start again.
		_world.free()

	var tree := context.get_tree()
	var parent: Node = tree.current_scene if tree.current_scene != null else tree.root
	var world: Node3D = (load("res://scripts/Visual/Lights/FireParticles.gd") as GDScript).new()
	world.name = "FireParticles"
	world.set_meta(&"joining", parent.get_instance_id())
	_world = world
	parent.add_child.call_deferred(world)
	return world


## Whether a manager not yet in the tree still has a level to join.
static func _joining(world: Node) -> bool:
	var parent := instance_from_id(int(world.get_meta(&"joining", 0)))
	return parent is Node and not (parent as Node).is_queued_for_deletion()


# The simulation

func _init() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF

	for kind in MAX:
		var pool := Pool.new(kind, MAX[kind])
		pool.draw = _make_draw(kind, MAX[kind])
		add_child(pool.draw)
		_pools[kind] = pool


func _exit_tree() -> void:
	if _world == self:
		_world = null


func _spawn(pool: Pool, at: Vector3, wind: Vector3, tint: Color, size: float) -> void:
	if pool.count >= pool.capacity():
		return

	var i := pool.count
	pool.count += 1
	pool.pos[i] = at
	pool.age[i] = 0.0
	pool.tint[i] = tint
	pool.puff[i] = _rng.randi_range(0, 3)
	var side := Vector3(_rng.randf_range(-1.0, 1.0), 0.0, _rng.randf_range(-1.0, 1.0))

	match pool.kind:
		&"ember":
			pool.vel[i] = Vector3.UP * _rng.randf_range(0.8, 1.6) + side * 0.3 + wind * 0.3
			pool.life[i] = _rng.randf_range(0.6, 1.2)
			pool.size[i] = _rng.randf_range(1.0, 2.0)
			pool.alpha[i] = 1.0
		&"spark":
			pool.vel[i] = Vector3.UP * _rng.randf_range(1.0, 2.0) + side * _rng.randf_range(1.0, 2.0)
			pool.life[i] = 0.3
			pool.size[i] = _rng.randf_range(1.0, 2.0)
			pool.alpha[i] = 1.0
		&"smoke":
			pool.vel[i] = Vector3.UP * _rng.randf_range(0.3, 0.6) + side * 0.08 + wind * 0.5
			pool.life[i] = _rng.randf_range(2.0, 3.0)
			pool.size[i] = size if size > 0.0 else 0.25
			pool.alpha[i] = _rng.randf_range(0.2, 0.35)
		&"steam":
			pool.vel[i] = Vector3.UP * 0.8 + side * 0.2 + wind * 0.5
			pool.life[i] = 0.6
			pool.size[i] = size if size > 0.0 else 0.2
			pool.alpha[i] = 0.4

	pool.start_size[i] = pool.size[i]


func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()

	for kind in _pools:
		var pool: Pool = _pools[kind]
		_step(pool, delta)
		_render(pool, camera)


func _step(pool: Pool, delta: float) -> void:
	var i := 0

	while i < pool.count:
		pool.age[i] += delta

		if pool.age[i] >= pool.life[i]:
			pool.remove(i)
			continue

		var v := pool.vel[i]

		match pool.kind:
			&"ember":
				# Hot air lifts it a little as its drag slows it.
				v = v * exp(-1.2 * delta) + Vector3.UP * 0.8 * delta
			&"spark":
				v = v * exp(-0.8 * delta) + Vector3.DOWN * 4.0 * delta
			&"smoke", &"steam":
				v = v * exp(-0.3 * delta)
				var grown := 1.0 + 1.5 * (pool.age[i] / pool.life[i])
				pool.size[i] = pool.start_size[i] * grown

		pool.vel[i] = v
		pool.pos[i] += v * delta
		i += 1


func _render(pool: Pool, camera: Camera3D) -> void:
	var mm := pool.draw.multimesh
	mm.visible_instance_count = pool.count

	if pool.count == 0 or camera == null:
		return

	var cam := camera.global_transform
	var px := 2.0 * tan(deg_to_rad(camera.fov) * 0.5) / GRID_LINES

	for i in pool.count:
		var o := pool.pos[i]
		var to_cam := cam.origin - o
		var distance := maxf(to_cam.length(), 0.001)
		to_cam /= distance
		var t := pool.age[i] / pool.life[i]
		var basis: Basis

		if pool.kind == &"ember" or pool.kind == &"spark":
			# A streak along its motion, a pixel or two wide wherever it is.
			var v := pool.vel[i]
			var along := v - to_cam * v.dot(to_cam)
			along = along.normalized() if along.length() > 0.001 else cam.basis.y
			var width := pool.size[i] * px * distance
			var length := width + v.length() * 0.04
			var side := along.cross(to_cam).normalized()
			basis = Basis(side * width, along * length, to_cam * width)
			var hot := EMBER_HOT.lerp(EMBER_COOL, t)
			var fade := 1.0 - smoothstep(0.7, 1.0, t)
			mm.set_instance_color(i, Color(hot.r * fade, hot.g * fade, hot.b * fade, 1.0))
		else:
			var s := pool.size[i]
			basis = Basis(cam.basis.x * s, cam.basis.y * s, cam.basis.z * s)
			var shown := pool.alpha[i] * minf(t / 0.15, 1.0) * (1.0 - smoothstep(0.5, 1.0, t))
			mm.set_instance_color(i, pool.tint[i])
			mm.set_instance_custom_data(i, Color(float(pool.puff[i]), shown, (1.0 - t) if pool.kind == &"smoke" else 0.0, 0.0))

		mm.set_instance_transform(i, Transform3D(basis, o))


func _make_draw(kind: StringName, capacity: int) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = kind == &"smoke" or kind == &"steam"
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	mm.mesh = quad
	mm.instance_count = capacity
	mm.visible_instance_count = 0
	var draw := MultiMeshInstance3D.new()
	draw.name = String(kind).capitalize()
	draw.multimesh = mm
	draw.layers = Layers.FX
	draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	draw.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	# Fires are all over the level: never cull the batch on its box.
	draw.custom_aabb = AABB(Vector3(-4000, -4000, -4000), Vector3(8000, 8000, 8000))

	if kind == &"smoke" or kind == &"steam":
		var look := ShaderMaterial.new()
		look.shader = SMOKE
		look.set_shader_parameter(&"puffs", load("res://assets/vfx/smoke.png"))

		if kind == &"steam":
			look.set_shader_parameter(&"body", Color(0.85, 0.85, 0.88))

		draw.material_override = look
	else:
		var glow := StandardMaterial3D.new()
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		glow.vertex_color_use_as_albedo = true
		glow.cull_mode = BaseMaterial3D.CULL_DISABLED
		glow.disable_fog = true
		glow.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		glow.set_meta(&"retro_skip", true)
		draw.material_override = glow

	return draw
