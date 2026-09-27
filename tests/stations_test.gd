extends Node3D
## Guard stations: camp life (GuardStation, GuardRota). A man with a station
## goes there at his ease and does its thing (sits, eats, sleeps, rummages
## through chests, carries crates, chops wood, leans on a rail); anything
## that stirs him ends it with its proper exit; calm again, he goes back.
##
##   Godot --headless --fixed-fps 60 --quit-after 3000000 --path . res://tests/stations_test.tscn

const GUARD := preload("res://Guard.tscn")
const INTRUDER := preload("res://Intruder.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const NavBakerScript := preload("res://scripts/AISystem/NavBaker.gd")
const SquadScript := preload("res://scripts/AISystem/Squad.gd")
const GarrisonScript := preload("res://scripts/AISystem/Garrison.gd")
const TemperamentScript := preload("res://scripts/AISystem/Temperament.gd")
const GuardScript := preload("res://scripts/AISystem/Guard.gd")
const SoundBus := preload("res://scripts/StimuliSystem/SoundBus.gd")
const LightProbe := preload("res://scripts/StimuliSystem/LightProbe.gd")
const Dangers := preload("res://scripts/AISystem/Dangers.gd")
const GuardStationScript := preload("res://scripts/AISystem/GuardStation.gd")
const GuardRotaScript := preload("res://scripts/AISystem/GuardRota.gd")

const RELAXED := 0
const SUSPICIOUS := 1

var results: Array[String] = []
var _barks := {}
var _heard: Array = []


## Hears every gameplay sound (for the lid's bang).
class Ears:
	var heard: Array

	func _init(into: Array) -> void:
		heard = into

	func hear_sound(event: Dictionary) -> void:
		heard.append(event)


func _ready() -> void:
	TemperamentScript.rolling = false
	GuardScript.bleeding_on = false
	# A floor pad of its own for each check, well apart: one baked floor this
	# long leaves navmesh edges unjoined along the benches (paths go round).
	for pad in [[0.0, 18.0], [30.0, 18.0], [60.0, 18.0], [90.0, 18.0], [122.0, 18.0], [155.0, 22.0], [183.0, 16.0], [205.0, 18.0], [232.0, 16.0]]:
		Props.block(self, Vector3(pad[0], -0.5, 0), Vector3(pad[1], 1, 20))

	# Benches and a bedroll's floor: low blocks the seats stand before.
	for x in [0.0, 30.0, 60.0, 90.0]:
		Props.block(self, Vector3(x, 0.22, -0.6), Vector3(2.4, 0.44, 0.5), Color(0.36, 0.25, 0.15))

	var baker := NavigationRegion3D.new()
	baker.set_script(NavBakerScript)
	add_child(baker)
	var ears := Ears.new(_heard)
	SoundBus.add_listener(ears)
	await baker.baked
	await _frames(5)
	await _run()
	SoundBus.remove_listener(ears)
	GuardScript.randomize_on = true

	print("\n==== RESULTS ====")
	for r in results:
		print(r)
	get_tree().quit()


func _run() -> void:
	# T1 to his seat, down on it, facing its way
	await _fresh()
	var seat1 := _station(&"sit", Vector3(0, 0, 0), PI)
	var g1 := _guard(Vector3(4, 0, 4), [seat1])
	var shown1 := []
	await _until(func():
		var a: StringName = g1.activity()
		if shown1.is_empty() or shown1[-1] != a:
			shown1.append(a)
		return a == &"sit", 900)
	var off1 := _flat(g1.global_position, seat1.global_position)
	var facing1 := rad_to_deg((-g1.global_basis.z).angle_to(-seat1.global_basis.z))
	_check("T1 a man with a sit station walks there, sits (sit_down then sit), and faces its way",
		shown1.has(&"sit_down") and g1.activity() == &"sit" and off1 < 0.45 and facing1 < 20.0,
		"shown %s, %.2f m off, facing %.0f deg off" % [shown1, off1, facing1])

	# T2 two seated men at ease pass the time
	await _fresh()
	var seat2a := _station(&"sit", Vector3(29.4, 0, 0), PI)
	var seat2b := _station(&"sit", Vector3(30.6, 0, 0), PI)
	var g2a := _guard(Vector3(29, 0, 4), [seat2a])
	var g2b := _guard(Vector3(31, 0, 4), [seat2b])
	await _until(func(): return g2a.activity() == &"sit" and g2b.activity() == &"sit", 900)
	g2a._life._talk_rest = 0.0
	g2b._life._talk_rest = 0.0
	await _until(func(): return g2a.activity() == &"sit_talk" or g2b.activity() == &"sit_talk", 900)
	_check("T2 two seated men at ease within 3.8 m talk: one shows sit_talk",
		g2a.activity() == &"sit_talk" or g2b.activity() == &"sit_talk",
		"%s / %s" % [g2a.activity(), g2b.activity()])

	# T3 stirred, a sitter stands up: busy while he does, then on his feet
	await _fresh()
	var seat3 := _station(&"sit", Vector3(60, 0, 0), PI)
	var g3 := _guard(Vector3(60, 0, 3), [seat3])
	await _until(func(): return g3.activity() == &"sit", 900)
	await _frames(2)
	var put_away: bool = not g3._rig.weapon.visible and bool(g3._hands.armed)
	g3.alert = 40.0
	g3.last_known_position = g3.global_position + Vector3(5, 0, 5)
	g3.has_last_known = true
	await _frames(3)
	var standing3: StringName = g3.activity()
	var busy3: bool = g3._rota.busy()
	await _frames(int(GuardRotaScript.STAND_UP * 60.0) + 10)
	_check("T3 stirred (alert to 40), a sitter shows stand_up, is busy, then leaves RELAXED on his feet",
		standing3 == &"stand_up" and busy3 and not g3._rota.busy() and g3.state != RELAXED and not (g3.activity() in [&"sit", &"sit_talk", &"stand_up"]),
		"at the stir %s busy %s; after: %s busy %s state %d" % [standing3, busy3, g3.activity(), g3._rota.busy(), g3.state])

	# T8 calm again, he goes back to his seat
	g3.alert = 0.0
	await _until(func(): return g3.state == RELAXED, 900)
	var back_at := [0]
	var frames8 := [0]
	await _until(func():
		frames8[0] += 1
		return g3.activity() == &"sit", int((GuardRotaScript.STATION_RETURN + 12.0) * 60.0))
	_check("T8 calm again for STATION_RETURN s, he goes back to his station",
		g3.activity() == &"sit" and float(frames8[0]) / 60.0 >= GuardRotaScript.STATION_RETURN - 0.5,
		"%s after %.1f s at his ease" % [g3.activity(), float(frames8[0]) / 60.0])

	# T12 (at ease his blade is in its scabbard: GuardRig) still his at his
	# station, and drawn once he goes to look
	g3.alert = g3.investigate_at + 5.0
	await _until(func(): return g3._rig.weapon.visible, 300)
	_check("T12 at his station his blade is in its scabbard (still his), and drawn once he goes to look",
		put_away and g3._rig.weapon.layers != 0 and g3._rig.weapon.visible,
		"seated: in its scabbard and his %s; looking: layers %d, drawn %s" % [put_away, g3._rig.weapon.layers, g3._rig.weapon.visible])

	# T4 asleep: blind, hard of hearing, and up when something gets through
	await _fresh()
	_light(Vector3(90, 3, 3))
	var bed4 := _station(&"sleep", Vector3(90, 0, 0), PI)
	var g4 := _guard(Vector3(90, 0, 0.5), [bed4])
	g4.rotation.y = PI
	await _until(func(): return g4.activity() == &"sleep", 900)
	var i4 := _intruder(Vector3(90, 0, 5))
	await _frames(180)
	var saw4: float = g4.alert
	SoundBus.emit_sound(g4.global_position + Vector3(4, 0.5, 0), 50.0, i4, &"clatter")
	await _frames(20)
	var quiet4: float = g4.alert
	var asleep4: bool = g4._rota.asleep()
	SoundBus.emit_sound(g4.global_position + Vector3(4, 0.5, 0), 70.0, i4, &"clatter")
	var woke4 := [false]
	await _until(func():
		woke4[0] = woke4[0] or g4.activity() == &"wake"
		return woke4[0], 120)
	_check("T4 a sleeper sees nothing in light at 5 m for 3 s, sleeps through a 50 dB noise at 4 m, and wakes (wake) at a 70 dB one",
		saw4 == 0.0 and quiet4 == 0.0 and asleep4 and woke4[0],
		"alert after 3 s in view %.1f, after the quiet noise %.1f (asleep %s), woke %s" % [saw4, quiet4, asleep4, woke4[0]])

	# T5 the quartermaster goes through his chests
	await _fresh()
	var chest5a: Node3D = Props.chest(self, Vector3(120, 0, -1.2), 0.0)
	var chest5b: Node3D = Props.chest(self, Vector3(124, 0, -1.2), 0.0)
	chest5a.add_to_group(&"stations_props")
	chest5b.add_to_group(&"stations_props")
	var at5a := _station(&"rummage", Vector3(120, 0, 0), PI, {"chest": chest5a})
	var at5b := _station(&"rummage", Vector3(124, 0, 0), PI, {"chest": chest5b})
	var g5 := _guard(Vector3(122, 0, 4), [at5a, at5b])
	var opened5a := [false]
	var rummaged5 := [false]
	await _until(func():
		opened5a[0] = opened5a[0] or chest5a.is_open
		rummaged5[0] = rummaged5[0] or g5.activity() == &"rummage"
		return chest5b.is_open, int((GuardRotaScript.RUMMAGE_TIME.y + 25.0) * 60.0))
	_check("T5 the quartermaster opens a chest, rummages, mutters, closes it, and opens the next",
		opened5a[0] and rummaged5[0] and not chest5a.is_open and chest5b.is_open and not _barks[g5].is_empty(),
		"first opened %s, rummaged %s, first closed again %s, second open %s, said %s" % [opened5a[0], rummaged5[0], not chest5a.is_open, chest5b.is_open, _barks[g5]])

	# T7 stirred at an open chest, he bangs the lid shut
	_heard.clear()
	g5.alert = 40.0
	g5.last_known_position = g5.global_position + Vector3(0, 0, 6)
	g5.has_last_known = true
	await _frames(30)
	var bang7 := _heard.any(func(e): return e["kind"] == &"clang" and (e["position"] as Vector3).distance_to(chest5b.global_position) < 2.0)
	_check("T7 stirred with a lid open, the lid is shut and a clang is heard on the SoundBus",
		not chest5b.is_open and bang7,
		"lid open %s, clang heard %s" % [chest5b.is_open, bang7])

	# T6 the carrier: a crate from the cart to the store; stirred, he drops it
	await _fresh()
	var drop6 := Marker3D.new()
	add_child(drop6)
	drop6.global_position = Vector3(160, 0, 0)
	drop6.add_to_group(&"stations_props")
	var crate6a := _crate(Vector3(150.6, 0.3, 0))
	var pick6 := _station(&"carry", Vector3(150, 0, 0), -PI * 0.5, {"drop_to": drop6})
	var g6 := _guard(Vector3(150, 0, 3), [pick6])
	var lifted6 := [false]
	await _until(func():
		lifted6[0] = lifted6[0] or (g6._rota.carried == crate6a and g6.activity() == &"carry")
		return lifted6[0] and g6._rota.carried == null, 2400)
	var set6 := _flat(crate6a.global_position, drop6.global_position)
	_check("T6a the carrier carries a crate from the pick-up to drop_to and sets it down",
		lifted6[0] and set6 < 1.2 and not crate6a.freeze,
		"lifted %s, set down %.2f m from the drop, frozen %s" % [lifted6[0], set6, crate6a.freeze])
	var crate6b := _crate(Vector3(150.6, 0.3, 0.6))
	await _until(func(): return g6._rota.carried == crate6b and g6.activity() == &"carry", 2400)
	var carrying6: bool = g6._rota.carried == crate6b
	await _frames(20)
	g6.alert = 40.0
	g6.last_known_position = g6.global_position + Vector3(0, 0, 6)
	g6.has_last_known = true
	await _frames(40)
	var loose6 := Dangers.throwables_near(g6, crate6b.global_position, 1.0).has(crate6b)
	_check("T6b stirred mid-carry, the crate falls loose and Dangers.throwables_near finds it",
		carrying6 and g6._rota.carried == null and not crate6b.freeze and crate6b.collision_layer == 1 and loose6,
		"was carrying %s, still carried %s, frozen %s, layer %d, throwable %s" % [carrying6, g6._rota.carried != null, crate6b.freeze, crate6b.collision_layer, loose6])

	# T9 one station, one man
	await _fresh()
	var seat9 := _station(&"sit", Vector3(180, 0, 0), PI)
	var g9a := _guard(Vector3(179, 0, 3), [seat9])
	var g9b := _guard(Vector3(181, 0, 3), [seat9])
	await _frames(600)
	var sitting9 := int(g9a.activity() in [&"sit", &"sit_down", &"sit_talk"]) + int(g9b.activity() in [&"sit", &"sit_down", &"sit_talk"])
	_check("T9 two men never hold one station",
		sitting9 == 1 and seat9.holder != null,
		"%s / %s, holder %s" % [g9a.activity(), g9b.activity(), seat9.holder])

	# T10 the chopper and the leaner show theirs
	await _fresh()
	var block10 := _station(&"chop", Vector3(200, 0, 0), PI)
	var rail10 := _station(&"lean", Vector3(206, 0, 0), PI)
	var g10a := _guard(Vector3(200, 0, 3), [block10])
	var g10b := _guard(Vector3(206, 0, 3), [rail10])
	var chopped := [false]
	var leaned := [false]
	await _until(func():
		chopped[0] = chopped[0] or g10a.activity() == &"chop"
		leaned[0] = leaned[0] or g10b.activity() == &"lean"
		return chopped[0] and leaned[0], 900)
	_check("T10 a chopper chops and a man at a rail leans on it",
		chopped[0] and leaned[0],
		"chop %s, lean %s" % [chopped[0], leaned[0]])

	# T10b the chopper chops with an axe in his hand, his blade in its
	# scabbard, and each blow is heard
	_heard.clear()
	var axe10 := [false]
	var drawn10 := [false]
	await _until(func():
		if g10a.activity() == &"chop":
			axe10[0] = axe10[0] or g10a._rig.man.find_child("StationAxe", true, false) != null
			drawn10[0] = drawn10[0] or g10a._rig.weapon.visible
		return false, 300)
	var blows10 := _heard.filter(func(e): return e["kind"] == &"chop" and e["source"] == g10a)
	_check("T10b a chopper at his station chops with an axe, blow on blow, each heard; his blade stays in its scabbard",
		axe10[0] and blows10.size() >= 2 and not drawn10[0],
		"axe %s, blows heard %d, blade out %s" % [axe10[0], blows10.size(), drawn10[0]])

	# T13 a carrier knocked out mid-carry: his crate falls loose
	await _fresh()
	var drop13 := Marker3D.new()
	add_child(drop13)
	drop13.global_position = Vector3(165, 0, 5)
	drop13.add_to_group(&"stations_props")
	var crate13 := _crate(Vector3(150.6, 0.3, 5))
	var pick13 := _station(&"carry", Vector3(150, 0, 5), -PI * 0.5, {"drop_to": drop13})
	var g13 := _guard(Vector3(150, 0, 8), [pick13])
	await _until(func(): return g13._rota.carried == crate13 and g13.activity() == &"carry", 2400)
	await _frames(20)
	var held13: bool = g13._rota.carried == crate13
	var height13 := crate13.global_position.y
	g13.knock_out(g13, true)
	await _frames(60)
	_check("T13 a carrier knocked out mid-carry lets his crate fall loose",
		held13 and not crate13.freeze and crate13.collision_layer == 1 and crate13.global_position.y < height13 - 0.3,
		"was holding %s, frozen %s, layer %d, height %.2f -> %.2f" % [held13, crate13.freeze, crate13.collision_layer, height13, crate13.global_position.y])

	# T14 a quartermaster killed at an open chest leaves the lid shut
	await _fresh()
	var chest14: Node3D = Props.chest(self, Vector3(120, 0, -1.2), 0.0)
	chest14.add_to_group(&"stations_props")
	var at14 := _station(&"rummage", Vector3(120, 0, 0), PI, {"chest": chest14})
	var g14 := _guard(Vector3(121, 0, 3), [at14])
	await _until(func(): return g14.activity() == &"rummage", 1200)
	var open14: bool = chest14.is_open
	g14.take_hit(999.0, null, &"backstab", g14.global_position + Vector3.UP, Vector3.FORWARD)
	await _frames(40)
	_check("T14 a quartermaster killed at an open chest leaves it shut and the station free",
		open14 and not chest14.is_open and at14.holder == null,
		"was open %s, open now %s, holder %s" % [open14, chest14.is_open, at14.holder])

	# T11 an eater sits and eats
	await _fresh()
	var seat11 := _station(&"eat", Vector3(230, 0, 0), PI)
	var g11 := _guard(Vector3(230, 0, 3), [seat11])
	var ate := [false]
	await _until(func():
		ate[0] = ate[0] or g11.activity() == &"eat"
		return ate[0], int((GuardRotaScript.EAT_EVERY.y + 8.0) * 60.0))
	_check("T11 a man at an eat station stands there and eats now and then",
		ate[0],
		"last shown %s" % g11.activity())


func _station(kind: StringName, at: Vector3, yaw: float, links := {}) -> Node3D:
	var station: Marker3D = GuardStationScript.new()
	station.kind = kind
	add_child(station)
	station.global_position = at
	station.rotation.y = yaw

	for key in links:
		station.set(key, station.get_path_to(links[key]))

	return station


func _guard(at: Vector3, stations: Array) -> CharacterBody3D:
	var g: CharacterBody3D = GUARD.instantiate()
	g.temperament = &"steady"
	g.position = at
	var paths: Array[NodePath] = []

	for station in stations:
		paths.append((station as Node).get_path())

	g.stations = paths
	add_child(g)
	_barks[g] = []
	g.barked.connect(func(t): _barks[g].append(t))
	return g


func _intruder(at: Vector3) -> CharacterBody3D:
	var i: CharacterBody3D = INTRUDER.instantiate()
	i.position = at
	add_child(i)
	return i


func _crate(at: Vector3) -> RigidBody3D:
	var crate := Props.crate(self, at, 0.5, 5.0)
	crate.add_to_group(&"cargo")
	return crate


func _light(at: Vector3) -> void:
	var lamp := OmniLight3D.new()
	lamp.omni_range = 12.0
	lamp.light_energy = 3.0
	lamp.add_to_group(&"test_lights")
	add_child(lamp)
	lamp.global_position = at
	LightProbe.invalidate()


func _fresh() -> void:
	for group in [&"guards", &"player"]:
		for g in get_tree().get_nodes_in_group(group):
			g.remove_from_group(group)
			g.set_physics_process(false)
			g.queue_free()

	for group in [&"bodies", &"dropped_weapons", &"dropped_lights", &"test_lights", &"guard_stations", &"cargo", &"stations_props"]:
		for thing in get_tree().get_nodes_in_group(group):
			thing.queue_free()

	SquadScript.clear_all()
	GarrisonScript.clear_all()
	LightProbe.invalidate()
	await _frames(3)
	GuardScript.randomize_on = false
	seed(1926)


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _until(cond: Callable, max_frames: int) -> void:
	for i in max_frames:
		if cond.call():
			return
		await get_tree().physics_frame


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
