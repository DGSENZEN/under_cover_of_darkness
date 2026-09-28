extends Node3D
## The night's creatures, for life at the edges of the picture: bats flitting
## round a height (a spire, a tower's top), their wings beating (our painted
## frames: bat.gdshader), jinking as bats do; fireflies low over grass,
## blinking. (Moths are Atmosphere's, at the lamp posts.) All of them go to ground in rain or a hard wind
## (the Night's), and come out again after.
##
##   var life := Wildlife.new(); add_child(life)
##   life.bats(Vector3(9, 17, -21), 5, 5.0)
##   life.fireflies(AABB(...), 30)

const BAT_SHADER := preload("res://scripts/Visual/bat.gdshader")
const BAT_FRAMES := "res://textures/painted/bat.png"
const GLOW := "res://assets/vfx/corona.png"

## Out while the rain is under this and the wind under this (m/s).
const CALM_RAIN := 0.2
const CALM_WIND := 6.5
## A bat: its size (m: larger than life, so the retro screen's big pixels
## keep it), its speed round its height (rad/s), how far it jinks.
const BAT_SIZE := Vector2(0.8, 0.4)
const BAT_TURN := Vector2(0.5, 0.9)
const BAT_JINK := 0.6

var _bats: Array = []
var _clock := 0.0
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	name = "Wildlife"
	_rng.seed = 1666


## `count` bats round `centre`, `radius` out, flying their loops.
func bats(centre: Vector3, count: int, radius: float) -> void:
	var material := ShaderMaterial.new()
	material.shader = BAT_SHADER
	material.set_shader_parameter(&"frames", load(BAT_FRAMES) if ResourceLoader.exists(BAT_FRAMES) else null)
	var quad := QuadMesh.new()
	quad.size = BAT_SIZE

	for i in count:
		var bat := MeshInstance3D.new()
		bat.name = "Bat%d" % _bats.size()
		bat.mesh = quad
		bat.material_override = material
		bat.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# (Turned to the eye in its shader: culled by a box, not its flat quad,
		# or seen from the side it is dropped.)
		bat.custom_aabb = AABB(-Vector3.ONE * 0.5, Vector3.ONE)
		bat.set_instance_shader_parameter(&"phase", _rng.randf())
		bat.add_to_group(&"bats")
		add_child(bat)
		_bats.append({"node": bat, "centre": centre, "radius": radius * _rng.randf_range(0.6, 1.1), "turn": _rng.randf_range(BAT_TURN.x, BAT_TURN.y) * (1.0 if _rng.randf() < 0.5 else -1.0),
			"phase": _rng.randf() * TAU, "rise": _rng.randf_range(-1.5, 2.5)})

	_fly(0.0)


## Fireflies low over the grass in `box`, blinking green-gold.
func fireflies(box: AABB, count: int) -> GPUParticles3D:
	var flies := GPUParticles3D.new()
	flies.name = "Fireflies%d" % get_tree_group_size(&"fireflies")
	flies.amount = count
	flies.lifetime = 6.0
	flies.preprocess = 6.0
	flies.visibility_aabb = AABB(-box.size * 0.5 - Vector3.ONE, box.size + Vector3.ONE * 2.0)
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = box.size * 0.5
	process.gravity = Vector3.ZERO
	process.spread = 180.0
	process.initial_velocity_min = 0.05
	process.initial_velocity_max = 0.2
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 1.2
	process.turbulence_noise_scale = 3.0
	# A blink or two in a life: dark, bright, dark.
	var blink := Curve.new()

	for point in [Vector2(0.0, 0.0), Vector2(0.2, 0.0), Vector2(0.28, 1.0), Vector2(0.36, 0.0), Vector2(0.62, 0.0), Vector2(0.7, 0.9), Vector2(0.78, 0.0), Vector2(1.0, 0.0)]:
		blink.add_point(point)

	var scale := CurveTexture.new()
	scale.curve = blink
	process.scale_curve = scale
	flies.process_material = process
	flies.draw_pass_1 = _speck(0.16, Color(0.8, 1.0, 0.4), true)
	flies.add_to_group(&"fireflies")
	add_child(flies)
	flies.global_position = box.get_center()
	return flies


func get_tree_group_size(group: StringName) -> int:
	return get_tree().get_nodes_in_group(group).size() if is_inside_tree() else 0


func _process(delta: float) -> void:
	_clock += delta
	var night := get_tree().get_first_node_in_group(&"night")
	var out := true

	if night != null and night.has_method(&"rain"):
		out = float(night.rain()) < CALM_RAIN and (night.wind() as Vector3).length() < CALM_WIND

	for group in [&"bats", &"fireflies"]:
		for node in get_tree().get_nodes_in_group(group):
			if is_ancestor_of(node):
				(node as Node3D).visible = out

	if out:
		_fly(delta)


## Each bat along its loop round its height: a wide circle, rising and
## falling, and a jink now and then.
func _fly(_delta: float) -> void:
	for bat in _bats:
		var node: Node3D = bat["node"]

		if not is_instance_valid(node):
			continue

		var t: float = _clock * float(bat["turn"]) + float(bat["phase"])
		var r: float = float(bat["radius"]) * (1.0 + 0.25 * sin(_clock * 0.7 + float(bat["phase"])))
		var jink := Vector3(sin(_clock * 7.3 + float(bat["phase"]) * 3.0), sin(_clock * 5.1 + float(bat["phase"])) * 0.6, cos(_clock * 6.7 + float(bat["phase"]) * 2.0)) * BAT_JINK
		node.global_position = (bat["centre"] as Vector3) + Vector3(cos(t) * r, float(bat["rise"]) + sin(t * 1.7) * 1.2, sin(t) * r * 0.85) + jink


## A soft speck of light for particles (our corona, small), unlit; `glows`
## adds it (a firefly shines), else it is a pale mote.
static func _speck(size: float, colour: Color, glows: bool) -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	paint.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if glows else BaseMaterial3D.BLEND_MODE_MIX
	paint.albedo_color = colour
	paint.vertex_color_use_as_albedo = true
	paint.albedo_texture = load(GLOW) if ResourceLoader.exists(GLOW) else null
	paint.disable_receive_shadows = true
	quad.material = paint
	return quad
