class_name PlaceSound
extends Node
## The Metro's sound (docs/superpowers/specs/2026-10-31-metro-sound-design.md): every space its own. The plan's spaces
## fall into families (FAMILIES), each with its beds (BEDS: the station hall's room, the market's crowd, the old layer's
## deep room), crossfaded through the openings as you walk (PlaceZones, a table of its own: the score's maps only the
## lane), the city's beds thinned away on the way into the old layer (city_of). The beds play on a bus of their own
## (MetroBed, under Ambience: they keep its duck under World and its hurt filter), darkened with depth. While it is in,
## Master carries a gentle glue (before its limiter) and the room's reverb is the family's (FAMILY_ACOUSTICS, blended
## through the openings); gone, both are as they were. A floor with no "surface" meta walks as its family's
## (surface_at). The Metro has one train (the lane's own TrainPass, saved, or one of its own): its rumble from the
## station's track mouths, its draught gusting on the platforms, the cables surging at its peak, all thinned away on the
## way into the old layer. The station set's machine sounds from the lists the set keeps (no tags in its files): its
## neon buzzing, a junction box at each cable run's end, the transformer along its floor mains, knocks down its mains and
## risers, its risers ticking as they cool, its fuming floor mouths breathing out. Everything else here runs on real time (TimeFx), so slow motion leaves the place alone.

const Sfx := preload("res://scripts/Audio/Sfx.gd")
const Focus := preload("res://scripts/Audio/Focus.gd")
const TimeFx := preload("res://scripts/Visual/TimeFx.gd")

## Each of the plan's spaces, by family (a space the plan adds later takes the nearest family through its openings).
const FAMILIES := {
	"hall": "hall", "corridor_w": "hall", "cross_w": "hall", "corridor_e": "hall", "cross_e": "hall",
	"corridor_nw": "hall", "exit_stairs_nw": "hall", "kiosk_landing_nw": "hall",
	"corridor_ne": "hall", "exit_stairs_ne": "hall", "kiosk_landing_ne": "hall",
	"corridor_sw": "hall", "exit_stairs_sw": "hall", "kiosk_landing_sw": "hall",
	"corridor_se": "hall", "exit_stairs_se": "hall", "kiosk_landing_se": "hall",
	"platform_n": "platforms", "platform_s": "platforms", "track": "platforms", "siding": "platforms",
	"stairs_n": "platforms", "stairs_s": "platforms",
	"market_stairs": "market", "pasaje": "market", "pasaje_n": "market", "pasaje_s": "market", "cistern_lane": "market",
	"herb_market": "market", "lane_sw": "market", "lane_se": "market", "tianguis_lane": "market", "fondas": "market",
	"rag_lane": "market", "storeroom": "market", "square_s": "market", "light_gallery": "market",
	"grate_room": "market", "loft": "market",
	"candle_lane": "lane", "chapel": "lane",
	"librarian_shop": "shop",
	"vent_shaft": "old", "niche": "old", "vaults": "old", "cistern": "old", "drain_n": "old", "crypt": "old",
	"templo_shells": "old", "pawn_vault": "old", "temple_tunnel": "old",
}
## Each family's beds: [loop (audio/ambience/), dB against its LOOP_GAIN, thinned by depth (the city's)].
const BEDS := {
	"hall": [["metro_room", -6.0, false], ["metro_crowd", -24.0, true]],
	"platforms": [["metro_room", -4.0, false]],
	"market": [["metro_crowd", -4.0, true], ["metro_room", -12.0, false]],
	"lane": [["metro_crowd", -18.0, true]],
	"shop": [["metro_room", -18.0, false]],
	"old": [["metro_room_deep", -10.0, false]],
}
## What a bare floor is in each family, and what its rooms ring like (Sfx.ACOUSTICS).
const FAMILY_SURFACE := {"hall": "tile", "platforms": "tile", "market": "tile", "lane": "tile", "shop": "carpet", "old": ""}
const FAMILY_ACOUSTICS := {"hall": "tile", "platforms": "tile", "market": "tile", "lane": "stone", "shop": "stone", "old": "cave"}
## The beds' bus, sent to Ambience: its glue, then its low-pass (open in the city, dark at the bottom of the old layer).
const BUS := &"MetroBed"
const LOW_OPEN := 9000.0
const LOW_DEEP := 900.0
## Master's glue while the Metro is in (before the limiter), and how it is known again.
const GLUE := {"threshold": -20.0, "ratio": 2.0, "attack_us": 10000.0, "release_ms": 250.0}
const GLUE_META := &"metro_glue"
## Silence (dB); how fast a bed moves toward its level (dB per real second).
const OUT := -80.0
const EASE_DB := 12.0
const SEED := 1987
## A train: its rumble at each track mouth (dB, at full city), heard this far over the mouth's bed; how long after it
## begins its draught gusts out (s); the seed of a train of its own.
const RUMBLE_DB := -4.0
const MOUTH_UP := 1.5
## The rumble is one take a pass, voiced two ways: from the track line at its point nearest you, heard this far (m), and
## flat through the walls this far under it (dB), both thinned by depth as the city is.
const RUMBLE_REACH := 90.0
const RUMBLE_SIZE := 8.0
const RUMBLE_FAR_DB := -16.0
const DRAUGHT_AFTER := 1.0
## The draught's level (dB, at a platform's full), and its stereo takes, kept with the beds.
const DRAUGHT_DB := -10.0
const DRAUGHT_TAKES := "res://audio/ambience/metro_draught_%d.wav"
const TRAIN_SEED := 31
## The station's machine: how far a junction box and the transformer are heard (m); how often a knock runs down a main
## or riser, a riser ticks, a mouth hisses (s), and how far under its gain the tick and the hiss sit (dB); how high
## over a mouth's foot its breath comes from (m).
const JUNCTION_REACH := 6.0
const TRANSFORMER_REACH := 7.0
const KNOCK_EVERY := Vector2(40.0, 90.0)
const TICK_EVERY := Vector2(6.0, 14.0)
const TICK_DB := -8.0
const HISS_EVERY := Vector2(18.0, 40.0)
const HISS_DB := -6.0
const MOUTH_BREATH := 0.9
## The station's signs on the Company's line while a train draws on it: how far they sag (at its full, and more on the
## line's dips: the deepest put a sign out), how fast the dips come and go.
const STATION_BROWNOUT := Vector2(0.35, 0.45)
const DIP_RATES := Vector2(23.0, 7.3)
## How far apart the signs' dips are in time (s): no two share one.
const SIGN_PHASE := 0.613

