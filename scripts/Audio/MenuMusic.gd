class_name MenuMusic
extends Node
## The menu theme: every stem plays at once, locked, in one AudioStreamSynchronized;
## four layers (base, low, high, fx) are weighted by where the player is in the
## menu, like Deadlock's Hideout. The chosen word's own instrument leans forward.
## Lives under the tree root so it can finish its phrase after the menu is gone.
const Sfx := preload("res://scripts/Audio/Sfx.gd")

enum State { ARRIVAL, BROWSING, IDLE, LORE, SETTINGS, CONTINUE, STARTING }

const SCORE_JSON := "res://audio/music/menu/score.json"
const LAYERS: Array[StringName] = [&"base", &"low", &"high", &"fx"]
const OUT := -80.0
## Each state's layer levels (dB). ARRIVAL's low and BROWSING's high are
## worked out live (the groove's entrance; how busy the player is).
const TARGETS := {
	State.ARRIVAL: {&"base": 0.0, &"low": OUT, &"high": OUT, &"fx": 0.0},
	State.BROWSING: {&"base": 0.0, &"low": 0.0, &"high": OUT, &"fx": -12.0},
	State.IDLE: {&"base": -10.0, &"low": OUT, &"high": OUT, &"fx": -14.0},
	State.LORE: {&"base": 0.0, &"low": -12.0, &"high": -14.0, &"fx": 0.0},
	State.SETTINGS: {&"base": 0.0, &"low": -14.0, &"high": OUT, &"fx": -14.0},
}
const ARRIVAL_BARS := 4
const HIGH_BUSY := -3.0
const IDLE_AFTER := 30.0
const ACTIVITY_STEP := 0.35
const ACTIVITY_FALL := 0.12
const LEAN := 4.0
## How fast a stem's gain moves toward its target (dB per second).
const SLEW := 24.0

@export var score_json_path := SCORE_JSON
var available := false
var state := State.ARRIVAL
var score: Dictionary = {}
## Loop position in seconds; by default what the player is heard to be at.
var position_source: Callable
## 0..1, how busy the player has been lately; brings the high layer in.
var activity := 0.0
var selected := -1
var player: AudioStreamPlayer
var _stream: AudioStreamSynchronized
var _gains: Dictionary = {}
var _idle := 0.0
var _wake_from := -1

func _ready() -> void:
	Sfx._ensure_buses()
	if not position_source.is_valid():
		position_source = _heard_position
	if not _load_score():
		return
	player = AudioStreamPlayer.new()
	player.name = "Score"
	player.bus = Sfx.BUS_MUSIC if AudioServer.get_bus_index(Sfx.BUS_MUSIC) >= 0 else &"Master"
	player.stream = _stream
	add_child(player)
	for stem in score.stems:
		_gains[StringName(stem.id)] = OUT
	_mix()
	player.play()
	available = true

func _load_score() -> bool:
	if not FileAccess.file_exists(score_json_path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(score_json_path))
	if not parsed is Dictionary:
		return false
	var resource := score_json_path.get_base_dir().path_join("score.tres")
	if not ResourceLoader.exists(resource):
		return false
	var source := load(resource) as AudioStreamSynchronized
	if source == null or source.stream_count != (parsed.stems as Array).size():
		return false
	score = parsed
	_stream = source.duplicate() as AudioStreamSynchronized
	return true

func _process(delta: float) -> void:
	step(delta)

## One frame of the menu score: timekeeping, state changes, then the mix.
func step(delta: float) -> void:
	if not available:
		return
	var pos := loop_position()
	var bar := MenuClock.bar_at(pos, float(score.bpm), int(score.beats_per_bar))
	activity = maxf(activity - ACTIVITY_FALL * delta, 0.0)
	if state == State.ARRIVAL and bar >= ARRIVAL_BARS:
		state = State.BROWSING
	if state == State.BROWSING:
		_idle += delta
		if _idle >= IDLE_AFTER:
			state = State.IDLE
	if state == State.IDLE and _wake_from >= 0 and bar != _wake_from:
		_wake_from = -1
		state = State.BROWSING
	for stem in score.stems:
		var id := StringName(stem.id)
		_gains[id] = move_toward(float(_gains[id]), stem_target_db(id), SLEW * delta)
	_mix()

func set_state(next: State) -> void:
	if not available or state == State.STARTING:
		return
	state = next
	_wake_from = -1
	_idle = 0.0

func set_selected(button: int) -> void:
	selected = button

## The player did something: wakes an idle menu on the next bar line.
func note_input() -> void:
	if not available:
		return
	_idle = 0.0
	activity = minf(activity + ACTIVITY_STEP, 1.0)
	if state == State.IDLE and _wake_from < 0:
		_wake_from = MenuClock.bar_at(loop_position(), float(score.bpm), int(score.beats_per_bar))

func loop_position() -> float:
	var pos: float = position_source.call()
	return fposmod(pos, float(score.loop_seconds)) if available else pos

## Where the layer is heading now (dB).
func layer_target_db(layer: StringName) -> float:
	if not available:
		return OUT
	var current := State.BROWSING if state == State.CONTINUE or state == State.STARTING else state
	if current == State.ARRIVAL and layer == &"low":
		var bars := MenuClock.beat_seconds(float(score.bpm)) * int(score.beats_per_bar) * ARRIVAL_BARS
		return maxf(linear_to_db(clampf(loop_position() / bars, 0.0, 1.0)), OUT)
	if current == State.BROWSING and layer == &"high":
		return maxf(linear_to_db(db_to_linear(HIGH_BUSY) * activity), OUT)
	return float(TARGETS[current][layer])

## Where one stem is heading: its layer's level, plus the lean if its word is chosen.
func stem_target_db(stem_id: StringName) -> float:
	var stem := _stem(stem_id)
	if stem.is_empty():
		return OUT
	var target := layer_target_db(StringName(stem.layer))
	if selected >= 0 and int(stem.button) == selected and target > OUT:
		target = minf(target + LEAN, 0.0)
	return target

func stem_gain_db(stem_id: StringName) -> float:
	return float(_gains.get(stem_id, OUT))

## 0..1: how present a layer is right now (its loudest stem), for the visuals.
func layer_energy(layer: StringName) -> float:
	if not available:
		return 0.0
	var loudest := OUT
	for stem in score.stems:
		if StringName(stem.layer) == layer:
			loudest = maxf(loudest, stem_gain_db(StringName(stem.id)))
	return 0.0 if loudest <= OUT else clampf(db_to_linear(loudest), 0.0, 1.0)

func _stem(stem_id: StringName) -> Dictionary:
	for stem in score.get("stems", []):
		if StringName(stem.id) == stem_id:
			return stem
	return {}

func _mix() -> void:
	for stem in score.stems:
		_stream.set_sync_stream_volume(int(stem.index), float(_gains[StringName(stem.id)]))

func _heard_position() -> float:
	if player == null or not player.playing:
		return 0.0
	return MenuClock.corrected(player.get_playback_position(), AudioServer.get_time_since_last_mix(), AudioServer.get_output_latency())
