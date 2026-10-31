class_name PlaceScore
extends Node
## A place's score (docs/superpowers/specs/2026-10-31-metro-score-design.md):
## one piece that morphs as you go. A bed (drone, pulse, room) loops for as
## long as you are in the place; every space has a theme of its own, a locked
## set of stems on a player of its own, started on one of the bed's phrase
## lines and faded by how much it is where you stand (PlaceZones). Depth turns
## the bed's drone from city to deep and thins the themes' city parts. A theme
## you stay with grows full, then after a while rests on its bass alone.
## Everything is timed by the bed's audio position, never by frame time, so
## slow motion and hit-stops leave the music alone.
## Loads score.json (tools/prepare_place_score.py) and the .tres it names.
const Sfx := preload("res://scripts/Audio/Sfx.gd")

## Its own bus, under Music: the live effects (the ánimas) sit on it.
const BUS := &"PlaceScore"
const OUT := -80.0
## A stem coming in from silence starts its swell here (still inaudible).
const ENTRY := -40.0
const FADE_BARS := 2
const SWELL_BARS := 1
const STOP_AFTER_PHRASES := 1
## Weight units per second (of the music's time).
const WEIGHT_GLIDE := 0.8
const DEPTH_GLIDE := 0.5
const FULL_AFTER_PHRASES := 2
const REST_AFTER_LOOPS := 4
const REST_PHRASES := 2
const CITY_THIN_DB := 24.0
## Under this a theme counts as left (for its growth and rest).
const HELD := 0.5
## A weight this small is nothing.
const NONE := 0.001

@export var score_json_path := ""
@export var plan_path := "res://assets/eclipse/metro/plan.json"
## Where the listener is (a Vector3): by default the player's position.
var listener_source: Callable
## The bed's heard position (s); by default its player's, latency-corrected.
var position_source: Callable
## The bed's position where its next mixed chunk starts (s): themes start from it.
var raw_source: Callable
var zones: PlaceZones
var available := false
var score := {}
var depth := 0.0

var _bed := {}
var _themes := {}
var _phrase := 0.0
var _bar := 0.0
## Bed time: the bed's position run on across its loops.
var _time := 0.0
var _last_loop_pos := -1.0
var _loops := 0
var _raw_last := -1.0
var _raw_loops := 0
var _weights := {}


func _ready() -> void:
	Sfx._ensure_buses()
	ensure_bus()
	if not _load():
		return
	if zones == null and FileAccess.file_exists(plan_path):
		zones = PlaceZones.from_plan(JSON.parse_string(FileAccess.get_file_as_string(plan_path)), score.get("spaces", {}), score.get("circles", []))
	if not listener_source.is_valid():
		listener_source = _listener
	if not raw_source.is_valid():
		raw_source = position_source if position_source.is_valid() else _bed_raw
	if not position_source.is_valid():
		position_source = _bed_heard
	available = true
	_bed.player.play()


func _process(delta: float) -> void:
	step(delta)


## One frame: the clock, where you are, then each set's mix.
func step(_delta: float) -> void:
	if not available:
		return
	var before := _time
	_time = _bed_time()
	var dt := maxf(_time - before, 0.0)
	var point: Variant = listener_source.call()
	if zones != null and point is Vector3:
		var found := zones.weights_at(point)
		# In no space (a gap, mid-jump): the last weights hold.
		if not found.is_empty():
			_weights = found
			depth = move_toward(depth, zones.depth_at(point), DEPTH_GLIDE * dt)
	_mix_bed(dt)
	for name in _themes:
		_step_theme(_themes[name], dt)


func bed_playing() -> bool:
	return available and _bed.player.playing


func theme_playing(theme: StringName) -> bool:
	return _themes.has(theme) and bool(_themes[theme].playing)


## The bed time of the theme's last start (-1: never started).
func theme_started_at(theme: StringName) -> float:
	return float(_themes[theme].started_at) if _themes.has(theme) else -1.0


## How much the theme is where you are now, glided (0..1).
func theme_weight(theme: StringName) -> float:
	return float(_themes[theme].weight) if _themes.has(theme) else 0.0


## &"calm", &"full" or &"rest".
func intensity_of(theme: StringName) -> StringName:
	return StringName(_themes[theme].intensity) if _themes.has(theme) else &"calm"


