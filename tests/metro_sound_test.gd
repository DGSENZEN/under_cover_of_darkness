extends Node3D
## The Metro's sound (docs/superpowers/specs/2026-10-31-metro-sound-design.md), headless with --fixed-fps 60, sound on
## and Master muted: Sfx's tile steps, gains and blended rooms (S1-S3); the director on a plan of its own (S4-S12);
## floors answering from the place (S14-S15); one train for the Metro (S16-S19, its signs sagging S23); the director in the Metro (S13) and
## the station's pieces sounding (S20), the candle lane un-hushed (S21-S22).

const Sfx := preload("res://scripts/Audio/Sfx.gd")
const Focus := preload("res://scripts/Audio/Focus.gd")
const METRO := preload("res://maps/metro.tscn")
const PLAYER := preload("res://Player.tscn")

## A plan of its own: the hall (the station), the Pasaje beyond its east door (the market layer), the vaults beyond
## that (the old layer), the shop north of the hall; each 10 m square, floors at 0.
const PLAN := {"spaces": [
	{"name": "hall", "polygon": [[0, 0], [10, 0], [10, 10], [0, 10]], "floor": 0.0, "height": 5.0, "layer": 1,
		"openings": [{"to": "pasaje", "at": [10, 5], "width": 3.0}, {"to": "librarian_shop", "at": [5, 10], "width": 2.0}]},
	{"name": "pasaje", "polygon": [[10, 0], [20, 0], [20, 10], [10, 10]], "floor": 0.0, "height": 5.0, "layer": 2,
		"openings": [{"to": "hall", "at": [10, 5], "width": 3.0}, {"to": "vaults", "at": [20, 5], "width": 3.0}]},
	{"name": "vaults", "polygon": [[20, 0], [30, 0], [30, 10], [20, 10]], "floor": 0.0, "height": 5.0, "layer": 3,
		"openings": [{"to": "pasaje", "at": [20, 5], "width": 3.0}]},
	{"name": "librarian_shop", "polygon": [[0, 10], [10, 10], [10, 20], [0, 20]], "floor": 0.0, "height": 5.0, "layer": 2,
		"openings": [{"to": "hall", "at": [5, 10], "width": 2.0}]},
	{"name": "platform_n", "polygon": [[0, -10], [10, -10], [10, 0], [0, 0]], "floor": 0.0, "height": 5.0, "layer": 1,
		"openings": [{"to": "hall", "at": [5, 0], "width": 3.0}]}]}
const HALL_MID := Vector3(5, 1, 5)
const HALL_MARKET_DOOR := Vector3(9.9, 1, 5)
const MARKET_MID := Vector3(15, 1, 5)
const OLD_MID := Vector3(25, 1, 5)
const SHOP_MID := Vector3(5, 1, 15)
const NOWHERE := Vector3(-40, 1, -40)
const PLATFORM_MID := Vector3(5, 1, -5)
## A station set's lists, as the real one keeps them (maps/metro_station.gd), and a lane with its train.
const STATION_SOURCE := "extends Node3D\nvar mouth_runs: Array = []\nvar runs: Array = []\nvar neon: Array = []\n" \
	+ "var mains: Array = []\nvar risers: Array = []\nvar mouths: Array = []\nvar floor_mains: Array = []\n"
const LANE_SOURCE := "extends Node\nvar train: TrainPass\n"

var results: Array[String] = []
var failures := 0


