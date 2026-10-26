class_name MenuMusic
extends Node
## The menu theme: every stem plays at once, locked, in one AudioStreamSynchronized;
## four layers (base, low, high, fx) are weighted by where the player is in the
## menu, like Deadlock's Hideout. The chosen word's own instrument leans forward.
## Lives under the tree root so it can finish its phrase after the menu is gone.
const Sfx := preload("res://scripts/Audio/Sfx.gd")

signal started
signal ended

enum State { ARRIVAL, BROWSING, IDLE, LORE, SETTINGS, CONTINUE, STARTING, ARCHETYPE }

const SCORE_JSON := "res://audio/music/menu/score.json"
const LAYERS: Array[StringName] = [&"base", &"low", &"high", &"fx"]
const OUT := -80.0
## Each screen's layer levels (dB): the menu sits on base and low, Lore adds
## the occult fx, the archetype screen brings in high.
const TARGETS := {
	State.ARRIVAL: {&"base": 0.0, &"low": 0.0, &"high": OUT, &"fx": OUT},
	State.BROWSING: {&"base": 0.0, &"low": 0.0, &"high": OUT, &"fx": OUT},
	State.IDLE: {&"base": -10.0, &"low": OUT, &"high": OUT, &"fx": OUT},
	State.LORE: {&"base": 0.0, &"low": 0.0, &"high": OUT, &"fx": 0.0},
	State.SETTINGS: {&"base": 0.0, &"low": 0.0, &"high": OUT, &"fx": OUT},
	State.ARCHETYPE: {&"base": 0.0, &"low": 0.0, &"high": 0.0, &"fx": OUT},
}
const ARRIVAL_BARS := 4
const IDLE_AFTER := 30.0
const ACTIVITY_STEP := 0.35
const ACTIVITY_FALL := 0.12
## How fast a stem's gain moves toward its target (dB per second).
const SLEW := 24.0
## Where a layer coming in from silence starts its swell (still inaudible).
const ENTRY := -40.0
## Jingles at once: hovers overall, presses per word; the oldest gives way.
const HOVER_VOICES := 2
const PRESS_VOICES := 1
const GIVE_WAY := 0.03
## New Game: each layer is gone at this fraction of the way to the phrase's end.
const LEAVES := {&"high": 0.4, &"low": 0.75, &"fx": 0.75, &"base": 1.0}
## After the phrase's bar line, whatever is still sounding fades this fast.
const LAST_FADE := 0.15

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
## The arrival cue (when the score has one): it plays first, and the loop
## starts as it lands on the downbeat.
var arrival_player: AudioStreamPlayer
var _loop_in := 0.0
var _stream: AudioStreamSynchronized
var _gains: Dictionary = {}
var _idle := 0.0
var _wake_from := -1
## The last jingle started: {button, kind, chord, variant, started_at_pos}.
var last_jingle := {}
var _voices: Array[Dictionary] = []
var _pending: Array[Dictionary] = []
var _turns := {}
var _streams := {}
var _warned := {}
var _ending := {}

func _ready() -> void:
	# The loading screen pauses the tree; the song finishes its phrase under it.
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	available = true
	var cue := String(score.get("arrival", "")) if score.get("arrival") != null else ""
	if not cue.is_empty() and ResourceLoader.exists(cue):
		arrival_player = AudioStreamPlayer.new()
		arrival_player.name = "Arrival"
		arrival_player.bus = player.bus
		arrival_player.stream = load(cue)
		add_child(arrival_player)
		arrival_player.play()
		_loop_in = float(score.get("arrival_seconds", 0.0))
	else:
		player.play()

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
	if _loop_in > 0.0:
		_loop_in -= delta
		if _loop_in <= 0.0:
			player.play()
	var pos := loop_position()
	if state == State.STARTING:
		_end_step(pos)
		return
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
		var target := stem_target_db(id)
		var gain := float(_gains[id])
		# A layer coming in from silence starts where it is still inaudible.
		if target > gain and gain < ENTRY:
			gain = ENTRY
		_gains[id] = move_toward(gain, target, SLEW * delta)
	_mix()
	_play_due(pos)

## Presses waiting for their eighth note (which may lie past the loop's end).
func _play_due(pos: float) -> void:
	for press_at in _pending.duplicate():
		var due: bool = pos >= float(press_at.at) and (not press_at.wraps or pos < float(press_at.from))
		if due:
			_pending.erase(press_at)
			_play(int(press_at.button), "press", String(press_at.chord), pos)
	_live_voices()

## A word was hovered or focused: its instrument answers at once, in the chord now.
func hover(button: int) -> void:
	if not available or state == State.STARTING:
		return
	var pos := loop_position()
	_play(button, "hover", _chord_at(pos), pos)

## A word was pressed: its phrase starts on the next eighth note.
func press(button: int) -> void:
	if not available or state == State.STARTING:
		return
	var pos := loop_position()
	var at := MenuClock.next_eighth(pos, float(score.bpm))
	var loop := float(score.loop_seconds)
	var wraps := at >= loop
	if wraps:
		at -= loop
	_pending = _pending.filter(func(p): return int(p.button) != button)
	_pending.append({"button": button, "at": at, "wraps": wraps, "from": pos, "chord": _chord_at(at)})

