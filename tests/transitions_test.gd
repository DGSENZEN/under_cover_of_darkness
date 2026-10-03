extends Node3D
## Districts as maps (the districts-as-maps plan): each district's map by
## itself (T1-T2), then the mission travelling between them through their
## gates, remembered and followed (T3-T12).
##   Godot --headless --fixed-fps 60 --path . res://tests/transitions_test.tscn

const OLD_TOWN := preload("res://maps/old_town.tscn")
const HARBOUR := preload("res://maps/city.tscn")
const LevelLoader := preload("res://scripts/Level/LevelLoader.gd")

const MISSION := preload("res://maps/mission.tscn")
## The harbour's load before its navmesh was baked offline (s).
const HARBOUR_LOAD_BEFORE := 13.8
## Exits ignore the player this long after he arrives (Mission.GRACE).
const GRACE := 1.0
## Guard.Alert.COMBAT.
const COMBAT := 4
## A body put back lies within this of where it lay (a limp man laid down).
const BODY_SLACK := 1.0
## A gate's crossing at most (s): dark, the next map built, up again.
const CROSSING := 3.0

var results: Array[String] = []


func _ready() -> void:
	await _alone()
	await _mission()
	print("\n==== RESULTS ====")

	for line in results:
		print(line)

	var failed := results.filter(func(r): return r.begins_with("FAIL")).size()
	print("\n%d pass, %d fail" % [results.size() - failed, failed])
	get_tree().quit()


# ---------------------------------------------------------------------------
# T1-T2: each district's map by itself
# ---------------------------------------------------------------------------

