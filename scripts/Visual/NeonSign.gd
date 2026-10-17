class_name NeonSign
extends Node3D
## A neon sign: its tube (the first MeshInstance3D child) drawn with
## Neon.material and its own light, both following a flicker pattern on game
## time (slow motion slows it too). The seed sets where in the pattern a sign
## starts and how fast it steps, so a corridor of signs does not blink as one,
## and two runs of a scene light alike.

@export var colour := Color(1.0, 0.3, 0.6)
## One letter a step: a off, m full, z half (Neon.level).
@export var pattern := "mmmmmmmmmmmmmmmmmmmmmamm":
	set(value):
		pattern = value
		_seeded()
@export var seed := 0:
	set(value):
		seed = value
		_seeded()
## How far past white the tube burns, and its light's energy when full.
@export var energy := 4.0
@export var light_energy := 1.2
@export var light_range := 5.0
## Steps a second before the seed's own drift (±15%).
@export var steps_per_second := 10.0:
	set(value):
		steps_per_second = value
		_seeded()

## How much of its power reaches it (a brownout when a train passes: 1 full).
var dim := 1.0
var tube: MeshInstance3D
var light: OmniLight3D
var _time := 0.0
var _start := 0
var _rate := 10.0
var _tube_material: ShaderMaterial


func _init() -> void:
	_seeded()


func _ready() -> void:
	for child in get_children():
		if child is MeshInstance3D and tube == null:
			tube = child
		elif child is OmniLight3D and light == null:
			light = child

	if tube != null:
		_tube_material = Neon.material(colour, energy)
		tube.material_override = _tube_material
		tube.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	if light == null:
		light = OmniLight3D.new()
		light.name = "Light"
		add_child(light)

	light.light_color = colour
	light.omni_range = light_range
	light.shadow_enabled = false
	_apply()


func _process(delta: float) -> void:
	_time += delta
	_apply()


## The tube's own material (a look-dev bay's form light swaps it out and back).
func tube_material() -> ShaderMaterial:
	return _tube_material


## The sign's level (0-1) now.
func level() -> float:
	return energy_at(_time)


## The sign's level (0-1) at `t` seconds of game time.
func energy_at(t: float) -> float:
	if pattern.is_empty():
		return 1.0

	var step := (_start + int(floor(t * _rate))) % pattern.length()
	return Neon.level(pattern[step])


func _seeded() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	_start = rng.randi_range(0, maxi(pattern.length() - 1, 0))
	_rate = steps_per_second * rng.randf_range(0.85, 1.15)


func _apply() -> void:
	var now := energy_at(_time) * dim

	if light != null:
		light.light_energy = light_energy * now

	if _tube_material != null:
		_tube_material.set_shader_parameter("flicker", now)