func hover_voices_playing() -> int:
	return _live_voices().filter(func(v): return v.kind == "hover" and not v.fading).size()

func press_voices_playing(button: int) -> int:
	return _live_voices().filter(func(v): return v.kind == "press" and v.button == button and not v.fading).size()

## Voices still sounding (a voice can be freed between frames when it finishes).
func _live_voices() -> Array[Dictionary]:
	_voices = _voices.filter(func(v): return is_instance_valid(v.player) and v.player.playing)
	return _voices

func _chord_at(pos: float) -> String:
	return MenuClock.chord_at(score.chords, MenuClock.bar_at(pos, float(score.bpm), int(score.beats_per_bar)), int(score.bars))

func _play(button: int, kind: String, chord: String, pos: float) -> void:
	var table: Dictionary = score.get("jingles", {}).get(str(button), {}).get(kind, {})
	if table.is_empty():
		return
	if not table.has(chord):
		if not _warned.has(chord):
			_warned[chord] = true
			push_warning("Menu score has no %s jingle in %s; using the loop's first chord." % [kind, chord])
		chord = String(score.chords[0].name) if table.has(String(score.chords[0].name)) else String(table.keys()[0])
	var paths: Array = table[chord]
	var key := "%d|%s|%s" % [button, kind, chord]
	var variant: int = int(_turns.get(key, 0)) % paths.size()
	_turns[key] = variant + 1
	var path := String(paths[variant])
	if not _streams.has(path):
		_streams[path] = load(path)
	# Make room: hovers share HOVER_VOICES, each word has PRESS_VOICES presses.
	var same := _live_voices().filter(func(v): return not v.fading and v.kind == kind and (kind == "hover" or v.button == button))
	var limit := HOVER_VOICES if kind == "hover" else PRESS_VOICES
	while same.size() >= limit:
		_give_way(same.pop_front())
	var voice := AudioStreamPlayer.new()
	voice.bus = player.bus
	voice.stream = _streams[path]
	add_child(voice)
	voice.play()
	voice.finished.connect(voice.queue_free)
	_voices.append({"player": voice, "kind": kind, "button": button, "fading": false})
	last_jingle = {"button": button, "kind": kind, "chord": chord, "variant": variant, "started_at_pos": pos}

func _give_way(voice: Dictionary) -> void:
	voice.fading = true
	var fade := create_tween()
	fade.tween_property(voice.player, "volume_db", OUT, GIVE_WAY)
	fade.tween_callback(voice.player.queue_free)

## New Game: the song plays on to the end of its phrase, thinning out (high
## first, then low and fx, then base) and fading to silence on that bar line.
## Less than a bar left, it finishes the next phrase instead. Then it frees itself.
func start_game() -> void:
	if not available:
		started.emit()
		ended.emit()
		queue_free()
		return
	if state == State.STARTING:
		return
	var pos := loop_position()
	var bpm := float(score.bpm)
	var bar_len := MenuClock.beat_seconds(bpm) * int(score.beats_per_bar)
	var end := MenuClock.phrase_end_after(pos, bpm, int(score.beats_per_bar), int(score.phrase_bars))
	if end - pos < bar_len:
		end += bar_len * int(score.phrase_bars)
	state = State.STARTING
	_ending = {"span": end - pos, "elapsed": 0.0, "last": pos, "end": end, "from": _gains.duplicate()}
	started.emit()

## Where (in loop seconds, unwrapped) the ending lands.
func ending_at() -> float:
	return float(_ending.get("end", -1.0))

## 0..1 of the way through the ending (0 when not ending).
func ending_progress() -> float:
	return float(_ending.get("elapsed", 0.0)) / float(_ending.span) if _ending.has("span") else 0.0

func _end_step(pos: float) -> void:
	if _ending.get("done", false):
		return
	var moved := pos - float(_ending.last)
	# A real wrap jumps back most of the loop; a hair back is the heard
	# position's jitter (mix timing), not time passing.
	if moved < -float(score.loop_seconds) * 0.5:
		moved += float(score.loop_seconds)
	elif moved < 0.0:
		moved = 0.0
	_ending.elapsed = float(_ending.elapsed) + moved
	_ending.last = pos
	var f := float(_ending.elapsed) / float(_ending.span)
	for stem in score.stems:
		var id := StringName(stem.id)
		var k := clampf(f / float(LEAVES[StringName(stem.layer)]), 0.0, 1.0)
		_gains[id] = OUT if k >= 1.0 else maxf(float(_ending.from[id]) + linear_to_db(1.0 - k), OUT)
	_mix()
	_play_due(pos)
	if f >= 1.0:
		# The phrase is over. Anything still sounding (a stall can carry the
		# song past its bar line at its last gain) fades, never cuts.
		_ending.done = true
		ended.emit()
		var tail := create_tween()
		tail.tween_property(player, "volume_db", OUT, LAST_FADE)
		tail.tween_callback(player.stop)
		tail.tween_callback(queue_free)

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
	return float(TARGETS[current][layer])

## Where one stem is heading: its layer's level.
func stem_target_db(stem_id: StringName) -> float:
	var stem := _stem(stem_id)
	if stem.is_empty():
		return OUT
	return layer_target_db(StringName(stem.layer))

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