func _ready() -> void:
	Sfx.enabled = true
	AudioServer.set_bus_mute(0, true)
	Sfx._ensure_buses()
	await _sfx()
	await _director()
	await _floors()
	await _trains()
	await _in_the_metro()
	Focus.reset()
	Sfx.silence()
	await _frames(3)
	print("\n==== RESULTS ====")
	for result in results:
		print(result)
	get_tree().quit(1 if failures > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _check(name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", name, detail])
	if not ok:
		failures += 1


func _world_reverb() -> AudioEffectReverb:
	var index := AudioServer.get_bus_index(Sfx.BUS_WORLD)
	for i in range(AudioServer.get_bus_effect_count(index)):
		if AudioServer.get_bus_effect(index, i) is AudioEffectReverb:
			return AudioServer.get_bus_effect(index, i)
	return null


## S1-S3: Sfx.
func _sfx() -> void:
	_check("S1 tile has its own steps; its runs, jumps and landings are stone's",
		Sfx.step("tile") == &"step_tile" and Sfx.step("tile", true) == &"step_tile"
		and Sfx.step("tile", false, "jump") == &"jump_stone" and Sfx.step("tile", false, "land") == &"land_stone",
		"%s %s %s %s" % [Sfx.step("tile"), Sfx.step("tile", true), Sfx.step("tile", false, "jump"), Sfx.step("tile", false, "land")])

	Sfx.set_acoustics_mix({"tile": 1.0})
	var tiled := _world_reverb().room_size
	Sfx.set_acoustics_mix({"stone": 1.0})
	var stoned := _world_reverb().room_size
	Sfx.set_acoustics_mix({"tile": 0.5, "stone": 0.5})
	var half := _world_reverb().room_size
	Sfx.set_acoustics("stone")
	_check("S2 the acoustics blend by weight", tiled > stoned and absf(half - (tiled + stoned) / 2.0) < 0.02,
		"%.3f %.3f %.3f" % [tiled, stoned, half])

	var shots := [&"pipe_tick", &"neon_ignite", &"cable_surge", &"train_far"]
	var loops := [&"metro_room", &"metro_room_deep", &"metro_crowd", &"junction_hum", &"transformer_hum"]
	_check("S3 every Metro name has a gain", shots.all(func(n): return Sfx.GAIN.has(n))
		and loops.all(func(n): return Sfx.LOOP_GAIN.has(n)),
		"missing %s" % str((shots.filter(func(n): return not Sfx.GAIN.has(n))
			+ loops.filter(func(n): return not Sfx.LOOP_GAIN.has(n)))))
	# The draught plays flat across both ears: stereo, kept with the beds (the named sounds, placed in the world, are mono).
	var gusts := []
	var k := 1
	while ResourceLoader.exists("res://audio/ambience/metro_draught_%d.wav" % k):
		gusts.append(load("res://audio/ambience/metro_draught_%d.wav" % k))
		k += 1
	_check("S24 the draught is stereo, with the beds, not a named sound", gusts.size() >= 4
		and gusts.all(func(g): return (g as AudioStreamWAV).stereo) and not Sfx.GAIN.has(&"metro_draught")
		and not ResourceLoader.exists("res://audio/sfx/metro_draught_1.wav"), "%d takes" % gusts.size())


func _near(value: float, want: float, within: float) -> bool:
	return absf(value - want) <= within


func _glue_count() -> int:
	var count := 0
	for i in range(AudioServer.get_bus_effect_count(0)):
		if AudioServer.get_bus_effect(0, i).has_meta(&"metro_glue"):
			count += 1
	return count


func _bus_count(bus: StringName) -> int:
	var count := 0
	for i in range(AudioServer.bus_count):
		if AudioServer.get_bus_name(i) == bus:
			count += 1
	return count


func _master_effects() -> Array:
	var kinds := []
	for i in range(AudioServer.get_bus_effect_count(0)):
		kinds.append(AudioServer.get_bus_effect(0, i).get_class())
	return kinds


## A director on PLAN, its ear at `at`.
func _director_at(at: Vector3) -> Array:
	var ear := Node3D.new()
	add_child(ear)
	ear.global_position = at
	var sound := PlaceSound.new()
	add_child(sound)
	sound.setup(PLAN, ear)
	return [sound, ear]


## S4-S12: the director on a plan of its own.
func _director() -> void:
	var before := _master_effects()
	var made := _director_at(HALL_MID)
	var sound: PlaceSound = made[0]
	var ear: Node3D = made[1]
	_check("S4 inside a space its family's bed is full", is_equal_approx(float(sound.family_weights_at(HALL_MID).get("hall", 0.0)), 1.0),
		str(sound.family_weights_at(HALL_MID)))
	_check("S5 at an opening two families cross over", _near(float(sound.family_weights_at(HALL_MARKET_DOOR).get("hall", 0.0)), 0.5, 0.1),
		str(sound.family_weights_at(HALL_MARKET_DOOR)))
	_check("S6 the city keeps full through the market, gone in the old layer",
		is_equal_approx(PlaceSound.city_of(0.0), 1.0) and is_equal_approx(PlaceSound.city_of(0.35), 1.0)
		and is_equal_approx(PlaceSound.city_of(0.7), 0.0), "%.2f %.2f %.2f" % [PlaceSound.city_of(0.0), PlaceSound.city_of(0.35), PlaceSound.city_of(0.7)])
	var market := sound.bed_db("metro_crowd", {"market": 1.0}, 0.35)
	var hall := sound.bed_db("metro_crowd", {"hall": 1.0}, 0.0)
	var old := sound.bed_db("metro_crowd", {"old": 1.0}, 0.7)
	_check("S7 the market's crowd is louder than the hall's; the old layer has none", market > hall and old <= -79.0,
		"%.1f %.1f %.1f" % [market, hall, old])
	sound.setup(PLAN, ear)
	_check("S8 set up twice: one glue, one MetroBed", _glue_count() == 1 and _bus_count(&"MetroBed") == 1,
		"%d glue, %d MetroBed" % [_glue_count(), _bus_count(&"MetroBed")])

	# S10: from the hall into nowhere, the beds hold (once they have come up: 56 dB at EASE_DB).
	await _frames(360)
	var room: AudioStreamPlayer = sound.beds.get("metro_room")
	var held := room.volume_db if room != null else -80.0
	ear.global_position = NOWHERE
	await _frames(30)
	var after := room.volume_db if room != null else -80.0
	_check("S10 standing in no space, the beds hold", room != null and held > -60.0 and _near(after, held, 1.0),
		"%.1f -> %.1f" % [held, after])

	# S12: in slow motion the beds still fade at their rate in real time.
	ear.global_position = MARKET_MID
	var crowd: AudioStreamPlayer = sound.beds.get("metro_crowd")
	var from := crowd.volume_db if crowd != null else 0.0
	Engine.time_scale = 0.2
	await _frames(30)
	Engine.time_scale = 1.0
	var moved := (crowd.volume_db - from) if crowd != null else 0.0
	_check("S12 slow motion: a bed fades on real time", crowd != null and _near(moved, PlaceSound.EASE_DB * 0.5, PlaceSound.EASE_DB * 0.05),
		"moved %.2f dB in 0.5 s real" % moved)

	sound.queue_free()
	ear.queue_free()
	await _frames(3)
	_check("S9 gone: Master as it was, no glue; the acoustics back to stone",
		_glue_count() == 0 and _master_effects() == before and Sfx._mix.is_empty() and Sfx._material == "stone",
		"%s vs %s" % [str(_master_effects()), str(before)])

	# S11: sound off.
	Sfx.enabled = false
	var quiet := _director_at(HALL_MID)
	await _frames(30)
	_check("S11 with sound off the director builds no beds", (quiet[0] as PlaceSound).beds.is_empty(), str((quiet[0] as PlaceSound).beds.keys()))
	quiet[0].queue_free()
	quiet[1].queue_free()
	await _frames(3)
	Sfx.enabled = true


## S13: the Metro itself.
func _in_the_metro() -> void:
	var metro: Node3D = METRO.instantiate()
	add_child(metro)
	await _frames(10)
	_check("S13 the Metro: the director is in, the default night ambience is not",
		metro.get_node_or_null("PlaceSound") is PlaceSound and String(metro.get_meta(&"ambience", "interior_night")) == "",
		"%s, ambience %s" % [str(metro.get_node_or_null("PlaceSound")), str(metro.get_meta(&"ambience", "unset"))])
	var sound: PlaceSound = metro.get_node("PlaceSound")
	var station: Node3D = metro.get_node("metro_station")
	var counts: Dictionary = sound.station_sources()
	_check("S20 the station's pieces sound: every sign buzzes, every run ends in a junction, the mains and vents are fed",
		station.neon.size() > 0 and counts.neon == station.neon.size() and station.neon.all(func(s): return s.buzz != &"")
		and counts.junctions == station.runs.size() and counts.knock_runs == station.mains.size() + station.risers.size()
		and counts.transformer_runs == station.floor_mains.size() and counts.ticks == station.risers.size()
		and counts.hisses == station.mouths.size(),
		"%s; neon %d runs %d mains %d risers %d floor mains %d mouths %d" % [str(counts), station.neon.size(), station.runs.size(),
			station.mains.size(), station.risers.size(), station.floor_mains.size(), station.mouths.size()])
	var lane: Node3D = metro.get_node("candle_lane")
	var vent: AudioStreamPlayer3D = lane.get("vent_hum")
	var rumble: AudioStreamPlayer = lane.get("rumble")
	var dark_wind: AudioStreamPlayer = lane.get("dark_wind")
	var crowd: Node = lane.get("crowd")
	_check("S21 set into the Metro the lane's vent breathes; its own rumble, crowd and dark wind stay hushed",
		vent != null and vent.stream != null and vent.playing and rumble.stream == null and dark_wind.stream == null
		and crowd.process_mode == Node.PROCESS_MODE_DISABLED,
		"vent %s playing %s, rumble %s, wind %s, crowd %s" % [vent.stream if vent else null, vent.playing if vent else false,
			rumble.stream, dark_wind.stream, crowd.process_mode])
	lane.train.start_pass()
	await _frames(int(5.5 * 60))
	var rattle: AudioStreamPlayer3D = lane.get("_rattle")
	_check("S22 at a train's peak the lane's jars rattle again", rattle != null and rattle.stream != null,
		str(rattle.stream if rattle else null))
	metro.queue_free()
	await _frames(3)


## S14-S15: a floor with no "surface" meta walks as its place.
func _floors() -> void:
	var made := _director_at(HALL_MID)
	var sound: PlaceSound = made[0]
	_check("S14 a bare floor in the hall walks as tile, in the shop as carpet, in the old layer as stone",
		sound.surface_at(HALL_MID) == "tile" and sound.surface_at(SHOP_MID) == "carpet" and sound.surface_at(OLD_MID) == "",
		"%s %s %s" % [sound.surface_at(HALL_MID), sound.surface_at(SHOP_MID), sound.surface_at(OLD_MID)])

	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10, 0.2, 10)
	shape.shape = box
	floor_body.add_child(shape)
	add_child(floor_body)
	floor_body.global_position = Vector3(5, -0.1, 5)
	var player: CharacterBody3D = PLAYER.instantiate()
	player.debug_traversal = false
	add_child(player)
	player.global_position = HALL_MID + Vector3(0, 0.05, 0)
	await _frames(20)
	var bare := String(player.call("_surface_name"))
	floor_body.set_meta(&"surface", "wood")
	var own := String(player.call("_surface_name"))
	_check("S15 the player on a bare floor in the hall walks on tile; the floor's own meta still wins",
		bare == "tile" and own == "wood", "%s, %s" % [bare, own])
	player.queue_free()
	floor_body.queue_free()
	sound.queue_free()
	made[1].queue_free()
	await _frames(3)


func _script(source: String) -> GDScript:
	var script := GDScript.new()
	script.source_code = source
	script.reload()
	return script




## A station whose track runs past the platform, its two mouths 60 and more metres off (past Sfx's reach), with a dozen
## signs on the line and two cable runs: one ending by the platform, one by the vaults.
func _fake_station() -> Node3D:
	var station: Node3D = _script(STATION_SOURCE).new()
	add_child(station)
	station.mouth_runs = [[-65.0, -55.0, -5.0, -1.0, 4.0], [65.0, 75.0, -5.0, -1.0, 4.0]]
	for k in 12:
		var sign := NeonSign.new()
		sign.seed = k
		station.add_child(sign)
		# (Past Focus's hearing, 14 m: there nothing counts them.)
		sign.position = Vector3(20.0 + k * 2.0, 3.0, -9.0)
		station.neon.append(sign)
	for end in [Vector3(1, 1, -9), Vector3(25, 1, 5)]:
		var run := Node3D.new()
		run.set_meta("points", PackedVector3Array([Vector3.ZERO, end]))
		station.add_child(run)
		station.runs.append(run)
	return station


## S16-S19, S23, S25-S26: one train for the Metro.
func _trains() -> void:
	var lane: Node = _script(LANE_SOURCE).new()
	var lane_train := TrainPass.new()
	lane_train.seed = 31
	lane.add_child(lane_train)
	lane.train = lane_train
	add_child(lane)
	var station := _fake_station()
	var ear := Node3D.new()
	add_child(ear)
	ear.global_position = PLATFORM_MID
	# (The ear hears through a camera, as the player does: Focus and Sfx measure from it.)
	var eye := Camera3D.new()
	ear.add_child(eye)
	eye.make_current()
	var sound := PlaceSound.new()
	add_child(sound)
	sound.setup(PLAN, ear, station, lane)
	_check("S16 with a lane, the Metro's train is the lane's", sound.train == lane_train, str(sound.train))

	await _frames(5)
	Sfx.recording = true
	Sfx.recorded.clear()
	sound.train.start_pass()
	var lowest := {}
	var most_at_once := 0
	var struck := 0
	for f in int(15.0 * 60):
		var before := Sfx.recorded.size()
		await get_tree().process_frame
		var now := Sfx.recorded.slice(before).filter(func(e): return e[0] == &"neon_ignite").size()
		most_at_once = maxi(most_at_once, now)
		struck += now
		for sign: NeonSign in station.neon:
			lowest[sign] = minf(float(lowest.get(sign, 1.0)), sign.dim)
		if f == int(1.3 * 60):
			var near: AudioStreamPlayer3D = sound.get("rumble_near")
			var far: AudioStreamPlayer = sound.get("rumble_far")
			var gusts := sound.train_heard().filter(func(h): return h[0] == &"metro_draught")
			_check("S17 a train heard from a platform 60 m and more from the mouths: its rumble voiced on the track nearest you, through the walls too, and its draught",
				near != null and near.playing and near.stream != null and near.max_distance >= 60.0
				and near.global_position.distance_to(Vector3(5.0, 0.5, -5.0)) < 0.5 and far != null and far.playing and gusts.size() == 1,
				"near %s at %s, far %s, gusts %d" % [near.playing if near else null, near.global_position if near else null,
					far.playing if far else null, gusts.size()])
		if f == int(6.0 * 60):
			var surges := sound.train_heard().filter(func(h): return h[0] == &"cable_surge")
			_check("S19 at the peak the cables surge, from the run end nearest the ear, though signs go out round it", surges.size() == 1
				and (surges[0][1] as Vector3).distance_to(Vector3(1, 1, -9)) < 0.01, str(surges))
	Sfx.recording = false
	var out := lowest.values().filter(func(v): return v < NeonSign.OUT_BELOW).size()
	_check("S23 the station's signs sag with the train, some far enough to go out, and come back",
		out > 0 and station.neon.all(func(s): return is_equal_approx(s.dim, 1.0)), "%d of 12 out" % out)
	_check("S25 the signs go out and strike back on out of step: never more than two at once", struck >= 1 and most_at_once <= 2,
		"%d ignitions, at most %d in a frame" % [struck, most_at_once])

	ear.global_position = OLD_MID
	await _frames(5)
	sound.train.start_pass()
	await _frames(int(1.3 * 60))
	var deep := sound.train_heard().filter(func(h): return h[0] == &"train_far" or h[0] == &"metro_draught")
	var near_deep: AudioStreamPlayer3D = sound.get("rumble_near")
	_check("S18 in the old layer the train is not heard",
		deep.is_empty() and (near_deep == null or not near_deep.playing or near_deep.volume_db <= -79.0), str(deep))
	await _frames(int(14.0 * 60))
	ear.global_position = NOWHERE
	await _frames(5)
	sound.train.start_pass()
	await _frames(int(1.3 * 60))
	var lost := sound.train_heard().filter(func(h): return h[0] == &"train_far" or h[0] == &"metro_draught")
	_check("S26 fallen out of every space from the old layer, the train is still not heard", lost.is_empty(), str(lost))
	for node in [sound, ear, station, lane]:
		node.queue_free()
	await _frames(3)
