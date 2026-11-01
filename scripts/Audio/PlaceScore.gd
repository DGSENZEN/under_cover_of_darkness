class_name PlaceScore
extends Node
## A place's score (docs/superpowers/specs/2026-10-31-metro-score-design.md):
## one piece that morphs as you go. A bed (drone, pulse, room) loops for as
## long as you are in the place; every space has a theme of its own, a locked
## set of stems on a player of its own, started on one of the bed's phrase
## lines and faded by how much it is where you stand (PlaceZones). Depth turns
## the bed's drone from city to deep and thins the themes' city parts. A theme may keep
## only some of the bed under it (the candle lane: the city drone, no pulse). A theme
## you stay with grows full, then after a while rests on its bass alone. What
## you have done picks a theme's variants (PeopleState), on its phrase lines.
## What the ánimas do near you (never their being near) bends it: one begging
## you detunes it, one straining or dragged back makes the pulse falter under
## a muffle, a swarm of them out at once; each act also brings in the stems
## written for it (`haunted`). On arriving, the entrance cue plays first and
## the bed comes in where it lands; in a fight the whole score sinks under the
## combat score (Music) and comes back as the fight fades.
## Everything is timed by the bed's audio position, never by frame time, so
## slow motion and hit-stops leave the music alone.
## Loads score.json (tools/prepare_place_score.py) and the .tres it names.
const Sfx := preload("res://scripts/Audio/Sfx.gd")
const AnimasScript := preload("res://scripts/Visual/Animas.gd")

## Its own bus, under Music: the live effects (the ánimas) sit on it.
const BUS := &"PlaceScore"
const OUT := -80.0
## A stem coming in from silence starts its swell here (still inaudible).
const ENTRY := -40.0
## A theme fades out over this many bars and swells in over this many (it follows you: a space's theme is up within
## a beat and half a bar of walking in, gone a bar after you leave).
const FADE_BARS := 1.0
const SWELL_BARS := 0.5
const STOP_AFTER_PHRASES := 1
## Weight units per second (of the music's time).
const WEIGHT_GLIDE := 2.0
const DEPTH_GLIDE := 0.5
const FULL_AFTER_PHRASES := 2
const REST_AFTER_LOOPS := 4
const REST_PHRASES := 2
const CITY_THIN_DB := 24.0
## Under this a theme counts as left (for its growth and rest).
const HELD := 0.5
## A weight this small is nothing.
const NONE := 0.001
## The ánimas within this (m) of you count; their acts ease in and out (per second).
const HAUNT_RANGE := 8.0
const HAUNT_RISE := 2.0
const HAUNT_FALL := 0.5
## This many out of the drain at once (not below) half swarm; one more, fully.
const SWARM_FROM := 4
const DETUNE_WET := 0.35
const MUFFLE_HZ := 1800.0
const OPEN_HZ := 20000.0
const PULSE_FALTER_DB := -12.0
## Under a fight at its height (the combat score's intensity 1), this much (dB).
const UNDER_COMBAT_DB := -18.0
const ACTS: Array[StringName] = [&"pleading", &"straining", &"dragged", &"swarm"]
## The ánimas are looked for this often (s).
const FIND_EVERY := 1.0

@export var score_json_path := ""
@export var plan_path := "res://assets/eclipse/metro/plan.json"
## Whether the entrance cue (score.json `cue`) plays before the bed.
@export var play_cue := true
## Where the listener is (a Vector3): by default the player's position.
var listener_source: Callable
## The bed's heard position (s); by default its player's, latency-corrected.
var position_source: Callable
## The bed's position where its next mixed chunk starts (s): themes start from it.
var raw_source: Callable
var zones: PlaceZones
## What the people of the city remember (a PeopleState, or null).
var people_source: Callable
## The ánimas near you: [{state, at}]; by default every Animas node's souls in HAUNT_RANGE.
var animas_source: Callable
## The cue's position (s); by default its player's.
var cue_source: Callable
## The combat score's intensity now (0..1); by default the level's Music node's.
var music_source: Callable
var cue_player: AudioStreamPlayer
var available := false
var score := {}
var depth := 0.0

var _bed := {}
var _themes := {}
var _phrase := 0.0
var _bar := 0.0
var _beat := 0.0
## Bed time: the bed's position run on across its loops, as heard and as mixed.
var _time := 0.0
var _raw := 0.0
var _last_loop_pos := -1.0
var _loops := 0
var _weights := {}
var _haunt := {&"pleading": 0.0, &"straining": 0.0, &"dragged": 0.0, &"swarm": 0.0}
var _animas: Array = []
var _find_in := 0.0