## The loudest of the theme's stems now (dB).
func theme_gain_db(theme: StringName) -> float:
	if not _themes.has(theme):
		return OUT
	var loudest := OUT
	for id in _themes[theme].gains:
		loudest = maxf(loudest, float(_themes[theme].gains[id]))
	return loudest


## One stem's gain now (dB); the bed's stems are under the set &"bed".
func stem_gain_db(set_name: StringName, stem_id: StringName) -> float:
	var set: Dictionary = _bed if set_name == &"bed" else _themes.get(set_name, {})
	return float(set.get("gains", {}).get(stem_id, OUT))


## Stops it for good: every player let go of (leaving the map, tests).
func hush() -> void:
	for set in [_bed] + _themes.values():
		if set.has("player") and is_instance_valid(set.player):
			set.player.stop()
			set.player.stream = null
	_themes.clear()
	_bed = {}
	available = false


func _exit_tree() -> void:
	hush()


## Makes the score's bus once (a second score finds it already there).
static func ensure_bus() -> void:
	if AudioServer.get_bus_index(BUS) >= 0:
		return
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, BUS)
	AudioServer.set_bus_send(index, Sfx.BUS_MUSIC if AudioServer.get_bus_index(Sfx.BUS_MUSIC) >= 0 else &"Master")


func _load() -> bool:
	if score_json_path.is_empty() or not FileAccess.file_exists(score_json_path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(score_json_path))
	if not parsed is Dictionary or not parsed.has("bed"):
		return false
	score = parsed
	_bar = PlaceClock.bar_seconds(float(score.bpm), int(score.beats_per_bar))
	_phrase = _bar * int(score.phrase_bars)
	_bed = _make_set(&"bed", score.bed)
	if _bed.is_empty():
		return false
	for name in score.get("themes", {}):
		var set := _make_set(StringName(name), score.themes[name])
		if not set.is_empty():
			_themes[StringName(name)] = set
	return true


func _make_set(set_name: StringName, entry: Dictionary) -> Dictionary:
	var path := String(entry.get("resource", ""))
	if not ResourceLoader.exists(path):
		return {}
	var source := load(path) as AudioStreamSynchronized
	if source == null or source.stream_count != (entry.stems as Array).size():
		return {}
	var stream := source.duplicate() as AudioStreamSynchronized
	var player := AudioStreamPlayer.new()
	player.name = String(set_name)
	player.bus = BUS
	player.stream = stream
	add_child(player)
	var gains := {}
	for stem in entry.stems:
		gains[StringName(stem.id)] = OUT
		stream.set_sync_stream_volume(int(stem.index), OUT)
	return {"name": set_name, "entry": entry, "stream": stream, "player": player, "gains": gains,
		"loop": float(entry.loop_seconds), "weight": 0.0, "playing": false, "scheduled_at": -1.0,
		"started_at": -1.0, "silent_for": 0.0, "held": 0.0, "away": 0.0, "intensity": &"calm", "rest_left": 0.0}


func _mix_bed(dt: float) -> void:
	for stem in _bed.entry.stems:
		var target := 0.0
		match String(stem.get("role", "")):
			"drone_city":
				target = _db(1.0 - depth)
			"drone_deep":
				target = _db(depth)
		_slide(_bed, StringName(stem.id), target, dt)
	_apply(_bed)


func _step_theme(set: Dictionary, dt: float) -> void:
	var wanted := float(_weights.get(String(set.name), 0.0))
	set.weight = move_toward(float(set.weight), wanted, WEIGHT_GLIDE * dt)
	if not set.playing:
		if float(set.weight) <= NONE:
			set.scheduled_at = -1.0
			return
		if float(set.scheduled_at) < 0.0:
			set.scheduled_at = PlaceClock.next_phrase_line(_time, _phrase)
		if _time + MenuClock.SLACK < float(set.scheduled_at):
			return
		_start(set)
	_grow(set, dt)
	for stem in set.entry.stems:
		_slide(set, StringName(stem.id), _target(set, stem), dt)
	_apply(set)
	# A phrase at silence and nothing calling it back: let go of its player.
	if theme_gain_db(StringName(set.name)) <= OUT + 0.5 and float(set.weight) <= NONE:
		set.silent_for = float(set.silent_for) + dt
		if float(set.silent_for) >= STOP_AFTER_PHRASES * _phrase:
			set.player.stop()
			set.playing = false
			set.scheduled_at = -1.0
	else:
		set.silent_for = 0.0


