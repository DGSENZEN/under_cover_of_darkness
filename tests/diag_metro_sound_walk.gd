extends Node
## A walk through the Metro, recorded for listening (docs/superpowers/specs/2026-10-31-metro-sound-design.md, "Order
## of work" 8): the real map (maps/metro.tscn: its beds, train, station machine, lane, shop and score), the player
## carried along the plan's own walks at a walking pace (its body still, only where it stands moving), Master written
## to a WAV. A train is sent through at the start, on the platform. Runs in real time (the audio's own).
##   Godot --headless --path . res://tests/diag_metro_sound_walk.tscn -- [--out=<file.wav>]
## Prints `WALK ok seconds=<n> -> <path>`, then each family as it is entered (`ENTER <s> <family>`, in the recording's own
## seconds: headless, the dummy driver mixes slower than the clock, more so the more is sounding).

const METRO := preload("res://maps/metro.tscn")
const PLAN := "res://assets/eclipse/metro/plan.json"
## Walking pace (m/s); how long it stays at each of the walk's stops in the lane (s); how high the player stands over a
## floor point (its origin, as the map spawns it).
const PACE := 1.6
const STAY := 6.0
const STAND := 1.05
## The candle lane after the market walk ends at its mouth: her stall, the shop's door, inside the shop, out again.
const LANE := [Vector3(12.8, -11.0, 74.2), Vector3(19.0, -11.0, 78.4), Vector3(19.0, -11.0, 82.0), Vector3(19.0, -11.0, 78.4)]

var out_path := "user://metro_sound_walk.wav"
var _points: Array[Vector3] = []
var _stays: Array[float] = []
var _started := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_path = arg.get_slice("=", 1)
	# (Sound is off headless by default: there it is what is being recorded.)
	preload("res://scripts/Audio/Sfx.gd").enabled = true
	var plan: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PLAN))
	_route(plan)
	var metro: Node3D = METRO.instantiate()
	add_child(metro)
	await get_tree().process_frame
	await get_tree().process_frame
	var player: Node3D = metro.get("player")
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var sound: PlaceSound = metro.get_node("PlaceSound")
	var record := AudioEffectRecord.new()
	record.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(AudioServer.get_bus_index(&"Master"), record)
	_started = Time.get_ticks_msec()
	record.set_recording_active(true)
	var length := _length()
	var family := ""
	var entered := []
	var sent := false
	while _now() < length:
		player.global_position = _where(_now()) + Vector3(0.0, STAND, 0.0)
		if not sent and _now() > 3.0:
			sent = true
			sound.train.start_pass()
		var weights := sound.family_weights_at(player.global_position)
		var most := ""
		for name in weights:
			if most == "" or float(weights[name]) > float(weights[most]):
				most = name
		if most != "" and most != family:
			family = most
			entered.append([_now(), family])
		await get_tree().process_frame
	record.set_recording_active(false)
	var wav := record.get_recording()
	var path := ProjectSettings.globalize_path(out_path)
	wav.save_to_wav(path)
	var heard := wav.get_length()
	print("WALK %s seconds=%.1f (walk %.1f) -> %s" % ["ok" if heard >= length * 0.8 else "failed", heard, length, path])
	for entry: Array in entered:
		print("ENTER %.1f %s" % [float(entry[0]) * heard / length, entry[1]])
	get_tree().quit(0)


func _now() -> float:
	return (Time.get_ticks_msec() - _started) / 1000.0


## The market walk, on through the lane to her stall and the shop and out, then (a cut) the old walk from the platform.
func _route(plan: Dictionary) -> void:
	for p: Array in plan.walks.market:
		_points.append(Vector3(p[0], p[1], p[2]))
		_stays.append(0.0)
	_stays[0] = 8.0
	for p: Vector3 in LANE:
		_points.append(p)
		_stays.append(STAY)
	_points.append(Vector3(-14.0, -11.0, 74.0))
	_stays.append(-1.0)
	for p: Array in plan.walks.old:
		_points.append(Vector3(p[0], p[1], p[2]))
		_stays.append(0.0)
	_stays[_stays.size() - 1] = 12.0


## The walk timed: [from, to, leaves, arrives, stays until] per leg; a stay of -1 before a point is a cut to it.
func _legs() -> Array:
	var legs := []
	var t := _stays[0]
	for i in range(1, _points.size()):
		var cut := _stays[i - 1] < 0.0
		var arrive := t + (0.0 if cut else _points[i - 1].distance_to(_points[i]) / PACE)
		legs.append([_points[i - 1], _points[i], t, arrive, arrive + maxf(_stays[i], 0.0)])
		t = arrive + maxf(_stays[i], 0.0)
	return legs


func _length() -> float:
	return float(_legs()[-1][4])


func _where(t: float) -> Vector3:
	if t <= _stays[0]:
		return _points[0]
	for leg: Array in _legs():
		if t <= float(leg[4]):
			if t <= float(leg[3]) and float(leg[3]) > float(leg[2]):
				return (leg[0] as Vector3).lerp(leg[1], clampf((t - float(leg[2])) / (float(leg[3]) - float(leg[2])), 0.0, 1.0))
			return leg[1]
	return _points[-1]
