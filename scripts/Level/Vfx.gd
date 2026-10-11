class_name Vfx
extends RefCounted
## The district's effects, each built from its preset (the effects plan):
## GPU particles drawing our own sheets through the shared effect shader
## (vfx_sprite.gdshader), glowing specks, candle flames. Ambient.gd places
## them where the dressing's emitters are and runs the nearest; each node
## an effect builds is a Node3D whose children are its parts.

const SPRITE := preload("res://scripts/Visual/vfx_sprite.gdshader")
const FLAME := preload("res://scripts/Visual/vfx_flame.gdshader")
const HAZE := preload("res://scripts/Visual/vfx_haze.gdshader")
const CANDLE := preload("res://scripts/Visual/vfx_candle.gdshader")
const STEM := preload("res://scripts/Visual/vfx_stem.gdshader")
const Flicker := preload("res://scripts/Level/VfxFlicker.gd")
const SMOKE := "res://assets/vfx/smoke.png"
const PETAL := "res://assets/vfx/petal.png"
const LEAF := "res://assets/vfx/leaf.png"
const PLUME := "res://assets/vfx/plume_a.png"
const PLUME_B := "res://assets/vfx/plume_b.png"
const PUFF := "res://assets/vfx/puff_a.png"
const PUFF_B := "res://assets/vfx/puff_b.png"
const FIRE := "res://assets/vfx/fire.png"
const SPARKS := "res://assets/vfx/sparks.png"
## A brazier's light at a flicker of 1, a coal ring's, a candle cluster's.
const BRAZIER_ENERGY := 1.4
const COALS_ENERGY := 0.45
const CANDLES_ENERGY := 0.35
const FIRE_COLOUR := Color("#ff9a3c")
## A brazier's flame tongues, their height over the coals (m).
const FLAME_HEIGHT := 1.0
const CANDLE_COLOUR := Color("#ffc070")
## Fire's heat to colour, in hard bands: below the first band nothing is
## drawn; then deep red-orange, orange, pale gold (warm, never white).
const FIRE_RAMP := [Color("#2a0a00"), Color("#c8400c"), Color("#ff8a1e"), Color("#ffd27a")]

## effect -> its parts and (for those with a flickering light) its light's
## energy at a flicker of 1. A part: "sprites" (a sheet, its grid, tint,
## opacity, erosion; six-way lit with a second sheet), "specks" (glowing),
## "flames", "haze", "stem" (a smoke column), "light", "trailed" (embers
## with trails that bounce and spark, their "sparks" sub-emitter beside
## them), "candles"; amount, lifetime, size [start, end] (m), velocity [min,
## max] (m/s) up a spread (degrees), gravity, the box born in (half
## extents, `offset` up), fps. A String part is another effect's parts.
const PRESETS := {
	"steam": [{"draw": "sprites", "sheet": PUFF, "sheet_b": PUFF_B, "grid": [4, 4], "tint": Color(0.94, 0.94, 0.96),
		"opacity": 0.55, "amount": 16, "lifetime": 1.4, "size": [0.35, 0.9], "velocity": [0.5, 0.9], "spread": 12.0,
		"gravity": Vector3(0, 0.3, 0), "box": Vector3(0.1, 0.05, 0.1), "fps": 30, "erosion": 0.5, "blown": 0.2,
		"anim": 1.0}],
	"copal": [{"draw": "sprites", "sheet": PLUME, "sheet_b": PLUME_B, "grid": [8, 4], "tint": Color("ECE6DA"),
		"opacity": 0.9, "amount": 40, "lifetime": 6.0, "size": [0.5, 2.4], "velocity": [0.4, 0.65], "spread": 8.0,
		"gravity": Vector3(0, 0.12, 0), "box": Vector3(0.08, 0.05, 0.08), "offset": 0.8, "fps": 30, "erosion": 0.35,
		"blown": 0.15, "anim": 1.0},
		{"draw": "stem", "size": Vector2(0.5, 1.0)}],
	"smoke": [{"draw": "sprites", "sheet": PUFF, "sheet_b": PUFF_B, "grid": [4, 4], "tint": Color(0.42, 0.4, 0.38),
		"opacity": 0.6, "amount": 14, "lifetime": 3.2, "size": [0.4, 1.4], "velocity": [0.4, 0.7], "spread": 15.0,
		"gravity": Vector3(0, 0.15, 0), "box": Vector3(0.15, 0.05, 0.15), "offset": 0.6, "fps": 30, "erosion": 0.4,
		"blown": 0.3, "anim": 1.0}],
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
	"candles": [{"draw": "candles"}, {"draw": "light", "colour": CANDLE_COLOUR, "range": 4.0, "at": Vector3(0, 0.4, 0)}],
	"brazier": [{"draw": "flames"}, {"draw": "trailed"}, {"draw": "haze"},
		{"draw": "light", "colour": FIRE_COLOUR, "range": 9.0, "at": Vector3(0, 0.5, 0)},
		{"draw": "sprites", "sheet": PUFF, "sheet_b": PUFF_B, "grid": [4, 4], "tint": Color(0.36, 0.34, 0.32),
		"opacity": 0.5, "amount": 10, "lifetime": 3.0, "size": [0.4, 1.4], "velocity": [0.4, 0.7], "spread": 12.0,
		"gravity": Vector3(0, 0.15, 0), "box": Vector3(0.12, 0.05, 0.12), "offset": 0.9, "fps": 30, "erosion": 0.4,
		"blown": 0.3, "anim": 1.0}],
	"coals": [{"draw": "trailed"}, {"draw": "light", "colour": FIRE_COLOUR, "range": 3.0, "at": Vector3(0, 0.2, 0)}],
}
## Effects whose light flickers with their flames, and its energy.
const FLICKERS := {"brazier": BRAZIER_ENERGY, "coals": COALS_ENERGY, "candles": CANDLES_ENERGY}