## From its own top, as late as the bed already is past the line.
func _start(set: Dictionary) -> void:
	var line := float(set.scheduled_at)
	var late := clampf(_raw_time() - line, 0.0, float(set.loop) - 0.001)
	for id in set.gains:
		set.gains[id] = OUT
	_apply(set)
	AudioServer.lock()
	set.player.play(late)
	AudioServer.unlock()
	set.playing = true
	set.started_at = line
	set.scheduled_at = -1.0
	set.silent_for = 0.0
	set.held = 0.0
	set.away = 0.0
	set.intensity = &"calm"


## Calm, then full after a while with you, then a rest on its bass alone.
func _grow(set: Dictionary, dt: float) -> void:
	if set.intensity == &"rest":
		set.rest_left = float(set.rest_left) - dt
		if float(set.rest_left) <= MenuClock.SLACK:
			set.intensity = &"calm"
			set.held = 0.0
		return
	if float(set.weight) >= HELD:
		set.held = float(set.held) + dt
		set.away = 0.0
	else:
		set.away = float(set.away) + dt
		if float(set.away) >= _phrase:
			set.held = 0.0
			set.intensity = &"calm"
	if float(set.held) + MenuClock.SLACK >= REST_AFTER_LOOPS * float(set.loop):
		set.intensity = &"rest"
		set.rest_left = REST_PHRASES * _phrase
	elif float(set.held) + MenuClock.SLACK >= FULL_AFTER_PHRASES * _phrase:
		set.intensity = &"full"


## Where one of a theme's stems is heading (dB).
func _target(set: Dictionary, stem: Dictionary) -> float:
	if set.intensity == &"rest" and String(stem.get("part", "")) != "bass":
		return OUT
	if String(stem.get("intensity", "")) == "full" and set.intensity != &"full":
		return OUT
	if stem.has("haunted"):
		return OUT
	var target := _db(float(set.weight))
	if bool(stem.get("city", false)):
		target -= CITY_THIN_DB * depth
	return maxf(target, OUT)


## A gain sliding toward its target: up over SWELL_BARS from ENTRY, down to OUT over FADE_BARS.
func _slide(set: Dictionary, id: StringName, target: float, dt: float) -> void:
	var gain := float(set.gains[id])
	if target > gain:
		if gain < ENTRY:
			gain = ENTRY
		gain = move_toward(gain, target, (0.0 - ENTRY) / (SWELL_BARS * _bar) * dt)
	else:
		gain = move_toward(gain, target, (0.0 - OUT) / (FADE_BARS * _bar) * dt)
	set.gains[id] = gain


func _apply(set: Dictionary) -> void:
	for stem in set.entry.stems:
		set.stream.set_sync_stream_volume(int(stem.index), float(set.gains[StringName(stem.id)]))


func _db(amount: float) -> float:
	return OUT if amount <= NONE else maxf(linear_to_db(amount), OUT)


func _bed_time() -> float:
	var pos := fposmod(float(position_source.call()), float(_bed.loop))
	if _last_loop_pos >= 0.0 and pos < _last_loop_pos - float(_bed.loop) * 0.5:
		_loops += 1
	_last_loop_pos = pos
	return _loops * float(_bed.loop) + pos


func _raw_time() -> float:
	var pos := fposmod(float(raw_source.call()), float(_bed.loop))
	if _raw_last >= 0.0 and pos < _raw_last - float(_bed.loop) * 0.5:
		_raw_loops += 1
	_raw_last = pos
	return _raw_loops * float(_bed.loop) + pos


func _bed_raw() -> float:
	return _bed.player.get_playback_position() if _bed.player.playing else 0.0


func _bed_heard() -> float:
	if not _bed.player.playing:
		return 0.0
	return PlaceClock.heard(_bed.player.get_playback_position(), AudioServer.get_time_since_last_mix(), AudioServer.get_output_latency())


func _listener() -> Variant:
	var you := get_tree().get_first_node_in_group(&"player") as Node3D
	return you.global_position if you != null else null
