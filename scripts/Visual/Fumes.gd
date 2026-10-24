class_name Fumes
extends Node3D
## Breath out of a mouth (a wall vent, a steamer's lid, a censer's resin, a brazier's coals), drawn on
## meshes the Deadlock way (docs/superpowers/refs/underground/vfx_method.md, vfx_fume.gdshader): a few
## plume tubes leaving the mouth and climbing, and puffs (lumpy balls the particles carry) breathed out
## among them that swell and eat themselves away. Built in the world's axes, out of the mouth along its
## effect node's up, whatever that node is turned to: a mouth facing up (a lid, a bowl) stands its
## plumes round a ring; one in a wall lines them along it. It leans on the draught (`draught`, m/s,
## set by Vfx.blow).

const SHADER := preload("res://scripts/Visual/vfx_fume.gdshader")
const Layers := preload("res://scripts/Visual/Layers.gd")
## How fast what it breathes drifts at most (m/s), the wind on it or not: uncapped, the oldest puffs
## sped off on a gust and the column broke into a string of balls.
const DRIFT_CAP := 1.2

## How wide the mouth is (m), how far its plumes climb (m), how many.
@export var width := 0.5
@export var rise := 1.2
@export var plumes := 4
## A plume's radius at its root and at its crown, as shares of the mouth's width.
@export var root := 0.1
@export var crown := 0.34
## Their colours: where the lamps catch them, in their shadow, the warmth at their foot; how much
## light of their own they carry (so steam reads pale under warm lamps and in shadow alike).
@export var lit := Color(0.86, 0.8, 0.72)
@export var shade := Color(0.42, 0.44, 0.52)
@export var warm := Color(0.9, 0.5, 0.25)
@export var warmth := 0.1
@export var glow := 0.12
@export var opacity := 0.45
## Puffs breathed out a second, their life (s), their size (a share of the mouth's width), how fast
## they leave it (m/s).
@export var puffs := 5.0
@export var puff_life := 2.6
@export var puff_size := 0.36
@export var puff_speed := 0.32
## How hard its plumes churn and wave (m at the mouth's width of 0.5).
@export var churn := 0.03
## Its puffs moved by the god's breath (Breath.gd's attractor, on their own layer).
@export var breathed := false
@export var seed := 0
## The air on it (m/s, world).
var draught := Vector3.ZERO:
	set(value):
		draught = value
		_blow()

var looks: Array[ShaderMaterial] = []
var tubes: Array[MeshInstance3D] = []
var puffer: GPUParticles3D
var _out := Vector3.FORWARD
var _built := false


func _process(_delta: float) -> void:
	# (Its effect node may be turned after it is placed: built on its first frame, in the world's axes.)
	if not _built:
		build()
	set_process(false)


## Builds its plumes and puffs out along its parent's up (the effect node's way out of the mouth).
func build() -> void:
	if _built:
		return
	_built = true
	var parent := get_parent() as Node3D
	_out = (parent.global_basis.y if parent != null and parent.is_inside_tree() else Vector3.UP).normalized()

	if is_inside_tree():
		global_basis = Basis()

	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var upward := absf(_out.dot(Vector3.UP)) > 0.9
	var across := Vector3.RIGHT if upward else _out.cross(Vector3.UP).normalized()

	for i in plumes:
		var path := PackedVector3Array()
		var off: Vector3
		var lean: Vector3

		if upward:
			# Round a ring, each leaning out a little as it climbs.
			var a := TAU * (float(i) + rng.randf_range(-0.2, 0.2)) / plumes
			var way := Vector3(cos(a), 0.0, sin(a))
			off = way * width * 0.35 if plumes > 1 else Vector3.ZERO
			lean = way * rise * rng.randf_range(0.06, 0.16)
		else:
			off = across * lerpf(-0.4, 0.4, (float(i) + 0.5) / plumes) * width + Vector3.UP * rng.randf_range(-0.08, 0.08)
			lean = across * rng.randf_range(-0.12, 0.12)

		var leave := rng.randf_range(0.12, 0.22) * (0.0 if upward else 1.0)
		var tall := rise * rng.randf_range(0.8, 1.0)

		for k in 16:
			var t := float(k) / 15.0
			# Out of the mouth and turning up as it rises, curling back toward the wall it climbs.
			var out_by := leave * (1.0 - pow(1.0 - minf(t * 2.5, 1.0), 2.0)) - (0.0 if upward else 0.05 * t)
			path.append(off + _out * out_by + Vector3.UP * tall * pow(t, 1.15) + lean * t * t)

		var tube := MeshInstance3D.new()
		tube.name = "plume_%d" % i
		tube.mesh = MeshVfx.plume(path, width * root, width * crown * rng.randf_range(0.85, 1.15), 12)
		# (On its mesh's own slot: the lab's form light passes over what an effect shader draws there.)
		tube.mesh.surface_set_material(0, _look(false, rng.randf() * 10.0))
		tube.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(tube)
		tubes.append(tube)

	if puffs > 0.0:
		_puffs(across, upward, rng)

	for visual: VisualInstance3D in find_children("*", "VisualInstance3D", true, false):
		Layers.effect(visual)

	for draw: GeometryInstance3D in find_children("*", "GeometryInstance3D", true, false):
		draw.visibility_range_end = Vfx.FADE_FROM
		draw.visibility_range_end_margin = Vfx.FADE_OVER
		draw.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF

	_blow()


