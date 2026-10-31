class_name TeslaArc
extends Node3D
## A tesla arc (docs/superpowers/specs/2026-10-31-station-machinery-design.md): a jagged ribbon of light that crackles
## step by step, flickering a light round it and throwing sparks. Two ways: a leap between two terminals (its points'
## first and last), or a ride along a cable run (all its points), a lit stretch travelling along it. Its shape is a
## function of its seed and game time alone (shape_at), so two runs of a scene crackle alike. Silent (no sound until
## the user's own recordings). Rebuilt between physics ticks, so drawn uninterpolated.

const SHADER := preload("res://scripts/Visual/tesla_arc.gdshader")

## Its points (local): two for a leap, the run's for a ride.
@export var points := PackedVector3Array()
@export var ride := false
@export var colour := Color("#5AB4FF")
## Its ribbon's half-width, its jags' reach (m).
@export var width := 0.05
@export var jag := 0.12
## Steps a second (each a new shape and flash).
@export var steps_per_second := 18.0
## A ride's lit stretch as a share of its run, and how fast it travels (m/s).
@export var reach := 0.6
@export var speed := 3.0
@export var light_energy := 1.5
@export var light_range := 6.0
@export var seed := 0

## How many times a leap's line is halved, each halving's jag, and how often a branch forks off.
const DEPTH := 5
const FALL := 0.5
const BRANCH := 0.35
## A ride's points every this many metres along its lit stretch.
const RIDE_STEP := 0.25
## The flash a step: its least and most, how it decays within the step.
const FLASH := Vector2(0.45, 1.2)
const DECAY := 0.55

var mesh_instance: MeshInstance3D
var light: OmniLight3D
var sparks: GPUParticles3D
var _time := 0.0
var _step := -1
var _mesh: ImmediateMesh
var _look: ShaderMaterial


func _ready() -> void:
	_mesh = ImmediateMesh.new()
	_look = ShaderMaterial.new()
	_look.shader = SHADER
	_look.set_shader_parameter("colour", colour)
	_look.set_shader_parameter("width", width)
	mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "ribbon"
	mesh_instance.mesh = _mesh
	mesh_instance.material_override = _look
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(mesh_instance)
	light = OmniLight3D.new()
	light.name = "light"
	light.light_color = colour
	light.omni_range = light_range
	light.shadow_enabled = false
	light.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(light)
	sparks = _sparks()
	add_child(sparks)
	_apply()


func _process(delta: float) -> void:
	_time += delta
	_apply()


## Its main path at game time `t` (local), deterministic in its seed and the step `t` falls in.
func shape_at(t: float) -> PackedVector3Array:
	if points.size() < 2:
		return points
	var rng := _rng(int(floor(t * steps_per_second)))
	if ride:
		return _ride_shape(t, rng)
	return _leap(points[0], points[points.size() - 1], rng)


## Where it burns brightest at game time `t` (local): a leap's middle, a ride's lit stretch's middle.
func centre_at(t: float) -> Vector3:
	if points.size() < 2:
		return Vector3.ZERO
	if not ride:
		return (points[0] + points[points.size() - 1]) / 2.0
	var span := _span(t)
	return _at((span.x + span.y) / 2.0)


func _apply() -> void:
	var step := int(floor(_time * steps_per_second))
	var into := _time * steps_per_second - step
	var rng := _rng(step)
	var flash := rng.randf_range(FLASH.x, FLASH.y) * (1.0 - DECAY * into)
	light.light_energy = light_energy * flash
	_look.set_shader_parameter("flash", flash)
	light.position = centre_at(_time)
	sparks.position = light.position
	if step == _step:
		return
	_step = step
	var main := shape_at(_time)
	_mesh.clear_surfaces()
	_ribbon(main)
	var branch := _branch(main, _rng(step + 7919))
	if branch.size() > 1:
		_ribbon(branch)


func _ribbon(path: PackedVector3Array) -> void:
	if path.size() < 2:
		return
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for k in path.size():
		var ahead := path[mini(k + 1, path.size() - 1)] - path[maxi(k - 1, 0)]
		for edge in [-1.0, 1.0]:
			_mesh.surface_set_normal(ahead.normalized())
			_mesh.surface_set_uv(Vector2(edge, float(k) / (path.size() - 1)))
			_mesh.surface_add_vertex(path[k])
	_mesh.surface_end()


