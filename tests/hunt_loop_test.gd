extends Node
## The whole loop, in the hunt gym as the running map: read the clue, pack, walk
## out, clear a wave, walk back; and die and come back to your pack. A bot with
## real keys. Stays under the root while the maps change around it.

const GYM := "res://maps/hunt_gym.tscn"
const SaveFiles := preload("res://scripts/Save/SaveFiles.gd")

var failed := 0
var runs: Array[String] = []
var gym: Node3D
var p: CharacterBody3D


func _ready() -> void:
	# Not the map: left alone when the map changes.
	get_tree().current_scene = null
	await get_tree().process_frame
	var copal_rounds: int = await _bot(true)
	var lead_rounds: int = await _bot(false)
	_check("LP2 with only lead packed it spends more than twice the rounds (%d, %d)" % [lead_rounds, copal_rounds], copal_rounds > 0 and lead_rounds > copal_rounds * 2.0)
	await _die_and_return()

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


func _walk_out() -> void:
	p.rotation.y = 0.0
	Input.action_press("move_forward")
	await _until(func(): return p.global_position.z < gym.YARD_START - 1.0, 5.0)
	Input.action_release("move_forward")


## One wave, with copal or with lead: the rounds it took.
func _bot(copal: bool) -> int:
	await _new_gym()
	p.invulnerable = true
	CityState.job.read_slot("eye_clue")

	if copal:
		gym.kit_table.piece(&"copal").frob(p)
		gym.kit_table.piece(&"egg").frob(p)

	await _walk_out()
	var g: Node = p.revolver

	if copal:
		await _press("switch_round")
		await _until(func(): return not g.is_reloading(), 8.0)

	var fired := [0]
	g.fired.connect(func(_barrel, _hits): fired[0] += 1)
	var eyes: Array = gym.get_tree().get_nodes_in_group(&"monsters").filter(func(m): return not m.asleep)
	var ticks := 0

	while eyes.any(func(m): return not m.dead) and ticks < 7200:
		ticks += 1
		var eye: Node3D = eyes.filter(func(m): return not m.dead).reduce(func(a, b): return a if a.global_position.distance_to(p.global_position) < b.global_position.distance_to(p.global_position) else b)
		_aim_at(eye)

		# The evil eye on you, and an egg in your pocket.
		if copal and p.statuses.has(&"evil_eye") and int(p.loadout.item_counts.get(&"egg", 0)) > 0 and not p.loadout.is_using():
			await _press("use_item")
		elif int(g.loaded[&"cylinder"]) == 0 and not g.is_reloading():
			await _press("reload")
		elif g.ready_to_fire():
			await _press("throw")
		else:
			await get_tree().physics_frame

	var cleared: bool = eyes.all(func(m): return m.dead)
	# Back to the door, and in.
	p.look_at_from_position(p.global_position, Vector3(0, p.global_position.y, 2.0), Vector3.UP)
	p.neck.rotation = Vector3.ZERO
	Input.action_press("move_forward")
	var back := await _until(func(): return not p.loadout.locked, 8.0)
	Input.action_release("move_forward")

	if copal:
		_check("LP1 read the clue, pack copal and the egg, walk out, wave 1 clears, and walk back", cleared and back and CityState.job.notes.has("eye_weakness"))
		_check("LP1b the walk back restocked the pouch from what was owned", p.inventory.ammo[&"copal_rounds"] > 6 and p.loadout.owned[&"copal_rounds"] < 12)

	return fired[0]


func _aim_at(target: Node3D) -> void:
	var way: Vector3 = (target.global_position - p.camera.global_position).normalized()
	p.rotation.y = atan2(-way.x, -way.z)
	p.neck.rotation = Vector3(asin(way.y), 0.0, 0.0)


func _die_and_return() -> void:
	await _new_gym()
	gym.kit_table.piece(&"copal").frob(p)
	gym.kit_table.piece(&"egg").frob(p)
	var wrote := [false]
	var on_saved := func(_run, _slot, error): wrote[0] = error == OK
	SaveGame.saved.connect(on_saved)
	await _walk_out()
	await _until(func(): return wrote[0], 6.0)
	SaveGame.saved.disconnect(on_saved)
	_check("LP3a walking out wrote the save", wrote[0])
	p.inventory.take_ammo(&"copal_rounds", 7)
	p.loadout.item_counts[&"egg"] = 0
	p.take_damage(100000.0, null)
	await _seconds(2.5)
	_check("LP3b dead, the page asks", p.is_dead and p.hud.death_page.visible)
	var old: Node = gym
	p.hud.death_page.load_latest()
	await _until(func(): return get_tree().current_scene != old and get_tree().current_scene != null and not SaveGame.loading, 15.0)
	await _frames(60)
	gym = get_tree().current_scene
	p = gym.player
	_check("LP3e a load makes no new run", SaveFiles.last_run() == runs[-1] and CityState.run_id == runs[-1])
	_check("LP3 dying brings you back to the door with the pack and all of it", p.loadout.rounds.has(&"copal") and p.inventory.ammo[&"copal_rounds"] == 12 and p.loadout.item_counts.get(&"egg", 0) == 2 and not p.is_dead)
	_check("LP3c just past the door, the wave not yet begun", absf(p.global_position.z - (-gym.ROOM.z)) < 2.5 and gym.wave_now == 0)
	p.look_at_from_position(p.global_position, Vector3(0, p.global_position.y, 2.0), Vector3.UP)
	Input.action_press("move_forward")
	var unlocked := await _until(func(): return not p.loadout.locked, 4.0)
	Input.action_release("move_forward")
	_check("LP3d a step back in and you can pack otherwise", unlocked)


func _press(action: String) -> void:
	Input.action_press(action)
	await get_tree().physics_frame
	Input.action_release(action)
	await get_tree().physics_frame


func _until(done: Callable, most: float) -> bool:
	var t := 0.0

	while t < most:
		if done.call():
			return true

		await get_tree().physics_frame
		t += 1.0 / 60.0

	return false


func _seconds(count: float) -> void:
	await _frames(int(count * 60.0))


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(label: String, ok: bool) -> void:
	print(("PASS " if ok else "FAIL ") + label)

	if not ok:
		failed += 1
