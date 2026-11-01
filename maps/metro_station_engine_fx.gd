extends Node3D
## What the Company's engine gives off into the hall (docs/superpowers/specs/2026-11-01-engine-presence-design.md):
## its core breathing on its beat (EngineBeat); later its steam, heat, light, power and strain. dress() builds it under
## the engine and lists each part in the engine's meta "fx"; this node, under the engine after its beat, drives them
## each frame on the beat's time, uninterpolated.

const ENGINE_CORE := preload("res://scripts/Visual/engine_core.gdshader")
const ENGINE_SHIMMER := preload("res://scripts/Visual/engine_shimmer.gdshader")
const ENGINE_SHAFT := preload("res://scripts/Visual/engine_shaft.gdshader")
const Layers := preload("res://scripts/Visual/Layers.gd")
## The core's light at the lowest of its breath, as a share of its full.
const CORE_LOW := 0.7
## The heat shimmer fades out this near the eye (m); its card (m, wide and tall), its foot over the hall's floor (the
## drum's cornice).
const NEAR_FADE := 1.5
const SHIMMER_SIZE := Vector2(3.2, 2.4)
const SHIMMER_FOOT := 2.5
## The shafts out of its windows: how bright at the full of its breath (additive), how far out (m), how much wider at
## their ends, how far down they lean (degrees).
const SHAFT_STRENGTH := 0.32
const SHAFT_LENGTH := 3.0
const SHAFT_SPREAD := 1.6
const SHAFT_TILT := 25.0
## Each window's light (a shadowless spot out and down): its energy at the full of its breath, its reach (m), its cone
## (degrees), how far down it leans (degrees).
const SPOT_ENERGY := 5.0
const SPOT_RANGE := 6.0
const SPOT_ANGLE := 38.0
const SPOT_TILT := 40.0
## The pool its light lays round it, on the floor and the ceiling: its radius (m), its glow at the full of its breath,
## the ceiling's height over the hall's floor (the coffers' beams).
const POOL_RADIUS := 6.5
const POOL_ENERGY := 0.35
const POOL_CEILING := 4.67
## A head's steam: its mouth (m), how high it climbs (m), the puffs a stroke breathes.
const STEAM_WIDTH := 0.3
const STEAM_RISE := 0.6
const STEAM_PUFFS := 3
## The dome's plume: its mouth round the crown's column (m); it climbs to just under the coffers' beams (4.67 m over
## the hall's floor).
const PLUME_WIDTH := 0.9
const PLUME_RISE := 0.8

var beat: EngineBeat
var fx := {}


## The engine's beat (its cranks' starts in `data`) and what it gives off, under `engine`.
static func dress(station, engine: Node3D, data: Dictionary, works_kit: Dictionary, works_look: Material) -> void:
	var beat := EngineBeat.new()
	beat.name = "beat"
	var starts := PackedFloat32Array()
	for spot: Dictionary in data["cranks"]:
		starts.append(float(spot["start"]))
	beat.starts = starts
	beat.turns = float(data["cranks"][0]["turns"]) if not data["cranks"].is_empty() else 0.25
	engine.add_child(beat)
	var driver = load("res://maps/metro_station_engine_fx.gd").new()
	driver.name = "fx"
	driver.beat = beat
	engine.add_child(driver)
	var fx: Dictionary = driver.fx
	var core := engine.get_node_or_null("core_light") as OmniLight3D
	fx["core"] = core
	fx["core_energy"] = core.light_energy if core != null else 0.0
	var works := engine.get_node_or_null("engine_works") as MeshInstance3D
	if works != null:
		for i in works.mesh.get_surface_count():
			var look := works.get_surface_override_material(i) as ShaderMaterial
			if look != null and look.shader == ENGINE_CORE:
				fx["core_look"] = look
	driver._steam(engine, data)
	driver._shimmer(engine)
	driver._light(engine, data)
	for spot: SpotLight3D in fx.get("spots", []):
		station.lights.append(spot)
	engine.set_meta("fx", fx)
	driver._breathe()


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _process(_delta: float) -> void:
	_breathe()