var zones: PlaceZones
var listener: Node3D
var station: Node3D
var lane: Node
## The beds playing, by loop name.
var beds := {}
## The Metro's one train, and its rumble's two voices (on the track nearest you; flat through the walls).
var train: TrainPass
var rumble_near: AudioStreamPlayer3D
var rumble_far: AudioStreamPlayer
var _levels := {}
var _weights := {}
var _depth := 0.0
var _rooms := {}
var _last_real := -1.0
var _built := false
var _rng := RandomNumberGenerator.new()
var _heard: Array = []
var _sources := {"neon": 0, "junctions": 0, "transformer_runs": 0, "knock_runs": 0, "ticks": 0, "hisses": 0}
var _pipes: Node3D
var _sag_clock := 0.0
var _draught: AudioStreamPlayer


func _init() -> void:
	add_to_group(&"place_sound")


## Sets it going on `plan` (the Metro's plan.json) for `listener` (the player); the station set and the lane, when they
## are set in. Once: a second call only takes the new plan and listener.
func setup(plan: Dictionary, ear: Node3D, station_set: Node3D = null, lane_set: Node = null) -> void:
	listener = ear
	station = station_set
	lane = lane_set
	zones = PlaceZones.from_plan(plan, FAMILIES, [])

	if _built:
		return

	_built = true
	_ensure_bus()
	_ensure_glue()
	_take_train()
	_station_machine()

	if not Sfx.enabled:
		return

	_rng.seed = SEED

	for family in BEDS:
		for bed: Array in BEDS[family]:
			var loop := String(bed[0])

			if beds.has(loop):
				continue

			var player := AudioStreamPlayer.new()
			player.name = loop
			player.stream = load("res://audio/ambience/%s.wav" % loop)
			player.bus = BUS
			player.volume_db = OUT
			add_child(player)
			player.play(_rng.randf_range(0.0, player.stream.get_length()))
			beds[loop] = player
			_levels[loop] = OUT


## {family: weight} at a point: the family stood in, and across an opening's threshold the one beyond; {} in no space.
func family_weights_at(point: Vector3) -> Dictionary:
	return zones.weights_at(point) if zones != null else {}


## How much of the city is heard at `depth` (PlaceZones): all of it through the station and the market, none in the
## old layer.
static func city_of(depth: float) -> float:
	return 1.0 - smoothstep(0.35, 0.7, depth)


