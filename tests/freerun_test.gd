extends Node3D
## Free-run climbing: placed handholds, the hold finder, and the moves that
## sprint held takes on its own (docs/superpowers/specs/2026-10-16-freerun-climbing-design.md).

const PLAYER := preload("res://Player.tscn")
const HANDHOLD := preload("res://scripts/PlayerUtils/Handhold.gd")

var player: CharacterBody3D
var results: Array[String] = []
var failed := false
var labels: Array[String] = []


func _ready() -> void:
	_box(Vector3(100, -0.5, 0), Vector3(260, 1, 40))
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


func _physics_process(_delta: float) -> void:
	if player != null and player.current_move != null:
		var label := String(player.current_move.label)
		if labels.is_empty() or labels[-1] != label:
			labels.append(label)


func _run() -> void:
	await _finder_checks()
	await _placed_hang_checks()
	await _pole_checks()


# Task 1: the hold finder.
func _finder_checks() -> void:
	var ledge := _hold(HANDHOLD.Kind.LEDGE, Vector3(0, 0.5, 10), 0.0, 2.0)
	await _frames(1)
	var clamped: Vector3 = ledge.grip_near(Vector3(5, 0.5, 10))
	_check("FR1 grip_near clamps to a ledge's ends", clamped.distance_to(Vector3(1, 0.5, 10)) < 0.001,
		"grip %s" % clamped)

	# A smooth 9 m wall, face at z = -3, with sills placed on it.
	var normal := Vector3.BACK
	_box(Vector3(10, 4.5, -4.5), Vector3(4, 9, 3))
	var near := _hold(HANDHOLD.Kind.LEDGE, Vector3(10, 2.9, -3), 0.0, 1.0)
	var far := _hold(HANDHOLD.Kind.LEDGE, Vector3(10, 4.0, -3), 0.0, 1.0)
	await _frames(2)
	var anchor: Vector3 = player.planner.hang_anchor(Vector3(10, 2.0, -3), normal, 2.0)
	var target: Dictionary = player.holds.next_hold(anchor, normal, 2.0, Vector3.UP, 2.5)
	_check("FR2 next_hold picks the hold above within reach", target.get("hold") == near and target.get("reach") == true,
		"target %s" % target)

	near.queue_free()
	await _frames(1)
	target = player.holds.next_hold(anchor, normal, 2.0, Vector3.UP, 2.5)
	_check("FR3 next_hold leaps when nothing is in reach", target.get("hold") == far and target.get("reach") == false,
		"target %s" % target)
	far.queue_free()

	_box(Vector3(20, 1.5, -4.5), Vector3(4, 3, 3))
	var buried := _hold(HANDHOLD.Kind.POINT, Vector3(20, 2.0, -4.5), 0.0, 1.0)
	await _frames(1)
	var inside: Dictionary = player.holds.hold_target(buried, Vector3(20, 2.0, -4.5))
	_check("FR4 a hold buried in geometry is never offered", inside.is_empty(), "target %s" % inside)
	buried.queue_free()

	# Two stone sills on a face set back behind them: no Handhold anywhere.
	_box(Vector3(30, 4.5, -4.8), Vector3(4, 9, 3))
	_box(Vector3(30, 1.95, -3.15), Vector3(4, 0.1, 0.3))
	_box(Vector3(30, 2.85, -3.15), Vector3(4, 0.1, 0.3))
	await _frames(2)
	anchor = player.planner.hang_anchor(Vector3(30, 1.9, -3), normal, 2.0)
	target = player.holds.next_hold(anchor, normal, 2.0, Vector3.UP, 2.5)
	_check("FR5 a detected ledge counts as a hold", not target.is_empty() and target.get("hold") == null and absf(float(target.get("lip_y", 0.0)) - 2.9) < 0.05,
		"target %s" % target)

	_box(Vector3(40, 4.5, -4.5), Vector3(6, 9, 3))
	var aside := _hold(HANDHOLD.Kind.POINT, Vector3(40 + 0.886, 2.156, -3), 0.0, 1.0)
	await _frames(1)
	anchor = player.planner.hang_anchor(Vector3(40, 2.0, -3), normal, 2.0)
	target = player.holds.next_hold(anchor, normal, 2.0, Vector3.UP, 2.5)
	_check("FR6 the cone excludes holds off to the side", target.is_empty(), "target %s" % target)
	aside.queue_free()