func _leap(a: Vector3, b: Vector3, rng: RandomNumberGenerator) -> PackedVector3Array:
	var path: Array[Vector3] = [a, b]
	var reach_now := jag * (1.0 - FALL) / (1.0 - pow(FALL, DEPTH)) * 1.4
	var across := _across(b - a)
	for level in DEPTH:
		var next: Array[Vector3] = []
		for k in path.size() - 1:
			next.append(path[k])
			var offset := across[0] * rng.randf_range(-1.0, 1.0) + across[1] * rng.randf_range(-1.0, 1.0)
			next.append((path[k] + path[k + 1]) / 2.0 + offset.limit_length(1.0) * reach_now)
		next.append(path[path.size() - 1])
		path = next
		reach_now *= FALL
	# (Never further than its reach from the line, however the halvings added up.)
	var out := PackedVector3Array()
	for p in path:
		var on := Geometry3D.get_closest_point_to_segment(p, a, b)
		out.append(on + (p - on).limit_length(jag * 1.4))
	return out


func _ride_shape(t: float, rng: RandomNumberGenerator) -> PackedVector3Array:
	var span := _span(t)
	var out := PackedVector3Array()
	var d := span.x
	while d < span.y:
		var on := _at(d)
		var across := _across(_at(minf(d + 0.05, _length())) - _at(maxf(d - 0.05, 0.0)))
		var offset := across[0] * rng.randf_range(-1.0, 1.0) + across[1] * rng.randf_range(-1.0, 1.0)
		out.append(on + offset.limit_length(1.0) * jag * 1.4)
		d += RIDE_STEP
	out.append(_at(span.y))
	return out


func _branch(main: PackedVector3Array, rng: RandomNumberGenerator) -> PackedVector3Array:
	if main.size() < 6 or rng.randf() > BRANCH:
		return PackedVector3Array()
	var from := main[rng.randi_range(2, main.size() - 3)]
	var across := _across(main[main.size() - 1] - main[0])
	var tip := from + (across[0] * rng.randf_range(-1.0, 1.0) + across[1] * rng.randf_range(-1.0, 1.0)).normalized() \
		* jag * 2.5
	return _leap(from, tip, rng)


## A ride's lit stretch at game time `t`: from, to (m along its run), travelling and wrapping round.
func _span(t: float) -> Vector2:
	var total := _length()
	var lit := total * reach
	var head := fposmod(t * speed + float(seed) * 1.7, total + lit)
	return Vector2(clampf(head - lit, 0.0, total), clampf(head, 0.0, total)) if head > 0.05 else Vector2(0.0, 0.05)


func _length() -> float:
	var total := 0.0
	for k in points.size() - 1:
		total += points[k].distance_to(points[k + 1])
	return total


func _at(d: float) -> Vector3:
	for k in points.size() - 1:
		var leg := points[k].distance_to(points[k + 1])
		if d <= leg or k == points.size() - 2:
			return points[k].lerp(points[k + 1], clampf(d / maxf(leg, 1e-6), 0.0, 1.0))
		d -= leg
	return points[points.size() - 1]


## Two directions square to `along` and to each other.
func _across(along: Vector3) -> Array[Vector3]:
	var a := along.normalized()
	var up := Vector3.UP if absf(a.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
	var one := a.cross(up).normalized()
	return [one, a.cross(one).normalized()]


func _rng(step: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(seed, step))
	return rng


func _sparks() -> GPUParticles3D:
	var out := GPUParticles3D.new()
	out.name = "sparks"
	out.amount = 12
	out.lifetime = 0.45
	out.explosiveness = 0.1
	out.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var move := ParticleProcessMaterial.new()
	move.direction = Vector3(0.0, -1.0, 0.0)
	move.spread = 70.0
	move.initial_velocity_min = 0.6
	move.initial_velocity_max = 1.8
	move.gravity = Vector3(0.0, -6.0, 0.0)
	move.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	move.emission_sphere_radius = 0.15
	move.scale_min = 0.5
	move.scale_max = 1.0
	out.process_material = move
	var dot := QuadMesh.new()
	dot.size = Vector2(0.03, 0.03)
	var look := StandardMaterial3D.new()
	look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	look.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	look.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	look.disable_fog = true
	look.albedo_color = colour.lightened(0.5)
	look.emission_enabled = true
	look.emission = colour
	dot.material = look
	out.draw_pass_1 = dot
	return out
