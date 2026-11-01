extends Node3D
## What the Company's engine gives off into the hall (docs/superpowers/specs/2026-11-01-engine-presence-design.md):
## its core breathing on its beat (EngineBeat); later its steam, heat, light, power and strain. dress() builds it under
## the engine and lists each part in the engine's meta "fx"; this node, under the engine after its beat, drives them
## each frame on the beat's time, uninterpolated.

const ENGINE_CORE := preload("res://scripts/Visual/engine_core.gdshader")
## The core's light at the lowest of its breath, as a share of its full.
const CORE_LOW := 0.7

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
	engine.set_meta("fx", fx)
	driver._breathe()


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _process(_delta: float) -> void:
	_breathe()


## The core's light and its streaks on the beat's breath.
func _breathe() -> void:
	var swell := beat.swell()
	var core: OmniLight3D = fx.get("core")
	if core != null:
		core.light_energy = float(fx["core_energy"]) * (CORE_LOW + (1.0 - CORE_LOW) * swell)
	var look: ShaderMaterial = fx.get("core_look")
	if look != null:
		look.set_shader_parameter("swell", swell)