func _ready() -> void:
	Sfx._ensure_buses()
	ensure_bus()
	if not _load():
		return
	if zones == null and FileAccess.file_exists(plan_path):
		zones = PlaceZones.from_plan(JSON.parse_string(FileAccess.get_file_as_string(plan_path)), score.get("spaces", {}), score.get("circles", []))
	if not people_source.is_valid():
		people_source = func() -> Variant: return CityState.people
	if not listener_source.is_valid():
		listener_source = _listener
	if not animas_source.is_valid():
		animas_source = _near_animas
	if not cue_source.is_valid():
		cue_source = func() -> float: return cue_player.get_playback_position() if cue_player != null and cue_player.playing else 0.0
	if not music_source.is_valid():
		music_source = _fight
	if not raw_source.is_valid():
		raw_source = position_source if position_source.is_valid() else _bed_raw
	if not position_source.is_valid():
		position_source = _bed_heard
	available = true
	var cue: Variant = score.get("cue")
	if play_cue and cue is Dictionary and ResourceLoader.exists(String(cue.path)):
		cue_player = AudioStreamPlayer.new()
		cue_player.name = "Cue"
		cue_player.bus = BUS
		cue_player.stream = load(String(cue.path))
		add_child(cue_player)
		cue_player.play()
	else:
		_bed.player.play()


func _process(delta: float) -> void:
	step(delta)


## One frame: the clock, where you are, then each set's mix.
func step(_delta: float) -> void:
	if not available:
		return
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUS), UNDER_COMBAT_DB * clampf(float(music_source.call()), 0.0, 1.0))
	if not _bed.player.playing:
		# The entrance cue: the bed comes in where it lands, the themes after it.
		# (A cue landing on its own end stops there: its having ended is landing too.)
		if cue_player != null and (not cue_player.playing or float(cue_source.call()) + MenuClock.SLACK >= int(score.cue.lands_bar) * _bar):
			# The cue lands on the bed's first downbeat: it is there at once, at full,
			# already at the depth of where you stand.
			# The place's own theme comes in with it, on the land.
			var here: Variant = listener_source.call()
			if zones != null and here is Vector3 and not zones.weights_at(here).is_empty():
				depth = zones.depth_at(here)
				_weights = zones.weights_at(here)
				for name in _themes:
					var set: Dictionary = _themes[name]
					set.weight = float(_weights.get(String(name), 0.0))
					if float(set.weight) > NONE:
						set.scheduled_at = 0.0
			_mix_bed(0.0, true)
			_bed.player.play()
		return
	var before := _time
	_time = _bed_time()
	_raw = _raw_time()
	var dt := maxf(_time - before, 0.0)
	var point: Variant = listener_source.call()
	if zones != null and point is Vector3:
		var found := zones.weights_at(point)
		# In no space (a gap, mid-jump): the last weights hold.
		if not found.is_empty():
			_weights = found
			depth = move_toward(depth, zones.depth_at(point), DEPTH_GLIDE * dt)
	_haunted_by(dt)
	_mix_bed(dt)
	for name in _themes:
		_step_theme(_themes[name], dt)


## How much each of the ánimas' acts is upon the music now (0..1).
func haunt() -> Dictionary:
	return _haunt.duplicate()


## The score bus's detune and muffle.
static func chorus() -> AudioEffectChorus:
	ensure_bus()
	return AudioServer.get_bus_effect(AudioServer.get_bus_index(BUS), 0) as AudioEffectChorus


static func muffle() -> AudioEffectLowPassFilter:
	ensure_bus()
	return AudioServer.get_bus_effect(AudioServer.get_bus_index(BUS), 1) as AudioEffectLowPassFilter


func cue_playing() -> bool:
	return cue_player != null and cue_player.playing


func bed_playing() -> bool:
	return available and _bed.player.playing


func theme_playing(theme: StringName) -> bool:
	return _themes.has(theme) and bool(_themes[theme].playing)


## The bed time of the theme's last start (-1: never started).
func theme_started_at(theme: StringName) -> float:
	return float(_themes[theme].started_at) if _themes.has(theme) else -1.0


## How far into itself the theme's player began, at its last start (s).
func theme_start_offset(theme: StringName) -> float:
	return float(_themes[theme].offset) if _themes.has(theme) else 0.0


## How much the theme is where you are now, glided (0..1).
func theme_weight(theme: StringName) -> float:
	return float(_themes[theme].weight) if _themes.has(theme) else 0.0


