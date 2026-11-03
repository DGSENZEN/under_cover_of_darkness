extends Node
## The revenant gym as the running map: its table, its waves, walking out and coming back.

const GYM := "res://maps/revenant_gym.tscn"
const SaveFiles := preload("res://scripts/Save/SaveFiles.gd")

var failed := 0
var runs: Array[String] = []
var gym: Node3D
var p: CharacterBody3D


func _ready() -> void:
	get_tree().current_scene = null
	await get_tree().process_frame
	get_tree().change_scene_to_file(GYM)
	await get_tree().scene_changed
	await _frames(60)
	gym = get_tree().current_scene
	p = gym.player
	runs.append(CityState.run_id)
	_check("G0 it loads: a room, a table, a yard", gym.kit_table != null and p != null)
	var kit: Array = gym._kit().map(func(entry): return entry[0])
	_check("G0b the table offers lead, copal, fire and the egg", kit == [&"lead", &"copal", &"fire", &"egg"])
	p.loadout.pack_round(&"copal")
	_check("G2 fire or copal on the table, one or the other", not p.loadout.pack_round(&"fire"))
	p.loadout.unpack_round(&"copal")
	p.loadout.pack_round(&"fire")
	p.loadout.restock()
	_check("G2b with fire packed, the shot barrel holds it", p.revolver.shot_round == &"fire")
	p.invulnerable = true
	var counts: Array[int] = []

	for number in 3:
		gym.wave(number + 1)
		await _frames(30)
		var awake: Array = get_tree().get_nodes_in_group(&"monsters").filter(func(m): return not m.asleep and not m.dead)
		counts.append(awake.size())

		for one in awake:
			one.health = 1.0
			one.take_hit(5.0, p, &"fire", one.global_position, Vector3.BACK)

		await _frames(5)

	_check("G1 waves of one, two and three come (%s)" % str(counts), counts == [1, 2, 3])
	_check("G1b and clear", gym._wave_cleared())
	await _frames(int(3.5 * 60.0))
	var all_put_out: bool = get_tree().get_nodes_in_group(&"monsters").all(func(m): return not m.visible)
	_check("G1c nothing of them left", all_put_out)
	# Its touch goes when you are back at the table.
	_check("G3 the touch goes, safe at the table", await _back_at_the_table())

	for run in runs:
		SaveFiles.delete_run(run)

	print("revenant_gym_test: %s" % ("FAILED %d" % failed if failed > 0 else "passed"))
	get_tree().quit(1 if failed > 0 else 0)


func _back_at_the_table() -> bool:
	var one: CharacterBody3D = preload("res://scripts/Monsters/Revenant.gd").new()
	one.position = Vector3(0, 0, -34)
	gym.add_child(one)
	await _frames(3)
	one._surge_in = 99.0
	p.touch.lay(one, 0.0, 0.0)
	p.loadout.lock()
	gym.safe_place.out_for = 99.0
	p.teleport(Transform3D(Basis.IDENTITY, Vector3(0, 1.05, 1.0)))
	var went: bool = await _until(func(): return not p.touch.on_you(), 3.0)
	return went and is_instance_valid(one) and not one.dead


func _until(done: Callable, most: float) -> bool:
	var left := int(most * 60.0)

	while left > 0:
		if done.call():
			return true

		left -= 1
		await get_tree().physics_frame

	return done.call()


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(label: String, ok: bool) -> void:
	print("%s %s" % ["PASS" if ok else "FAIL", label])

	if not ok:
		failed += 1
