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
const HALO := preload("res://scripts/Visual/vfx_halo.gdshader")
const WISP := preload("res://scripts/Visual/vfx_wisp.gdshader")
const STEM := preload("res://scripts/Visual/vfx_stem.gdshader")
const MIST := preload("res://scripts/Visual/vfx_mist.gdshader")
const FOG := preload("res://scripts/Visual/vfx_fog.gdshader")
const DUST := preload("res://scripts/Visual/vfx_dust.gdshader")
const Flicker := preload("res://scripts/Level/VfxFlicker.gd")
const Layers := preload("res://scripts/Visual/Layers.gd")
const DRIFT := preload("res://scripts/Visual/vfx_drift.gdshader")
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
## The seeped's colour (the colour rule: phosphor green).
const SEEPED := Color("7FD36A")
## Dust is laid this far under its lamp (tools/level/dress_scenes.py).
const DUST_UNDER_LAMP := 3.5
## The wind's push on what drifts (petals, leaves), per m/s of wind.
const WIND_PUSH := 0.6
## How long a petal or a leaf lasts, falling and lying (s).
const DRIFT_LIFE := 20.0
## An effect fades out with the camera's distance from FADE_FROM over
## FADE_OVER (m): gone before Ambient's REACH (60 m).
const FADE_FROM := 45.0
const FADE_OVER := 10.0
## How fast drift crosses the ground at most (m/s), and how near a
## building to what drifts stands a wall for it (Vfx.walls, m).
const DRIFT_ACROSS := 1.2
const WALL_REACH := 20.0
const CANDLE_COLOUR := Color("#ffc070")
## A candle's flame at a size of 1: its widest across and its height (m), a little bigger than a
## real one's, so it reads.
const CANDLE_FLAME := Vector2(0.065, 0.085)
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
	# Breath and smoke drawn on meshes, the Deadlock way (Fumes.gd): plumes climbing out of the mouth
	# and lumpy puffs breathed among them, lit in hard bands, eaten away with a hard edge.
	"steam": [{"draw": "fumes", "width": 0.35, "rise": 1.4, "plumes": 3, "root": 0.12, "crown": 0.42,
		"lit": Color(0.94, 0.94, 0.96), "shade": Color(0.55, 0.6, 0.7), "warmth": 0.0, "glow": 0.18, "opacity": 0.55,
		"puffs": 6.0, "puff_life": 1.6, "puff_size": 0.42, "puff_speed": 0.6}],
	# A copal burner's column: pale, slow, climbing high, pooling in a haze over it.
	"copal": [{"draw": "fumes", "width": 0.25, "rise": 2.6, "plumes": 3, "root": 0.16, "crown": 1.1,
		"lit": Color("ECE6DA"), "shade": Color(0.5, 0.5, 0.56), "warmth": 0.04, "glow": 0.1, "opacity": 0.6,
		"puffs": 3.0, "puff_life": 4.0, "puff_size": 0.6, "puff_speed": 0.4, "offset": 0.8, "breathed": true},
		{"draw": "pool", "size": Vector3(3.0, 1.6, 3.0), "at": Vector3(0, 2.4, 0)}],
	# A censer's thread of copal (the Underground's curandera): two thin, cool, see-through threads off
	# the resin, widening and fraying as they rise; gone just under the canvas, where it gathers in a haze.
	"censer": [{"draw": "fumes", "width": 0.05, "rise": 0.82, "plumes": 2, "root": 0.25, "crown": 2.6,
		"lit": Color("B4B8C2"), "shade": Color(0.4, 0.42, 0.5), "warmth": 0.0, "glow": 0.08, "opacity": 0.42,
		"puffs": 1.5, "puff_life": 2.6, "puff_size": 0.9, "puff_speed": 0.14, "churn": 0.12},
		{"draw": "pool", "size": Vector3(1.6, 0.4, 1.6), "at": Vector3(0, 0.9, 0), "density": 1.4}],
	# A tamale steamer's steam, escaping round its lid: white, quick, thinning fast; a little light of
	# its own so it reads pale from its shadowed side too (lit only, it went brown under the warm lamps).
	"pot_steam": [{"draw": "fumes", "width": 0.3, "rise": 0.7, "plumes": 3, "root": 0.12, "crown": 0.38,
		"lit": Color(0.95, 0.95, 0.97), "shade": Color(0.55, 0.58, 0.66), "warmth": 0.0, "glow": 0.2, "opacity": 0.5,
		"puffs": 7.0, "puff_life": 1.3, "puff_size": 0.3, "puff_speed": 0.25}],
	# Warm air breathed out of a wall vent (its node turned so up is out of the wall): pale and cool,
	# the works' warm breath clouding in the corridor's cold, so it reads on the warm-lit tiles; dust
	# carried on it.
	"vent_breath": [{"draw": "fumes", "width": 0.5, "rise": 1.2, "plumes": 3, "puffs": 5.0, "puff_life": 2.6,
		"lit": Color(0.94, 0.93, 0.9), "shade": Color(0.5, 0.56, 0.68), "warm": Color(0.95, 0.52, 0.24),
		"opacity": 0.6},
		{"draw": "motes", "tint": Color(1.0, 0.9, 0.7, 0.6), "amount": 16, "lifetime": 3.0, "size": [0.015, 0.015],
		"velocity": [0.2, 0.4], "spread": 25.0, "gravity": Vector3(0, 0.12, 0), "box": Vector3(0.26, 0.01, 0.15),
		"fps": 15}],
	"smoke": [{"draw": "fumes", "width": 0.35, "rise": 2.2, "plumes": 3, "root": 0.14, "crown": 0.6,
		"lit": Color(0.42, 0.4, 0.38), "shade": Color(0.2, 0.2, 0.22), "warmth": 0.0, "glow": 0.03, "opacity": 0.65,
		"puffs": 5.0, "puff_life": 3.2, "puff_size": 0.5, "puff_speed": 0.5, "offset": 0.6}],
	"embers": [{"draw": "specks", "tint": Color("FFA040"), "amount": 30, "lifetime": 1.4, "size": [0.035, 0.015],
		"velocity": [0.8, 1.6], "spread": 25.0, "gravity": Vector3(0, 0.6, 0), "box": Vector3(0.2, 0.05, 0.2), "fps": 30,
		"blown": 0.2}],
	"mist": [{"draw": "fog", "shader": MIST, "size": Vector3(6.0, 1.2, 6.0), "at": Vector3(0, 0.5, 0), "density": 1.6},
		{"draw": "sprites", "sheet": PUFF, "sheet_b": PUFF_B, "grid": [4, 4], "tint": SEEPED, "opacity": 0.15,
		"amount": 8, "lifetime": 5.0, "size": [0.8, 2.2], "velocity": [0.1, 0.3], "spread": 180.0, "flat": true,
		"gravity": Vector3(0, -0.05, 0), "box": Vector3(0.5, 0.05, 0.5), "fps": 15, "erosion": 0.6, "anim": 1.0,
		"glows": true, "ground": 0.1}],
	"petals": [{"draw": "drift", "mesh": "petal_a", "amount": 24, "box": Vector3(2.0, 0.6, 2.0), "offset": 1.8,
		"breathed": true},
		{"draw": "drift", "mesh": "petal_b", "amount": 24, "box": Vector3(2.0, 0.6, 2.0), "offset": 1.8, "breathed": true}],
	"leaves": [{"draw": "drift", "mesh": "leaf_ash", "amount": 24, "box": Vector3(2.5, 0.5, 2.5), "offset": 0.0},
		{"draw": "drift", "mesh": "leaf_laurel", "amount": 16, "box": Vector3(2.5, 0.5, 2.5), "offset": 0.0}],
	"dust": [{"draw": "motes", "tint": Color(1.0, 0.92, 0.75, 0.6), "amount": 40, "lifetime": 6.0, "size": [0.02, 0.02],
		"velocity": [0.02, 0.06], "spread": 180.0, "gravity": Vector3.ZERO, "box": Vector3(2.0, 1.5, 2.0), "fps": 15,
		"breathed": true}],
	"canal_fog": [{"draw": "fog", "shader": FOG, "size": Vector3(40.0, 2.0, 12.0), "at": Vector3.ZERO, "density": 1.5}],
	"candles": [{"draw": "candles"}, {"draw": "light", "colour": CANDLE_COLOUR, "range": 4.0, "at": Vector3(0, 0.4, 0)}],
	"brazier": [{"draw": "flames"}, {"draw": "trailed"}, {"draw": "haze"},
		{"draw": "light", "colour": FIRE_COLOUR, "range": 9.0, "at": Vector3(0, 0.5, 0)},
		{"draw": "fumes", "width": 0.3, "rise": 2.0, "plumes": 2, "root": 0.2, "crown": 0.7,
		"lit": Color(0.38, 0.36, 0.34), "shade": Color(0.18, 0.17, 0.19), "warm": Color(1.0, 0.5, 0.2), "warmth": 0.25,
		"glow": 0.03, "opacity": 0.6, "puffs": 4.0, "puff_life": 3.0, "puff_size": 0.5, "puff_speed": 0.5, "offset": 0.9}],
	"coals": [{"draw": "trailed"}, {"draw": "light", "colour": FIRE_COLOUR, "range": 3.0, "at": Vector3(0, 0.2, 0)}],
}
## Effects whose light flickers with their flames, and its energy.
const FLICKERS := {"brazier": BRAZIER_ENERGY, "coals": COALS_ENERGY, "candles": CANDLES_ENERGY}