## The stem playing a part of a theme now (its variant, or its default).
func part_choice(theme: StringName, part: StringName) -> StringName:
	return StringName(_themes[theme].choice.get(part, &"")) if _themes.has(theme) else &""


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
	if cue_player != null and is_instance_valid(cue_player):
		cue_player.stop()
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
	var detune := AudioEffectChorus.new()
	detune.dry = 1.0
	detune.wet = 0.0
	AudioServer.add_bus_effect(index, detune)
	var low := AudioEffectLowPassFilter.new()
	low.cutoff_hz = OPEN_HZ
	AudioServer.add_bus_effect(index, low)


func _load() -> bool:
	if score_json_path.is_empty() or not FileAccess.file_exists(score_json_path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(score_json_path))
	if not parsed is Dictionary or not parsed.has("bed"):
		return false
	score = parsed
	_bar = PlaceClock.bar_seconds(float(score.bpm), int(score.beats_per_bar))
	_phrase = _bar * int(score.phrase_bars)
	_beat = MenuClock.beat_seconds(float(score.bpm))
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
		"started_at": -1.0, "silent_for": 0.0, "held": 0.0, "away": 0.0, "intensity": &"calm", "rest_left": 0.0,
		"choice": {}, "line": -1, "offset": 0.0}


func _mix_bed(dt: float, at_once := false) -> void:
	for stem in _bed.entry.stems:
		var target := 0.0
		match String(stem.get("role", "")):
			"drone_city":
				target = _db(1.0 - depth)
			"drone_deep":
				target = _db(depth)
			"pulse":
				target = PULSE_FALTER_DB * maxf(float(_haunt[&"straining"]), float(_haunt[&"dragged"]))
		target = maxf(target + _db(_bed_share(String(stem.get("role", "")))), OUT)
		if at_once:
			_bed.gains[StringName(stem.id)] = target
		else:
			_slide(_bed, StringName(stem.id), target, dt)
	_apply(_bed)


## How much of a bed role plays now (0..1): all of it outside any theme; under a theme
## that names its bed (score.json `bed`), only the roles it names, and those its haunts
## bring back (`haunt_bed`) while an anima act is on.
func _bed_share(role: String) -> float:
	var taken := 0.0
	var kept := 0.0
	var haunting := 0.0
	for act in ACTS:
		haunting = maxf(haunting, float(_haunt[act]))
	for name in _themes:
		var set: Dictionary = _themes[name]
		var w := float(set.weight)
		if w <= NONE or not set.entry.has("bed"):
			continue
		taken += w
		if role in set.entry.bed:
			kept += w
		elif role in set.entry.get("haunt_bed", []):
			kept += w * haunting
	return clampf(1.0 - minf(taken, 1.0) + kept, 0.0, 1.0)


func _step_theme(set: Dictionary, dt: float) -> void:
	var wanted := float(_weights.get(String(set.name), 0.0))
	set.weight = move_toward(float(set.weight), wanted, WEIGHT_GLIDE * dt)
	if not set.playing:
		if float(set.weight) <= NONE:
			set.scheduled_at = -1.0
			return
		if float(set.scheduled_at) < 0.0:
			set.scheduled_at = PlaceClock.next_line(_time, _beat)
		# Started when the bed's next mixed chunk reaches the line (the mixer runs
		# ahead of what is heard), so both are mixed from the same place.
		if _raw + MenuClock.SLACK < float(set.scheduled_at):
			return
		_start(set)
	_grow(set, dt)
	# Its variants change on its phrase lines only, never mid-phrase (its phrases run with the bed's).
	var line := floori((_time + MenuClock.SLACK) / _phrase)
	if line != int(set.line):
		set.line = line
		_choose(set)
	for stem in set.entry.stems:
		var id := StringName(stem.id)
		var swapped_out: bool = stem.has("part") and set.choice.get(StringName(stem.part), id) != id
		_slide(set, id, OUT if swapped_out else _target(set, stem), dt, 1.0 if swapped_out else FADE_BARS)
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


## On a beat, from where the bed is in its phrase (so its phrase runs with the bed's), as late as the bed already is
## past the beat.
func _start(set: Dictionary) -> void:
	var line := float(set.scheduled_at)
	var late := clampf(fposmod(line, _phrase) + _raw - line, 0.0, float(set.loop) - 0.001)
	for id in set.gains:
		set.gains[id] = OUT
	_apply(set)
	AudioServer.lock()
	set.player.play(late)
	AudioServer.unlock()
	set.playing = true
	set.started_at = line
	set.offset = late
	set.scheduled_at = -1.0
	set.silent_for = 0.0
	set.held = 0.0
	set.away = 0.0
	set.intensity = &"calm"
	set.line = -1