func _alone() -> void:
	var old: Node = OLD_TOWN.instantiate()
	add_child(old)
	await old.ready_to_play
	var start: Transform3D = old.marker("old_town_start").get("transform", Transform3D())
	var at_start: bool = old.player.global_position.distance_to(start.origin + Vector3.UP * 1.05) < 1.0
	var proxy: bool = old.get_node_or_null("city_harbour_proxy") != null
	var massing: Node = old.get_node_or_null("city_massing")
	var no_own_massing: bool = massing != null and massing.get_node_or_null("old_town") == null and massing.get_node_or_null("cathedral") != null
	_check("T1 the stand-in old town loads by itself: at its spawn, the harbour drawn by its proxy, its own massing left out, its navmesh from file",
		at_start and proxy and no_own_massing and bool(old.baker.from_file), "at spawn %s, harbour proxy %s, own massing out %s, from file %s" % [
			at_start, proxy, no_own_massing, old.baker.from_file])
	old.queue_free()
	await _frames(5)

	var harbour: Node = HARBOUR.instantiate()
	add_child(harbour)
	await harbour.ready_to_play
	var quick: bool = bool(harbour.baker.from_file) and float(harbour.load_seconds) < HARBOUR_LOAD_BEFORE
	var loaded_in: float = harbour.load_seconds
	var saved: String = harbour.navmesh_dir.path_join("harbour.scn")
	harbour.queue_free()
	await _frames(5)

	# The same file, its hash no longer the export's: the map bakes live.
	var stale_dir := "user://stale_nav"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(stale_dir))
	var snap: Node = (ResourceLoader.load(saved, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene).instantiate()
	snap.set_meta(&"source_hash", "an older export")
	var packed := PackedScene.new()
	packed.pack(snap)
	ResourceSaver.save(packed, stale_dir.path_join("harbour.scn"))
	snap.free()
	var again: Node = HARBOUR.instantiate()
	again.set("navmesh_dir", stale_dir)
	add_child(again)
	await again.ready_to_play
	var live: bool = not bool(again.baker.from_file) and bool(again.baker.is_baked)
	_check("T2 the harbour loads its saved navmesh, faster than before; a stale one is baked live instead",
		quick and live, "from file %s in %.1f s (was %.1f s); stale baked live %s" % [quick, loaded_in, HARBOUR_LOAD_BEFORE, live])
	again.queue_free()
	await _frames(5)


# ---------------------------------------------------------------------------
# T3-T12: the mission, through the gates
# ---------------------------------------------------------------------------

var mission: Node


func _mission() -> void:
	mission = MISSION.instantiate()
	add_child(mission)
	await mission.arrived
	var gates := ["sea_gate", "wall_walk", "guindais", "west_wall"]

	# T3 the Sea Gate both ways, standing where each side's arrival is
	await _through("exit_sea_gate")
	var there: bool = mission.map.district == &"old_town" and _at("from_harbour_sea_gate")
	# T6 standing still on arrival does not send him back
	await _seconds(3.0)
	var stays: bool = mission.map.district == &"old_town"
	await _through("to_harbour_sea_gate")
	var back: bool = mission.map.district == &"harbour" and _at("from_old_town_sea_gate")
	_check("T3 the Sea Gate leads to the old town and back, to each side's arrival, facing in", there and back, "there %s, back %s" % [there, back])
	_check("T6 standing still on arrival does not send him back", stays, "still in the old town after 3 s %s" % [stays])

	# T4 the other three gates, both ways
	var paired: Array[String] = []

	for gate in gates.slice(1):
		await _through("exit_" + gate)
		var out: bool = mission.map.district == &"old_town" and _at("from_harbour_" + gate)
		await _through("to_harbour_" + gate)
		var home: bool = mission.map.district == &"harbour" and _at("from_old_town_" + gate)

		if out and home:
			paired.append(gate)

	_check("T4 the wall-walk, Guindais and west wall gates pair both ways", paired.size() == 3, "paired %s" % [paired])

	# T5 the purse, tools, keys and health go with him
	var player: Node = mission.map.player
	player.inventory.add_loot(50)
	player.inventory.take_one(&"waterflask")
	player.inventory.add_key(&"customs", "the customs key")
	player.set("health", 70.0)
	var before := _carried(player)
	await _through("exit_sea_gate")
	var after := _carried(mission.map.player)
	# (His shield refills while nothing hurts him: as he had it at the gate,
	# give or take what fills during the crossing.)
	var at_gate := float(CityState.carried.get("health", -1.0))
	var health := float(mission.map.player.get("health"))
	var refill := float(mission.map.player.get("recover_rate")) * CROSSING
	_check("T5 the purse, tools, keys and health travel", before == after and at_gate >= 70.0 and health >= at_gate and health <= at_gate + refill,
		"before %s, after %s, health %.1f at the gate, %.1f after" % [before, after, at_gate, health])
	await _through("to_harbour_sea_gate")

	# T7 the harbour remembers loot, a door, a lamp
	var built: Dictionary = mission.map.made["city_harbour"]
	var loot_name: String = built["pickups"].keys().filter(func(n): return built["pickups"][n] is Loot)[0]
	built["pickups"][loot_name].frob(mission.map.player)
	var door_name: String = built["doors"].keys().filter(func(n): return not bool(built["doors"][n].locked))[0]
	built["doors"][door_name].frob(mission.map.player)
	var lamp_name := _lit_lamp(built["lights"])
	built["lights"][lamp_name].put_out(&"douse")
	await _seconds(1.5)
	await _through("exit_sea_gate")
	await _through("to_harbour_sea_gate")
	built = mission.map.made["city_harbour"]
	var remembered: bool = not is_instance_valid(built["pickups"][loot_name]) and bool(built["doors"][door_name].is_open) \
		and not built["lights"][lamp_name].is_lit()
	_check("T7 the harbour remembers: loot taken, a door open, a lamp out", remembered, "%s gone %s, %s open %s, %s out %s" % [loot_name,
		not is_instance_valid(built["pickups"][loot_name]), door_name, built["doors"][door_name].is_open, lamp_name, not built["lights"][lamp_name].is_lit()])

	# T8 a guard knocked out stays down
	var inigo: Node = mission.map.guards["Inigo"]
	inigo.knock_out(mission.map.player, true)
	await _seconds(2.5)
	var fell: Vector3 = _body("Inigo").global_position if _body("Inigo") != null else Vector3.INF
	await _through("exit_sea_gate")
	await _through("to_harbour_sea_gate")
	var lies: Node = _body("Inigo")
	# (He carried a lantern: put down again in silence, no lantern drops anew.)
	var dropped: int = get_tree().get_nodes_in_group(&"dropped_lights").filter(func(l): return mission.map.is_ancestor_of(l)).size()
	_check("T8 a guard knocked out stays down: no Inigo, his body where he fell, no lantern dropped again", not _standing("Inigo") and lies != null
		and lies.global_position.distance_to(fell) < BODY_SLACK and dropped == 0, "standing %s, body %s, %.2f m from where he fell, lanterns dropped %d" % [
			_standing("Inigo"), lies != null, lies.global_position.distance_to(fell) if lies != null else -1.0, dropped])

	# T9 a body on the shoulder is left at the gate
	mission.map.player.inventory.holster()
	await _frames(2)
	mission.map.player.frob.shoulder(_body("Inigo"))
	var carried: bool = mission.map.player.frob.shouldered != null
	await _through("exit_sea_gate")
	var empty: bool = mission.map.player.frob.shouldered == null
	await _through("to_harbour_sea_gate")
	var gate_at: Vector3 = _exit("exit_sea_gate").global_position
	var left: Node = _body("Inigo")
	_check("T9 a body on the shoulder is left at the gate", carried and empty and left != null and _flat(left.global_position, gate_at) < 3.0,
		"carried %s, hands empty there %s, body %.1f m from the gate" % [carried, empty, _flat(left.global_position, gate_at) if left != null else -1.0])

	# T10 a chasing watchman follows through the gate
	var duarte: Node = mission.map.guards["Duarte"]
	duarte.global_position = Vector3(-55.0, 2.6, -70.0)
	duarte.reset_physics_interpolation()
	await _frames(2)
	duarte.call("_engage", mission.map.player)
	await _seconds(0.5)
	await _through("exit_sea_gate")
	var arrival: Vector3 = (mission.map.marker("from_harbour_sea_gate")["transform"] as Transform3D).origin
	var follower: Node = null

	for i in 60 * 12:
		await get_tree().physics_frame
		follower = mission.map.guards.get("Duarte")

		if follower != null and is_instance_valid(follower) and int(follower.get("state")) == COMBAT:
			break

	var close: bool = follower != null and is_instance_valid(follower) and follower.global_position.distance_to(arrival) < 15.0
	var away: bool = CityState.districts.get(&"harbour", {}).get("guards", {}).get("Duarte", {}).has("away")
	_check("T10 a chasing watchman follows through the gate", close and int(follower.get("state")) == COMBAT and away,
		"followed %s, in combat %s, near the arrival %s, away at home %s" % [follower != null and is_instance_valid(follower),
			int(follower.get("state")) == COMBAT if follower != null and is_instance_valid(follower) else false, close, away])

	# T11 a follower knocked out in the old town is not raised at home
	if follower != null and is_instance_valid(follower):
		follower.knock_out(mission.map.player, true)

	await _seconds(1.5)
	await _through("to_harbour_sea_gate")
	_check("T11 a follower knocked out in the old town is not raised at home", not _standing("Duarte") and not mission.map.guards.has("Duarte"),
		"standing %s" % [_standing("Duarte")])

	# T13 a man who chases the player home is his district's own again: one
	# of him, his, where he was left; and (T13b) knocked out at home, he
	# stays down
	for test in [["T13", "Rodrigo", false], ["T13b", "Tome", true]]:
		var who: String = test[1]
		await _chase_through(who, Vector3(-55.0, 2.6, -70.0), "exit_sea_gate")
		var out13: bool = (await _until_fighting(who)) != null
		await _through("to_harbour_sea_gate")
		var home13 := await _until_fighting(who)
		var back13: bool = home13 != null

		if bool(test[2]) and home13 != null:
			home13.knock_out(mission.map.player, true)
			await _seconds(1.5)

		await _through("exit_west_wall")
		var kept: Dictionary = CityState.districts.get(&"harbour", {}).get("guards", {}).get(who, {})
		await _through("to_harbour_west_wall")
		var men: Array = get_tree().get_nodes_in_group(&"guards").filter(func(g): return mission.map.is_ancestor_of(g) and String(g.get("given_name")) == who)

		if bool(test[2]):
			_check("T13b a man who chased the player home and was knocked out there stays down", out13 and back13 and men.is_empty()
				and _body(who) != null, "followed out %s, back %s, standing %d, body %s" % [out13, back13, men.size(), _body(who) != null])
		else:
			var at13: Vector3 = (kept["transform"] as Transform3D).origin if kept.has("transform") else Vector3.INF
			var one: bool = men.size() == 1 and mission.map.guards.get(who) == men[0] and not mission.map.visitors.has(who)
			_check("T13 a man who chased the player home is one man, the district's own, where he was left", out13 and back13 and one
				and men[0].global_position.distance_to(at13) < 3.0, "followed out %s, back %s, men %d, his own %s, %.1f m from where left" % [out13,
					back13, men.size(), one, men[0].global_position.distance_to(at13) if not men.is_empty() else -1.0])

	# T14 a follower the player turns back before is not lost: away from home,
	# and waiting on the far side
	await _chase_through("Baltasar", Vector3(-55.0, 2.6, -64.0), "exit_sea_gate")
	await _through("to_harbour_sea_gate")
	var gone_home: bool = not _standing("Baltasar")
	await _through("exit_sea_gate")
	await _seconds(1.0)
	var waiting: Node = mission.map.guards.get("Baltasar")
	var near14: bool = waiting != null and is_instance_valid(waiting) and waiting.global_position.distance_to(
		(mission.map.marker("from_harbour_sea_gate")["transform"] as Transform3D).origin) < 20.0
	_check("T14 a follower the player turns back before is not lost: away from home, on the far side", gone_home and near14,
		"away from home %s, in the old town near the gate %s" % [gone_home, near14])
	await _through("to_harbour_sea_gate")

	# T6b an exit entered within a second of arriving does nothing; after it, it leads on
	await _seconds(0.5)
	var arrived_map: Node = mission.map
	var arrived_at: Vector3 = mission.map.player.global_position
	mission.map.player.teleport(Transform3D(mission.map.player.global_basis, _exit("exit_sea_gate").global_position))
	await _seconds(1.5)
	var held_back: bool = mission.map == arrived_map
	mission.map.player.teleport(Transform3D(mission.map.player.global_basis, arrived_at))
	await _seconds(0.3)
	await _through("exit_sea_gate")
	_check("T6b an exit entered in the arrival's first second does nothing; entered after it, it leads on", held_back and mission.map.district == &"old_town",
		"held back %s, then through %s" % [held_back, mission.map.district == &"old_town"])
	await _through("to_harbour_sea_gate")

	# T12 a sealed way says where it goes and goes nowhere
	var harbour_map: Node = mission.map
	await _seconds(GRACE + 0.2)
	mission.map.player.teleport(Transform3D(Basis(), _exit("exit_river").global_position))
	await _seconds(2.0)
	_check("T12 a sealed way goes nowhere", mission.map == harbour_map and mission.map.district == &"harbour", "still in the harbour %s" % [
		mission.map == harbour_map])
	mission.queue_free()
	await _frames(5)


## Through `exit` (an exit of the map in hand), once the arrival's grace is
## over: the next map, ready.
func _through(exit_name: String) -> void:
	await _seconds(GRACE + 0.2)
	var area := _exit(exit_name)

	if area == null:
		push_error("transitions_test: no exit %s in %s" % [exit_name, mission.map.district])
		return

	var from: int = mission.map.get_instance_id()
	mission.map.player.teleport(Transform3D(mission.map.player.global_basis, area.global_position))

	for i in 60 * 30:
		await get_tree().process_frame

		if bool(mission.get("settled")) and mission.map != null and is_instance_valid(mission.map) and mission.map.get_instance_id() != from:
			break

	await _frames(2)


## `who` (a guard of the map in hand) put at `at`, after the player, and the
## player through `exit_name` (he follows).
func _chase_through(who: String, at: Vector3, exit_name: String) -> void:
	var g: Node = mission.map.guards[who]
	# (The player between him and the gate: he runs at the gate.)
	var gate := _exit(exit_name).global_position
	mission.map.player.teleport(Transform3D(mission.map.player.global_basis, Vector3(gate.x, at.y, lerpf(at.z, gate.z, 0.3))))
	g.global_position = at
	g.reset_physics_interpolation()
	await _frames(2)
	g.call("_engage", mission.map.player)
	await _seconds(0.5)
	await _through(exit_name)


## The guard `who` of the map in hand once he is fighting (within 12 s), or null.
func _until_fighting(who: String) -> Node:
	for i in 60 * 12:
		await get_tree().physics_frame
		var g: Variant = mission.map.guards.get(who)

		if g != null and is_instance_valid(g) and int(g.get("state")) == COMBAT:
			return g

	return null


func _exit(exit_name: String) -> Area3D:
	return mission.map.get_node_or_null(exit_name) as Area3D


## The player stands at `arrival` (a marker of the map in hand), facing as it does.
func _at(arrival: String) -> bool:
	var m: Dictionary = mission.map.marker(arrival)

	if m.is_empty():
		return false

	var at: Transform3D = m["transform"]
	var player: Node3D = mission.map.player
	var turned := absf(wrapf(player.rotation.y - at.basis.get_euler().y, -PI, PI))
	return player.global_position.distance_to(at.origin + Vector3.UP * 1.05) < 1.0 and turned < deg_to_rad(10.0)


func _standing(who: String) -> bool:
	return get_tree().get_nodes_in_group(&"guards").any(func(g): return mission.map.is_ancestor_of(g) and g.name == who)


func _body(who: String) -> Node3D:
	for body in get_tree().get_nodes_in_group(&"bodies"):
		if mission.map.is_ancestor_of(body) and String(body.get("called")) == who:
			return body

	return null


## What `player` carries, as plain text: purse, keys, belt (id and count).
func _carried(player: Node) -> String:
	var keys: Array = player.inventory.keys.map(func(k): return String(k))
	keys.sort()
	var belt: Array = player.inventory.belt.map(func(e): return "%s x%d" % [e["id"], int(e["count"])])
	return "purse %d, keys %s, belt %s" % [player.inventory.purse, keys, belt]


## The first lamp of `lights` (name → node) that burns and can be doused.
func _lit_lamp(lights: Dictionary) -> String:
	for lamp_name in lights:
		var lamp: Variant = lights[lamp_name]

		if lamp is Node and is_instance_valid(lamp) and bool(lamp.get("can_douse")) and lamp.has_method("is_lit") and lamp.is_lit():
			return String(lamp_name)

	return ""


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _seconds(s: float) -> void:
	await _frames(int(s * Engine.physics_ticks_per_second))


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
