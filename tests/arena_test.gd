extends Node
## The proving grounds map: it builds, its levers let fighters into the
## ring, the gauntlet moves on wave by wave, and its training posts do what
## their signs say.

const ARENA := preload("res://maps/combat_arena.tscn")
const DummyScript := preload("res://scripts/Combat/TrainingDummy.gd")
const TemperamentScript := preload("res://scripts/AISystem/Temperament.gd")

var arena: Node3D
var player: CharacterBody3D
var results: Array[String] = []


func _ready() -> void:
	# Every guard at his class's own temperament: these checks are exact.
	TemperamentScript.rolling = false
	arena = ARENA.instantiate()
	add_child(arena)
	player = arena.player
	player.invulnerable = true
	player.reload_on_death = false

	if player.has_node("LightGem"):
		player.get_node("LightGem").queue_free()

	player.debug_light_level = 1.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await arena._baker.baked
	await _frames(10)
	await _run()

	print("\n==== RESULTS ====")
	for r in results:
		print(r)
	get_tree().quit()


func _run() -> void:
	# A1 it builds: the player, the posts and patrols, levers, dummies, hazards
	var guards := get_tree().get_nodes_in_group(&"guards").size()
	var levers := _count(func(n): return n.get_script() != null and n.has_method("get_prompt") and n.has_signal("pulled"))
	var dummies := _count(func(n): return n.get_script() == DummyScript)
	var barrels := get_tree().get_nodes_in_group(&"explosives").size()
	_check("A1 the proving grounds build: posts, patrols, levers, straw men, powder", guards >= 9 and levers == 8 and dummies == 5 and barrels >= 6,
		"guards %d levers %d dummies %d barrels %d" % [guards, levers, dummies, barrels])

	# A2 a lever lets a swordsman into the ring, and he comes for you
	player.global_position = Vector3(0, 1.05, -10)
	await _frames(5)
	_lever("Swordsman (1)").frob(player)
	await _frames(2)
	var fighter: CharacterBody3D = arena._ring[0] if not arena._ring.is_empty() else null
	var reached := false

	for i in 600:
		if fighter != null and is_instance_valid(fighter) and fighter.global_position.distance_to(player.global_position) < 2.6:
			reached = true
			break

		await _frames(1)

	_check("A2 the swordsman's lever sends him through the gate to fight you", fighter != null and fighter.archetype == &"swordsman" and reached and fighter.state == 4,
		"spawned %s reached %s state %s" % [fighter != null, reached, fighter.state if fighter != null else -1])

	# A3 clearing the ring
	_lever("Clear the ring (7)").frob(player)
	await _frames(3)
	_check("A3 clearing the ring removes its fighters", arena._ring.is_empty() and (fighter == null or not is_instance_valid(fighter)), "left %d" % arena._ring.size())

	# A4 the gauntlet: wave after wave
	arena._start_gauntlet()
	await _until(func(): return arena._ring.size() == 1, 240)
	var first: int = arena._ring.size()
	arena._ring[0].die(null)
	await _until(func(): return arena._ring.size() == 2, 360)
	var second: int = arena._ring.size()
	_check("A4 the gauntlet: one swordsman, and when he falls, two", first == 1 and second == 2 and arena._wave == 1,
		"wave one %d, wave two %d (wave %d)" % [first, second, arena._wave])
	arena._clear_ring()
	await _frames(5)

	# A5 each kind is its own man: build, health, weapon
	var looks := {}

	for kind in [&"swordsman", &"duelist", &"brute", &"archer"]:
		var g: CharacterBody3D = arena._spawn(kind, Vector3(-40 + looks.size() * 3, 0, 20), 0.0)
		await _frames(2)
		var radius: float = (g.get_node("CollisionShape3D").shape as CapsuleShape3D).radius
		var tip: Vector3 = g._rig.weapon.mesh.get_meta(&"blade_tip", Vector3.ZERO)
		looks[kind] = [radius, g.max_health, tip.y]
		g.queue_free()

	var distinct: bool = looks[&"brute"][0] > looks[&"swordsman"][0] and looks[&"brute"][1] > looks[&"swordsman"][1] and looks[&"duelist"][1] < looks[&"swordsman"][1] and looks[&"duelist"][2] != looks[&"swordsman"][2] and looks[&"archer"][2] == 0.0
	_check("A5 swordsman, duelist, brute and archer differ in build, health and weapon", distinct, "%s" % looks)

	# A6 the arms master swings on a beat, and never leaves his post. Anyone
	# still after you from before is sent back to his post first.
	var master := _named("Arms master")

	for g in get_tree().get_nodes_in_group(&"guards"):
		if g != master:
			g.alert = 0.0
			g._set_state(0)
			g._fighter.release_token()

	var post: Vector3 = master.global_position
	player.global_position = post + Vector3(0, 1.05, 1.7)
	player.rotation.y = 0.0
	await _frames(20)
	master._engage(player)
	var strikes := 0
	var was := &""

	for i in 360:
		if master._phase == &"strike" and was != &"strike":
			strikes += 1

		was = master._phase
		await _frames(1)

	_check("A6 the arms master swings on a steady beat and keeps his post", strikes >= 3 and master.global_position.distance_to(post) < 0.3,
		"strikes %d moved %.2f m" % [strikes, master.global_position.distance_to(post)])

	# A7 the fencer never swings first
	var fencer := _named("Fencer")
	player.global_position = fencer.global_position + Vector3(0, 1.05, 1.7)
	await _frames(10)
	fencer._engage(player)
	var fencer_swung := false

	for i in 240:
		if fencer._phase != &"":
			fencer_swung = true

		await _frames(1)

	_check("A7 the fencer never swings first", not fencer_swung and fencer.state == 4, "swung %s state %d" % [fencer_swung, fencer.state])

	# A8 a straw man says what it took
	var dummy: StaticBody3D = null

	for n in _all(arena):
		if n.get_script() == DummyScript and not n.guards:
			dummy = n
			break

	var labels_before := _count(func(n): return n is Label3D)
	dummy.take_hit(34.0, player, &"quick", dummy.global_position + Vector3.UP * 1.2, Vector3.FORWARD)
	await _frames(2)
	_check("A8 a straw man calls out what it took", _count(func(n): return n is Label3D) == labels_before + 1, "labels %d -> %d" % [labels_before, _count(func(n): return n is Label3D)])

	# A9 R (the rest lever) puts you right
	player.health = 20.0
	player.combat.stamina = 3.0
	_lever("Rest (R)").frob(player)
	_check("A9 resting restores health and stamina", player.health == player.max_health and player.combat.stamina == player.combat.stamina_max, "health %.0f stamina %.0f" % [player.health, player.combat.stamina])


func _lever(title: String) -> Node:
	for n in _all(arena):
		if n.has_signal("pulled") and n.get("verb") == title:
			return n

	return null


func _named(speaker: String) -> CharacterBody3D:
	for g in get_tree().get_nodes_in_group(&"guards"):
		if g.speaker_name == speaker:
			return g

	return null


func _all(node: Node) -> Array:
	var found := [node]

	for child in node.get_children():
		found.append_array(_all(child))

	return found


func _count(test: Callable) -> int:
	var n := 0

	for node in _all(arena):
		if test.call(node):
			n += 1

	return n


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
