extends Node
## What the mixed gym's worst costs, in real frames: the last wave up, its eyes turned, six curse
## eyes and three on you. Windowed:
## Godot --disable-vsync --path . --resolution 1152x648 res://tests/diag_mixed_perf.tscn

const SaveFiles := preload("res://scripts/Save/SaveFiles.gd")


func _ready() -> void:
	get_tree().current_scene = null
	await get_tree().process_frame
	get_tree().change_scene_to_file("res://maps/mixed_gym.tscn")
	await get_tree().scene_changed

	for i in 60:
		await get_tree().physics_frame

	var gym: Node3D = get_tree().current_scene
	var p: CharacterBody3D = gym.player
	p.invulnerable = true
	p.teleport(Transform3D(Basis.IDENTITY, Vector3(0, 1.05, -16)))
	await _measure("empty yard", 120)
	gym.wave(3)

	for one in get_tree().get_nodes_in_group(&"monsters"):
		if not one.asleep and one.get("form") == null:
			one.turn()

	await _measure("wave three, all eyes turned", 240)
	p.statuses.apply(&"evil_eye", 600.0)

	for i in 5:
		p.curse.deepen()

	var on_you := 0

	for one in get_tree().get_nodes_in_group(&"monsters"):
		if not one.asleep and one.get("form") != null and on_you < 3 and one.form != &"torso":
			one.global_position = p.global_position + Vector3(0.5, 0.3, 0.2)
			one.put_on_you()
			on_you += 1

	await _measure("the worst: six curse eyes, three on you (%d)" % on_you, 600)
	SaveFiles.delete_run(CityState.run_id)
	get_tree().quit()


func _measure(label: String, frames: int) -> void:
	var took: Array[float] = []
	var was := Time.get_ticks_usec()
	var scripts := 0.0
	var physics := 0.0
	var physics_most := 0.0
	var scripts_most := 0.0

	for i in frames:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		took.append(float(now - was) / 1000.0)
		was = now
		var a := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		var b := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		scripts += a
		physics += b
		scripts_most = maxf(scripts_most, a)
		physics_most = maxf(physics_most, b)

	took = took.slice(20)
	took.sort()
	var sum := 0.0

	for t in took:
		sum += t

	print("  process mean %.1f most %.1f ms, physics mean %.1f most %.1f ms, draw calls %d, objects %d" % [scripts / frames, scripts_most, physics / frames, physics_most, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)])
	print("PERF %s: mean %.1f ms, p99 %.1f ms, worst %.1f ms, over 16.7 ms: %d of %d, gobs %d" % [label, sum / took.size(), took[int(took.size() * 0.99)], took[-1], took.filter(func(t): return t > 16.7).size(), took.size(), get_tree().get_nodes_in_group(&"eye_gobs").size()])
