class_name Vfx
extends RefCounted
## The district's effects, each built from its preset (the effects plan):
## GPU particles drawing our own sheets through the shared effect shader
## (vfx_sprite.gdshader), glowing specks, candle flames. Ambient.gd places
## them where the dressing's emitters are and runs the nearest; each node
## an effect builds is a Node3D whose children are its parts.

const SPRITE := preload("res://scripts/Visual/vfx_sprite.gdshader")
const FlameFx := preload("res://scripts/Visual/Lights/FlameFx.gd")
const SMOKE := "res://assets/vfx/smoke.png"
const PETAL := "res://assets/vfx/petal.png"
const LEAF := "res://assets/vfx/leaf.png"

## effect -> its parts; a part: "sprites" (sheet, grid, tint, opacity,
## erosion), "specks" (tint) or "candles"; amount, lifetime, size [start,
## end] (m), velocity [min, max] (m/s) up a spread (degrees), gravity, the
## box it is born in (half extents, centred `offset` up), fps.
const PRESETS := {
	"steam": [{"draw": "sprites", "sheet": SMOKE, "grid": [4, 1], "tint": Color(0.92, 0.92, 0.95), "opacity": 0.45,
		"amount": 24, "lifetime": 1.2, "size": [0.25, 0.75], "velocity": [0.6, 1.0], "spread": 15.0,
		"gravity": Vector3(0, 0.3, 0), "box": Vector3(0.1, 0.05, 0.1), "fps": 30, "erosion": 0.5}],
	"copal": [{"draw": "sprites", "sheet": SMOKE, "grid": [4, 1], "tint": Color("ECE6DA"), "opacity": 0.6,
		"amount": 40, "lifetime": 4.5, "size": [0.35, 1.7], "velocity": [0.3, 0.6], "spread": 12.0,
		"gravity": Vector3(0, 0.12, 0), "box": Vector3(0.12, 0.05, 0.12), "fps": 30, "erosion": 0.4, "blown": 0.25}],
	"smoke": [{"draw": "sprites", "sheet": SMOKE, "grid": [4, 1], "tint": Color(0.5, 0.48, 0.46), "opacity": 0.5,
		"amount": 30, "lifetime": 3.0, "size": [0.3, 1.2], "velocity": [0.4, 0.7], "spread": 15.0,
		"gravity": Vector3(0, 0.15, 0), "box": Vector3(0.15, 0.05, 0.15), "fps": 30, "erosion": 0.4, "blown": 0.3}],
	"embers": [{"draw": "specks", "tint": Color("FFA040"), "amount": 30, "lifetime": 1.4, "size": [0.035, 0.015],
		"velocity": [0.8, 1.6], "spread": 25.0, "gravity": Vector3(0, 0.6, 0), "box": Vector3(0.2, 0.05, 0.2), "fps": 30,
		"blown": 0.2}],
	"mist": [{"draw": "sprites", "sheet": SMOKE, "grid": [4, 1], "tint": Color("7FD36A"), "opacity": 0.3,
		"amount": 30, "lifetime": 4.0, "size": [0.6, 2.0], "velocity": [0.1, 0.35], "spread": 180.0, "flat": true,
		"gravity": Vector3(0, 0.02, 0), "box": Vector3(1.2, 0.15, 1.2), "fps": 15, "erosion": 0.3}],
	"petals": [{"draw": "sprites", "sheet": PETAL, "grid": [2, 2], "tint": Color.WHITE, "opacity": 1.0,
		"amount": 20, "lifetime": 8.0, "size": [0.12, 0.12], "velocity": [0.1, 0.3], "spread": 180.0,
		"gravity": Vector3(0, -0.8, 0), "box": Vector3(2.0, 0.6, 2.0), "offset": 1.8, "fps": 15, "blown": 0.4}],
	"leaves": [{"draw": "sprites", "sheet": LEAF, "grid": [2, 2], "tint": Color.WHITE, "opacity": 1.0,
		"amount": 8, "lifetime": 8.0, "size": [0.16, 0.16], "velocity": [0.1, 0.3], "spread": 180.0,
		"gravity": Vector3(0, -0.9, 0), "box": Vector3(2.5, 0.5, 2.5), "fps": 15, "blown": 0.4}],
	"dust": [{"draw": "specks", "tint": Color(1.0, 0.92, 0.75, 0.6), "amount": 30, "lifetime": 6.0, "size": [0.02, 0.02],
		"velocity": [0.02, 0.06], "spread": 180.0, "gravity": Vector3.ZERO, "box": Vector3(2.5, 1.5, 2.5), "fps": 15}],
	"canal_fog": [{"draw": "sprites", "sheet": SMOKE, "grid": [4, 1], "tint": Color(0.7, 0.75, 0.8), "opacity": 0.25,
		"amount": 20, "lifetime": 6.0, "size": [1.5, 3.5], "velocity": [0.05, 0.2], "spread": 180.0, "flat": true,
		"gravity": Vector3.ZERO, "box": Vector3(4.0, 0.1, 1.5), "fps": 15, "erosion": 0.3}],
	"candles": [{"draw": "candles"}],
	"brazier": ["smoke", "embers"],
	"coals": ["embers"],
}