## How loud `loop` is wanted (dB) for `weights` ({family: weight}) at `depth`: the families' wishes summed as levels,
## a city bed thinned by city_of; OUT when no family there has it.
func bed_db(loop: String, weights: Dictionary, depth: float) -> float:
	var level := 0.0

	for family in weights:
		for bed: Array in BEDS.get(family, []):
			if String(bed[0]) != loop:
				continue

			var gain := float(Sfx.LOOP_GAIN.get(StringName(loop), 0.0)) + float(bed[1])
			level += float(weights[family]) * db_to_linear(gain) * (city_of(depth) if bool(bed[2]) else 1.0)

	return maxf(linear_to_db(level), OUT) if level > 0.0 else OUT


## How many of the station's pieces were given a sound, by kind (neon, junctions, transformer_runs, knock_runs, ticks,
## hisses).
func station_sources() -> Dictionary:
	return _sources


## The station's signs sagging as a train draws on the line (unevenly, as the lane's lights do), on game time.
func _sag(delta: float) -> void:
	if station == null or not is_instance_valid(station) or station.get("neon") == null or train == null:
		return

	_sag_clock += delta
	var s := train.strength()
	var signs: Array = station.get("neon")

	# Each sign dips on its own phase of the line's flutter: they go out and come back one by one, not as a wall.
	for i in range(signs.size()):
		var t := _sag_clock + float(i) * SIGN_PHASE
		var dip := clampf(0.5 + 0.5 * sin(t * DIP_RATES.x) * sin(t * DIP_RATES.y + 1.1), 0.0, 1.0)
		signs[i].set("dim", 1.0 - s * (STATION_BROWNOUT.x + STATION_BROWNOUT.y * dip))


## The station set's machine given its sounds, from the lists it keeps.
func _station_machine() -> void:
	if station == null or not is_instance_valid(station) or station.get("neon") == null:
		return

	var signs: Array = station.get("neon")

	for i in range(signs.size()):
		signs[i].set("buzz", StringName("neon_buzz_%d" % (1 + i % 3)))
		signs[i].set("on_line", true)

	_sources.neon = signs.size()
	_pipes = (load("res://scripts/Audio/PipeSounds.gd") as GDScript).new()
	_pipes.name = "station_pipes"
	add_child(_pipes)

	for run: Node3D in station.get("runs"):
		var points: PackedVector3Array = run.get_meta("points", PackedVector3Array())

		if not points.is_empty():
			var end := run.to_global(points[points.size() - 1])
			_pipes.call("run", &"junction_hum", end, end, JUNCTION_REACH)
			_sources.junctions += 1

	for main: Node3D in station.get("floor_mains"):
		var ends := _long_ends(main)
		_pipes.call("run", &"transformer_hum", ends[0], ends[1], TRANSFORMER_REACH)
		_sources.transformer_runs += 1

	for piece: Node3D in station.get("mains") + station.get("risers"):
		var ends := _long_ends(piece)
		_pipes.call("knocks", ends[0], ends[1], KNOCK_EVERY)
		_sources.knock_runs += 1

	for riser: Node3D in station.get("risers"):
		var ends := _long_ends(riser)
		_pipes.call("events", &"pipe_tick", (ends[0] + ends[1]) / 2.0, TICK_EVERY, TICK_DB)
		_sources.ticks += 1

	for mouth: Node3D in station.get("mouths"):
		_pipes.call("events", &"pipe_hiss", mouth.global_position + Vector3(0.0, MOUTH_BREATH, 0.0), HISS_EVERY, HISS_DB)
		_sources.hisses += 1


## A piece's two ends along its longest side (world): its drawn box's, at the middles of its two smallest faces.
static func _long_ends(piece: Node3D) -> Array[Vector3]:
	var drawn: MeshInstance3D = piece as MeshInstance3D

	if drawn == null:
		for child in piece.find_children("*", "MeshInstance3D", true, false):
			drawn = child
			break

	if drawn == null or drawn.mesh == null:
		return [piece.global_position, piece.global_position]

	var box := drawn.mesh.get_aabb()
	var axis := Vector3.ZERO
	axis[box.size.max_axis_index()] = box.size[box.size.max_axis_index()] / 2.0
	var middle := box.get_center()
	return [drawn.to_global(middle - axis), drawn.to_global(middle + axis)]


## What this train's pass played: [[sound, where (Vector3; Vector3.ZERO for the flat draught), dB]], the last pass's.
func train_heard() -> Array:
	return _heard


## The lane's train when the lane is set in (one clock: its lights sag on it), else one of its own.
func _take_train() -> void:
	var theirs: Variant = lane.get("train") if lane != null else null
	train = theirs if theirs is TrainPass else null

	if train == null:
		train = TrainPass.new()
		train.name = "train"
		train.seed = TRAIN_SEED
		add_child(train)

	train.began.connect(_on_train_began)
	train.peaked.connect(_on_train_peaked)