static var _noise: NoiseTexture2D
static var _noise_3d: NoiseTexture3D
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

		for candles: MultiMeshInstance3D in root.find_children("candle*", "MultiMeshInstance3D", true, false):
			root.flames.append(candles.multimesh.mesh.surface_get_material(0))

	# (A sub-emitter is its emitter's sibling.)
	for child in root.get_children():
		if child is GPUParticles3D and child.has_meta("spark_with"):
			child.sub_emitter = NodePath("../" + String(child.get_meta("spark_with")))

	# Drawn where effects are: never seen by the lightgem.
	for visual in root.find_children("*", "VisualInstance3D", true, false):
		if not visual is Light3D:
			Layers.effect(visual)

	# Fading out with distance before Ambient stops it (no pop at its reach):
	# its lights and drawn parts by themselves, its fog by Vfx.fade.
	for light: Light3D in root.find_children("*", "Light3D", true, false):
		light.distance_fade_enabled = true
		light.distance_fade_begin = FADE_FROM
		light.distance_fade_length = FADE_OVER

	for draw: GeometryInstance3D in root.find_children("*", "GeometryInstance3D", true, false):
		if not draw is GPUParticles3D:
			draw.visibility_range_end = FADE_FROM
			draw.visibility_range_end_margin = FADE_OVER
			draw.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF

	for fog: FogVolume in root.find_children("*", "FogVolume", true, false):
		var thick: Material = fog.material
		fog.set_meta("density", thick.density if thick is FogMaterial else float(thick.get_shader_parameter(&"density")))

	return root


