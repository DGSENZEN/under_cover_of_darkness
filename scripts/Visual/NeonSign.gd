class_name NeonSign
extends Node3D

const Sfx := preload("res://scripts/Audio/Sfx.gd")
const Focus := preload("res://scripts/Audio/Focus.gd")
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

## Its hum (a loop in Sfx.LOOP_GAIN; none, silent), heard this far (m). Its stutters: how likely each one ticks off
## and zaps back, and how soon after the last (s of game time).
@export var buzz := &""
const HUM_REACH := 4.5
const TICK_CHANCE := 0.35
const TICK_APART := 5.0

## How much of its power reaches it (a brownout when a train passes: 1 full).
var dim := 1.0
var tube: MeshInstance3D
var light: OmniLight3D
var _time := 0.0
var _start := 0
var _rate := 10.0
var _tube_material: ShaderMaterial
## Its hum (built on its first frame, with sound on and a buzz), how many times it has ticked off.
var hum: AudioStreamPlayer3D
var ticks := 0
var _sound_rng := RandomNumberGenerator.new()
var _was_lit := true
var _last_tick := -INF
var _zap := false


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
	_sound()


func _exit_tree() -> void:
	if hum != null:
		hum.stop()
		hum.stream = null


## Its hum's level (dB) for its loop's `gain` and how lit the tube is (0-1).
static func hum_db(gain: float, level: float) -> float:
	return gain + linear_to_db(maxf(level, 0.02))


## The hum following the tube (and a brownout); a stutter off now and then ticking, the strike back zapping.
func _sound() -> void:
	if buzz == &"" or not Sfx.enabled:
		return

	if hum == null:
		# (Here, not in _ready: a level that hushes its players as it is set up must not reach it.)
		_sound_rng.seed = seed * 31 + 3
		hum = AudioStreamPlayer3D.new()
		hum.name = "hum"
		hum.stream = load("res://audio/ambience/%s.wav" % buzz)
		hum.bus = Sfx.BUS_WORLD
		hum.unit_size = 1.2
		hum.max_distance = HUM_REACH
		hum.attenuation_filter_cutoff_hz = Sfx.AIR_CUTOFF
		hum.attenuation_filter_db = Sfx.AIR_DB
		hum.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		add_child(hum)
		Focus.hold(self, hum, &"loop", -80.0)
		hum.play(_sound_rng.randf_range(0.0, hum.stream.get_length()))

	# (The hum sags with a brownout; only the tube's own stutters tick, never its power sinking.)
	var lit := energy_at(_time)
	Focus.base(hum, hum_db(float(Sfx.LOOP_GAIN[buzz]), lit * dim))

	if _was_lit and lit < 0.5:
		if _sound_rng.randf() < TICK_CHANCE and _time - _last_tick >= TICK_APART \
				and Focus.allow(self, &"detail", global_position):
			Sfx.play(self, &"neon_tick", global_position)
			ticks += 1
			_last_tick = _time
			_zap = true
	elif not _was_lit and lit >= 0.5 and _zap:
		_zap = false
		Sfx.play(self, &"neon_zap", global_position)

	_was_lit = lit >= 0.5


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
