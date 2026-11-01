extends Node3D
## What the Company's engine gives off into the hall (docs/superpowers/specs/2026-11-01-engine-presence-design.md):
## its core breathing on its beat (EngineBeat); later its steam, heat, light, power and strain. dress() builds it under
## the engine and lists each part in the engine's meta "fx"; this node, under the engine after its beat, drives them
## each frame on the beat's time, uninterpolated.

const ENGINE_CORE := preload("res://scripts/Visual/engine_core.gdshader")
const ENGINE_SHIMMER := preload("res://scripts/Visual/engine_shimmer.gdshader")
const Layers := preload("res://scripts/Visual/Layers.gd")
## The core's light at the lowest of its breath, as a share of its full.
const CORE_LOW := 0.7
## The heat shimmer fades out this near the eye (m); its card (m, wide and tall), its foot over the hall's floor (the
## drum's cornice).
const NEAR_FADE := 1.5
const SHIMMER_SIZE := Vector2(3.2, 2.4)
const SHIMMER_FOOT := 2.5
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


## The core's light and its streaks on the beat's breath.
func _breathe() -> void:
	var swell := beat.swell()
	var core: OmniLight3D = fx.get("core")
	if core != null:
		core.light_energy = float(fx["core_energy"]) * (CORE_LOW + (1.0 - CORE_LOW) * swell)
	var look: ShaderMaterial = fx.get("core_look")
	if look != null:
		look.set_shader_parameter("swell", swell)
	var shimmer: MeshInstance3D = fx.get("shimmer")
	if shimmer != null:
		(shimmer.material_override as ShaderMaterial).set_shader_parameter("swell", swell)
