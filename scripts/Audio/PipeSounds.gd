extends Node3D
## The pipes along the Underground's walls, heard (docs/superpowers/specs/2026-10-24-underground-sound-layers-design.md):
## a main's water heard along its whole length (a line source: its loop slides along the run to the point nearest
## you, never past its ends), a knock travelling down a main now and then (strikes further along, each fainter), and
## what happens at one place on one (a gulp, a valve's breath, the weeping joint's drops, the gas line's tick).
## Places in this node's frame. Every one-shot asks Focus first; what was played is counted with sound off too.

const Sfx := preload("res://scripts/Audio/Sfx.gd")
const Focus := preload("res://scripts/Audio/Focus.gd")

## A knock's strikes: how many, how far each goes on from the last (m), how soon after it (s), how much fainter (dB).
const STRIKES := 3
const STRIKE_ON := Vector2(2.5, 4.0)
const STRIKE_AFTER := Vector2(0.16, 0.38)
const STRIKE_FAINTER := -4.0
## How often a run's loop looks again for a wall between it and you (s).
const LOOK_EVERY := 0.5
## How fast a run's loop comes down or back up when a wall comes between or goes (dB/s; its dulling with it).
const EASE_DB := 20.0

@export var seed := 9

## What has played, by sound (and "refused": what Focus held back); the last of them, [time, sound, where (world)].
var played := {}
var heard: Array = []

var _runs: Array = []
var _knocks: Array = []
var _events: Array = []
var _strikes: Array = []
## Each knock laid out so far, and whether Focus let it through (its first strike asks; the rest ride on that).
var _trains := 0
var _let := {}
var _clock := 0.0
var _look_in := 0.0
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.seed = seed


func _ready() -> void:
	_rng.seed = seed


## A main's `loop` heard along `from`-`to`, out to `reach` m.
func run(loop: StringName, from: Vector3, to: Vector3, reach := 8.0) -> void:
	_runs.append({"loop": loop, "from": from, "to": to, "reach": reach, "player": null, "hidden": 0.0,
		"level": float(Sfx.LOOP_GAIN[loop]), "target": float(Sfx.LOOP_GAIN[loop]), "cutoff": Sfx.AIR_CUTOFF,
		"cutoff_to": Sfx.AIR_CUTOFF})


## A knock travelling along `from`-`to` every `every` s (from a place on it, one way or the other).
func knocks(from: Vector3, to: Vector3, every: Vector2) -> void:
	_knocks.append({"from": from, "to": to, "every": every, "next": _rng.randf_range(every.x, every.y)})


## `sound` at `at` every `every` s, `db` over its gain, at `pitch`.
func events(sound: StringName, at: Vector3, every: Vector2, db := 0.0, pitch := 1.0) -> void:
	_events.append({"sound": sound, "at": at, "every": every, "db": db, "pitch": pitch,
		"next": _rng.randf_range(every.x, every.y)})


## Run `i`'s player (null until its first frame, or with sound off).
func emitter_of(i: int) -> AudioStreamPlayer3D:
	return _runs[i]["player"] if i < _runs.size() else null


func _process(delta: float) -> void:
	_clock += delta
	var camera := get_viewport().get_camera_3d()
	_look_in -= delta
	var look := _look_in <= 0.0

	if look:
		_look_in = LOOK_EVERY

	for r: Dictionary in _runs:
		_slide(r, camera, look, delta)

	for k: Dictionary in _knocks:
		if _clock >= k["next"]:
			k["next"] = _clock + _rng.randf_range(k["every"].x, k["every"].y)
			_knock(k)

	for e: Dictionary in _events:
		if _clock >= e["next"]:
			e["next"] = _clock + _rng.randf_range(e["every"].x, e["every"].y)
			_play(e["sound"], to_global(e["at"]), e["db"], e["pitch"])

	while not _strikes.is_empty() and _strikes[0][0] <= _clock:
		var strike: Array = _strikes.pop_front()
		var train: int = strike[3]

		if not _let.has(train):
			_let[train] = _play(&"pipe_knock", strike[1], strike[2], 1.0)
		elif _let[train]:
			_play(&"pipe_knock", strike[1], strike[2], 1.0, false)

		if strike[4]:
			_let.erase(train)


