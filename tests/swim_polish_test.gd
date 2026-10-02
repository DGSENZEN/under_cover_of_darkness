extends Node3D
## Real player, water, floors and banks: regressions for control and exits.

const PLAYER := preload("res://Player.tscn")
const WATER := preload("res://scripts/Interaction/WaterVolume.gd")
const CLIMB := preload("res://scripts/PlayerUtils/ClimbVolume.gd")
var player: CharacterBody3D
var results: Array[String] = []
var failed := false
var deep: Area3D
var bank_pool: Area3D


func _ready() -> void:
	_box(Vector3(0, -8.5, 0), Vector3(30, 1, 30))
	deep = WATER.build(self, Vector3(0, -4, 0), Vector3(30, 8, 30))
	_box(Vector3(40, -4.5, 0), Vector3(16, 1, 16))
	bank_pool = WATER.build(self, Vector3(40, -2, 0), Vector3(16, 4, 16))
	_box(Vector3(40, -1.75, -6), Vector3(10, 4.5, 4)) # bank top 0.5, face -4
	_box(Vector3(80, -1.84, 0), Vector3(10, 1, 10)) # 1.34 m borderline floor
	WATER.build(self, Vector3(80, -1.5, 0), Vector3(10, 3, 10))
	_box(Vector3(100, -1.3, 0), Vector3(10, 1, 10)) # 0.8 m shallow floor
	WATER.build(self, Vector3(100, -1.5, 0), Vector3(10, 3, 10))
	_box(Vector3(120, -4.5, 0), Vector3(10, 1, 10))
	WATER.build(self, Vector3(120, -2, 0), Vector3(10, 4, 10))
	_box(Vector3(120, -0.1, 0), Vector3(10, 0.2, 10)) # flooded ceiling underside -0.2
	_box(Vector3(140, -4.5, 0), Vector3(12, 1, 12))
	WATER.build(self, Vector3(140, -2, 0), Vector3(12, 4, 12))
	_box(Vector3(140, -1, -3), Vector3(6, 6, 1))
	_ladder(Vector3(140, -1.0, -2.15), Vector3(1.2, 5.0, 0.7))
	_box(Vector3(165, -8.5, 0), Vector3(20, 1, 12))
	WATER.build(self, Vector3(165, -4, 0), Vector3(20, 8, 12))
	var ramp := _box(Vector3(165, -2, 0), Vector3(12, 0.5, 8))
	ramp.rotation.z = deg_to_rad(20)
	_box(Vector3(173, -0.2, 0), Vector3(5, 1, 8))
	_box(Vector3(60, -4.5, 0), Vector3(12, 1, 12))
	WATER.build(self, Vector3(60, -2, 0), Vector3(12, 4, 12))
	_box(Vector3(60, -1.75, -6), Vector3(10, 4.5, 4))
	_box(Vector3(60, 1.6, -6), Vector3(10, 0.2, 4)) # insufficient bank headroom
	_box(Vector3(200, -4.5, 0), Vector3(16, 1, 16))
	WATER.build(self, Vector3(200, -2, 0), Vector3(16, 4, 16))
	_box(Vector3(200, -1.6, -6), Vector3(10, 4.8, 4)) # top0.8, reachable at full arm extension
	_box(Vector3(220, -4.5, 0), Vector3(16, 1, 16))
	WATER.build(self, Vector3(220, -2, 0), Vector3(16, 4, 16))
	_box(Vector3(220, -1.3, -6), Vector3(10, 5.4, 4)) # top1.4, beyond swimmer reach
	player = PLAYER.instantiate()
	player.show_hud = false
	add_child(player)
	player.invulnerable = true
	player.reload_on_death = false
	player.debug_traversal = false
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
	# Looking along a descending course must actually descend, rather than
	# drifting toward the surface while forward remains flat.
	await _place(Vector3(0, -3.5, 3))
	player.neck.rotation.x = -PI / 4
	var start := player.global_position
	Input.action_press("move_forward")
	await _frames(60)
	var travel := player.global_position - start
	_check("SP1 forward follows a submerged downward view", travel.y < -0.9 and travel.z < -0.9,
		"travel %s velocity %s" % [travel, player.velocity])

	await _place(Vector3(0, -3.5, 3))
	player.neck.rotation.x = PI / 4
	start = player.global_position
	Input.action_press("move_back")
	await _frames(60)
	travel = player.global_position - start
	_check("SP2 reverse follows the opposite submerged course", travel.y < -0.9 and travel.z > 0.9,
		"travel %s" % travel)

	await _place(Vector3(0, -3.5, 3))
	player.neck.rotation.x = -PI / 3
	start = player.global_position
	Input.action_press("move_right")
	await _frames(35)
	travel = player.global_position - start
	_check("SP3 strafe does not dive with the view", travel.x > 0.6 and travel.y > -0.12,
		"travel %s" % travel)

	await _place(Vector3(0, -3.5, 3))
	Input.action_press("move_forward")
	Input.action_press("move_right")
	Input.action_press("sprint")
	Input.action_press("crouch")
	await _frames(60)
	_check("SP4 diving diagonal sprint respects one swim speed", player.velocity.length() <= 4.25 and player.velocity.y < -1.5,
		"velocity %s magnitude %.3f" % [player.velocity, player.velocity.length()])

	await _place(Vector3(0, -3.5, 3))
	player.neck.rotation.x = -PI / 3
	Input.action_press("move_forward")
	Input.action_press("jump")
	await _frames(45)
	_check("SP5 jump overrides a downward course to surface", player.velocity.y > 1.5,
		"position %s velocity %s" % [player.global_position, player.velocity])

	await _place(Vector3(0, -0.68, 3))
	player.neck.rotation.x = -PI / 3
	start = player.global_position
	await _frames(120)
	_check("SP6 looking down alone keeps a stable surface", absf(player.global_position.y + 0.68) < 0.05 and not player.is_underwater(),
		"position %s underwater %s" % [player.global_position, player.is_underwater()])
	Input.action_press("move_forward")
	await _frames(50)
	_check("SP7 forward plus a downward view dives from the surface", player.global_position.y < start.y - 0.9 and player.is_underwater(),
		"position %s underwater %s" % [player.global_position, player.is_underwater()])

	await _place(Vector3(0, -3.5, 3))
	Input.action_press("move_forward")
	await _frames(50)
	Input.action_release("move_forward")
	start = player.global_position
	await _frames(40)
	travel = player.global_position - start
	_check("SP8 release coasts briefly then settles", travel.z < -0.1 and travel.z > -0.9 and absf(player.velocity.z) < 0.05,
		"travel %s velocity %s" % [travel, player.velocity])

	# One press just before the obstacle enters scanning range is enough.
	await _place(Vector3(40, -0.68, -2.38))
	player.velocity = Vector3(0, 0, -3)
	Input.action_press("move_forward")
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	for i in 150:
		await _frames(1)
		if player.movement_state == 0 and player.get_feet_position().y > 0.4:
			break
	Input.action_release("move_forward")
	await _frames(30)
	_check("SP9 a buffered bank press climbs out", player.movement_state == 0 and player.get_feet_position().y > 0.4 and player.global_position.z < -4.5,
		"position %s state %d reject %s" % [player.global_position, player.movement_state, player._last_reject])

	await _place(Vector3(100, 0.23, 1))
	await _frames(90)
	_check("SP10 shallow water stays walking", player.movement_state == 0 and player.water != null,
		"position %s state %d" % [player.global_position, player.movement_state])
	await _place(Vector3(80, -0.31, 1))
	await _frames(90)
	_check("SP11 borderline standing depth does not force swimming", player.movement_state == 0 and player.global_position.y > -0.4,
		"position %s state %d" % [player.global_position, player.movement_state])

	await _place(Vector3(120, -2.5, 1))
	Input.action_press("jump")
	var crossed := false
	for i in 150:
		await _frames(1)
		crossed = crossed or player.global_position.y > -1.19
	_check("SP12 surfacing respects a solid flooded ceiling", not crossed and player.movement_state == 4 and player.scanner.fits(player.global_position, player.is_crouched),
		"position %s crossed %s state %d" % [player.global_position, crossed, player.movement_state])

	await _place(Vector3(140, -2.5, -1.2))
	Input.action_press("move_forward")
	var grabbed := false
	for i in 50:
		await _frames(1)
		if player.movement_state == 3:
			grabbed = true
			break
	_check("SP13 a submerged ladder can be taken without surfacing first", grabbed and player.current_climb != null,
		"position %s state %d" % [player.global_position, player.movement_state])

	# Teleport registrations settle later, but control should already use
	# the destination volume when the next physics tick starts.
	await _place(Vector3(0, -3.5, 3))
	player.teleport(Transform3D(Basis.IDENTITY, Vector3(40, -2.5, 2)))
	player._update_water()
	_check("SP14 a water teleport immediately resolves the destination", player.water == bank_pool and player.movement_state == 4,
		"water %s state %d" % [player.water, player.movement_state])

	_release()
	player.teleport(Transform3D(Basis.IDENTITY, Vector3(0, -3.5, 3)))
	player.add_water_volume(deep)
	player.jump_buffer_timer = 0.15
	player.coyote_timer = 0.12
	player._jump_cut_allowed = true
	player.velocity = Vector3(3, -20, 0)
	player._update_water()
	_check("SP15 entry keeps lateral momentum and clears ground actions", absf(player.velocity.x - 3.0) < 0.01 and player.velocity.y >= -3.0 and player.jump_buffer_timer == 0.0 and player.coyote_timer == 0.0 and not player._jump_cut_allowed,
		"velocity %s buffer %.2f coyote %.2f jump cut %s" % [player.velocity, player.jump_buffer_timer, player.coyote_timer, player._jump_cut_allowed])

	await _place(Vector3(0, -2.5, 3))
	Input.action_press("jump")
	var highest := -INF
	for i in 240:
		await _frames(1)
		highest = maxf(highest, player.neck.global_position.y)
	_check("SP16 held ascent settles without jumping above the surface", highest < 0.17 and absf(player.neck.global_position.y - 0.12) < 0.03 and absf(player.velocity.y) < 0.03,
		"highest eyes %.3f final eyes %.3f vertical speed %.3f" % [highest, player.neck.global_position.y, player.velocity.y])

	await _place(Vector3(159, -0.68, 0))
	player.rotation.y = -PI / 2
	Input.action_press("move_forward")
	var previous: int = player.movement_state
	var changes := 0
	var walked_shallows := false
	for i in 300:
		await _frames(1)
		if player.movement_state != previous:
			changes += 1
			previous = player.movement_state
		walked_shallows = walked_shallows or (player.movement_state == 0 and player.get_feet_position().y < -0.3)
		if player.global_position.x > 172:
			break
	_release()
	_check("SP17 a sloped shore exits swimming once and walks onto land", walked_shallows and changes == 1 and player.movement_state == 0 and player.global_position.x > 171.5 and player.get_feet_position().y > 0.2,
		"position %s changes %d walked shallows %s state %d" % [player.global_position, changes, walked_shallows, player.movement_state])

	await _place(Vector3(60, -0.68, -3.4))
	Input.action_press("move_forward")
	Input.action_press("jump")
	await _frames(90)
	_check("SP18 a bank without headroom cannot pull the swimmer through it", player.movement_state == 4 and player.scanner.fits(player.global_position, player.is_crouched) and player.global_position.z > -3.51,
		"position %s state %d reject %s" % [player.global_position, player.movement_state, player._last_reject])

	await _place(Vector3(0, 0.7, 3))
	await _frames(100)
	Input.action_press("crouch")
	await _frames(240)
	_check("SP19 diving to a deep bottom does not restore a ground jump", player.movement_state == 4 and player.get_feet_position().y < -7.95 and player.coyote_timer == 0.0,
		"feet %s state %d coyote %.3f" % [player.get_feet_position(), player.movement_state, player.coyote_timer])

	await _place(Vector3(0, -3.5, 3))
	player.neck.rotation.x = -PI / 4
	Input.action_press("move_forward")
	await _frames(60)
	player.neck.rotation.x = deg_to_rad(-85)
	var peak := 0.0
	for i in 20:
		await _frames(1)
		peak = maxf(peak, player.velocity.length())
	_check("SP20 changing a submerged course never gains speed", peak <= 3.05,
		"peak %.3f velocity %s" % [peak, player.velocity])


	await _place(Vector3(40, -2.5, -3.4))
	Input.action_press("move_forward")
	Input.action_press("jump")
	var reached_land := await _wait_for_bank(0.5)
	_check("SP21 a held ascent continues into a bank mantle", reached_land,
		"position %s state %d buffer %.3f reject %s" % [player.global_position, player.movement_state, player.jump_buffer_timer, player._last_reject])

	await _place(Vector3(200, -0.68, -3.4))
	Input.action_press("move_forward")
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	reached_land = await _wait_for_bank(0.8)
	_check("SP22 a reachable higher lip mantles from swimming", reached_land,
		"position %s state %d reject %s" % [player.global_position, player.movement_state, player._last_reject])

	await _place(Vector3(220, -0.68, -3.4))
	Input.action_press("move_forward")
	Input.action_press("jump")
	await _frames(160)
	_check("SP23 a water exit cannot climb beyond hand reach", player.movement_state == 4 and player.global_position.z > -3.51,
		"position %s state %d reject %s" % [player.global_position, player.movement_state, player._last_reject])


	await _place(Vector3(40, -0.68, -3.4))
	Input.action_press("move_forward")
	Input.action_press("jump")
	Input.action_press("crouch")
	await _frames(45)
	_check("SP24 explicit dive overrides a held water exit", player.movement_state == 4 and player.global_position.y < -1.3,
		"position %s state %d" % [player.global_position, player.movement_state])


func _wait_for_bank(top: float) -> bool:
	for i in 300:
		await _frames(1)
		if player.movement_state == 0 and player.get_feet_position().y > top - 0.05 and player.global_position.z < -4.4:
			return true
	return false


func _place(at: Vector3) -> void:
	_release()
	player.teleport(Transform3D(Basis.IDENTITY, at))
	player._set_crouched(false)
	player.neck.rotation.x = 0.0
	await _frames(5)


func _release() -> void:
	for action in ["move_forward", "move_back", "move_left", "move_right", "jump", "crouch", "sprint"]:
		Input.action_release(action)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


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


func _ladder(center: Vector3, size: Vector3) -> void:
	var volume := Area3D.new()
	volume.set_script(CLIMB)
	volume.collision_layer = 0
	volume.collision_mask = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	volume.add_child(shape)
	add_child(volume)
	volume.global_position = center


func _check(label: String, ok: bool, detail: String) -> void:
	failed = failed or not ok
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", label, detail])
