class_name NeonSign
extends Node3D

const SaveFields := preload("res://scripts/Save/SaveFields.gd")
## What a save keeps of it (SaveFields): its clock, ticks and zap.
const SAVED := ["_time", "ticks", "_was_lit", "_last_tick", "_zap", "_out"]

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
## Its power this low and the tube is out (a train's draw on the line, at its deepest); coming back past BACK_ABOVE it
## strikes on again with its ignition.
const OUT_BELOW := 0.3
const BACK_ABOVE := 0.6
## Ignitions this many frames apart at least, across every sign: a row of signs coming back is heard as one striking on,
## not a wall of them. (Frames, not seconds: the same in every run of a suite.)
const IGNITE_APART := 15

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
var _out := false
## Fed from the Company's line (the station's signs, PlaceSound): only then is it a train's draw that puts it out and
## an ignition that brings it back. (The lane's and the bay's are dimmed by the dark train's cold too: no ignition.)
var on_line := false
## The frame a sign last struck on (shared by all signs).
static var _ignited_at := -IGNITE_APART


func _init() -> void:
	_seeded()


func _ready() -> void:
	# Saves itself (SaveGame); absent when a tool runs the script alone.
	var save := get_node_or_null("/root/SaveGame")

	if save != null:
		save.register(self)
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


## The hum following the tube (and a brownout); a stutter off now and then ticking, the strike back zapping; put out by
## a deep brownout, its ignition on coming back.
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

	# Put out by its power sinking, it strikes back on (its ignition's tail is the hum coming in).
	if dim < OUT_BELOW:
		_out = true
	elif _out and dim > BACK_ABOVE:
		_out = false
		var now := Engine.get_process_frames()

		if on_line and now - _ignited_at >= IGNITE_APART and Focus.allow(self, &"detail", global_position):
			_ignited_at = now
			Sfx.play(self, &"neon_ignite", global_position)


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


## Its clock, ticks and zap, for a save (SaveGame).
func save_state() -> Dictionary:
	var state := SaveFields.save(self, SAVED)
	return state


func load_state(state: Dictionary) -> void:
	SaveFields.restore(self, state, SAVED)
