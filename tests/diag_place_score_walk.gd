extends Node
## A walk through the candle lane, recorded for listening (the Metro score
## spec, "Testing"): the place score plays as a listener moves along a set
## path, with the Metro's plan for its zones, and the Music bus is written to
## a WAV. Runs in real time (the audio's own).
##   Godot --headless --path . res://tests/diag_place_score_walk.tscn -- \
##     [--score=res://audio/music/metro/score.json] [--walk=lane|her|shop|all] \
##     [--pleading=<s>] [--out=<file.wav>]
## --pleading holds one begging ánima by you for that long at the walk's middle.
## Prints `WALK ok seconds=<n>` when the recording is the walk's length (headless,
## within the dummy driver's slowness) and the
## bed's downbeats in it fall a bar apart.

const FIXTURE := "res://tests/fixtures/place_score/score.json"
## The walk's places (the Metro's coordinates; the lane's floor is -11).
const MOUTH := Vector3(-2.0, -11.0, 75.45)
const HER := Vector3(12.8, -11.0, 74.2)
const DOOR := Vector3(19.0, -11.0, 78.4)
const SHOP := Vector3(19.0, -11.0, 82.0)
const PASAJE := Vector3(-6.0, -11.0, 75.45)
const PACE := 1.6
## Each walk: [where, seconds to stay there once arrived] in turn, from the first.
const WALKS := {
	"lane": [[MOUTH, 20.0], [Vector3(26.0, -11.0, 75.45), 10.0], [PASAJE, 5.0]],
	"her": [[MOUTH, 10.0], [HER, 30.0], [MOUTH, 5.0]],
	"shop": [[MOUTH, 10.0], [DOOR, 0.0], [SHOP, 30.0], [DOOR, 0.0], [MOUTH, 5.0]],
	"all": [[MOUTH, 20.0], [HER, 30.0], [DOOR, 0.0], [SHOP, 30.0], [DOOR, 0.0], [PASAJE, 5.0]],
}

var score_path := FIXTURE
var walk := "all"
var pleading := 0.0
var out_path := "user://place_score_walk.wav"
var _legs: Array = []
var _length := 0.0
var _started := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var value := arg.get_slice("=", 1)
		if arg.begins_with("--score="):
			score_path = value
		elif arg.begins_with("--walk="):
			walk = value
		elif arg.begins_with("--pleading="):
			pleading = float(value)
		elif arg.begins_with("--out="):
			out_path = value
	_plan_walk()
	var sfx := preload("res://scripts/Audio/Sfx.gd")
	sfx._ensure_buses()
	var record := AudioEffectRecord.new()
	record.format = AudioStreamWAV.FORMAT_16_BITS
	var music := AudioServer.get_bus_index(sfx.BUS_MUSIC)
	AudioServer.add_bus_effect(music, record)
	var score := PlaceScore.new()
	score.score_json_path = score_path
	score.listener_source = func() -> Vector3: return _where(_now())
	var middle := _length * 0.5
	score.animas_source = func() -> Array:
		var t := _now()
		if pleading > 0.0 and absf(t - middle) < pleading * 0.5:
			return [{"state": "pleading", "at": _where(t)}]
		return []
	AudioServer.lock()
	_started = Time.get_ticks_msec()
	record.set_recording_active(true)
	add_child(score)
	AudioServer.unlock()
	if not score.available:
		print("WALK failed: no score at %s" % score_path)
		get_tree().quit(1)
		return
	while _now() < _length:
		await get_tree().process_frame
	record.set_recording_active(false)
	var wav := record.get_recording()
	var path := ProjectSettings.globalize_path(out_path)
	wav.save_to_wav(path)
	var seconds := wav.get_length()
	var steady := _downbeats_a_bar_apart(wav, PlaceClock.bar_seconds(float(score.score.bpm), int(score.score.beats_per_bar)))
	# Headless, Godot's dummy driver mixes a few per cent slower than the clock.
	var ok := seconds >= _length * 0.9 - 1.0 and seconds <= _length + 1.0 and steady
	print("WALK %s seconds=%.1f (walk %.1f) downbeats_steady=%s -> %s" % ["ok" if ok else "failed", seconds, _length, steady, path])
	get_tree().quit(0 if ok else 1)


func _now() -> float:
	return (Time.get_ticks_msec() - _started) / 1000.0


## Legs: [from, to, leaves_at, arrives_at, stays_until].
func _plan_walk() -> void:
	var stops: Array = WALKS.get(walk, WALKS["all"])
	var at: Vector3 = stops[0][0]
	var t := float(stops[0][1])
	_legs.append([at, at, 0.0, 0.0, t])
	for i in range(1, stops.size()):
		var to: Vector3 = stops[i][0]
		var arrive := t + at.distance_to(to) / PACE
		var stay := arrive + float(stops[i][1])
		_legs.append([at, to, t, arrive, stay])
		at = to
		t = stay
	_length = t


func _where(t: float) -> Vector3:
	for leg in _legs:
		if t <= float(leg[4]):
			if t <= float(leg[3]) and float(leg[3]) > float(leg[2]):
				return (leg[0] as Vector3).lerp(leg[1], clampf((t - float(leg[2])) / (float(leg[3]) - float(leg[2])), 0.0, 1.0))
			return leg[1]
	return _legs[-1][1]


## Whether the fixture's clicks (every bar) after the cue are a bar apart (within 5 ms).
## A real score has no clicks: then this only checks that something sounded.
func _downbeats_a_bar_apart(wav: AudioStreamWAV, bar: float) -> bool:
	var data := wav.data
	var rate := wav.mix_rate
	var onsets := PackedInt64Array()
	var frames := data.size() / 4
	var loudest := 0
	for f in range(0, mini(frames, int(rate * 20.0)), 7):
		loudest = maxi(loudest, absi(data.decode_s16(f * 4)))
	var frame := 0
	while frame < frames and onsets.size() < 12:
		if absi(data.decode_s16(frame * 4)) > loudest / 2:
			onsets.append(frame)
			frame += int(rate * bar * 0.8)
		else:
			frame += 1
	if score_path != FIXTURE:
		return onsets.size() > 0
	if onsets.size() < 6:
		return false
	for i in range(2, onsets.size()):
		var gap := float(onsets[i] - onsets[i - 1]) / rate
		if absf(gap - bar) > 0.005:
			return false
	return true