static var _noise: NoiseTexture2D
static var _ramp: GradientTexture1D


## An effect's node, its parts built (null for an effect it does not know).
static func system(effect: String) -> Node3D:
	if not PRESETS.has(effect):
		push_warning("Vfx: no effect %s" % effect)
		return null

	var root: Node3D = Flicker.new() if FLICKERS.has(effect) else Node3D.new()
	root.name = effect
	var parts := []

	for part in PRESETS[effect]:
		parts += PRESETS[part] if part is String else [part]

	for part in parts:
		for node in _part(part):
			root.add_child(node)

	if root is Flicker:
		root.energy = FLICKERS[effect]
		root.seed = randf() * 100.0

		for light in root.find_children("*", "OmniLight3D", true, false):
			root.light = light

		for flames in root.find_children("flames*", "MeshInstance3D", true, false):
			root.flames.append(flames.get_surface_override_material(0))

	# (A sub-emitter is its emitter's sibling.)
	for child in root.get_children():
		if child is GPUParticles3D and child.has_meta("spark_with"):
			child.sub_emitter = NodePath("../" + String(child.get_meta("spark_with")))

	return root


static func _part(p: Dictionary) -> Array:
	match p["draw"]:
		"candles":
			return [_candles()]
		"flames":
			return [_flames()]
		"haze":
			return [_haze()]
		"stem":
			return [_stem(p["size"])]
		"light":
			return [_light(p)]
		"trailed":
			return _trailed()

	return [_particles(p)]


static func _particles(p: Dictionary) -> GPUParticles3D:
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
	# A flipbook plays once over a particle's life; a sheet of variants (no
	# "anim") shows one, picked at random.
	if p.get("anim", 0.0) > 0.0:
		process.anim_speed_min = p["anim"]
		process.anim_speed_max = p["anim"]
	else:
		process.anim_offset_max = 1.0
	process.set_meta("gravity", p["gravity"])
	process.set_meta("blown", p.get("blown", 0.0))

	# Carried on the wind (which adds to its gravity) at most a little past
	# its own pace: the column bends over, never breaking into a string of
	# puffs sped off one by one.
	if p.get("blown", 0.0) > 0.0:
		var pace := Curve.new()
		pace.max_value = 4.0
		pace.add_point(Vector2(0, p["velocity"][1] + 0.25))
		pace.add_point(Vector2(1, p["velocity"][1] + 0.25))
		var pace_texture := CurveTexture.new()
		pace_texture.curve = pace
		process.velocity_limit_curve = pace_texture

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

		if p.has("sheet_b"):
			look.set_shader_parameter(&"sheet_b", load(p["sheet_b"]))
			look.set_shader_parameter(&"six_ways", true)

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


## A cluster of five to nine candle flames round a spot: one MultiMesh, each
## flame its own phase.
static func _candles() -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_custom_data = true
	var quad := QuadMesh.new()
	quad.size = Vector2(0.05, 0.1)
	quad.center_offset = Vector3(0, 0.05, 0)
	var look := ShaderMaterial.new()
	look.shader = CANDLE
	look.set_shader_parameter(&"sheet", load("res://assets/vfx/flame_candle.png"))
	look.set_shader_parameter(&"ramp", load("res://assets/vfx/ramps/candle.png"))
	quad.material = look
	multi.mesh = quad
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	multi.instance_count = rng.randi_range(5, 9)

	for i in multi.instance_count:
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.05, 0.6)
		multi.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * rng.randf_range(0.8, 1.3)),
			Vector3(cos(a) * r, rng.randf_range(0.08, 0.3), sin(a) * r)))
		multi.set_instance_custom_data(i, Color(rng.randf(), 0, 0, 0))

	var draw := MultiMeshInstance3D.new()
	draw.name = "candles"
	draw.multimesh = multi
	draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	draw.visible = false
	return draw


