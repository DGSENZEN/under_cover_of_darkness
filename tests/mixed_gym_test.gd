extends Node
## The mixed gym as the running map: its table, its waves of eyes and ánimas together, and a bot
## with real keys that clears the first.

const GYM := "res://maps/mixed_gym.tscn"
const ANIMA_GYM := preload("res://maps/anima_gym.gd")
const HUNT := preload("res://maps/hunt_gym.gd")
const SaveFiles := preload("res://scripts/Save/SaveFiles.gd")

var failed := 0
var runs: Array[String] = []
var gym: Node3D
var p: CharacterBody3D


func _ready() -> void:
	get_tree().current_scene = null
	await get_tree().process_frame
	await _layout()
	await _bot()
	_check("X5 tested alone is kept: the other two gyms are as they were", HUNT.WAVES[0]["eyes"] == 3 and ANIMA_GYM.ANIMA_WAVES[0] == {&"hands": 5})

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
	_check("X0 it loads: a room, a table, a yard", gym.kit_table != null and p != null)
	var kit: Array = gym._kit().map(func(item): return item[0])
	_check("X4 the kit has what answers both", kit == [&"lead", &"copal", &"copal_line", &"egg"])
	p.invulnerable = true
	_check("X6 nothing comes till you step out", _awake().is_empty())
	await _walk_out()
	await _frames(10)
	_check("X1 wave one: three hands and two eyes (%s)" % str(_counts(_awake())), _counts(_awake()) == {&"hands": 3, &"eyes": 2})
	_check("X1b an ánima has its leap chance, and rests", _awake().filter(_is_anima).all(func(m): return m.rests and m.leap_chance < 1.0))
	_check("X1c the eyes are circling", _awake().filter(func(m): return not _is_anima(m)).all(func(m): return m.state == m.State.CIRCLE))
	_clear(_awake())
	await _until(func(): return gym.wave_now == 2, 8.0)
	await _frames(5)
	_check("X2 clearing one brings the next: two faces, three hands, three eyes (%s)" % str(_counts(_awake())), _counts(_awake()) == {&"face": 2, &"hands": 3, &"eyes": 3})
	_clear(_awake())
	await _until(func(): return gym.wave_now == 3, 8.0)
	await _frames(5)
	var third_is: Dictionary = _counts(_awake())
	_clear(_awake())
	await _until(func(): return gym.wave_now == 4, 8.0)
	await _frames(5)
	var last_wave: Array = _awake()
	var the_elite: Array = last_wave.filter(func(m): return _is_anima(m) and m.elite)
	_check("X2c the last: an elite, with enough by it to take three (%s)" % str(_counts(last_wave)), the_elite.size() == 1 and _counts(last_wave) == {&"torso": 1, &"face": 2, &"hands": 4, &"eyes": 3} and last_wave.filter(func(m): return _is_anima(m) and m != the_elite[0] and m.global_position.distance_to(the_elite[0].global_position) < 4.0).size() >= 3)
	_check("X2b the third: a torso, two faces, three hands, four eyes (%s)" % str(third_is), third_is == {&"torso": 1, &"face": 2, &"hands": 3, &"eyes": 4})


## Wave one, with copal and the whip, at most 60 s of it.
func _bot() -> void:
	await _new_gym()
	p.invulnerable = true
	gym.kit_table.piece(&"copal").frob(p)
	gym.kit_table.piece(&"copal_line").frob(p)
	await _walk_out()
	var g: Node = p.revolver
	await _press("switch_round")
	await _until(func(): return not g.is_reloading(), 8.0)
	p.health = p.max_health
	p.invulnerable = false
	p.reload_on_death = false
	var members: Array = _awake()
	var ticks := 0

	while members.any(func(m): return not m.dead) and ticks < 3600:
		ticks += 1

		if p.health < 50.0:
			p.health = p.max_health

		var living: Array = members.filter(func(m): return not m.dead)
		var nearest: Node3D = living.reduce(func(a, b): return a if a.global_position.distance_to(p.global_position) < b.global_position.distance_to(p.global_position) else b)
		_aim_at(nearest)

		if p.leech.count() > 0:
			p.revolver.try_whip()
			await _frames(8)
			ticks += 8
		elif int(g.loaded[&"cylinder"]) == 0 and not g.is_reloading():
			await _press("reload")
		elif g.ready_to_fire():
			await _press("throw")
		else:
			await get_tree().physics_frame

	p.invulnerable = true
	_check("X3 a bot can clear it (%.1f s)" % (float(ticks) / 60.0), members.all(func(m): return m.dead))


func _walk_out() -> void:
	p.rotation.y = 0.0
	Input.action_press("move_forward")
	await _until(func(): return p.global_position.z < gym.YARD_START - 1.0, 5.0)
	Input.action_release("move_forward")


func _aim_at(target: Node3D) -> void:
	var way: Vector3 = (target.global_position - p.camera.global_position).normalized()
	p.rotation.y = atan2(-way.x, -way.z)
	p.neck.rotation.x = asin(way.y)


func _is_anima(m: Node) -> bool:
	return m.get("form") != null


func _awake() -> Array:
	return get_tree().get_nodes_in_group(&"monsters").filter(func(m): return not m.dead and not m.asleep)


func _counts(list: Array) -> Dictionary:
	var counts := {}

	for m in list:
		var kind_of: StringName = m.form if _is_anima(m) else &"eyes"
		counts[kind_of] = counts.get(kind_of, 0) + 1

	return counts


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