## An effect's fog thinned to `share` of its own (1 near, 0 at its reach).
static func fade(node: Node3D, share: float) -> void:
	for fog: FogVolume in node.find_children("*", "FogVolume", true, false):
		var thick: Material = fog.material
		var full: float = fog.get_meta("density")

		if thick is FogMaterial:
			thick.density = full * share
		else:
			thick.set_shader_parameter(&"density", full * share)


static func _part(p: Dictionary) -> Array:
	match p["draw"]:
		"candles":
			return _candles()
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
		"fog":
			return [_fog(p)]
		"drift":
			return [_drift(p)]
		"pool":
			return [_pool(p)]
		"fumes":
			return [_fumes(p)]

	if p.has("ground"):
		return [_particles(p), _ground(p["ground"])]

	return [_particles(p)]


## The ground `depth` under an effect's spot, for what it gives off to
## slide along (the plaza is flat under a booth: a box, not a heightfield).
static func _ground(depth: float) -> GPUParticlesCollisionBox3D:
	var ground := GPUParticlesCollisionBox3D.new()
	ground.name = "ground"
	ground.size = Vector3(6, 0.2, 6)
	ground.position = Vector3(0, -depth - 0.1, 0)
	return ground


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
	# (The wind reaches it through its gravity, Vfx.blow, not the drift's
	# attractor; only the god's breath, its own attractor, moves what it
	# breathes.)
	process.attractor_interaction_enabled = p.get("breathed", false)

	# (Moved by the breath on its own layer, unseen by the wind's attractor:
	# the wind reaches it through its gravity.)
	if p.get("breathed", false):
		particles.layers = Layers.BREATHED

	if p.has("ground"):
		process.collision_mode = ParticleProcessMaterial.COLLISION_RIGID
		process.collision_bounce = 0.0
		process.collision_friction = 0.6
		particles.collision_base_size = 0.2

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

	if p["draw"] == "motes":
		var mote := ShaderMaterial.new()
		mote.shader = DUST
		mote.set_shader_parameter(&"tint", p["tint"])
		mote.set_shader_parameter(&"cone_axis", Vector3.DOWN)
		mote.set_shader_parameter(&"cone_angle", 0.6)
		quad.material = mote
	elif p["draw"] == "sprites":
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

		look.set_shader_parameter(&"glows", p.get("glows", false))

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


