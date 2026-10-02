extends Node3D
## Real geometry regressions for ledge contact, shimmy and mantle clearance.

const PLAYER := preload("res://Player.tscn")

var player: CharacterBody3D
var results: Array[String] = []
var failed := false


func _ready() -> void:
	_box(Vector3(40, -0.5, 0), Vector3(120, 1, 30))
	# A thin shelf, with no face 20 cm below its lip.
	_box(Vector3(0, 3.55, -4.5), Vector3(6, 0.1, 3))
	# Two adjoining tops with a small height change.
	_box(Vector3(9, 1.8, -4.5), Vector3(2, 3.6, 3))
	_box(Vector3(11, 1.85, -4.5), Vector3(2, 3.7, 3))
	# A rise outside the allowed shimmy height range.
	_box(Vector3(20, 1.9, -4.5), Vector3(4, 3.8, 3))
	_box(Vector3(30, 1.8, -4.5), Vector3(8, 3.6, 3))
	# 1.25 m headroom: crouching fits, the decorative mantle lift does not.
	_box(Vector3(40, 0.6, -4.5), Vector3(4, 1.2, 3))
	_box(Vector3(40, 2.55, -3.5), Vector3(4, 0.2, 5))
	_box(Vector3(50, 0.6, -4.5), Vector3(4, 1.2, 3))
	# A shelf under a second shelf: pull up onto the one in our hands.
	_box(Vector3(60, 3.55, -4.5), Vector3(4, 0.1, 3))
	_box(Vector3(60, 3.95, -4.5), Vector3(4, 0.1, 3))
	# A lower, thin landing across an alley. Aim on its top, away from its rim.
	_box(Vector3(70, 2.8, -4.5), Vector3(4, 5.6, 3))
	_box(Vector3(70, 2.15, 1.5), Vector3(4, 0.1, 3))
	# Inside corner, with enough length to continue along the second face.
	_box(Vector3(80, 1.8, -4.5), Vector3(6, 3.6, 3))
	_box(Vector3(82.5, 1.8, -1.5), Vector3(1, 3.6, 3))
	_box(Vector3(89, 3.55, -4.5), Vector3(2, 0.1, 3))
	_box(Vector3(91, 3.65, -4.5), Vector3(2, 0.1, 3))
	player = PLAYER.instantiate()
	add_child(player)
	player.debug_traversal = false
	player.reload_on_death = false
	player.invulnerable = true
	if player.has_node("LightGem"):
		player.get_node("LightGem").queue_free()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _frames(5)
	await _run()
	_release_all()
	print("\n==== RESULTS ====")
	for result in results:
		print(result)
	get_tree().quit(1 if failed else 0)