## For each part: the first of its variants whose condition holds, else the one with none.
func _choose(set: Dictionary) -> void:
	var people: Variant = people_source.call() if people_source.is_valid() else null
	var chosen := {}
	for stem in set.entry.stems:
		if not stem.has("part"):
			continue
		var part := StringName(stem.part)
		if chosen.has(part):
			continue
		if not stem.has("variant"):
			chosen[part] = StringName(stem.id)
		elif people != null and people.holds(String(stem.variant.when), String(stem.variant.character)):
			chosen[part] = StringName(stem.id)
	set.choice = chosen


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
	var target := _db(float(set.weight))
	if stem.has("haunted"):
		target += _db(float(_haunt.get(StringName(stem.haunted), 0.0)))
	if bool(stem.get("city", false)):
		target -= CITY_THIN_DB * depth
	return maxf(target, OUT)


## A gain sliding toward its target: up over SWELL_BARS from ENTRY, down to OUT over fade_bars.
func _slide(set: Dictionary, id: StringName, target: float, dt: float, fade_bars: float = FADE_BARS) -> void:
	var gain := float(set.gains[id])
	if target > gain:
		if gain < ENTRY:
			gain = ENTRY
		gain = move_toward(gain, target, (0.0 - ENTRY) / (SWELL_BARS * _bar) * dt)
	else:
		gain = move_toward(gain, target, (0.0 - OUT) / (fade_bars * _bar) * dt)
	set.gains[id] = gain


func _apply(set: Dictionary) -> void:
	for stem in set.entry.stems:
		set.stream.set_sync_stream_volume(int(stem.index), float(set.gains[StringName(stem.id)]))


## The ánimas' acts near you, eased; the bus's detune and muffle follow them.
func _haunted_by(dt: float) -> void:
	var doing := {&"pleading": 0.0, &"straining": 0.0, &"dragged": 0.0, &"swarm": 0.0}
	var out := 0
	for soul in animas_source.call():
		var state := StringName(soul.state)
		if doing.has(state):
			doing[state] = 1.0
		if state != &"below":
			out += 1
	doing[&"swarm"] = clampf(float(out - SWARM_FROM + 1) / 2.0, 0.0, 1.0)
	for act in ACTS:
		var now := float(_haunt[act])
		_haunt[act] = move_toward(now, float(doing[act]), (HAUNT_RISE if doing[act] > now else HAUNT_FALL) * dt)
	chorus().wet = DETUNE_WET * float(_haunt[&"pleading"])
	var falter := maxf(float(_haunt[&"straining"]), float(_haunt[&"dragged"]))
	muffle().cutoff_hz = OPEN_HZ * pow(MUFFLE_HZ / OPEN_HZ, falter)


## Every Animas node's souls within HAUNT_RANGE of you (the nodes looked for now and then).
func _near_animas() -> Array:
	_find_in -= get_process_delta_time()
	if _find_in <= 0.0:
		_find_in = FIND_EVERY
		_animas = get_tree().root.find_children("*", "Node3D", true, false).filter(func(n): return n.get_script() == AnimasScript)
	var point: Variant = listener_source.call()
	var near := []
	if not point is Vector3:
		return near
	for node: Node3D in _animas:
		if not is_instance_valid(node) or node.global_position.distance_to(point) > HAUNT_RANGE:
			continue
		for i in range(int(node.count)):
			near.append({"state": node.state_of(i), "at": node.global_position})
	return near


func _db(amount: float) -> float:
	return OUT if amount <= NONE else maxf(linear_to_db(amount), OUT)


func _bed_time() -> float:
	var pos := fposmod(float(position_source.call()), float(_bed.loop))
	if _last_loop_pos >= 0.0 and pos < _last_loop_pos - float(_bed.loop) * 0.5:
		_loops += 1
	_last_loop_pos = pos
	return _loops * float(_bed.loop) + pos


## The mixed position as bed time: the heard time, moved by how far the mixer is
## from it within the loop (never a loop apart, whichever side of a wrap).
func _raw_time() -> float:
	var loop := float(_bed.loop)
	var apart := fposmod(float(raw_source.call()), loop) - fposmod(_time, loop)
	return _time + wrapf(apart, -loop * 0.5, loop * 0.5)


func _bed_raw() -> float:
	return _bed.player.get_playback_position() if _bed.player.playing else 0.0


func _bed_heard() -> float:
	if not _bed.player.playing:
		return 0.0
	return PlaceClock.heard(_bed.player.get_playback_position(), AudioServer.get_time_since_last_mix(), AudioServer.get_output_latency())


## The level's combat score's intensity (0 with none).
func _fight() -> float:
	var level := get_tree().current_scene
	var music := level.get_node_or_null("Music") if level != null else null
	return float(music.get("intensity")) if music != null and music.get("intensity") != null else 0.0


func _listener() -> Variant:
	var you := get_tree().get_first_node_in_group(&"player") as Node3D
	return you.global_position if you != null else null