## A cluster of five to nine candle flames round a spot: one MultiMesh of
## real teardrop flames (MeshVfx.flame, the Deadlock way), each its own size
## and phase; on the same transforms, the glows they throw round them and the
## threads of smoke they now and then send up.
static func _candles() -> Array:
	var flame := MeshVfx.flame(1.0, 0.3, 16, 12)
	var look := ShaderMaterial.new()
	look.shader = CANDLE
	look.set_shader_parameter(&"noise", MeshVfx.noise())
	flame.surface_set_material(0, look)
	var quad := QuadMesh.new()
	var glow := ShaderMaterial.new()
	glow.shader = HALO
	glow.set_shader_parameter(&"colour", CANDLE_COLOUR)
	quad.material = glow
	# (Its thread of smoke cut along its height, so it can curl.)
	var thread := QuadMesh.new()
	thread.subdivide_depth = 20
	var smoke := ShaderMaterial.new()
	smoke.shader = WISP
	smoke.set_shader_parameter(&"noise", MeshVfx.noise())
	thread.material = smoke
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var count := rng.randi_range(5, 9)
	var draws := []

	for drawn in [["candles", flame], ["candle_halos", quad], ["candle_wisps", thread]]:
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_custom_data = true
		multi.mesh = drawn[1]
		multi.instance_count = count
		var draw := MultiMeshInstance3D.new()
		draw.name = drawn[0]
		draw.multimesh = multi
		draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		draw.visible = false
		draws.append(draw)

	for i in count:
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.05, 0.6)
		_set_flame(draws, i, Vector3(cos(a) * r, rng.randf_range(0.08, 0.3), sin(a) * r), rng.randf_range(0.8, 1.3),
			rng.randf())

	return draws


## A candle's flame `i` stood at `at` (local), `size` times a flame's own, on its `phase`: the
## flame and its glow alike.
static func _set_flame(draws: Array, i: int, at: Vector3, size: float, phase: float) -> void:
	var shape := Basis.from_scale(Vector3(CANDLE_FLAME.x, CANDLE_FLAME.y, CANDLE_FLAME.x) * size)

	for draw: MultiMeshInstance3D in draws:
		draw.multimesh.set_instance_transform(i, Transform3D(shape, at))
		draw.multimesh.set_instance_custom_data(i, Color(phase, 0, 0, 0))