## Three flame tongues crossed over the coals.
static func _flames() -> MeshInstance3D:
	var mesh := ArrayMesh.new()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)

	for k in 3:
		var a := k * PI / 3.0
		var side := Vector3(cos(a), 0, sin(a)) * 0.34
		var up := Vector3(0, FLAME_HEIGHT, 0)

		for v in [[-side, 0.0, 1.0], [side, 1.0, 1.0], [side + up, 1.0, 0.0],
				[-side, 0.0, 1.0], [side + up, 1.0, 0.0], [-side + up, 0.0, 0.0]]:
			surface.set_uv(Vector2(v[1], v[2]))
			surface.add_vertex(v[0])

	surface.commit(mesh)
	var look := ShaderMaterial.new()
	look.shader = FLAME
	look.set_shader_parameter(&"sheet", load(FIRE))
	look.set_shader_parameter(&"noise", noise())
	look.set_shader_parameter(&"ramp", ramp())
	look.set_shader_parameter(&"phase", randf())
	look.set_shader_parameter(&"height", FLAME_HEIGHT)
	var flames := MeshInstance3D.new()
	flames.name = "flames"
	flames.mesh = mesh
	# (Their faded foot sunk in the coals, the effect's spot their heap's top.)
	flames.position = Vector3(0, -0.12, 0)
	flames.set_surface_override_material(0, look)
	flames.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flames.visible = false
	return flames


## The heat haze over a fire.
static func _haze() -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.8, 1.2)
	var look := ShaderMaterial.new()
	look.shader = HAZE
	look.set_shader_parameter(&"noise", noise())
	quad.material = look
	var haze := MeshInstance3D.new()
	haze.name = "haze"
	haze.mesh = quad
	haze.position = Vector3(0, 1.0, 0)
	haze.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	haze.visible = false
	return haze


## The column of copal smoke over its source: two crossed planes.
static func _stem(size: Vector2) -> MeshInstance3D:
	var mesh := ArrayMesh.new()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)

	for k in 2:
		var side := (Vector3(1, 0, 0) if k == 0 else Vector3(0, 0, 1)) * size.x / 2

		for v in [[-side, 0.0, 1.0], [side, 1.0, 1.0], [side + Vector3(0, size.y, 0), 1.0, 0.0],
				[-side, 0.0, 1.0], [side + Vector3(0, size.y, 0), 1.0, 0.0], [-side + Vector3(0, size.y, 0), 0.0, 0.0]]:
			surface.set_uv(Vector2(v[1], v[2]))
			surface.set_normal(Vector3.UP.cross(side.normalized()))
			surface.add_vertex(v[0])

	surface.commit(mesh)
	var look := ShaderMaterial.new()
	look.shader = STEM
	look.set_shader_parameter(&"noise", noise())
	# (Its noise in metres: in the quad's UVs a tall quad stretches it.)
	look.set_shader_parameter(&"size", size)
	var stem := MeshInstance3D.new()
	stem.name = "stem"
	stem.mesh = mesh
	stem.set_surface_override_material(0, look)
	stem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stem.visible = false
	return stem


static func _light(p: Dictionary) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.light_color = p["colour"]
	light.omni_range = p["range"]
	light.light_energy = 1.0
	light.position = p["at"]
	# (Flickering: in the volumetric fog it would ghost.)
	light.light_volumetric_fog_energy = 0.0
	light.visible = false
	return light