func _run() -> void:
	await _hang(Vector3(0, 2.55, -2.48), 3.6)
	Input.action_press("move_right")
	await _frames(30)
	_check("LP1 shimmy along a thin shelf", player.movement_state == 2 and player.global_position.x > 0.4,
		"position %s state %d" % [player.global_position, player.movement_state])

	await _hang(Vector3(9.9, 2.55, -2.48), 3.6)
	Input.action_press("move_right")
	var biggest_step := 0.0
	for i in 30:
		var before := player.global_position
		await _frames(1)
		biggest_step = maxf(biggest_step, before.distance_to(player.global_position))
	_check("LP2 small ledge seams do not teleport the body", biggest_step < 0.05 and player.global_position.x > 10.2 and player.movement_state == 2,
		"max step %.3f position %s state %d" % [biggest_step, player.global_position, player.movement_state])

	_release_all()
	var high: Dictionary = player.planner.probe_hang(Vector3(20, 2.55, -2.48), Vector3.BACK, 3.6, 0.12)
	_check("LP3 shimmy probe respects its height limit", high.is_empty(), "hit %s" % high)

	await _hang(Vector3(30, 2.55, -2.48), 3.6)
	Input.action_press("move_right")
	var initial := player.global_position
	await _frames(1)
	var first_step := player.global_position.x - initial.x
	await _frames(29)
	var travel := player.global_position.x - initial.x
	Input.action_release("move_right")
	var released := player.global_position.x
	await _frames(20)
	var drift := player.global_position.x - released
	_check("LP4 shimmy eases into motion and settles on release", first_step > 0.0 and first_step < 0.018 and travel > 0.4 and drift > 0.001 and drift < 0.09,
		"first %.4f travel %.3f drift %.3f" % [first_step, travel, drift])

	await _place(Vector3(40, 1.03, -2.48))
	var profile = player.scanner.scan(Vector3.FORWARD, Vector3.ZERO, false)
	var planned: bool = profile != null and player._try_traversal(profile)
	await _frames(100)
	_check("LP5 mantle uses available crouched headroom", planned and player.movement_state == 0 and player.is_crouched and absf(player.global_position.y - 2.2) < 0.08 and player.global_position.z < -3.0,
		"planned %s position %s crouched %s reject %s" % [planned, player.global_position, player.is_crouched, player._last_reject])

	await _place(Vector3(50, 1.03, -2.48))
	profile = player.scanner.scan(Vector3.FORWARD, Vector3.ZERO, false)
	planned = profile != null and player._try_traversal(profile)
	# A guard walks onto the destination after the path was planned.
	var blocker := _box(Vector3(50, 2.2, -3.65), Vector3(1.0, 2.0, 0.5))
	blocker.collision_layer = 2
	var overlapped := false
	for i in 80:
		await _frames(1)
		if not player.scanner.fits(player.global_position, player.is_crouched):
			overlapped = true
	_check("LP6 a blocker entering a mantle path is never crossed", planned and not overlapped and player.current_move == null,
		"planned %s overlapped %s state %d position %s" % [planned, overlapped, player.movement_state, player.global_position])
	blocker.queue_free()

	await _hang(Vector3(60, 2.55, -2.48), 3.6)
	var pull_up = player.planner.pull_up(Vector3.BACK, player.global_position)
	_check("LP7 pull up cannot silently switch to a different shelf", pull_up == null,
		"selected top %s" % (pull_up.contact_point if pull_up != null else Vector3.ZERO))

	# Hold right around both outside corners of a normal wall.
	await _hang(Vector3(33.6, 2.55, -2.48), 3.6)
	Input.action_press("move_right")
	await _frames(130)
	_check("LP8 outside corner keeps a valid hang", player.movement_state == 2 and player.hang_normal.x > 0.9 and player.scanner.fits(player.global_position, false),
		"position %s normal %s state %d" % [player.global_position, player.hang_normal, player.movement_state])

	await _place(Vector3(30, 1.03, -2.48))
	Input.action_press("move_forward")
	Input.action_press("jump")
	for i in 100:
		await _frames(1)
		if player.current_move != null and player.current_move.ends_in_hang:
			break
	var caught: bool = player.current_move != null and player.current_move.ends_in_hang
	_release_all()
	await _frames(2)
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	await _frames(110)
	_check("LP9 jump pressed during the catch flows into a pull up", caught and player.movement_state == 0 and absf(player.global_position.y - 4.6) < 0.08,
		"caught %s position %s state %d" % [caught, player.global_position, player.movement_state])

	await _hang(Vector3(70, 4.55, -2.48), 5.6)
	_aim(Vector3(70, 2.2, 1.0))
	await _frames(8)
	var target_found: bool = not player.hang_target.is_empty()
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	await _frames(100)
	_check("LP10 aiming inside a thin ledge top finds its reachable rim", target_found and player.movement_state == 2 and player.hang_normal.z < -0.9 and absf(player.hang_lip_y - 2.2) < 0.03,
		"target %s position %s normal %s lip %.2f reject %s" % [target_found, player.global_position, player.hang_normal, player.hang_lip_y, player._last_reject])

	await _hang(Vector3(80.5, 2.55, -2.48), 3.6)
	Input.action_press("move_right")
	await _frames(100)
	_check("LP11 inside corner continues onto its adjoining wall", player.movement_state == 2 and player.hang_normal.x < -0.9 and player.global_position.z > -2.0 and player.scanner.fits(player.global_position, false),
		"position %s normal %s state %d reject %s" % [player.global_position, player.hang_normal, player.movement_state, player._last_reject])

	# A fresh crouch press during a catch is also remembered, unlike the
	# original held jump that got us there.
	await _place(Vector3(30, 1.03, -2.48))
	Input.action_press("move_forward")
	Input.action_press("jump")
	for i in 100:
		await _frames(1)
		if player.current_move != null and player.current_move.ends_in_hang:
			break
	caught = player.current_move != null and player.current_move.ends_in_hang
	_release_all()
	Input.action_press("crouch")
	await _frames(2)
	Input.action_release("crouch")
	await _frames(80)
	_check("LP12 crouch pressed during catch drops without regrabbing", caught and player.movement_state == 0 and player.global_position.y < 1.1,
		"caught %s position %s state %d" % [caught, player.global_position, player.movement_state])

	await _hang(Vector3(89.9, 2.55, -2.48), 3.6)
	Input.action_press("move_right")
	await _frames(40)
	_check("LP13 shimmy finds a slightly higher thin shelf", player.movement_state == 2 and player.global_position.x > 90.3 and absf(player.hang_lip_y - 3.7) < 0.03 and player.hang_normal.z > 0.9,
		"position %s normal %s lip %.2f reject %s" % [player.global_position, player.hang_normal, player.hang_lip_y, player._last_reject])


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


func _place(at: Vector3) -> void:
	_release_all()
	player.teleport(Transform3D(Basis.IDENTITY, at))
	player._set_crouched(false)
	player.neck.rotation.x = 0.0
	await _frames(3)


func _hang(at: Vector3, lip: float) -> void:
	await _place(at)
	player.global_position = at
	player._enter_hang(Vector3.BACK, lip, false)
	await _frames(2)


func _release_all() -> void:
	for action in ["move_forward", "move_back", "move_left", "move_right", "jump", "crouch", "sprint"]:
		Input.action_release(action)


func _aim(target: Vector3) -> void:
	var direction: Vector3 = target - player.neck.global_position
	player.rotation.y = atan2(-direction.x, -direction.z)
	player.neck.rotation.x = atan2(direction.y, Vector2(direction.x, direction.z).length())


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(label: String, ok: bool, detail: String) -> void:
	failed = failed or not ok
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", label, detail])