## Breath out of a mouth drawn on meshes (Fumes.gd): plumes and puffs, built once its node is turned.
static func _fumes(p: Dictionary) -> Fumes:
	var fumes := Fumes.new()
	fumes.name = "fumes"

	for key in p:
		if key in fumes:
			fumes.set(key, p[key])

	fumes.position.y = p.get("offset", 0.0)
	fumes.seed = randi()
	fumes.visible = false
	return fumes


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


## What drifts down (petals, leaves): one drift-kit mesh a system (a second
## draw pass would draw both meshes on every particle), driven by the drift
## shader, landing on the camera's heightfield (Vfx.heightfield), carried by
## the map's wind (an attractor: only effects on Layers.FX feel it).
static func _drift(p: Dictionary) -> GPUParticles3D:
	var drift := GPUParticles3D.new()
	drift.name = p["mesh"]
	drift.amount = p["amount"]
	drift.lifetime = DRIFT_LIFE
	drift.fixed_fps = 30
	drift.interpolate = true
	drift.local_coords = false
	drift.emitting = false
	drift.layers = Layers.FX | (Layers.BREATHED if p.get("breathed", false) else 0)
	# (Half a petal's thickness: it comes to rest this far over the ground.)
	drift.collision_base_size = 0.007
	var reach: Vector3 = p["box"] + Vector3(12, 0, 12)
	drift.visibility_aabb = AABB(-reach - Vector3(0, 8, 0), reach * 2.0 + Vector3(0, 12, 0))
	var how := ShaderMaterial.new()
	how.shader = DRIFT
	how.set_shader_parameter(&"box", p["box"])
	how.set_shader_parameter(&"offset", p["offset"])
	how.set_shader_parameter(&"limit", 3.0)
	how.set_shader_parameter(&"drift_limit", DRIFT_ACROSS)
	drift.process_material = how
	drift.draw_pass_1 = KitLoader.meshes("drift_kit")[p["mesh"]]
	drift.material_override = KitLoader.material("drift_kit")
	return drift


## The ground under the camera for what drifts down to land on (one a map):
## the ground layer only, 60 m round the camera, redrawn as it moves.
static func heightfield(map: Node3D) -> GPUParticlesCollisionHeightField3D:
	var field := GPUParticlesCollisionHeightField3D.new()
	field.name = "drift_ground"
	field.size = Vector3(60, 30, 60)
	field.resolution = GPUParticlesCollisionHeightField3D.RESOLUTION_512
	field.update_mode = GPUParticlesCollisionHeightField3D.UPDATE_MODE_WHEN_MOVED
	field.follow_camera_enabled = true
	# What it draws: the ground layer (a tree's crown would catch what falls
	# through it); what lands on it: the effects (a collider's cull_mask is
	# the particles it stops, not what it sees).
	field.heightfield_mask = Layers.GROUND
	field.cull_mask = Layers.FX
	map.add_child(field)
	# (Drawn when it moves: drawn once now, the camera perhaps standing still.)
	RenderingServer.particles_collision_height_field_update(field.get_base())
	return field


