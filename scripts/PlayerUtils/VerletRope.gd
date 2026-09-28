extends "res://scripts/PlayerUtils/ClimbVolume.gd"
## A simulated rope or chain the player can climb and swing on.
##
## Hangs from this node's origin. Simulated as a chain of points with distance
## constraints (verlet), which is stable, cheap, and swings like a pendulum
## under the player's input. Rendered as a MultiMesh: cylinders for a rope,
## alternating flat links for a chain.
##
## It is also its own ClimbVolume: the detection box follows the rope.

enum Style {
	ROPE,
	CHAIN,
}

@export var style := Style.ROPE
@export var length := 6.0
@export var segments := 18
@export var thickness := 0.035

## Per-frame velocity retention. Lower swings die faster.
@export_range(0.9, 1.0, 0.001) var damping := 0.985
@export var rope_gravity := 9.8
@export_range(1, 20, 1) var constraint_iterations := 8

## How hard the climber's input pushes the rope sideways, in m/s².
@export var swing_strength := 7.0
## Extra sag pulled into the rope at the grip while someone hangs on it.
@export var climber_weight := 2.0
## The fastest the rope carries a climber, or throws him off it (m/s).
@export var max_swing_speed := 9.0

var points := PackedVector3Array()
var previous := PackedVector3Array()
var segment_length := 0.3

var _shape: CollisionShape3D
var _box: BoxShape3D
var _visual: MultiMeshInstance3D
var _material: StandardMaterial3D

var _grip_param := -1.0
## The step the last tick integrated (game seconds). A hit-stop or slow motion
## shrinks the step, not the tick rate: the swing carried into the next tick
## is scaled by the change, so the rope moves in game time.
var _last_step := 0.0
var _grip_push := Vector3.ZERO
var _buffer_now := PackedFloat32Array()
var _buffer_before := PackedFloat32Array()


func _ready() -> void:
	super._ready()
	rope = true
	segment_length = length / float(segments)

	points.resize(segments + 1)
	previous.resize(segments + 1)
	_reseed()

	_box = BoxShape3D.new()
	_shape = CollisionShape3D.new()
	_shape.shape = _box
	add_child(_shape)

	_build_visual()
	_update_collision_box()
	_update_visual()


func _physics_process(delta: float) -> void:
	# Moved (placed by a level after it was added, or teleported): hang again
	# from where it now is, instead of whipping across the level.
	if points.size() > 0 and points[0].distance_to(global_position) > 1.0:
		_reseed()

	_simulate(delta)
	_update_collision_box()
	_update_visual()


# ---------------------------------------------------------------------------
# Simulation
# ---------------------------------------------------------------------------

func _simulate(delta: float) -> void:
	if delta <= 0.0:
		return

	var gravity_step := Vector3.DOWN * rope_gravity * delta * delta
	# Damping is per tick at the normal rate; the swing carried over is last
	# tick's travel, rescaled to this tick's step.
	var hz := float(maxi(Engine.physics_ticks_per_second, 1))
	var carry := pow(damping, delta * hz) * (delta / _last_step if _last_step > 0.0 else 1.0)
	_last_step = delta

	# Point 0 is pinned to the anchor.
	points[0] = global_position
	previous[0] = global_position

	for i in range(1, segments + 1):
		var velocity := (points[i] - previous[i]) * carry
		previous[i] = points[i]
		points[i] += velocity + gravity_step

	# The climber's input and weight act on the grip point.
	if _grip_param >= 0.0:
		var index := _index_for_param(_grip_param)
		points[index] += _grip_push * delta * delta
		points[index] += Vector3.DOWN * climber_weight * delta * delta

	_grip_push = Vector3.ZERO

	for _iteration in range(constraint_iterations):
		for i in range(segments):
			var a := points[i]
			var b := points[i + 1]
			var offset := b - a
			var distance := offset.length()

			if distance < 0.00001:
				continue

			var correction := offset * ((distance - segment_length) / distance)

			if i == 0:
				points[i + 1] = b - correction
			else:
				points[i] = a + correction * 0.5
				points[i + 1] = b - correction * 0.5


# ---------------------------------------------------------------------------
# Climber interface
# ---------------------------------------------------------------------------

## Distance along the rope from the anchor to the point nearest `position`.
func closest_param(position: Vector3) -> float:
	var best := 0.0
	var best_distance := INF

	for i in range(segments + 1):
		var d := points[i].distance_squared_to(position)

		if d < best_distance:
			best_distance = d
			best = segment_length * i

	return best


## World position of the rope at `param` metres from the anchor.
func rope_point(param: float) -> Vector3:
	var clamped := clampf(param, 0.0, length)
	var scaled := clamped / segment_length
	var index := mini(int(floor(scaled)), segments - 1)
	var t := scaled - float(index)
	return points[index].lerp(points[index + 1], t)