## How much of the city is heard where you are: in no space (a gap, a fall), as where you last stood.
func _city_here() -> float:
	if listener == null or not is_instance_valid(listener):
		return 0.0

	var at := listener.global_position
	return city_of(zones.depth_at(at) if not family_weights_at(at).is_empty() else _depth)


## The station's tracks, each a line from its westmost mouth to its eastmost (the mouths of one track share its z).
func _tracks() -> Array:
	var by_line := {}

	for mouth in _mouths():
		var key := snappedf(mouth.z, 0.5)
		by_line[key] = by_line.get(key, []) + [mouth]

	var tracks := []

	for key in by_line:
		var ends: Array = by_line[key]
		ends.sort_custom(func(a: Vector3, b: Vector3): return a.x < b.x)
		tracks.append([ends[0], ends[ends.size() - 1]])

	return tracks


## The point on the track nearest you (of the nearest track).
func _on_track() -> Vector3:
	var best := Vector3.ZERO
	var nearest := INF

	for track: Array in _tracks():
		var point := Geometry3D.get_closest_point_to_segment(listener.global_position, track[0], track[1])

		if point.distance_to(listener.global_position) < nearest:
			nearest = point.distance_to(listener.global_position)
			best = point

	return best


## Where the station's track mouths are (their runs' middles, over their beds).
func _mouths() -> Array[Vector3]:
	var mouths: Array[Vector3] = []

	if station == null or not is_instance_valid(station):
		return mouths

	for run: Array in station.get("mouth_runs"):
		mouths.append(station.to_global(Vector3((float(run[0]) + float(run[1])) / 2.0, float(run[3]) + MOUTH_UP, float(run[2]))))

	return mouths


func _on_train_began() -> void:
	_heard = []
	var city := _city_here()

	if city <= 0.001:
		return

	if not _tracks().is_empty():
		var db := RUMBLE_DB + linear_to_db(city)
		_heard.append([&"train_far", _on_track(), db])
		_rumble(city)

	var gust := float(family_weights_at(listener.global_position).get("platforms", 0.0)) * city

	if gust > 0.0:
		get_tree().create_timer(DRAUGHT_AFTER, false).timeout.connect(_gust.bind(gust))


## The pass's rumble, one take, started on both its voices (Sfx's pool would drop it past its reach: the track's mouths
## lie 50 m and more from most of the station).
func _rumble(city: float) -> void:
	if not Sfx.enabled:
		return

	var take := Sfx.stream(&"train_far")

	if take == null:
		return

	if rumble_near == null:
		rumble_near = AudioStreamPlayer3D.new()
		rumble_near.name = "rumble_near"
		rumble_near.bus = Sfx.BUS_WORLD
		rumble_near.max_distance = RUMBLE_REACH
		rumble_near.unit_size = RUMBLE_SIZE
		rumble_near.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		add_child(rumble_near)
		rumble_far = AudioStreamPlayer.new()
		rumble_far.name = "rumble_far"
		rumble_far.bus = BUS
		add_child(rumble_far)

	for voice: Node in [rumble_near, rumble_far]:
		voice.set("stream", take)
		voice.call("play")

	_voice_rumble(city)


## The rumble's voices where you are now: the near one on the track's nearest point, both thinned by depth.
func _voice_rumble(city: float) -> void:
	var gain := float(Sfx.GAIN.get(&"train_far", 0.0)) + RUMBLE_DB
	rumble_near.global_position = _on_track()
	rumble_near.volume_db = maxf(gain + linear_to_db(maxf(city, 0.0001)), OUT)
	rumble_far.volume_db = maxf(gain + RUMBLE_FAR_DB + linear_to_db(maxf(city, 0.0001)), OUT)


## The air a train pushes out, gusting flat on the beds' bus.
func _gust(amount: float) -> void:
	var db := DRAUGHT_DB + linear_to_db(amount)
	_heard.append([&"metro_draught", Vector3.ZERO, db])

	if not Sfx.enabled:
		return

	if _draught == null:
		_draught = AudioStreamPlayer.new()
		_draught.name = "draught"
		_draught.bus = BUS
		add_child(_draught)

	var takes := 0

	while ResourceLoader.exists(DRAUGHT_TAKES % (takes + 1)):
		takes += 1

	if takes == 0:
		return

	_draught.stream = load(DRAUGHT_TAKES % (1 + _rng.randi() % takes))
	_draught.volume_db = db
	_draught.play()


