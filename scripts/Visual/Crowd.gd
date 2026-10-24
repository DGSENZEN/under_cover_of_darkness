class_name Crowd
extends Node3D
## The crowd heard in the Underground's corridors: a murmur from both ends
## (people everywhere, no one word), passers-by's footsteps on the tile, now
## and then a cough, a laugh, a sigh from somewhere down the corridor. Heard,
## not seen, until the people themselves come. Seeded, on game time.

const BED := "res://audio/ambience/crowd_murmur.wav"
const STEP := "res://audio/sfx/step_tile_%d.wav"
const STEPS := 8
## The voices it draws on (the game's own, cut from the NOX voices), and how many takes each has at most.
const VOICES := ["cough", "cough_f", "laugh", "laugh_b", "laugh_f", "sigh", "sigh_f", "throat", "throat_b", "throat_f"]
const TAKES := 10
## Seconds between voices.
const VOICE_EVERY := Vector2(5.0, 14.0)
## The murmur's loudness (dB), and how far it sinks under a train.
const BED_DB := -12.0
const BED_DUCK := 9.0
## A walker's pace (m/s) and stride (s), how long one waits between walks (s).
const PACE := Vector2(1.0, 1.5)
const STRIDE := 0.55
const WAIT := Vector2(1.5, 7.0)

## The corridor's run (x) and the lanes people walk (z, in front of the stalls).
@export var span := Vector2(-11.0, 11.0)
@export var lanes := Vector2(1.2, 3.8)
@export var walker_count := 3
@export var seed := 0

## How much a passing train masks the crowd (0-1).
var duck := 0.0
var beds: Array[AudioStreamPlayer3D] = []
var walkers: Array[Dictionary] = []
var steps_played := 0
var voices_played := 0
var next_voice := 0.0
var _rng := RandomNumberGenerator.new()
var _steps: Array[AudioStream] = []
var _voices: Array[AudioStream] = []
var _voice_player: AudioStreamPlayer3D


func _ready() -> void:
	_rng.seed = seed

	for k in STEPS:
		_steps.append(load(STEP % (k + 1)))

	for group in VOICES:
		for k in TAKES:
			var path := "res://audio/sfx/%s_%d.wav" % [group, k + 1]

			if ResourceLoader.exists(path):
				_voices.append(load(path))

	for x in [span.x + 1.0, span.y - 1.0]:
		var bed := AudioStreamPlayer3D.new()
		bed.name = "murmur"
		bed.stream = load(BED)
		bed.unit_size = 8.0
		bed.max_distance = 40.0
		bed.volume_db = BED_DB
		bed.autoplay = true
		add_child(bed)
		bed.position = Vector3(x, 1.6, (lanes.x + lanes.y) * 0.5)
		beds.append(bed)

	for i in walker_count:
		var feet := AudioStreamPlayer3D.new()
		feet.name = "walker_%d" % i
		feet.unit_size = 3.0
		feet.max_distance = 16.0
		add_child(feet)
		var w := {"feet": feet, "x": 0.0, "z": 0.0, "dir": 1.0, "pace": 1.2, "wait": 0.0, "stride": 0.0}
		_new_walk(w)
		w["x"] = _rng.randf_range(span.x, span.y)
		walkers.append(w)

	_voice_player = AudioStreamPlayer3D.new()
	_voice_player.name = "voice"
	_voice_player.unit_size = 4.0
	_voice_player.max_distance = 22.0
	add_child(_voice_player)
	next_voice = _rng.randf_range(VOICE_EVERY.x, VOICE_EVERY.y)


func _process(delta: float) -> void:
	for bed in beds:
		bed.volume_db = bed_volume(duck)

	for w in walkers:
		if w["wait"] > 0.0:
			w["wait"] -= delta
			continue

		w["x"] += w["dir"] * w["pace"] * delta
		w["stride"] -= delta
		var feet: AudioStreamPlayer3D = w["feet"]
		feet.position = Vector3(w["x"], 0.05, w["z"])

		if w["stride"] <= 0.0:
			w["stride"] = STRIDE * 1.2 / w["pace"]
			feet.stream = _steps[_rng.randi() % _steps.size()]
			feet.pitch_scale = _rng.randf_range(0.92, 1.08)
			feet.play()
			steps_played += 1

		if w["x"] < span.x or w["x"] > span.y:
			_new_walk(w)

	next_voice -= delta

	if next_voice <= 0.0:
		voice()


## The murmur's loudness (dB) under a train masking it this much (0-1).
func bed_volume(masked: float) -> float:
	return BED_DB - BED_DUCK * clampf(masked, 0.0, 1.0)


## Someone in the crowd coughs, laughs, sighs: somewhere down the corridor.
func voice() -> void:
	if not _voices.is_empty():
		_voice_player.stream = _voices[_rng.randi() % _voices.size()]
		_voice_player.pitch_scale = _rng.randf_range(0.94, 1.06)
		var side := -1.0 if _rng.randf() < 0.5 else 1.0
		_voice_player.position = Vector3(side * _rng.randf_range(4.0, span.y - 1.0), 1.6,
			_rng.randf_range(lanes.x, lanes.y))
		_voice_player.play()

	voices_played += 1
	next_voice = _rng.randf_range(VOICE_EVERY.x, VOICE_EVERY.y)


## A walker off on a new walk: from one end, its own lane and pace, after a wait.
func _new_walk(w: Dictionary) -> void:
	w["dir"] = 1.0 if _rng.randf() < 0.5 else -1.0
	w["x"] = span.x if w["dir"] > 0.0 else span.y
	w["z"] = _rng.randf_range(lanes.x, lanes.y)
	w["pace"] = _rng.randf_range(PACE.x, PACE.y)
	w["wait"] = _rng.randf_range(WAIT.x, WAIT.y)
	w["stride"] = 0.0
