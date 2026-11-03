extends Node
## What its gym's worst costs, in real frames: three of them coming at you, then all three burning. Windowed:
## Godot --disable-vsync --path . --resolution 1152x648 res://tests/diag_revenant_perf.tscn


func _ready() -> void:
	get_tree().current_scene = null
	await get_tree().process_frame
	get_tree().change_scene_to_file("res://maps/revenant_gym.tscn")
	await get_tree().scene_changed

	for i in 60:
		await get_tree().physics_frame

	var gym: Node3D = get_tree().current_scene
	var p: CharacterBody3D = gym.player
	p.invulnerable = true
	p.teleport(Transform3D(Basis.IDENTITY, Vector3(0, 1.05, -16)))
	await _measure("the yard, empty", 200)
	gym.wave(3)
	var three: Array = get_tree().get_nodes_in_group(&"monsters").filter(func(m): return not m.asleep)

	for i in three.size():
		three[i].global_position = p.global_position + Vector3(float(i) * 2.6 - 2.6, -1.05, -6.0)

	await _measure("three, coming at you", 300)

	for one in three:
		one.take_hit(5.0, p, &"fire", one.global_position, Vector3.BACK)

	await _measure("three burning", 240)
	get_tree().quit()


func _measure(what: String, frames: int) -> void:
	for i in 20:
		await get_tree().process_frame

	var took: Array[float] = []
	var was := Time.get_ticks_usec()
	var physics := 0.0

	for i in frames:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		took.append(float(now - was) / 1000.0)
		was = now
		physics += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0

	took = took.slice(10)
	took.sort()
	var sum := 0.0

	for t in took:
		sum += t

	print("PERF %s: mean %.1f ms, p99 %.1f ms, over 16.7 ms: %d of %d, physics %.1f ms" % [what, sum / took.size(), took[int(took.size() * 0.99)], took.filter(func(t): return t > 16.7).size(), took.size(), physics / float(frames)])
