extends Node3D
## Measures every fight move as it stands, with the real player and real
## input, and prints one row per move (the hunts plan, Task 1).
##   Godot --headless --fixed-fps 60 --path . res://tests/diag_fight_moves.tscn

const PLAYER := preload("res://Player.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const ACTIONS := ["move_left", "move_right", "move_forward", "move_back", "sprint", "crouch", "aim", "throw", "reload", "blink", "dodge"]

var p: CharacterBody3D


func _ready() -> void:
	Props.block(self, Vector3(0, -0.5, 0), Vector3(60, 1, 60))
	p = PLAYER.instantiate()
	add_child(p)
	p.debug_traversal = false
	p.invulnerable = true
	p.reload_on_death = false
	p.position = Vector3(0, 1.05, 0)
	Props.give_revolver(p, 200, 20)
	Props.give_weapons(p)
	p.inventory.select_by_id(&"revolver")
	await _frames(60)
	await _strafes()
	await _gun_rows()
	await _q_rows()
	print("==== DONE ====")
	get_tree().quit(0)


func _strafes() -> void:
	# Start: from still, seconds to 90% of walk sideways.
	await _settle()
	Input.action_press("move_right")
	var start := await _time_until(func(): return _side() >= p.walk_speed * 0.9, 2.0)
	await _frames(30)
	Input.action_release("move_right")
	var stop := await _time_until(func(): return _flat() < 0.2, 2.0)
	_row("strafe start", "%.3f s to 90%% of walk (%.1f m/s)" % [start, p.walk_speed])
	_row("strafe stop", "%.3f s to under 0.2 m/s" % stop)

	await _settle()
	Input.action_press("move_left")
	await _frames(40)
	Input.action_release("move_left")
	Input.action_press("move_right")
	var reverse := await _time_until(func(): return _side() >= p.walk_speed * 0.9, 2.0)
	Input.action_release("move_right")
	_row("strafe reverse", "%.3f s from held left to 90%% held right" % reverse)

	await _settle()
	Input.action_press("sprint")
	Input.action_press("move_right")
	var ready_ticks := 0
	var ticks := 90
	var top := 0.0

	for i in ticks:
		await get_tree().physics_frame
		top = maxf(top, absf(_side()))
		ready_ticks += 1 if p.revolver.ready_to_fire() else 0

	Input.action_release("move_right")
	Input.action_release("sprint")
	_row("strafe + sprint", "%.2f m/s sideways; gun ready %d of %d ticks" % [top, ready_ticks, ticks])

	await _settle()
	Input.action_press("aim")
	await _frames(20)
	Input.action_press("move_right")
	await _frames(60)
	_row("aim strafe", "%.2f m/s sideways" % absf(_side()))
	Input.action_release("move_right")
	Input.action_release("aim")

	await _settle()
	Input.action_press("move_right")
	var loaded_was: int = p.revolver.loaded[&"cylinder"]

	for i in 180:
		Input.action_press("throw")
		await get_tree().physics_frame
		Input.action_release("throw")
		await get_tree().physics_frame

	Input.action_release("move_right")
	_row("fire while strafing", "%d shots in 6 s at a walk, clicking every other tick" % (loaded_was - int(p.revolver.loaded[&"cylinder"])))

	await _settle()
	p.inventory.ammo[&"rounds"] = 200
	p.revolver.loaded[&"cylinder"] = 6
	Input.action_press("move_right")
	await _frames(20)
	var mesh := _gun_mesh()
	var low := INF
	var high := -INF

	for i in 120:
		await get_tree().physics_frame

		if mesh != null:
			var x: float = (p.camera.global_transform.affine_inverse() * mesh.global_position).x
			low = minf(low, x)
			high = maxf(high, x)

	Input.action_release("move_right")
	_row("gun lateral swing", "%.4f m peak to peak over 2 s" % (high - low) if mesh != null else "no gun mesh found")


func _gun_rows() -> void:
	await _settle()
	p.revolver.reset_for_practice()
	await _frames(40)
	var hip := await _cadence(false)
	var aimed := await _cadence(true)
	_row("shot cadence", "%.3f s at the hip, %.3f s aimed" % [hip, aimed])

	await _settle()
	p.revolver.reset_for_practice()
	await _frames(40)
	p.revolver.loaded[&"cylinder"] = 0
	Input.action_press("reload")
	await get_tree().physics_frame
	Input.action_release("reload")
	await _frames(2)
	var reload := await _time_until(func(): return not p.revolver.is_reloading(), 15.0)
	_row("full reload", "%.3f s, empty to %d" % [reload, p.revolver.loaded[&"cylinder"]])


func _q_rows() -> void:
	await _settle()
	var at: Vector3 = p.global_position
	var power_was: float = p.power.power
	Input.action_press("blink")
	await _frames(2)
	Input.action_release("blink")
	await _frames(40)
	_row("Q tap, gun drawn", "%.2f m, %.0f power spent" % [at.distance_to(p.global_position), power_was - p.power.power])

	p.inventory.select_by_id(&"sword")
	await _frames(60)
	await _settle()
	at = p.global_position
	Input.action_press("dodge")
	await _frames(2)
	Input.action_release("dodge")
	var dodged: float = await _time_until(func(): return p.combat.phase != p.combat.Phase.DODGE and _flat() < 0.2, 2.0)
	_row("Q tap, sword drawn", "%.2f m in %.3f s" % [at.distance_to(p.global_position), dodged])
	p.inventory.select_by_id(&"revolver")


func _cadence(aimed: bool) -> float:
	if aimed:
		Input.action_press("aim")
		await _frames(20)

	var shots: Array[float] = []
	var t := 0.0
	var left: int = p.revolver.loaded[&"cylinder"]
	p.revolver.loaded[&"cylinder"] = 6
	left = 6

	while shots.size() < 3 and t < 6.0:
		Input.action_press("throw")
		await get_tree().physics_frame
		Input.action_release("throw")
		await get_tree().physics_frame
		t += 2.0 / 60.0

		if int(p.revolver.loaded[&"cylinder"]) < left:
			left = p.revolver.loaded[&"cylinder"]
			shots.append(t)

	if aimed:
		Input.action_release("aim")

	await _frames(50)
	return (shots[-1] - shots[0]) / maxf(shots.size() - 1.0, 1.0) if shots.size() > 1 else -1.0


func _gun_mesh() -> MeshInstance3D:
	return p.hand.gun_mesh()


func _settle() -> void:
	for action in ACTIONS:
		Input.action_release(action)

	p.teleport(Transform3D(Basis.IDENTITY, Vector3(0, 1.05, 0)))
	p.power.power = p.power.MAX
	await _frames(40)


func _side() -> float:
	return p.velocity.dot(p.global_basis.x)


func _flat() -> float:
	return Vector2(p.velocity.x, p.velocity.z).length()


func _time_until(done: Callable, most: float) -> float:
	var t := 0.0

	while t < most:
		if done.call():
			return t

		await get_tree().physics_frame
		t += 1.0 / 60.0

	return -1.0


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _row(what: String, value: String) -> void:
	print("ROW | %s | %s" % [what, value])
