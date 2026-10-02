extends Node3D
## Real capsules on wet terrain, including the harbour rowboat's collision recipe.

const PLAYER := preload("res://Player.tscn")
const WATER := preload("res://scripts/Interaction/WaterVolume.gd")
var player: CharacterBody3D
var results: Array[String] = []
var failed := false

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="):
			Engine.physics_ticks_per_second = int(arg.trim_prefix("--hz="))
	for x in [0, 20, 40, 60, 80, 100, 120]:
		_box(Vector3(x, -4.5, 0), Vector3(14, 1, 16))
		WATER.build(self, Vector3(x, -2, 0), Vector3(14, 4, 16))
	# Borderline shallows are standable when entered from land as well as water.
	_box(Vector3(0, -1.84, -5), Vector3(8, 1, 8)) # top -1.34
	# Same 20 cm risers as the harbour quay steps, starting below the surface.
	for i in 12:
		var top := -1.5 + 0.2 * i
		_box(Vector3(20, (top - 4) * 0.5, -2.2 - 0.4 * i), Vector3(6, top + 4, 0.4))
	_box(Vector3(20, -1.65, -7.5), Vector3(6, 4.7, 2))
	# Exact rowboat collision dimensions from kit_ships.py, translated to z=-4.
	_box(Vector3(40, -0.17, -4), Vector3(3.2, 0.1, 1.0))
	_box(Vector3(40, 0.2, -3.32), Vector3(3.6, 0.8, 0.1))
	_box(Vector3(40, 0.2, -4.68), Vector3(3.6, 0.8, 0.1))
	# A walkable bank top with a face tilted 20 degrees away from vertical.
	var slope := _box(Vector3(60, -1.75, -6), Vector3(8, 4.5, 4))
	slope.rotation.x = deg_to_rad(20)
	# A narrow rail over deep water is not a valid exit.
	_box(Vector3(80, 0.2, -4), Vector3(6, 0.8, 0.1))
	# A shallow tread with too little room for the swimmer's standing capsule.
	_box(Vector3(100, -1.84, -5), Vector3(8, 1, 8))
	_box(Vector3(100, 0.3, -5), Vector3(8, 0.2, 8)) # underside 0.2
	# Boat rail, but its interior floor is obstructed by a low deckhead.
	_box(Vector3(120, -0.17, -4), Vector3(3.2, 0.1, 1.0))
	_box(Vector3(120, 0.2, -3.32), Vector3(3.6, 0.8, 0.1))
	_box(Vector3(120, 0.2, -4.68), Vector3(3.6, 0.8, 0.1))
	_box(Vector3(120, 1.0, -4), Vector3(3.2, 0.1, 1.0))
	player = PLAYER.instantiate()
	player.show_hud = false
	add_child(player)
	player.invulnerable = true
	player.reload_on_death = false
	player.get_node("LightGem").queue_free()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _frames(5)
	await _run()
	_release()
	print("\n==== RESULTS ====")
	for result in results:
		print(result)
	get_tree().quit(1 if failed else 0)