## An effect's node, its parts built (null for an effect it does not know).
static func system(effect: String) -> Node3D:
	if not PRESETS.has(effect):
		push_warning("Vfx: no effect %s" % effect)
		return null

	var root := Node3D.new()
	root.name = effect

	for part in PRESETS[effect]:
		if part is String:
			for sub in PRESETS[part]:
				root.add_child(_part(sub))
		else:
			root.add_child(_part(part))

	return root


static func _part(p: Dictionary) -> Node3D:
	if p["draw"] == "candles":
		return _candles()

	var particles := GPUParticles3D.new()
	particles.amount = p["amount"]
	particles.lifetime = p["lifetime"]
	particles.fixed_fps = p["fps"]
	particles.interpolate = true
	particles.local_coords = false
	particles.emitting = false
	var reach: Vector3 = p["box"] + Vector3(2, 0, 2) + Vector3(0, p["lifetime"] * p["velocity"][1] + 2.0, 0)
	particles.visibility_aabb = AABB(-reach + Vector3(0, -1.0, 0), reach * 2.0 + Vector3(0, 1.0, 0))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = p["box"]
	process.emission_shape_offset = Vector3(0, p.get("offset", 0.0), 0)
	process.direction = Vector3(1, 0, 0) if p.get("flat", false) else Vector3(0, 1, 0)
	process.spread = p["spread"]
	process.initial_velocity_min = p["velocity"][0]
	process.initial_velocity_max = p["velocity"][1]
	process.gravity = p["gravity"]
	process.damping_min = 0.2
	process.damping_max = 0.4
	process.scale_min = p["size"][0]
	process.scale_max = p["size"][0] * 1.2
	var grow := Curve.new()
	grow.add_point(Vector2(0, 1))
	grow.add_point(Vector2(1, p["size"][1] / p["size"][0]))
	grow.max_value = maxf(1.0, p["size"][1] / p["size"][0])
	var grow_texture := CurveTexture.new()
	grow_texture.curve = grow
	process.scale_curve = grow_texture
	# Fading in and out over its life.
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.15, Color(1, 1, 1, 1))
	fade.add_point(0.7, Color(1, 1, 1, 1))
	var fade_texture := GradientTexture1D.new()
	fade_texture.gradient = fade
	process.color_ramp = fade_texture
	process.angle_min = -180.0
	process.angle_max = 180.0
	process.anim_offset_max = 1.0
	process.set_meta("gravity", p["gravity"])
	process.set_meta("blown", p.get("blown", 0.0))
	particles.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	particles.draw_pass_1 = quad

	if p["draw"] == "sprites":
		var look := ShaderMaterial.new()
		look.shader = SPRITE
		look.set_shader_parameter(&"sheet", load(p["sheet"]))
		look.set_shader_parameter(&"grid", Vector2i(p["grid"][0], p["grid"][1]))
		look.set_shader_parameter(&"tint", p["tint"])
		look.set_shader_parameter(&"opacity", p["opacity"])
		look.set_shader_parameter(&"erosion", p.get("erosion", 0.0))
		quad.material = look
	else:
		var glow := StandardMaterial3D.new()
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		glow.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		# (Without it the billboard drops the particle's scale: metre squares.)
		glow.billboard_keep_scale = true
		glow.vertex_color_use_as_albedo = true
		glow.albedo_color = p["tint"]
		glow.disable_fog = true
		quad.material = glow

	particles.set_meta("tint", p["tint"])
	return particles


## Three candle flames (FlameFx's candle sheet) round a spot.
static func _candles() -> Node3D:
	var group := Node3D.new()
	group.name = "candles"

	for k in 3:
		var flame: Node3D = FlameFx.new()
		flame.sheet = &"candle"
		flame.ramp = &"candle"
		flame.size = 0.05
		flame.layers = 1
		flame.core = false
		group.add_child(flame)
		flame.position = Vector3(cos(k * 2.1) * 0.12, 0.0, sin(k * 2.1) * 0.12)

	group.visible = false
	return group


## An effect's colour (its first particles' tint).
static func tint(particles: GPUParticles3D) -> Color:
	return particles.get_meta("tint", Color.WHITE)


## Starts or stops every part of an effect (stopped ones fade out, kept).
static func emit(node: Node3D, on: bool) -> void:
	for child in node.get_children():
		if child is GPUParticles3D:
			child.emitting = on
		else:
			child.visible = on


## Thins an effect (1 full, 0 none).
static func thin(node: Node3D, ratio: float) -> void:
	for child in node.get_children():
		if child is GPUParticles3D:
			child.amount_ratio = ratio


## Carries what an effect gives off on the wind.
static func blow(node: Node3D, wind: Vector3) -> void:
	for child in node.get_children():
		if child is GPUParticles3D:
			var process := child.process_material as ParticleProcessMaterial
			process.gravity = process.get_meta("gravity") + Vector3(wind.x, 0, wind.z) * float(process.get_meta("blown"))