## The buildings near what drifts down (petals', leaves' emitters within
## WALL_REACH): a particle collision box over each plot (its footprint's
## smallest enclosing rectangle, from its base to its roof), so drift and
## sparks stop at a wall instead of passing through it.
static func walls(map: Node3D, plots: Array, emitters: Array) -> void:
	var drifting: Array = emitters.filter(func(e): return e["effect"] in ["petals", "leaves"])

	for plot in plots:
		var points: Array = plot["polygon"].map(func(pt): return Vector2(pt[0], pt[1]))
		var middle := Vector2.ZERO

		for pt in points:
			middle += pt

		middle /= points.size()

		if not drifting.any(func(e): return Vector2(e["at"][0], e["at"][2]).distance_to(middle) < WALL_REACH):
			continue

		# The smallest rectangle round it lies along one of its edges.
		var best := []

		for k in points.size():
			var along: Vector2 = (points[(k + 1) % points.size()] - points[k]).normalized()
			var side := Vector2(-along.y, along.x)
			var a := points.map(func(pt): return pt.dot(along))
			var b := points.map(func(pt): return pt.dot(side))
			var area: float = (a.max() - a.min()) * (b.max() - b.min())

			if best.is_empty() or area < best[0]:
				best = [area, along, side, a.min(), a.max(), b.min(), b.max()]

		var centre: Vector2 = best[1] * (best[3] + best[4]) / 2.0 + best[2] * (best[5] + best[6]) / 2.0
		var wall := GPUParticlesCollisionBox3D.new()
		wall.name = "wall"
		wall.size = Vector3(best[4] - best[3], float(plot["height"]), best[6] - best[5])
		wall.cull_mask = Layers.FX
		map.add_child(wall)
		wall.global_transform = Transform3D(Basis(Vector3.UP, -atan2(best[1].y, best[1].x)),
			Vector3(centre.x, float(plot["base"]) + float(plot["height"]) / 2.0, centre.y))


## The player's head to what effects throw (one a map, kept on the camera
## by its map): sparks, embers, petals stop at it, never through it.
static func head() -> GPUParticlesCollisionSphere3D:
	var sphere := GPUParticlesCollisionSphere3D.new()
	sphere.name = "head"
	sphere.radius = 0.35
	sphere.cull_mask = Layers.FX
	return sphere


## The wind on what drifts (one a map): an attractor pushing every way the
## same (fully directional), steered by Vfx.steer.
static func wind_attractor() -> GPUParticlesAttractorBox3D:
	var wind := GPUParticlesAttractorBox3D.new()
	wind.name = "wind"
	wind.size = Vector3(160, 60, 160)
	wind.directionality = 1.0
	wind.attenuation = 0.0
	wind.cull_mask = Layers.FX
	return wind


## Turns the wind's attractor to blow `wind` (m/s) round `at` (the camera).
static func steer(attractor: GPUParticlesAttractorBox3D, wind: Vector3, at: Vector3) -> void:
	var flat := Vector3(wind.x, 0, wind.z)
	attractor.global_position = at

	if flat.length() > 0.01:
		# (A directional attractor pushes along its -Z.)
		attractor.global_basis = Basis.looking_at(flat.normalized(), Vector3.UP)

	attractor.strength = flat.length() * WIND_PUSH


## A fog volume (box) drawn by its own fog shader.
static func _fog(p: Dictionary) -> FogVolume:
	var look := ShaderMaterial.new()
	look.shader = p["shader"]
	look.set_shader_parameter(&"noise", noise_3d())
	look.set_shader_parameter(&"density", p["density"])

	if p["shader"] == MIST:
		look.set_shader_parameter(&"colour", SEEPED)

	var volume := FogVolume.new()
	volume.name = "fog"
	volume.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	volume.size = p["size"]
	volume.position = p["at"]
	volume.material = look
	volume.visible = false
	return volume


## A small pool of haze over a smoke (copal's), catching the lamps.
static func _pool(p: Dictionary) -> FogVolume:
	var haze := FogMaterial.new()
	haze.density = p.get("density", 0.12)
	haze.albedo = Color("ECE6DA")
	haze.edge_fade = 0.6
	var volume := FogVolume.new()
	volume.name = "pool"
	volume.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
	volume.size = p["size"]
	volume.position = p["at"]
	volume.material = haze
	volume.visible = false
	return volume


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
	process.attractor_interaction_enabled = false
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