## Each cylinder's head breathing steam on its own stroke, and the dome's plume.
func _steam(engine: Node3D, data: Dictionary) -> void:
	var steam: Array = []
	for k in data.get("heads", []).size():
		var head: Dictionary = data["heads"][k]
		var fumes := _fumes(engine, "steam_%d" % k, Vector3(float(head["x"]), float(head["y"]) - 6.0, float(head["z"])),
			STEAM_WIDTH, STEAM_RISE, k)
		fumes.plumes = 0
		fumes.puffs = 0.0
		fumes.bursting = true
		fumes.puff_life = 1.4
		fumes.puff_speed = 0.5
		fumes.puff_size = 0.5
		steam.append(fumes)
	fx["steam"] = steam
	beat.stroke.connect(func(index: int) -> void:
		if index < steam.size():
			(steam[index] as Fumes).burst(STEAM_PUFFS))
	if data.has("dome"):
		var dome: Dictionary = data["dome"]
		var plume := _fumes(engine, "plume", Vector3(float(dome["x"]), float(dome["y"]) - 6.0, float(dome["z"])),
			PLUME_WIDTH, PLUME_RISE, 9)
		plume.plumes = 3
		plume.ring = 0.45
		plume.opacity = 0.3
		plume.puffs = 0.6
		fx["plume"] = plume


## A mouth facing up at `at` (the engine's frame), breathing.
func _fumes(engine: Node3D, mouth_name: String, at: Vector3, width: float, rise: float, seed: int) -> Fumes:
	var mouth := Node3D.new()
	mouth.name = mouth_name
	engine.add_child(mouth)
	mouth.position = at
	var fumes := Fumes.new()
	fumes.name = "fumes"
	fumes.width = width
	fumes.rise = rise
	fumes.seed = 700 + seed
	mouth.add_child(fumes)
	fumes.build()
	return fumes


## The heat over the drum: a card turned to the eye, bending what is seen through it.
func _shimmer(engine: Node3D) -> void:
	var card := MeshInstance3D.new()
	card.name = "shimmer"
	var quad := QuadMesh.new()
	quad.size = SHIMMER_SIZE
	card.mesh = quad
	var look := ShaderMaterial.new()
	look.shader = ENGINE_SHIMMER
	look.set_shader_parameter("near_fade", NEAR_FADE)
	card.material_override = look
	card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	card.layers = Layers.STATION_HALL
	card.extra_cull_margin = 1.0
	engine.add_child(card)
	card.position = Vector3(0.0, SHIMMER_FOOT + SHIMMER_SIZE.y / 2.0, 0.0)
	fx["shimmer"] = card


## Its light leaving its windows as shafts, and lying round it in a pool.
func _light(engine: Node3D, data: Dictionary) -> void:
	var blue: Color = load("res://maps/metro_station_dressing.gd").COMPANY_BLUE
	var shafts: Array = []
	var spots: Array = []
	for window: Dictionary in data.get("windows", []):
		var shaft := MeshInstance3D.new()
		shaft.name = "shaft_%d" % int(window["heading"])
		shaft.mesh = _frustum(float(window["width"]), float(window["height"]))
		var look := ShaderMaterial.new()
		look.shader = ENGINE_SHAFT
		look.set_shader_parameter("tint", blue)
		look.set_shader_parameter("strength", SHAFT_STRENGTH)
		look.set_shader_parameter("soft_depth", 0.4)
		shaft.material_override = look
		shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shaft.layers = Layers.STATION_HALL
		engine.add_child(shaft)
		# (Out along its heading, leaning down: its local -Z out of the window.)
		var out := Vector3(cos(deg_to_rad(float(window["heading"]))), 0.0, sin(deg_to_rad(float(window["heading"]))))
		var basis := Basis.looking_at(out, Vector3.UP).rotated(out.cross(Vector3.UP).normalized(), -deg_to_rad(SHAFT_TILT))
		shaft.transform = Transform3D(basis, Vector3(float(window["x"]), float(window["y"]) - 6.0, float(window["z"])))
		shafts.append(shaft)
		var spot := SpotLight3D.new()
		spot.name = "window_light_%d" % int(window["heading"])
		spot.light_color = blue
		spot.light_energy = SPOT_ENERGY
		spot.spot_range = SPOT_RANGE
		spot.spot_angle = SPOT_ANGLE
		spot.spot_attenuation = 1.4
		spot.shadow_enabled = false
		spot.light_cull_mask = Layers.STATION_HALL | Layers.WORLD | Layers.ACTORS | Layers.VIEWMODEL | Layers.FX | Layers.GEM_PROBE
		engine.add_child(spot)
		var aim := Basis.looking_at(out, Vector3.UP).rotated(out.cross(Vector3.UP).normalized(), -deg_to_rad(SPOT_TILT))
		spot.transform = Transform3D(aim, shaft.position)
		spots.append(spot)
	fx["shafts"] = shafts
	fx["spots"] = spots
	var glow := GradientTexture2D.new()
	glow.fill = GradientTexture2D.FILL_RADIAL
	glow.fill_from = Vector2(0.5, 0.5)
	glow.fill_to = Vector2(1.0, 0.5)
	# (Its fall in the colour and the alpha both: a decal's alpha, from its albedo, says where it lies; its emission's
	# colour how bright.)
	var fall := Gradient.new()
	fall.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	fall.set_color(1, Color(0.0, 0.0, 0.0, 0.0))
	fall.add_point(0.4, Color(0.42, 0.42, 0.42, 0.5))
	fall.add_point(0.75, Color(0.08, 0.08, 0.08, 0.1))
	fall.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CUBIC
	glow.gradient = fall
	var pools: Array = []
	for up in [false, true]:
		var pool := Decal.new()
		pool.name = "pool_ceiling" if up else "pool_floor"
		pool.size = Vector3(2.0 * POOL_RADIUS, 1.2, 2.0 * POOL_RADIUS)
		pool.texture_albedo = glow
		pool.texture_emission = glow
		pool.emission_energy = POOL_ENERGY
		pool.modulate = blue
		pool.albedo_mix = 0.0
		pool.upper_fade = 0.4
		pool.lower_fade = 0.4
		pool.cull_mask = Layers.STATION_HALL
		engine.add_child(pool)
		# (The floor's projected down onto the hall's floor and the plinth; the ceiling's up onto the coffers.)
		pool.position = Vector3(0.0, POOL_CEILING - 0.4 if up else 0.4, 0.0)
		if up:
			pool.rotation = Vector3(PI, 0.0, 0.0)
		pools.append(pool)
	fx["pool"] = pools