func _run() -> void:
	await _place(Vector3(0, -0.68, 0))
	Input.action_press("move_forward")
	await _until_z(-2.5, 160)
	_release()
	await _frames(90)
	_check("WG1 swimming into standable shallows restores walking", player.movement_state == 0 and player.is_on_floor() and player.global_position.z < -1.5,
		"position %s state %d feet %s" % [player.global_position, player.movement_state, player.get_feet_position()])

	await _place(Vector3(20, -0.68, -1))
	Input.action_press("move_forward")
	await _until_z(-7, 360)
	_release()
	await _frames(90)
	_check("WG2 wet quay steps can be walked out without a jump", player.movement_state == 0 and player.global_position.z < -6.8 and player.get_feet_position().y > 0.6,
		"position %s state %d reject %s" % [player.global_position, player.movement_state, player._last_reject])

	await _place(Vector3(40, -0.68, -2.6))
	Input.action_press("move_forward")
	Input.action_press("jump")
	var entered_boat := false
	var crossed_solid := false
	for i in 180:
		await _frames(1)
		crossed_solid = crossed_solid or not player.scanner.fits(player.global_position, player.is_crouched)
		if player.movement_state == 0 and absf(player.global_position.z + 4) < 0.18:
			entered_boat = true
			break
	_release()
	await _frames(60)
	_check("WG3 a swimmer clambers across a boat gunwale onto its floor", entered_boat and not crossed_solid and player.movement_state == 0 and player.is_on_floor() and player.get_feet_position().y > -0.24 and player.get_feet_position().y < 0 and absf(player.global_position.z + 4) < 0.2,
		"position %s state %d entered %s crossed %s reject %s" % [player.global_position, player.movement_state, entered_boat, crossed_solid, player._last_reject])

	await _place(Vector3(60, -0.68, -2.6))
	Input.action_press("move_forward")
	Input.action_press("jump")
	await _until_z(-5, 180)
	_release()
	await _frames(90)
	_check("WG4 a reachable sloped bank supports a water mantle", player.movement_state == 0 and player.global_position.z < -4.5 and player.get_feet_position().y > -0.1,
		"position %s state %d reject %s" % [player.global_position, player.movement_state, player._last_reject])

	await _place(Vector3(80, -0.68, -3.3))
	Input.action_press("move_forward")
	Input.action_press("jump")
	await _frames(180)
	_check("WG5 a thin rail over deep water cannot invent an exit", player.movement_state == 4 and player.global_position.z > -3.55 and player.scanner.fits(player.global_position, player.is_crouched),
		"position %s state %d reject %s" % [player.global_position, player.movement_state, player._last_reject])

	await _place(Vector3(100, -0.68, 0))
	Input.action_press("move_forward")
	await _frames(180)
	_check("WG6 a shallow tread cannot step through a low ceiling", player.movement_state == 4 and player.global_position.z > -1.0 and player.scanner.fits(player.global_position, player.is_crouched),
		"position %s state %d" % [player.global_position, player.movement_state])

	await _place(Vector3(120, -0.68, -2.6))
	Input.action_press("move_forward")
	Input.action_press("jump")
	await _frames(180)
	_check("WG7 a boat exit cannot cross a blocked deckhead", player.movement_state == 4 and player.global_position.z > -2.9 and player.scanner.fits(player.global_position, player.is_crouched),
		"position %s state %d reject %s" % [player.global_position, player.movement_state, player._last_reject])

	# A dive releases the wet stair hold rather than freezing the ascent height.
	await _place(Vector3(20, -0.68, -1))
	Input.action_press("move_forward")
	var stepped := false
	for i in 80:
		await _frames(1)
		if player.movement_state == 4 and player._step_lock_timer > 0.0:
			stepped = true
			break
	_release()
	var before := player.global_position.y
	Input.action_press("move_back")
	Input.action_press("crouch")
	await _frames(60)
	_check("WG8 diving off a wet step releases its height hold", stepped and player.movement_state == 4 and player.global_position.y < before - 0.5,
		"position %s stepped %s start %.3f state %d" % [player.global_position, stepped, before, player.movement_state])

func _place(at: Vector3) -> void:
	_release()
	player.teleport(Transform3D(Basis.IDENTITY, at))
	player._set_crouched(false)
	player.neck.rotation.x = 0
	await _frames(5)

func _release() -> void:
	for action in ["move_forward", "move_back", "move_left", "move_right", "jump", "crouch", "sprint"]:
		Input.action_release(action)

func _frames(count: int) -> void:
	for i in maxi(1, int(round(float(count) * Engine.physics_ticks_per_second / 60.0))):
		await get_tree().physics_frame

func _until_z(limit: float, count: int) -> void:
	for i in count:
		await _frames(1)
		if player.movement_state == 0 and player.global_position.z < limit:
			return

func _box(center: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	add_child(body)
	body.global_position = center
	return body

func _check(label: String, ok: bool, detail: String) -> void:
	failed = failed or not ok
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", label, detail])