## At the train's peak the Company's cables surge: from the end of the station's cable run nearest you.
func _on_train_peaked() -> void:
	if station == null or not is_instance_valid(station) or _city_here() <= 0.001:
		return

	var ear := listener.global_position
	var nearest := Vector3.INF

	for run: Node3D in station.get("runs"):
		var points: PackedVector3Array = run.get_meta("points", PackedVector3Array())

		if points.is_empty():
			continue

		var end := run.to_global(points[points.size() - 1])

		if end.distance_to(ear) < nearest.distance_to(ear):
			nearest = end

	if nearest != Vector3.INF and Focus.allow(self, &"detail", nearest):
		Sfx.play(self, &"cable_surge", nearest)
		_heard.append([&"cable_surge", nearest, 0.0])


## What a floor with no "surface" meta is at a point: its family's (FAMILY_SURFACE); "" (stone) in no space.
func surface_at(point: Vector3) -> String:
	var weights := family_weights_at(point)
	var best := ""
	var most := 0.0

	for family in weights:
		if float(weights[family]) > most:
			most = float(weights[family])
			best = String(family)

	return String(FAMILY_SURFACE.get(best, ""))


func _process(delta: float) -> void:
	var real := TimeFx.real_since(_last_real) if _last_real >= 0.0 else 0.0
	_last_real = TimeFx.real_time()
	_sag(delta)

	if rumble_near != null and rumble_near.playing:
		_voice_rumble(_city_here())

	if listener == null or not is_instance_valid(listener) or zones == null:
		return

	var at := listener.global_position
	var weights := family_weights_at(at)

	# In no space (a gap, a fall), the place stays as it was.
	if not weights.is_empty():
		_weights = weights
		_depth = zones.depth_at(at)

	for loop in beds:
		_levels[loop] = move_toward(float(_levels[loop]), bed_db(loop, _weights, _depth), EASE_DB * real)
		(beds[loop] as AudioStreamPlayer).volume_db = _levels[loop]

	var rooms := {}

	for family in _weights:
		var kind := String(FAMILY_ACOUSTICS.get(family, "stone"))
		rooms[kind] = float(rooms.get(kind, 0.0)) + float(_weights[family])

	if rooms != _rooms and not rooms.is_empty():
		_rooms = rooms
		Sfx.set_acoustics_mix(rooms)

	var index := AudioServer.get_bus_index(BUS)

	if index >= 0:
		for i in range(AudioServer.get_bus_effect_count(index)):
			var low := AudioServer.get_bus_effect(index, i) as AudioEffectLowPassFilter
			if low != null:
				low.cutoff_hz = lerpf(LOW_OPEN, LOW_DEEP, smoothstep(0.35, 1.0, _depth))


func _exit_tree() -> void:
	for player: AudioStreamPlayer in beds.values():
		player.stop()
		player.stream = null

	var master := AudioServer.get_bus_index(&"Master")

	for i in range(AudioServer.get_bus_effect_count(master) - 1, -1, -1):
		if AudioServer.get_bus_effect(master, i).has_meta(GLUE_META):
			AudioServer.remove_bus_effect(master, i)

	var index := AudioServer.get_bus_index(BUS)

	if index >= 0:
		AudioServer.remove_bus(index)

	Sfx.set_acoustics("stone")


## The beds' bus, once: under Ambience, its glue and its low-pass.
static func _ensure_bus() -> void:
	if AudioServer.get_bus_index(BUS) >= 0:
		return

	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, BUS)
	AudioServer.set_bus_send(index, Sfx.BUS_AMBIENCE if AudioServer.get_bus_index(Sfx.BUS_AMBIENCE) >= 0 else &"Master")
	var glue := AudioEffectCompressor.new()
	glue.threshold = -24.0
	glue.ratio = 2.0
	glue.attack_us = 20000.0
	glue.release_ms = 300.0
	AudioServer.add_bus_effect(index, glue)
	var low := AudioEffectLowPassFilter.new()
	low.cutoff_hz = LOW_OPEN
	AudioServer.add_bus_effect(index, low)


## Master's glue, once, before everything on it (the limiter last).
static func _ensure_glue() -> void:
	var master := AudioServer.get_bus_index(&"Master")

	for i in range(AudioServer.get_bus_effect_count(master)):
		if AudioServer.get_bus_effect(master, i).has_meta(GLUE_META):
			return

	var glue := AudioEffectCompressor.new()
	glue.threshold = GLUE.threshold
	glue.ratio = GLUE.ratio
	glue.attack_us = GLUE.attack_us
	glue.release_ms = GLUE.release_ms
	glue.set_meta(GLUE_META, true)
	AudioServer.add_bus_effect(master, glue, 0)