## Starts or stops it.
func emit(on: bool) -> void:
	visible = on

	if puffer != null:
		puffer.emitting = on


func _puffs(across: Vector3, upward: bool, rng: RandomNumberGenerator) -> void:
	puffer = GPUParticles3D.new()
	puffer.name = "puffs"
	puffer.amount = maxi(int(puffs * puff_life), 1)
	puffer.lifetime = puff_life
	puffer.fixed_fps = 30
	puffer.interpolate = true
	puffer.local_coords = false
	puffer.visibility_aabb = AABB(Vector3(-2, -1, -2), Vector3(4, rise + 3.0, 4))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	var spread_out := Vector3(width * 0.35, 0.01, width * 0.35) if upward else across.abs() * width * 0.45 + Vector3.UP * 0.12
	process.emission_box_extents = spread_out.max(Vector3.ONE * 0.01)
	process.emission_shape_offset = _out * minf(width * 0.1, 0.05)
	process.direction = _out
	process.spread = 25.0
	process.initial_velocity_min = puff_speed * 0.75
	process.initial_velocity_max = puff_speed * 1.25
	process.gravity = Vector3(0, 0.35, 0)
	process.damping_min = 0.25
	process.damping_max = 0.4
	process.angle_min = -180.0
	process.angle_max = 180.0
	process.angular_velocity_min = -25.0
	process.angular_velocity_max = 25.0
	process.scale_min = 0.8
	process.scale_max = 1.2
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.35))
	grow.add_point(Vector2(0.3, 0.8))
	grow.add_point(Vector2(1.0, 1.6))
	var grow_tex := CurveTexture.new()
	grow_tex.curve = grow
	process.scale_curve = grow_tex
	var cap := Curve.new()
	cap.max_value = DRIFT_CAP
	cap.add_point(Vector2(0.0, DRIFT_CAP))
	cap.add_point(Vector2(1.0, DRIFT_CAP))
	var cap_tex := CurveTexture.new()
	cap_tex.curve = cap
	process.velocity_limit_curve = cap_tex
	process.set_meta("gravity", process.gravity)
	process.attractor_interaction_enabled = breathed
	puffer.process_material = process

	if breathed:
		puffer.layers = Layers.BREATHED
	var ball := SphereMesh.new()
	ball.radius = width * puff_size
	ball.height = width * puff_size * 1.75
	ball.radial_segments = 14
	ball.rings = 8
	ball.material = _look(true, rng.randf() * 10.0)
	puffer.draw_pass_1 = ball
	puffer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(puffer)
	puffer.emitting = visible


func _look(is_puff: bool, look_seed: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter(&"noise", MeshVfx.noise())
	m.set_shader_parameter(&"noise_3d", Vfx.noise_3d())
	m.set_shader_parameter(&"lit", lit)
	m.set_shader_parameter(&"shade", shade)
	m.set_shader_parameter(&"warm", warm)
	m.set_shader_parameter(&"glow", glow)
	m.set_shader_parameter(&"opacity", opacity * (1.0 if is_puff else 0.85))
	m.set_shader_parameter(&"puff", 1.0 if is_puff else 0.0)
	m.set_shader_parameter(&"seed", look_seed)
	m.set_shader_parameter(&"erosion", 0.3 if is_puff else 0.36)
	m.set_shader_parameter(&"tail_eat", 0.55 if is_puff else 0.35)
	m.set_shader_parameter(&"warmth", warmth * (0.5 if is_puff else 1.0))
	# (Its churn and its noise's tiling in metres, whatever its size: a thin thread waves less.)
	m.set_shader_parameter(&"churn", churn * width / 0.5)
	m.set_shader_parameter(&"tiling", Vector2(1.2, 1.5 * rise / 1.2))
	looks.append(m)
	return m


func _blow() -> void:
	if not _built:
		return

	for m in looks:
		if m.get_shader_parameter(&"puff") < 0.5:
			m.set_shader_parameter(&"sway", draught * 0.6)

	var process := puffer.process_material as ParticleProcessMaterial if puffer != null else null

	if process != null and process.has_meta("gravity"):
		process.gravity = process.get_meta("gravity") + Vector3(draught.x, 0.0, draught.z) * 0.5