## Velocity of the rope at `param`, per second of game time: the last tick's
## travel over the step it integrated (`_delta` is not it during a hit-stop
## that began or ended between the two), never faster than max_swing_speed.
func rope_velocity(param: float, _delta: float) -> Vector3:
	var index := _index_for_param(param)

	if _last_step <= 0.0:
		return Vector3.ZERO

	return ((points[index] - previous[index]) / _last_step).limit_length(max_swing_speed)


## Hold on at `param`. Call every frame while attached; pass the climber's
## desired swing acceleration in world space.
func grip(param: float, push: Vector3) -> void:
	_grip_param = param
	_grip_push = push


func release() -> void:
	_grip_param = -1.0
	_grip_push = Vector3.ZERO


## Direction from the rope toward `from`, at the rope point nearest it.
func get_rope_normal(from: Vector3) -> Vector3:
	var nearest := rope_point(closest_param(from))
	var n := from - nearest
	n.y = 0.0

	if n.length_squared() < 0.0001:
		return Vector3.BACK

	return n.normalized()


func _index_for_param(param: float) -> int:
	return clampi(int(round(param / segment_length)), 1, segments)


# ---------------------------------------------------------------------------
# Detection box and rendering
# ---------------------------------------------------------------------------

func _update_collision_box() -> void:
	var low := points[0]
	var high := points[0]

	for i in range(1, segments + 1):
		low = low.min(points[i])
		high = high.max(points[i])

	var margin := Vector3(0.6, 0.2, 0.6)
	_box.size = (high - low) + margin * 2.0
	_shape.global_position = (low + high) * 0.5
	_shape.global_basis = Basis.IDENTITY


## Hang straight down from the anchor, at rest.
func _reseed() -> void:
	for i in range(segments + 1):
		points[i] = global_position - Vector3.UP * segment_length * i
		previous[i] = points[i]

	_last_step = 0.0
	_buffer_before = PackedFloat32Array()


func _build_visual() -> void:
	_visual = MultiMeshInstance3D.new()
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D

	_material = StandardMaterial3D.new()
	_material.roughness = 0.85

	if style == Style.CHAIN:
		var link := BoxMesh.new()
		link.size = Vector3(thickness * 3.5, segment_length * 1.08, thickness * 1.3)
		multimesh.mesh = link
		_material.albedo_color = Color(0.45, 0.45, 0.5)
		_material.metallic = 0.7
		_material.roughness = 0.45
	else:
		var strand := CylinderMesh.new()
		strand.top_radius = thickness
		strand.bottom_radius = thickness
		strand.height = segment_length * 1.05
		strand.radial_segments = 8
		multimesh.mesh = strand
		_material.albedo_color = Color(0.72, 0.6, 0.4)

	multimesh.mesh.material = _material
	multimesh.instance_count = segments
	_visual.multimesh = multimesh
	_visual.top_level = true
	add_child(_visual)


func _update_visual() -> void:
	var multimesh := _visual.multimesh

	if _buffer_now.size() != segments * 12:
		_buffer_now.resize(segments * 12)

	for i in range(segments):
		var a := points[i]
		var b := points[i + 1]
		var axis := b - a

		if axis.length_squared() < 0.000001:
			axis = Vector3.DOWN * segment_length

		var y := axis.normalized()
		var reference := Vector3.RIGHT if absf(y.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
		var x := y.cross(reference).normalized()
		var z := x.cross(y).normalized()
		var basis := Basis(x, y, z)

		# Chain links alternate their orientation around the strand.
		if style == Style.CHAIN and i % 2 == 1:
			basis = basis * Basis(Vector3.UP, PI * 0.5)

		var middle := (a + b) * 0.5
		var k := i * 12
		_buffer_now[k] = basis.x.x
		_buffer_now[k + 1] = basis.y.x
		_buffer_now[k + 2] = basis.z.x
		_buffer_now[k + 3] = middle.x
		_buffer_now[k + 4] = basis.x.y
		_buffer_now[k + 5] = basis.y.y
		_buffer_now[k + 6] = basis.z.y
		_buffer_now[k + 7] = middle.y
		_buffer_now[k + 8] = basis.x.z
		_buffer_now[k + 9] = basis.y.z
		_buffer_now[k + 10] = basis.z.z
		_buffer_now[k + 11] = middle.z

	# The rope moves on physics ticks. With physics interpolation on, hand the
	# renderer this tick's shape and the last one, and it draws the swing
	# smoothly in between.
	var interpolating := is_inside_tree() and get_tree().physics_interpolation

	if interpolating and _buffer_before.size() == _buffer_now.size():
		multimesh.set_buffer_interpolated(_buffer_now, _buffer_before)
	else:
		multimesh.buffer = _buffer_now

	_buffer_before = _buffer_now.duplicate()
