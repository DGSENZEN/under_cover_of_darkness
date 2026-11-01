extends Node3D
## The Metro's sound (docs/superpowers/specs/2026-10-31-metro-sound-design.md), headless with --fixed-fps 60, sound on
## and Master muted: Sfx's tile steps, gains and blended rooms (S1-S3); the director on a plan of its own (S4-S12);
## floors answering from the place (S14-S15); the director in the Metro (S13).

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
		"openings": [{"to": "hall", "at": [5, 10], "width": 2.0}]}]}
const HALL_MID := Vector3(5, 1, 5)
const HALL_MARKET_DOOR := Vector3(9.9, 1, 5)
const MARKET_MID := Vector3(15, 1, 5)
const OLD_MID := Vector3(25, 1, 5)
const SHOP_MID := Vector3(5, 1, 15)
const NOWHERE := Vector3(-40, 1, -40)

var results: Array[String] = []
var failures := 0


func _ready() -> void:
	Sfx.enabled = true
	AudioServer.set_bus_mute(0, true)
	Sfx._ensure_buses()
	await _sfx()
	await _director()
	await _floors()
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

	var shots := [&"pipe_tick", &"neon_ignite", &"cable_surge", &"train_far", &"metro_draught"]
	var loops := [&"metro_room", &"metro_room_deep", &"metro_crowd", &"junction_hum", &"transformer_hum"]
	_check("S3 every Metro name has a gain", shots.all(func(n): return Sfx.GAIN.has(n))
		and loops.all(func(n): return Sfx.LOOP_GAIN.has(n)),
		"missing %s" % str((shots.filter(func(n): return not Sfx.GAIN.has(n))
			+ loops.filter(func(n): return not Sfx.LOOP_GAIN.has(n)))))


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