## A shaft's frustum: its sides from the window (`width` by `height`, at z 0) out along -Z, SHAFT_SPREAD wider at its
## end; UV.y along it, UV.x round it.
static func _frustum(width: float, height: float) -> ArrayMesh:
	var near := [Vector3(-width, -height, 0.0) / 2.0, Vector3(width, -height, 0.0) / 2.0,
		Vector3(width, height, 0.0) / 2.0, Vector3(-width, height, 0.0) / 2.0]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 4:
		var a: Vector3 = near[k]
		var b: Vector3 = near[(k + 1) % 4]
		var far_a := Vector3(a.x * SHAFT_SPREAD, a.y * SHAFT_SPREAD, -SHAFT_LENGTH)
		var far_b := Vector3(b.x * SHAFT_SPREAD, b.y * SHAFT_SPREAD, -SHAFT_LENGTH)
		var u0 := k / 4.0
		var u1 := (k + 1) / 4.0
		var normal := (b - a).cross(far_a - a).normalized()
		for corner: Array in [[a, Vector2(u0, 0.0)], [b, Vector2(u1, 0.0)], [far_b, Vector2(u1, 1.0)],
				[a, Vector2(u0, 0.0)], [far_b, Vector2(u1, 1.0)], [far_a, Vector2(u0, 1.0)]]:
			tool.set_normal(normal)
			tool.set_uv(corner[1])
			tool.add_vertex(corner[0])
	return tool.commit()


## The core's light and its streaks on the beat's breath.
func _breathe() -> void:
	var swell := beat.swell()
	var core: OmniLight3D = fx.get("core")
	if core != null:
		core.light_energy = float(fx["core_energy"]) * (CORE_LOW + (1.0 - CORE_LOW) * swell)
	var look: ShaderMaterial = fx.get("core_look")
	if look != null:
		look.set_shader_parameter("swell", swell)
	for shaft: MeshInstance3D in fx.get("shafts", []):
		(shaft.material_override as ShaderMaterial).set_shader_parameter("strength", SHAFT_STRENGTH * lerpf(0.6, 1.0, swell))
	for spot: SpotLight3D in fx.get("spots", []):
		spot.light_energy = SPOT_ENERGY * lerpf(0.6, 1.0, swell)
	for pool: Decal in fx.get("pool", []):
		pool.modulate.a = lerpf(0.5, 1.0, swell)
	var shimmer: MeshInstance3D = fx.get("shimmer")
	if shimmer != null:
		(shimmer.material_override as ShaderMaterial).set_shader_parameter("swell", swell)
