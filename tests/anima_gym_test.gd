extends Node
## The ánima gym as the running map: its table, its waves, and a bot with real keys:
## with copal and the whip it clears a wave; with lead alone it can't.

const GYM := "res://maps/anima_gym.tscn"
const HUNT := preload("res://maps/hunt_gym.gd")
const SaveFiles := preload("res://scripts/Save/SaveFiles.gd")
const AnimaScript := preload("res://scripts/Monsters/Anima.gd")
const STATE: Dictionary = AnimaScript.State

var failed := 0
var runs: Array[String] = []
var gym: Node3D
var p: CharacterBody3D


func _ready() -> void:
	get_tree().current_scene = null
	await get_tree().process_frame
	await _layout()
	var lead: Dictionary = await _bot(false)
	var copal: Dictionary = await _bot(true)
	_check("G8 a bot with copal and the whip clears wave one (%.1f s, %d rounds)" % [copal["seconds"], copal["fired"]], copal["cleared"])
	_check("G9 lead alone wastes rounds and time, and would have died (%.1f s, %d rounds, %.0f life lost)" % [lead["seconds"], lead["fired"], lead["life_lost"]], lead["fired"] >= copal["fired"] * 2.5 and lead["life_lost"] >= 100.0)
	_check("G10 the hunt gym is as it was", HUNT.WAVES[0]["eyes"] == 3 and HUNT.WAVES.size() == 3)

	for run in runs:
		SaveFiles.delete_run(run)

	print("==== RESULTS ====")
	get_tree().quit(1 if failed > 0 else 0)


func _new_gym() -> void:
	get_tree().change_scene_to_file(GYM)
	await get_tree().scene_changed
	await _frames(60)
	gym = get_tree().current_scene
	p = gym.player
	runs.append(CityState.run_id)


func _layout() -> void:
	await _new_gym()
	_check("G1 it loads: a room, a table, a yard", gym.kit_table != null and p != null)
	var kit: Array = gym._kit().map(func(entry): return entry[0])
	_check("G2 the table offers lead, copal and the line, no egg", kit == [&"lead", &"copal", &"copal_line"])
	_check("G7 no eyes in it", get_tree().get_nodes_in_group(&"monsters").all(func(m): return m.get("form") != null))
	p.invulnerable = true
	await _walk_out()
	var awake := _awake()
	_check("G3 into the yard, five hands come (%d)" % awake.size(), awake.size() == 5 and awake.all(func(m): return m.form == &"hands"))
	_check("G3b up out of the drains, not all at once from one place", _spread(awake))
	_clear(awake)
	await _until(func(): return gym.wave_now == 2, 8.0)
	_check("G4 cleared, the next: two faces and four hands", _forms(_awake()) == {&"face": 2, &"hands": 4})
	_clear(_awake())
	await _until(func(): return gym.wave_now == 3, 8.0)
	_check("G5 the third: a torso, two faces, four hands", _forms(_awake()) == {&"torso": 1, &"face": 2, &"hands": 4})
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.keycode = KEY_F6
	_clear(_awake())
	await _frames(2)
	await _new_gym()
	var before: int = gym.wave_now
	gym._input(ev)
	await _frames(5)
	_check("G6 F6 calls the next wave", gym.wave_now == before + 1)


func _walk_out() -> void:
	p.rotation.y = 0.0
	Input.action_press("move_forward")
	await _until(func(): return p.global_position.z < gym.YARD_START - 1.0, 5.0)
	Input.action_release("move_forward")


## Wave one, at most 30 s of it, with copal and the whip or with lead alone.
func _bot(copal: bool) -> Dictionary:
	await _new_gym()
	p.invulnerable = true
	CityState.job.read_slot("anima_clue")

	if copal:
		gym.kit_table.piece(&"copal").frob(p)
		gym.kit_table.piece(&"copal_line").frob(p)

	await _walk_out()
	var g: Node = p.revolver

	if copal:
		await _press("switch_round")
		await _until(func(): return not g.is_reloading(), 8.0)

	var fired := [0]
	g.fired.connect(func(_barrel, _hits): fired[0] += 1)
	var drained := [0.0]
	p.health = p.max_health
	p.invulnerable = false
	p.reload_on_death = false
	var members: Array = _awake()
	var ticks := 0

	while members.any(func(m): return not m.dead) and ticks < 3600:
		ticks += 1

		# Kept alive, to see what it would have cost.
		if p.health < 50.0:
			drained[0] += p.max_health - p.health
			p.health = p.max_health

		var living: Array = members.filter(func(m): return not m.dead)
		var nearest: Node3D = living.reduce(func(a, b): return a if a.global_position.distance_to(p.global_position) < b.global_position.distance_to(p.global_position) else b)
		_aim_at(nearest)

		if copal and p.leech.count() > 0:
			p.revolver.try_whip()
			await _frames(8)
			ticks += 8
		elif int(g.loaded[&"cylinder"]) == 0 and not g.is_reloading():
			await _press("reload")
		elif g.ready_to_fire():
			await _press("throw")
		else:
			await get_tree().physics_frame

	drained[0] += p.max_health - p.health
	p.invulnerable = true
	return {"cleared": members.all(func(m): return m.dead), "fired": fired[0], "seconds": float(ticks) / 60.0, "life_lost": drained[0]}


func _aim_at(target: Node3D) -> void:
	var way: Vector3 = (target.global_position - p.camera.global_position).normalized()
	p.rotation.y = atan2(-way.x, -way.z)
	p.neck.rotation = Vector3(asin(way.y), 0.0, 0.0)


func _awake() -> Array:
	return get_tree().get_nodes_in_group(&"monsters").filter(func(m): return not m.asleep and not m.dead)


func _forms(list: Array) -> Dictionary:
	var counts := {}

	for m in list:
		counts[m.form] = int(counts.get(m.form, 0)) + 1

	return counts


func _spread(list: Array) -> bool:
	for i in list.size():
		for j in range(i + 1, list.size()):
			if list[i].global_position.distance_to(list[j].global_position) < 1.0:
				return false

	return true


func _clear(list: Array) -> void:
	for m in list:
		m.take_hit(9999.0, p, &"power", m.global_position, Vector3.FORWARD)


func _press(action: String) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)


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