## A 3D noise of our own (seamless), shared by the fog shaders.
static func noise_3d() -> NoiseTexture3D:
	if _noise_3d == null:
		var fast := FastNoiseLite.new()
		fast.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		fast.frequency = 0.06
		fast.fractal_octaves = 3
		_noise_3d = NoiseTexture3D.new()
		_noise_3d.width = 64
		_noise_3d.height = 64
		_noise_3d.depth = 64
		_noise_3d.seamless = true
		_noise_3d.noise = fast

	return _noise_3d


## Puts an effect at `at` (world): what of it is placed by the world, too
## (dust's lamp, DUST_UNDER_LAMP above it; candles' flames on their
## emitter's "wicks", world, from tools/level/dress_scenes.py).
static func place(node: Node3D, at: Vector3, emitter := {}) -> void:
	node.global_position = at

	if emitter.has("wicks"):
		_on_wicks(node, at, emitter["wicks"])

	# What falls from it lands on its ground (`ground` m under its spot).
	if emitter.has("ground"):
		for floor_box in node.find_children("ground", "GPUParticlesCollisionBox3D", false, false):
			floor_box.position.y = -float(emitter["ground"]) - floor_box.size.y / 2.0

	for child in node.get_children():
		if child is GPUParticles3D and child.draw_pass_1 != null:
			var look := (child.draw_pass_1 as Mesh).surface_get_material(0) as ShaderMaterial

			if look != null and look.shader == DUST:
				look.set_shader_parameter(&"lamp", at + Vector3(0, DUST_UNDER_LAMP, 0))


## Candles' flames stood each on its wick (world), their light over them
## all; where they stand kept on the draw ("flames", local).
static func _on_wicks(node: Node3D, at: Vector3, wicks: Array) -> void:
	var draws := node.find_children("candle*", "MultiMeshInstance3D", false, false)

	if draws.is_empty():
		return

	var places := PackedVector3Array()
	var middle := Vector3.ZERO

	for draw: MultiMeshInstance3D in draws:
		draw.multimesh.instance_count = wicks.size()

	for i in wicks.size():
		var w := Vector3(wicks[i][0], wicks[i][1], wicks[i][2]) - at
		places.append(w)
		middle += w
		# (Each flame its own size and phase, from where it stands.)
		var seed := absf(sin(w.x * 12.9898 + w.z * 78.233) * 43758.5453)
		_set_flame(draws, i, w, 0.85 + 0.3 * fposmod(seed, 1.0), fposmod(seed * 7.0, 1.0))

	for draw in draws:
		draw.set_meta("flames", places)

	if wicks.size() > 0:
		for light in node.find_children("*", "OmniLight3D", false, false):
			light.position = middle / wicks.size() + Vector3(0, 0.3, 0)


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
	# (A hidden fire's flicker stops with it.)
	node.set_process(on)

	for child in node.get_children():
		if child is Fumes:
			child.emit(on)
		elif child is GPUParticles3D:
			if not child.has_meta("sub"):
				child.emitting = on
		elif child is VisualInstance3D or child is Light3D:
			child.visible = on


## Thins an effect (1 full, 0 none).
static func thin(node: Node3D, ratio: float) -> void:
	for child in node.get_children():
		if child is GPUParticles3D:
			child.amount_ratio = ratio
		elif child is Fumes and child.puffer != null:
			child.puffer.amount_ratio = ratio


## Carries what an effect gives off on the wind.
static func blow(node: Node3D, wind: Vector3) -> void:
	for child in node.get_children():
		if child is Fumes:
			child.draught = wind
		# (Candle flames lean on it.)
		if child is MultiMeshInstance3D and String(child.name) in ["candles", "candle_wisps"]:
			child.multimesh.mesh.surface_get_material(0).set_shader_parameter(&"draught", wind)
		# (A sub-emitter, sparks, has no wind of its own.)
		if child is GPUParticles3D and child.process_material.has_meta("blown"):
			var process := child.process_material as ParticleProcessMaterial
			process.gravity = process.get_meta("gravity") + Vector3(wind.x, 0, wind.z) * float(process.get_meta("blown"))