# Task 2: hanging on placed holds, careful layer.
func _placed_hang_checks() -> void:
	_box(Vector3(50, 3, -4.5), Vector3(4, 6, 3))
	var bracket := _hold(HANDHOLD.Kind.POINT, Vector3(50, 2.3, -3), 0.0, 1.0)
	await _catch_from(Vector3(50, 1.03, -1.2))
	_check("FR7 a held jump catches a placed bracket", player.movement_state == 2 and player.hang_hold == bracket,
		"state %d hold %s position %s reject %s" % [player.movement_state, player.hang_hold, player.global_position, player._last_reject])
	await _frames(120)
	_check("FR8 hanging on a placed hold does not drop for want of a lip ray", player.movement_state == 2 and player.hang_hold == bracket,
		"state %d position %s" % [player.movement_state, player.global_position])
	_release_all()

	_box(Vector3(70, 3, -4.5), Vector3(6, 6, 3))
	var sill := _hold(HANDHOLD.Kind.LEDGE, Vector3(70, 2.3, -3), 0.0, 2.0)
	await _catch_from(Vector3(70, 1.03, -1.2))
	var caught: bool = player.hang_hold == sill
	Input.action_press("move_right")
	await _frames(150)
	_check("FR9 shimmy stops at a placed ledge's end", caught and player.movement_state == 2 and player.global_position.x <= 71.05 and player.global_position.x > 70.6,
		"caught %s state %d position %s reject %s" % [caught, player.movement_state, player.global_position, player._last_reject])
	_release_all()


# Task 3: drainpipes.
func _pole_checks() -> void:
	_box(Vector3(90, 3, -4.5), Vector3(4, 6, 3))
	_hold(HANDHOLD.Kind.POLE, Vector3(90, 0, -2.9), 0.0, 6.0)
	await _frames(2)
	await _place(Vector3(90, 1.03, -1.6))
	Input.action_press("move_forward")
	var climbed := false
	var hands_off := INF
	var contacts = player.hand._contacts
	for i in 500:
		await _frames(1)
		if player.movement_state == 3:
			climbed = true
			if i % 20 == 0 and contacts.weight(0) > 0.95 and contacts.weight(1) > 0.95:
				var worst := 0.0
				for side in [0, 1]:
					var at: Vector3 = contacts.hand(side).origin
					worst = maxf(worst, Vector2(at.x - 90, at.z + 2.9).length())
				hands_off = worst if hands_off == INF else maxf(hands_off, worst)
		if climbed and player.movement_state == 0 and player._on_floor_now():
			break
	_release_all()
	var feet: float = player.global_position.y - 1.0
	_check("FR10 climb a drainpipe to its top", climbed and feet >= 5.9,
		"climbed %s feet %.2f state %d" % [climbed, feet, player.movement_state])
	_check("FR12 hands hold the pipe", hands_off < 0.08, "worst %.3f m off the pipe" % hands_off)

	_box(Vector3(100, 3, -4.5), Vector3(4, 6, 3))
	_hold(HANDHOLD.Kind.POLE, Vector3(100, 0, -2.9), 0.0, 6.0)
	var beside := _hold(HANDHOLD.Kind.LEDGE, Vector3(100.6, 3.0, -3), 0.0, 0.6)
	await _frames(2)
	await _place(Vector3(100, 1.03, -1.6))
	Input.action_press("move_forward")
	await _until(func(): return player.movement_state == 3 and player.global_position.y > 2.0, 300)
	Input.action_release("move_forward")
	Input.action_press("move_right")
	await _until(func(): return player.movement_state == 2, 120)
	_release_all()
	_check("FR11 step off a pipe onto a ledge beside it", player.movement_state == 2 and player.hang_hold == beside,
		"state %d hold %s position %s reject %s" % [player.movement_state, player.hang_hold, player.global_position, player._last_reject])
	await _frames(10)


func _until(condition: Callable, max_frames: int) -> void:
	for i in max_frames:
		if condition.call():
			return
		await _frames(1)


## Walk at the wall ahead holding jump, until hanging or 120 frames pass.
func _catch_from(at: Vector3) -> void:
	await _place(at)
	Input.action_press("move_forward")
	await _frames(4)
	Input.action_press("jump")
	for i in 120:
		await _frames(1)
		if player.movement_state == 2:
			break
	_release_all()


func _hold(kind: int, at: Vector3, yaw: float, length: float) -> Node3D:
	var hold: Node3D = HANDHOLD.new()
	hold.kind = kind
	hold.length = length
	add_child(hold)
	hold.global_position = at
	hold.rotation.y = yaw
	return hold


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


func _place(at: Vector3, yaw := 0.0) -> void:
	_release_all()
	player.teleport(Transform3D(Basis(Vector3.UP, yaw), at))
	player._set_crouched(false)
	player.neck.rotation.x = 0.0
	await _frames(3)
	labels.clear()


func _hang(at: Vector3, lip: float, normal := Vector3.BACK) -> void:
	await _place(at, atan2(normal.x, normal.z))
	player.global_position = at
	player._enter_hang(normal, lip, false)
	await _frames(2)
	labels.clear()


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