## Embers from the coals: trails, bouncing on the ground (a collider a hand
## under the brazier's foot), throwing sparks where they land.
static func _trailed() -> Array:
	var embers := GPUParticles3D.new()
	embers.name = "embers"
	embers.amount = 24
	embers.lifetime = 1.8
	embers.fixed_fps = 30
	embers.interpolate = true
	embers.emitting = false
	embers.trail_enabled = true
	# (Short streaks: a longer trail on a quick ember draws a stick of light.)
	embers.trail_lifetime = 0.1
	embers.collision_base_size = 0.02
	embers.visibility_aabb = AABB(Vector3(-3, -1.5, -3), Vector3(6, 6, 6))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(0.2, 0.05, 0.2)
	process.direction = Vector3(0, 1, 0)
	process.spread = 35.0
	process.initial_velocity_min = 0.6
	process.initial_velocity_max = 1.4
	process.gravity = Vector3(0, -1.5, 0)
	process.damping_min = 0.3
	process.damping_max = 0.6
	process.collision_mode = ParticleProcessMaterial.COLLISION_RIGID
	process.collision_bounce = 0.45
	process.collision_friction = 0.3
	process.sub_emitter_mode = ParticleProcessMaterial.SUB_EMITTER_AT_COLLISION
	process.sub_emitter_amount_at_collision = 2
	process.set_meta("gravity", process.gravity)
	process.set_meta("blown", 0.15)
	embers.process_material = process
	var ribbon := RibbonTrailMesh.new()
	ribbon.shape = RibbonTrailMesh.SHAPE_CROSS
	ribbon.size = 0.018
	ribbon.sections = 4
	var taper := Curve.new()
	taper.add_point(Vector2(0, 0))
	taper.add_point(Vector2(1, 1))
	ribbon.curve = taper
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow.use_particle_trails = true
	glow.albedo_color = Color("FFA040")
	glow.disable_fog = true
	ribbon.material = glow
	embers.draw_pass_1 = ribbon
	embers.set_meta("tint", Color("FFA040"))
	embers.set_meta("spark_with", "sparks")
	var sparks := GPUParticles3D.new()
	sparks.name = "sparks"
	sparks.amount = 48
	sparks.lifetime = 0.35
	sparks.fixed_fps = 30
	sparks.emitting = false
	sparks.set_meta("sub", true)
	sparks.visibility_aabb = embers.visibility_aabb
	var flick := ParticleProcessMaterial.new()
	flick.direction = Vector3(0, 1, 0)
	flick.spread = 70.0
	flick.initial_velocity_min = 0.6
	flick.initial_velocity_max = 1.4
	flick.gravity = Vector3(0, -9.8, 0)
	flick.scale_min = 0.025
	flick.scale_max = 0.04
	sparks.process_material = flick
	var quad := QuadMesh.new()
	var bright := StandardMaterial3D.new()
	bright.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bright.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	bright.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	bright.billboard_keep_scale = true
	bright.albedo_texture = load(SPARKS)
	bright.albedo_color = Color("FFC060")
	bright.disable_fog = true
	quad.material = bright
	sparks.draw_pass_1 = quad
	var ground := GPUParticlesCollisionBox3D.new()
	ground.name = "ground"
	ground.size = Vector3(4, 0.2, 4)
	ground.position = Vector3(0, -1.0, 0)
	return [embers, sparks, ground]


## A climbing noise texture of our own (seamless), shared.
static func noise() -> NoiseTexture2D:
	if _noise == null:
		_noise = NoiseTexture2D.new()
		_noise.seamless = true
		_noise.width = 128
		_noise.height = 128
		var n := FastNoiseLite.new()
		n.frequency = 0.03
		n.fractal_octaves = 3
		_noise.noise = n

	return _noise


## Fire's heat to colour, banded.
static func ramp() -> GradientTexture1D:
	if _ramp == null:
		var g := Gradient.new()
		g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
		# (Each stop just under its band's value, 1/3, 2/3 and 1: a band
		# takes its own colour, not the one below.)
		g.offsets = PackedFloat32Array([0.0, 0.3, 0.6, 0.9])
		g.colors = PackedColorArray(FIRE_RAMP)
		_ramp = GradientTexture1D.new()
		_ramp.gradient = g

	return _ramp


## A fire's flicker at time t, its own by `seed`: 0.6 .. 1.1, mostly high,
## now and then a gutter.
static func flicker(t: float, seed: float) -> float:
	var f := 0.85 + 0.12 * sin(t * 7.3 + seed) + 0.08 * sin(t * 13.1 + seed * 2.3) - 0.1 * maxf(sin(t * 1.7 + seed * 0.7), 0.0)
	return clampf(f, 0.6, 1.1)


## An effect's colour (its first particles' tint).
static func tint(particles: GPUParticles3D) -> Color:
	return particles.get_meta("tint", Color.WHITE)


## Starts or stops every part of an effect (stopped ones fade out, kept);
## a sub-emitter is started by its emitter, never here.
static func emit(node: Node3D, on: bool) -> void:
	for child in node.get_children():
		if child is GPUParticles3D:
			if not child.has_meta("sub"):
				child.emitting = on
		elif child is VisualInstance3D or child is Light3D:
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