func _exit_tree() -> void:
	for r: Dictionary in _runs:
		if r["player"] != null:
			r["player"].stop()
			r["player"].stream = null


## Run `r`'s loop (built on its first frame: a level that hushes its players as it is set up must not reach it), slid
## to the point on the run nearest you, quieter for a wall between.
func _slide(r: Dictionary, camera: Camera3D, look: bool, delta: float) -> void:
	if not Sfx.enabled:
		return

	var player: AudioStreamPlayer3D = r["player"]

	if player == null:
		player = AudioStreamPlayer3D.new()
		player.name = "run_%s" % r["loop"]
		player.stream = load("res://audio/ambience/%s.wav" % r["loop"])
		player.bus = Sfx.BUS_WORLD
		player.unit_size = 1.2
		player.max_distance = r["reach"]
		player.attenuation_filter_cutoff_hz = Sfx.AIR_CUTOFF
		player.attenuation_filter_db = Sfx.AIR_DB
		player.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		add_child(player)
		r["player"] = player
		Focus.hold(self, player, &"loop", float(Sfx.LOOP_GAIN[r["loop"]]))
		player.play(_rng.randf_range(0.0, player.stream.get_length()))

	if camera != null:
		var a := to_global(r["from"])
		var b := to_global(r["to"])
		var along := clampf((camera.global_position - a).dot(b - a) / maxf((b - a).length_squared(), 1e-6), 0.0, 1.0)
		player.global_position = a.lerp(b, along)

	if look:
		var hidden := Sfx.occlusion_at(self, player.global_position)
		r["target"] = float(Sfx.LOOP_GAIN[r["loop"]]) + (Sfx.OCCLUDED_DB if hidden >= 1.0 else (Sfx.AROUND_DB if hidden > 0.0 else 0.0))
		r["cutoff_to"] = Sfx.OCCLUDED_CUTOFF if hidden >= 1.0 else (Sfx.AROUND_CUTOFF if hidden > 0.0 else Sfx.AIR_CUTOFF)

	# (Eased, never in a step: the level by EASE_DB, the dulling along with it, log-wise.)
	r["level"] = move_toward(r["level"], r["target"], EASE_DB * delta)
	var gap := absf(r["target"] - r["level"]) / maxf(absf(Sfx.OCCLUDED_DB), 1.0)
	r["cutoff"] = exp(lerpf(log(r["cutoff_to"]), log(r["cutoff"]), clampf(gap, 0.0, 1.0)))
	Focus.base(player, r["level"])
	player.attenuation_filter_cutoff_hz = r["cutoff"]


## A knock's strikes laid out along its run from a place on it, toward its farther end, each further and fainter,
## stopping at the end.
func _knock(k: Dictionary) -> void:
	var a: Vector3 = k["from"]
	var b: Vector3 = k["to"]
	var length := a.distance_to(b)
	var way := (b - a) / maxf(length, 1e-6)
	var along := _rng.randf_range(0.0, length)
	# (Toward the longer side of the run from there, so it has room to travel.)
	var forward := 1.0 if along < length * 0.5 else -1.0
	var when := _clock
	var laid: Array = []
	_trains += 1

	for n in STRIKES:
		if along < 0.0 or along > length:
			break

		laid.append([when, to_global(a + way * along), STRIKE_FAINTER * n, _trains, false])
		along += forward * _rng.randf_range(STRIKE_ON.x, STRIKE_ON.y)
		when += _rng.randf_range(STRIKE_AFTER.x, STRIKE_AFTER.y)

	# (Its last strike lets go of whether it was let through.)
	if not laid.is_empty():
		laid[-1][4] = true

	_strikes.append_array(laid)

	_strikes.sort_custom(func(p: Array, q: Array) -> bool: return p[0] < q[0])


## Plays `sound` if Focus lets it (unless `ask` is false: a knock's later strikes); whether it played.
func _play(sound: StringName, at: Vector3, db: float, pitch: float, ask := true) -> bool:
	if ask and not Focus.allow(self, &"detail", at):
		played[&"refused"] = int(played.get(&"refused", 0)) + 1
		return false

	Sfx.play(self, sound, at, db, pitch)
	played[sound] = int(played.get(sound, 0)) + 1
	heard.append([_clock, sound, at])

	if heard.size() > 32:
		heard.pop_front()

	return true
