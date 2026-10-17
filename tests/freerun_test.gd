extends Node3D
## Free-run climbing: placed handholds, the hold finder, and the moves that
## sprint held takes on its own (docs/superpowers/specs/2026-10-16-freerun-climbing-design.md).

const PLAYER := preload("res://Player.tscn")
const HANDHOLD := preload("res://scripts/PlayerUtils/Handhold.gd")
const PROPS := preload("res://scripts/Interaction/Props.gd")
const LEVEL_GAMEPLAY := preload("res://scripts/Level/LevelGameplay.gd")


## Just enough of a loaded level for a marker builder: its markers by ucd.
class FakeLevel:
	var markers: Array = []

	func of(ucd: String) -> Array:
		return markers.filter(func(m): return m["ucd"] == ucd)

var player: CharacterBody3D
var results: Array[String] = []
var failed := false
var labels: Array[String] = []


func _ready() -> void:
	_box(Vector3(100, -0.5, 0), Vector3(260, 1, 40))
	_box(Vector3(330, -0.5, 0), Vector3(200, 1, 40))
	_box(Vector3(530, -0.5, 0), Vector3(200, 1, 40))
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
	await _climb_checks()
	await _ground_checks()
	await _edge_checks()
	await _eject_checks()
	await _down_checks()
	await _roll_checks()
	await _presentation_checks()
	_marker_checks()
	await _review_checks()
	await _flow_checks()
	await _arms_checks()
	await _weight_checks()
	await _hanging_body_checks()


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


## A 9 m wall at x with LEDGE holds every 0.9 m from 2.4 m: the column of
## sills a façade climb goes up. Returns the holds, lowest first.
func _sill_column(x: float) -> Array:
	_box(Vector3(x, 4.5, -4.5), Vector3(4, 9, 3))
	var column := []
	for i in 8:
		column.append(_hold(HANDHOLD.Kind.LEDGE, Vector3(x, 2.4 + 0.9 * i, -3), 0.0, 1.0))
	await _frames(2)
	return column


func _hang_on(hold: Node3D) -> void:
	var lip: float = hold.global_position.y
	var anchor: Vector3 = player.planner.hang_anchor(hold.global_position, Vector3.BACK, lip)
	await _place(anchor)
	player.global_position = anchor
	player._enter_hang(Vector3.BACK, lip, false, &"", hold)
	await _frames(2)
	labels.clear()


# Task 4: hand over hand with sprint held.
func _climb_checks() -> void:
	var column: Array = await _sill_column(120)
	await _hang_on(column[0])
	Input.action_press("sprint")
	Input.action_press("move_forward")
	var fell := false
	for i in 600:
		await _frames(1)
		if player.movement_state == 0 and player.global_position.y - 1.0 < 8.5:
			fell = true
		if player.movement_state == 0 and player.global_position.y - 1.0 > 8.9:
			break
	_release_all()
	_check("FR13 holding sprint+forward climbs a column of sills to the roof", labels.has("reach") and player.global_position.y - 1.0 >= 8.9 and not fell,
		"labels %s feet %.2f fell %s reject %s" % [labels, player.global_position.y - 1.0, fell, player._last_reject])

	_box(Vector3(130, 4.5, -4.5), Vector3(4, 9, 3))
	var low := _hold(HANDHOLD.Kind.LEDGE, Vector3(130, 2.4, -3), 0.0, 1.0)
	var high := _hold(HANDHOLD.Kind.LEDGE, Vector3(130, 4.4, -3), 0.0, 1.0)
	await _frames(2)
	await _hang_on(low)
	Input.action_press("sprint")
	Input.action_press("move_forward")
	await _until(func(): return player.movement_state == 2 and player.hang_hold == high, 200)
	_release_all()
	_check("FR14 a 2 m gap above is leapt", labels.has("leap") and player.hang_hold == high,
		"labels %s hold %s" % [labels, player.hang_hold])

	column = await _sill_column(140)
	await _hang_on(column[0])
	Input.action_press("sprint")
	Input.action_press("move_forward")
	var starts := 0
	var last_move = null
	for i in 300:
		await _frames(1)
		if player.current_move != null and player.current_move != last_move:
			starts += 1
			last_move = player.current_move
			if starts == 2:
				break
	Input.action_release("sprint")
	await _frames(90)
	_release_all()
	_check("FR15 releasing sprint stops on the hold", starts == 2 and player.movement_state == 2 and absf(player.hang_lip_y - 4.2) < 0.05,
		"starts %d state %d lip %.2f" % [starts, player.movement_state, player.hang_lip_y])

	_box(Vector3(150, 4.5, -4.5), Vector3(4, 9, 3))
	var start := _hold(HANDHOLD.Kind.POINT, Vector3(150, 2.4, -3), 0.0, 1.0)
	var up_right := _hold(HANDHOLD.Kind.POINT, Vector3(150.6, 3.0, -3), 0.0, 1.0)
	_hold(HANDHOLD.Kind.POINT, Vector3(149.75, 3.35, -3), 0.0, 1.0)
	await _frames(2)
	await _hang_on(start)
	Input.action_press("sprint")
	Input.action_press("move_forward")
	Input.action_press("move_right")
	await _until(func(): return player.movement_state == 2 and player.hang_hold != start and player.hang_hold != null, 200)
	_release_all()
	_check("FR13b diagonal reaches the up-right hold", player.hang_hold == up_right,
		"hold %s at %s" % [player.hang_hold, player.global_position])


## Sprint (or walk) straight ahead from at for up to frames, stopping early
## once the body is hanging or past z_done. No presses of jump.
func _run_at(at: Vector3, sprint: bool, frames: int, z_done := -INF) -> void:
	await _place(at)
	if sprint:
		Input.action_press("sprint")
	Input.action_press("move_forward")
	for i in frames:
		await _frames(1)
		if player.movement_state == 2 or (player.movement_state == 0 and player.global_position.z < z_done):
			break
	_release_all()
	await _frames(30)


# Task 5: free-run on the ground.
func _ground_checks() -> void:
	_box(Vector3(160, 0.45, -4), Vector3(4, 0.9, 0.2))
	await _frames(2)
	for hz in [60, 30]:
		Engine.physics_ticks_per_second = hz
		await _run_at(Vector3(160, 1.03, 2), true, 160, -5.0)
		Engine.physics_ticks_per_second = 60
		_check("FR16 sprinting at a fence vaults it with no press (%d Hz)" % hz, labels.has("vault") and player.global_position.z < -4.4,
			"labels %s z %.2f" % [labels, player.global_position.z])

	await _run_at(Vector3(160, 1.03, 2), false, 160, -5.0)
	_check("FR18c walking at the fence does nothing without a press", labels.is_empty() and player.global_position.z > -4.0,
		"labels %s z %.2f" % [labels, player.global_position.z])

	_box(Vector3(170, 0.6, -5), Vector3(4, 1.2, 4))
	await _frames(2)
	await _run_at(Vector3(170, 1.03, 2), true, 160, -4.0)
	_check("FR17 sprinting at a 1.2 m wall mantles it with no press", labels.size() > 0 and labels[0].contains("mantle") and player.global_position.y > 2.1,
		"labels %s position %s" % [labels, player.global_position])

	_box(Vector3(180, 3, -4.5), Vector3(4, 6, 3))
	var sill := _hold(HANDHOLD.Kind.LEDGE, Vector3(180, 3.4, -3), 0.0, 1.0)
	await _frames(2)
	await _run_at(Vector3(180, 1.03, 3), true, 160)
	_check("FR18 sprinting at a 3.4 m sill wall-runs up to it", labels.has("wall run") and player.movement_state == 2 and player.hang_hold == sill and absf(player.hang_lip_y - 3.4) < 0.05,
		"labels %s state %d lip %.2f reject %s" % [labels, player.movement_state, player.hang_lip_y, player._last_reject])
	player._drop_from_hang()
	await _frames(60)

	_box(Vector3(190, 3, -4.5), Vector3(4, 6, 3))
	await _frames(2)
	await _run_at(Vector3(190, 1.03, 3), true, 160)
	_check("FR18b a smooth wall with nothing to hold is not climbed", labels.is_empty() and player.movement_state == 0,
		"labels %s state %d" % [labels, player.movement_state])


# Task 6: gaps and edges.
func _edge_checks() -> void:
	_box(Vector3(200, 3, 0), Vector3(4, 6, 10))
	_box(Vector3(200, 3, -13.5), Vector3(4, 6, 12))
	_box(Vector3(210, 3, 0), Vector3(4, 6, 10))
	_box(Vector3(220, 0.5, 0), Vector3(4, 1, 10))
	await _frames(2)

	player.invulnerable = false
	var health: float = player.health
	await _run_at(Vector3(200, 7.03, 4), true, 200, -9.0)
	_check("FR19 a roof gap with a landing is jumped", player.global_position.z < -7.6 and player.global_position.y - 1.0 > 5.9 and player.health >= health,
		"position %s health %.1f -> %.1f" % [player.global_position, health, player.health])

	await _place(Vector3(210, 7.03, 4))
	Input.action_press("sprint")
	Input.action_press("move_forward")
	var fastest := 0.0
	for i in 120:
		await _frames(1)
		fastest = maxf(fastest, Vector2(player.velocity.x, player.velocity.z).length())
	_release_all()
	await _frames(20)
	_check("FR19b a roof edge with no landing stops you at the lip", player.global_position.y - 1.0 > 5.9 and player.global_position.z <= -4.3 and player.global_position.z >= -5.0 and fastest > 8.0,
		"position %s fastest %.1f" % [player.global_position, fastest])
	player.invulnerable = true

	await _run_at(Vector3(220, 2.03, 4), true, 100, -7.0)
	_check("FR19c a 1 m step down is simply run off", player.global_position.y - 1.0 < 0.2 and player.global_position.z < -5.0,
		"position %s" % player.global_position)


# Task 7: back eject, across an alley 3 m wide.
func _eject_checks() -> void:
	for x in [230.0, 240.0]:
		_box(Vector3(x, 4.5, -4.5), Vector3(4, 9, 3))
		var start := _hold(HANDHOLD.Kind.LEDGE, Vector3(x, 3.0, -3), 0.0, 1.0)
		var bracket: Node3D = null
		if x == 230.0:
			_box(Vector3(x, 1.5, 1.5), Vector3(4, 3, 3))
		else:
			_box(Vector3(x, 4.5, 1.5), Vector3(4, 9, 3))
			bracket = _hold(HANDHOLD.Kind.POINT, Vector3(x, 3.0, 0), PI, 1.0)
		await _frames(2)
		await _hang_on(start)
		_aim(Vector3(x, 3.0, 0.0))
		await _frames(8)
		Input.action_press("jump")
		await _frames(2)
		Input.action_release("jump")
		await _until(func(): return player.movement_state == 2 and player.hang_normal.z < -0.9, 120)
		var name := "FR20 back eject to a ledge across an alley" if bracket == null else "FR21 back eject to a placed bracket"
		_check(name, player.movement_state == 2 and player.hang_normal.z < -0.9 and labels.has("leap") and (bracket == null or player.hang_hold == bracket),
			"state %d normal %s labels %s hold %s reject %s" % [player.movement_state, player.hang_normal, labels, player.hang_hold, player._last_reject])
		player._drop_from_hang()
		await _frames(90)


# Task 8: parkour down, sprint + crouch held.
func _down_checks() -> void:
	_box(Vector3(260, 3, 0), Vector3(4, 6, 10))
	await _frames(2)
	await _place(Vector3(260, 7.03, -4.3))
	Input.action_press("sprint")
	Input.action_press("crouch")
	await _until(func(): return player.movement_state == 2, 90)
	_check("FR22 sprint+crouch at a roof edge lowers into a hang", player.movement_state == 2 and not player.is_crouched,
		"state %d crouched %s reject %s" % [player.movement_state, player.is_crouched, player._last_reject])
	_release_all()
	player._drop_from_hang()
	await _frames(90)

	var column: Array = await _sill_column(250)
	await _hang_on(column[-1])
	player.invulnerable = false
	var health: float = player.health
	Input.action_press("sprint")
	Input.action_press("crouch")
	await _until(func(): return player.movement_state == 0 and player._on_floor_now(), 600)
	_release_all()
	_check("FR23 sprint+crouch on a facade climbs down hold to hold to the street", player.global_position.y - 1.0 < 0.2 and player.health >= health and labels.has("reach"),
		"feet %.2f health %.1f -> %.1f labels %s" % [player.global_position.y - 1.0, health, player.health, labels])
	player.invulnerable = true
	await _frames(20)

	await _place(Vector3(270, 1.03, 0))
	Input.action_press("sprint")
	Input.action_press("crouch")
	await _frames(20)
	_check("FR24 sprint+crouch on open ground just crouches", player.is_crouched and player.movement_state == 0,
		"crouched %s state %d" % [player.is_crouched, player.movement_state])
	_release_all()
	await _frames(20)


# Task 9: a sprinting landing rolls.
func _roll_checks() -> void:
	player.invulnerable = false
	var damage := {}
	for sprint in [true, false]:
		await _place(Vector3(290, 10.03, 0))
		player.health = player.max_health
		if sprint:
			Input.action_press("sprint")
		await _until(func(): return player._on_floor_now(), 120)
		await _frames(2)
		damage[sprint] = player.max_health - player.health
		_release_all()
		player.health = player.max_health
	player.invulnerable = true
	var relief: float = player.roll_relief_speed * player.fall_damage_per_speed
	_check("FR25 a sprinting landing from 9 m hurts less than a walking one", damage[false] - damage[true] >= relief * 0.9 and damage[true] > 0.0,
		"sprint %.1f walk %.1f" % [damage[true], damage[false]])


# Task 10: hands on the reached hold, the camera's roll, the stowed sword.
func _presentation_checks() -> void:
	var column: Array = await _sill_column(310)
	await _hang_on(column[0])
	var contacts = player.hand._contacts
	Input.action_press("sprint")
	Input.action_press("move_forward")
	var worst_roll := 0.0
	var hands_checked := false
	var hands_off := INF
	var landed_before := [1.0, 1.0]
	var reached := false
	for i in 600:
		await _frames(1)
		worst_roll = maxf(worst_roll, absf(rad_to_deg(player.camera.global_basis.get_euler().z)))
		# Each hand, as it lands on a hold during a reach, is on that hold.
		if player.current_move != null and player.current_move.label == &"reach":
			for side in [0, 1]:
				var g = contacts.grips[side]
				if g.travel >= 1.0 and landed_before[side] < 1.0 and g.wanted:
					var at: Vector3 = contacts.hand(side).origin
					var off := absf(at.z + 3.0)
					var lip := 9.0
					for k in 8:
						if absf(at.y - (2.4 + 0.9 * k)) < absf(at.y - lip):
							lip = 2.4 + 0.9 * k
					off = maxf(off, absf(at.y - lip))
					hands_off = off if not hands_checked else maxf(hands_off, off)
					hands_checked = true
		for side in [0, 1]:
			landed_before[side] = contacts.grips[side].travel
		if player.movement_state == 0 and player.global_position.y - 1.0 > 8.9:
			break
	_release_all()
	_check("FR26 hands plant on the reached hold", hands_checked and hands_off < 0.1, "checked %s worst %.3f m" % [hands_checked, hands_off])
	_check("FR28 camera roll stays under the cap through a climb", worst_roll <= player.freerun_max_roll_degrees,
		"worst roll %.2f deg (cap %.1f)" % [worst_roll, player.freerun_max_roll_degrees])

	# Running up a wall the hands stay free until the catch is near.
	_box(Vector3(330, 3, -4.5), Vector3(4, 6, 3))
	_hold(HANDHOLD.Kind.LEDGE, Vector3(330, 3.4, -3), 0.0, 1.0)
	await _frames(2)
	await _place(Vector3(330, 1.03, 3))
	Input.action_press("sprint")
	Input.action_press("move_forward")
	var early_free := true
	var reaching := false
	var ran := false
	for i in 160:
		await _frames(1)
		if player.current_move != null and player.current_move.label == &"wall run":
			ran = true
			if player.move_progress < 0.25 and contacts.state != 0:
				early_free = false
			if player.move_progress > 0.45 and player.move_progress < 0.6 and contacts.state != 0:
				reaching = true
		if player.movement_state == 2:
			break
	_release_all()
	_check("FR26b running up a wall, the hands come up for the hold halfway", ran and early_free and reaching, "ran %s free early %s reaching %s" % [ran, early_free, reaching])
	player._drop_from_hang()
	await _frames(60)

	# The sword: away on a hold, back in hand once off it.
	PROPS.give_weapons(player)
	player.inventory.select_by_id(&"sword")
	_box(Vector3(320, 1.2, -4.5), Vector3(4, 2.4, 3))
	await _frames(40)
	var shown_before: bool = player.hand.is_item_visible()
	await _place(Vector3(320, 1.03, -2.48))
	Input.action_press("move_forward")
	await _frames(2)
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	await _until(func(): return player.movement_state == 2, 90)
	Input.action_release("move_forward")
	await _frames(30)
	var hidden: bool = not player.hand.is_item_visible() and player.combat.stowed
	Input.action_press("throw")
	await _frames(3)
	Input.action_release("throw")
	var still: bool = player.combat.phase == 0
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	await _until(func(): return player.movement_state == 0, 120)
	await _frames(60)
	var back: bool = player.hand.is_item_visible() and not player.combat.stowed
	_check("FR27 the sword is stowed on a hold and back on landing", shown_before and hidden and still and back,
		"shown %s hidden %s idle %s back %s state %d" % [shown_before, hidden, still, back, player.movement_state])
	player.inventory.select_by_id(&"")
	await _frames(20)


# Task 12: handhold markers become Handholds.
func _marker_checks() -> void:
	var level := FakeLevel.new()
	var kinds := ["ledge", "pole", "point"]
	for i in 3:
		level.markers.append({"name": "hold_%d" % i, "ucd": "handhold", "props": {"kind": kinds[i], "length": 1.5 + i},
			"transform": Transform3D(Basis(Vector3.UP, 0.5), Vector3(400 + i, 3.0, 0)), "size": null})
	var holder := Node3D.new()
	add_child(holder)
	var made: Array = LEVEL_GAMEPLAY.handholds(holder, level)
	var ok := made.size() == 3
	for i in mini(made.size(), 3):
		var hold: Node3D = made[i]
		ok = ok and hold.kind == [HANDHOLD.Kind.LEDGE, HANDHOLD.Kind.POLE, HANDHOLD.Kind.POINT][i]
		ok = ok and is_equal_approx(hold.length, 1.5 + i) and hold.global_position.is_equal_approx(Vector3(400 + i, 3.0, 0))
		ok = ok and is_equal_approx(hold.global_rotation.y, 0.5) and hold.is_in_group(HANDHOLD.GROUP)
	_check("FR29 handhold markers build Handholds of each kind", ok, "made %s" % [made])
	holder.queue_free()


# Final review findings, each pinned.
func _review_checks() -> void:
	# C1: S on a wall while free-running steers down; it never lets go.
	var column: Array = await _sill_column(340)
	await _hang_on(column[3])
	Input.action_press("sprint")
	await _frames(3)
	# A real key press, through the input queue: just pressed on the next tick.
	var back := InputEventAction.new()
	back.action = &"move_back"
	back.pressed = true
	Input.parse_input_event(back)
	var let_go := false
	for i in 90:
		await _frames(1)
		if player.movement_state == 0:
			let_go = true
		if player.hang_lip_y < 4.3:
			break
	_release_all()
	await _frames(40)
	_check("FR30 back while free-running on a wall climbs down, never lets go", not let_go and player.movement_state == 2 and player.hang_lip_y < 4.3,
		"let go %s state %d lip %.2f" % [let_go, player.movement_state, player.hang_lip_y])
	await _frames(10)

	# C2: dropped down 2 m to a bracket, it is still held once the keys go.
	_box(Vector3(350, 4.5, -4.5), Vector3(4, 9, 3))
	var upper := _hold(HANDHOLD.Kind.POINT, Vector3(350, 6.4, -3), 0.0, 1.0)
	var lower := _hold(HANDHOLD.Kind.POINT, Vector3(350, 4.4, -3), 0.0, 1.0)
	await _frames(2)
	await _hang_on(upper)
	Input.action_press("sprint")
	Input.action_press("crouch")
	await _until(func(): return player.movement_state == 2 and player.hang_hold == lower, 200)
	_release_all()
	await _frames(60)
	_check("FR31 a bracket dropped down to stays held", player.movement_state == 2 and player.hang_hold == lower,
		"state %d hold %s lip %.2f" % [player.movement_state, player.hang_hold, player.hang_lip_y])

	# I1: a 40 cm seam between two roofs is run across, not braked at.
	_box(Vector3(360, 3, 0), Vector3(4, 6, 10))
	_box(Vector3(360, 3, -10.4), Vector3(4, 6, 10))
	await _frames(2)
	await _run_at(Vector3(360, 7.03, 4), true, 160, -8.0)
	_check("FR32 a narrow roof seam is run across", player.global_position.z < -7.0 and player.global_position.y - 1.0 > 5.9,
		"position %s" % player.global_position)

	# I2: sprinting up a 4 m staircase of solid boxes reaches its top.
	for i in 16:
		var h := 0.25 * (i + 1)
		_box(Vector3(370, h * 0.5, 2.0 - 0.3 * i), Vector3(3, h, 0.3))
	_box(Vector3(370, 2.0, -5.0), Vector3(3, 4.0, 4.0))
	await _frames(2)
	await _run_at(Vector3(370, 1.03, 4.5), true, 300, -4.0)
	_check("FR33 sprinting up a tall box staircase reaches the top", player.global_position.y - 1.0 > 3.9,
		"position %s reject %s" % [player.global_position, player._last_reject])

	# I3: a hold floating in air, and one buried 10 cm in its wall, are refused.
	var floating := _hold(HANDHOLD.Kind.POINT, Vector3(380, 3.0, 5.0), 0.0, 1.0)
	_box(Vector3(390, 4.5, -4.5), Vector3(4, 9, 3))
	var buried := _hold(HANDHOLD.Kind.LEDGE, Vector3(390, 3.0, -3.1), 0.0, 1.0)
	await _frames(2)
	var in_air: Dictionary = player.holds.hold_target(floating, floating.global_position)
	var in_wall: Dictionary = player.holds.hold_target(buried, buried.global_position)
	_check("FR34 a hold with nothing behind it, or sunk in its wall, is never offered", in_air.is_empty() and in_wall.is_empty(),
		"air %s wall %s" % [in_air, in_wall])

	# I4: with the guard up, sprint is no free-run: the crate is not taken.
	PROPS.give_weapons(player)
	player.inventory.select_by_id(&"sword")
	_box(Vector3(400, 0.6, -5), Vector3(4, 1.2, 4))
	await _frames(40)
	await _place(Vector3(400, 1.03, 2))
	Input.action_press("block")
	await _frames(10)
	Input.action_press("sprint")
	Input.action_press("move_forward")
	await _frames(150)
	_release_all()
	Input.action_release("block")
	_check("FR35 guarding, sprint does not free-run", labels.is_empty(), "labels %s" % [labels])
	player.inventory.select_by_id(&"")
	await _frames(20)


# Flow (playtest Oct 16: "janky, no smooth feeling"): moves carry into each
# other, and the camera takes part.
func _flow_checks() -> void:
	var column: Array = await _sill_column(420)
	await _hang_on(column[0])
	Input.action_press("sprint")
	Input.action_press("move_forward")
	var started := -1
	var hang_frames := 0
	var slowest := INF
	var last: Vector3 = player.global_position
	var climbed_at := -1
	var after_pull := []
	var worst_roll := 0.0
	var reach_roll := 0.0
	var pulling := false
	for i in 600:
		await _frames(1)
		var pos: Vector3 = player.global_position
		var speed: float = pos.distance_to(last) * 60.0
		last = pos
		var label := String(player.current_move.label) if player.current_move != null else ""
		if started < 0 and label == "reach":
			started = i
		if label == "pull up":
			pulling = true
		if started >= 0 and not pulling:
			if player.movement_state == 2:
				hang_frames += 1
			slowest = minf(slowest, speed)
			var roll: float = absf(rad_to_deg(player.juice.view_rotation.z))
			worst_roll = maxf(worst_roll, roll)
			if label == "reach":
				reach_roll = maxf(reach_roll, roll)
		if pulling and player.movement_state == 0:
			if climbed_at < 0:
				climbed_at = i
			after_pull.append(Vector2(player.velocity.x, player.velocity.z).length())
			if after_pull.size() >= 8:
				break
	_release_all()
	# (A hand landing holds the pull a moment, the hit: slow, not stopped.)
	_check("FR36 a climb up a column of sills never stops between holds", started >= 0 and hang_frames == 0 and slowest > 0.5,
		"hang frames %d slowest %.2f m/s" % [hang_frames, slowest])
	_check("FR36b nine metres of sills climbed in three seconds", climbed_at > 0 and (climbed_at - started) / 60.0 <= 3.0,
		"%.2f s" % ((climbed_at - started) / 60.0))
	_check("FR39 a free-run pull-up runs on over the top", after_pull.size() >= 5 and after_pull[4] >= 4.0,
		"speeds %s" % [after_pull])
	_check("FR40 a reach leans the view toward the hand, under the cap", reach_roll >= 0.5 and worst_roll <= player.freerun_max_roll_degrees,
		"reach roll %.2f worst %.2f deg" % [reach_roll, worst_roll])
	await _frames(20)

	# A wall run carries straight on up the sills over it.
	_box(Vector3(430, 4.5, -4.5), Vector3(4, 9, 3))
	for y in [3.4, 4.3, 5.2]:
		_hold(HANDHOLD.Kind.LEDGE, Vector3(430, y, -3), 0.0, 1.0)
	await _frames(2)
	await _place(Vector3(430, 1.03, 3))
	Input.action_press("sprint")
	Input.action_press("move_forward")
	var ran := false
	var stops := 0
	var widest := 0.0
	var looked_up := 0.0
	for i in 300:
		await _frames(1)
		var label := String(player.current_move.label) if player.current_move != null else ""
		if label == "wall run":
			ran = true
			widest = maxf(widest, player.camera.fov - player.juice.base_fov)
			looked_up = maxf(looked_up, rad_to_deg(player.juice.view_rotation.x))
		if ran and player.hang_lip_y > 5.1 and player.movement_state != 1:
			break
		if ran and player.movement_state == 2:
			stops += 1
	_release_all()
	_check("FR37 a wall run flows into the climb above it", ran and stops == 0 and player.hang_lip_y > 5.1,
		"ran %s hang frames %d lip %.2f" % [ran, stops, player.hang_lip_y])
	_check("FR41 a wall run looks up and widens the view", widest >= 3.0 and looked_up >= 5.0,
		"fov +%.1f pitch %.1f deg" % [widest, looked_up])
	player._drop_from_hang()
	await _frames(90)

	# Sprinting over a waist-high wall keeps most of the sprint.
	_box(Vector3(440, 0.6, -5), Vector3(4, 1.2, 4))
	await _frames(2)
	await _place(Vector3(440, 1.03, 3))
	Input.action_press("sprint")
	Input.action_press("move_forward")
	var mantled := false
	var kept := 0.0
	var speeds := []
	var was: Vector3 = player.global_position
	var after := -1
	for i in 200:
		await _frames(1)
		var step: float = player.global_position.distance_to(was) * 60.0
		was = player.global_position
		if i > 25:
			speeds.append(step)
		if player.current_move != null and String(player.current_move.label).contains("mantle"):
			mantled = true
		elif mantled and player.movement_state == 0:
			after += 1
			if after == 3:
				kept = Vector2(player.velocity.x, player.velocity.z).length()
			if after >= 8:
				break
	_release_all()
	var slowest_step: float = speeds.min() if not speeds.is_empty() else 0.0
	_check("FR38b no frozen frame going into or out of a sprinting mantle", slowest_step >= 0.4 * player.sprint_speed,
		"slowest %.2f m/s of %s" % [slowest_step, speeds.slice(0, 60)])
	_check("FR38 a sprinting mantle keeps most of the sprint", mantled and kept >= 0.7 * player.sprint_speed,
		"mantled %s speed after %.2f" % [mantled, kept])
	await _frames(30)

	# The landing roll tumbles the view forward and back up.
	await _place(Vector3(450, 10.03, 0))
	Input.action_press("sprint")
	var dipped := 0.0
	for i in 150:
		await _frames(1)
		dipped = minf(dipped, rad_to_deg(player.juice.view_rotation.x))
		if player._on_floor_now() and i > 60:
			pass
	_release_all()
	_check("FR42 a landing roll tumbles the view forward", dipped <= -40.0, "lowest pitch %.1f deg" % dipped)

	# Sprint let go in the air, still running forward on landing: a roll too.
	await _place(Vector3(455, 10.03, 0))
	player.velocity = Vector3(0, 0, -6.0)
	Input.action_press("move_forward")
	dipped = 0.0
	for i in 150:
		await _frames(1)
		dipped = minf(dipped, rad_to_deg(player.juice.view_rotation.x))
	_release_all()
	_check("FR43 a hard landing running forward rolls without sprint held", dipped <= -40.0, "lowest pitch %.1f deg" % dipped)


# Arms (Mirror's Edge Catalyst, Oct 16): the hands are in frame on every climb.
func _arms_checks() -> void:
	var column: Array = await _sill_column(470)
	await _hang_on(column[0])
	Input.action_press("sprint")
	Input.action_press("move_forward")
	var cam: Camera3D = player.camera
	var size: Vector2 = get_viewport().get_visible_rect().size
	var contacts = player.hand._contacts
	var arms = player.hand._arms
	var looked := 0
	var seen := 0
	var worst := Vector2.ZERO
	for i in 240:
		await _frames(1)
		if player.movement_state == 0:
			break
		if contacts.weight(0) < 0.9 or contacts.weight(1) < 0.9:
			continue
		# Over the top the hands push down and leave out of the bottom, as a
		# body rising past them does: that is the end of the climb.
		if player.current_move != null and player.current_move.label == &"pull up":
			continue
		looked += 1
		var both := true
		for side in [0, 1]:
			var at: Vector3 = arms.hand_position(side)
			var on: Vector2 = cam.unproject_position(at)
			if cam.is_position_behind(at) or on.x < 0 or on.y < 0 or on.x > size.x or on.y > size.y:
				both = false
				worst = on
		if both:
			seen += 1
	_release_all()
	_check("FR44 both hands are in frame through a climb", looked > 30 and seen >= looked * 0.95,
		"in frame %d of %d (a miss at %s of %s)" % [seen, looked, worst.round(), size])
	await _frames(30)

	# Hand over hand, hooked; the pull-up's hands press at shoulder width.
	column = await _sill_column(480)
	await _hang_on(column[0])
	Input.action_press("sprint")
	Input.action_press("move_forward")
	var apart := 0.0
	var hooked := INF
	var land_seen := [1.0, 1.0]
	var pull_seen := 0
	var pull_planted := 0
	var pull_framed := 0
	var pull_out := 0
	var widest := 0.0
	for i in 400:
		await _frames(1)
		var label := String(player.current_move.label) if player.current_move != null else ""
		if label == "reach":
			apart = maxf(apart, absf(contacts.hand(0).origin.y - contacts.hand(1).origin.y))
			for side in [0, 1]:
				var g = contacts.grips[side]
				if g.travel >= 1.0 and land_seen[side] < 1.0 and g.wanted:
					hooked = minf(hooked, contacts.curl(side))
		for side in [0, 1]:
			land_seen[side] = contacts.grips[side].travel
		if label == "pull up" and player.move_progress < 0.6:
			pull_seen += 1
			var lip: float = player.current_move.contact_point.y
			var on_lip := true
			for side in [0, 1]:
				var at: Vector3 = contacts.hand(side).origin
				on_lip = on_lip and contacts.weight(side) > 0.5 and absf(at.y - lip) < 0.08
			if on_lip:
				pull_planted += 1
			widest = maxf(widest, absf(contacts.hand(0).origin.x - contacts.hand(1).origin.x))
			if player.move_progress > 0.15:
				pull_framed += 1
				for side in [0, 1]:
					var on: Vector2 = cam.unproject_position(arms.hand_position(side))
					if on.x < size.x * 0.15 or on.x > size.x * 0.85 or on.y < size.y * 0.3 or on.y > size.y * 0.95:
						pull_out += 1
						break
		if player.movement_state == 0 and player.global_position.y - 1.0 > 8.9:
			break
	_release_all()
	_check("FR45 hand over hand: one hand leads the other up", apart >= 0.3, "most apart %.2f m" % apart)
	_check("FR46 hands hook over the hold they reach", hooked != INF and hooked >= 0.8, "least curl %.2f" % hooked)
	_check("FR47 pulling up, the hands press on the lip at shoulder width", pull_seen > 3 and pull_planted >= pull_seen * 0.9 and widest <= 0.6,
		"planted %d of %d, widest %.2f m" % [pull_planted, pull_seen, widest])
	_check("FR47b pulling up, the view is on the hands: lower middle of the frame", pull_framed > 3 and pull_out <= pull_framed * 0.2,
		"%d of %d frames with a hand off the lower middle" % [pull_out, pull_framed])
	await _frames(30)

	# The roll: both forearms tuck in front of you.
	await _place(Vector3(490, 10.03, 0))
	Input.action_press("sprint")
	var tucked := 0
	for i in 150:
		await _frames(1)
		if player.juice.view_rotation.x < deg_to_rad(-20.0):
			var both := true
			for side in [0, 1]:
				var at: Vector3 = arms.hand_position(side)
				var on: Vector2 = cam.unproject_position(at)
				both = both and arms.reach.weights[side] > 0.5 and not cam.is_position_behind(at) and on.x > 0 and on.y > 0 and on.x < size.x and on.y < size.y
			if both:
				tucked += 1
	_release_all()
	_check("FR48 the forearms tuck in front through the roll", tucked >= 10, "%d tumbling frames with both hands in front" % tucked)
	PROPS.give_weapons(player)
	player.inventory.select_by_id(&"sword")
	await _frames(40)
	await _place(Vector3(495, 10.03, 0))
	Input.action_press("sprint")
	var put_away := false
	var apart_px := 0.0
	for i in 150:
		await _frames(1)
		if player.juice.tumble_amount() > 0.6:
			put_away = put_away or player.combat.stowed
			apart_px = maxf(apart_px, cam.unproject_position(arms.hand_position(0)).distance_to(cam.unproject_position(arms.hand_position(1))))
	_release_all()
	await _frames(60)
	_check("FR49 the sword is away through the roll, and both hands show", put_away and apart_px > size.x * 0.12 and player.hand.is_item_visible(),
		"stowed %s hands %.0f px apart, back after %s" % [put_away, apart_px, player.hand.is_item_visible()])
	player.inventory.select_by_id(&"")


# Weight (playtest Oct 16: "the arms feel like noodles, every landing rolls").
func _weight_checks() -> void:
	# Landings: a running jump is nothing, 2.2 m is a hard landing, 4 m a roll.
	for case in [["jump", 1.03, true], ["hard", 3.23, false], ["roll", 5.03, false]]:
		var x: float = 500.0 + 10.0 * ["jump", "hard", "roll"].find(case[0])
		await _place(Vector3(x, case[1], 2))
		player.velocity = Vector3(0, 0, -6.0)
		Input.action_press("sprint")
		Input.action_press("move_forward")
		if case[2]:
			await _frames(10)
			Input.action_press("jump")
			await _frames(2)
			Input.action_release("jump")
		var tumble := 0.0
		var pitch := 0.0
		var shook := 0.0
		for i in 120:
			await _frames(1)
			tumble = maxf(tumble, player.juice.tumble_amount())
			pitch = minf(pitch, rad_to_deg(player.juice.view_rotation.x))
			shook = maxf(shook, player.juice._trauma)
		_release_all()
		await _frames(20)
		match case[0]:
			"jump":
				_check("FR54 a running jump on flat ground neither rolls nor lands hard", tumble == 0.0 and shook < 0.1,
					"tumble %.2f shake %.2f" % [tumble, shook])
			"hard":
				_check("FR55 a 2.2 m drop on the run lands hard, without a roll", tumble == 0.0 and pitch <= -4.0 and shook >= 0.2,
					"tumble %.2f pitch %.1f shake %.2f" % [tumble, pitch, shook])
			"roll":
				_check("FR56 a 4 m drop on the run rolls", tumble > 0.5, "tumble %.2f" % tumble)

	# The climb: arms that bend under the body instead of stretching to the
	# holds; hands thrown at a hold and landing on it; the body sagging on the
	# arms before each pull lifts it.
	var column: Array = await _sill_column(540)
	await _hang_on(column[0])
	var reach = player.hand._arms.reach
	var contacts = player.hand._contacts
	var grips_before: int = player.juice.grip_count
	Input.action_press("sprint")
	Input.action_press("move_forward")
	var frames := 0
	var slide_sum := 0.0
	var slide_max := 0.0
	var overshot := false
	var sags := []
	var move_ref = null
	var start_y := 0.0
	var low_y := 0.0
	var reaches := 0
	for i in 400:
		await _frames(1)
		if player.movement_state == 0:
			break
		frames += 1
		for side in [0, 1]:
			slide_sum += reach.shoulder_slides[side]
			slide_max = maxf(slide_max, reach.shoulder_slides[side])
			var g = contacts.grips[side]
			if g.travel > 0.6 and g.travel < 1.0:
				var heading: Vector3 = g.at.origin - g.from.origin
				if heading.length() > 0.2 and (g.current().origin - g.at.origin).dot(heading.normalized()) > 0.005:
					overshot = true
		var m = player.current_move
		if m != null and m.label == &"reach":
			if m != move_ref:
				if move_ref != null:
					sags.append(start_y - low_y)
				move_ref = m
				reaches += 1
				start_y = m.points[0].y
				low_y = start_y
			if player.move_progress < 0.35:
				low_y = minf(low_y, player.global_position.y)
	_release_all()
	var mean := slide_sum / maxf(frames * 2.0, 1.0)
	_check("FR50 climbing, the arms bend to the holds instead of stretching", mean <= 0.04 and slide_max <= 0.12,
		"shoulder slide mean %.3f max %.3f m" % [mean, slide_max])
	_check("FR51 a hand is thrown at its hold and lands a little past it", overshot, "overshot %s" % overshot)
	_check("FR52 every hand landing on a hold is felt", player.juice.grip_count - grips_before >= reaches * 2 - 1,
		"%d grips for %d reaches" % [player.juice.grip_count - grips_before, reaches])
	var sagged := sags.filter(func(d): return d >= 0.03).size()
	_check("FR53 the body sags on the arms before each pull lifts it", sags.size() >= 3 and sagged == sags.size(),
		"sags %s" % [sags])
	await _frames(30)


# The body hangs from the hands (playtest Oct 16: "no weight to the climbing,
# neither when shifting"): a sprung weight under whatever holds it.
func _hanging_body_checks() -> void:
	var column: Array = await _sill_column(560)
	await _hang_on(column[0])
	var contacts = player.hand._contacts
	var cam: Camera3D = player.camera
	Input.action_press("sprint")
	Input.action_press("move_forward")
	var one_handed := 0
	var toward := 0
	var biggest := 0.0
	var jolt := 0.0
	var lagged := false
	var overshot := false
	var landed_at := -100
	var travels := [1.0, 1.0]
	for i in 400:
		await _frames(1)
		if player.movement_state == 0:
			break
		var off: Vector3 = player.juice.climb_offset
		biggest = maxf(biggest, Vector2(off.x, off.y).length())
		# Exactly one hand holding: the body swings under it.
		var holding := []
		for side in [0, 1]:
			var g = contacts.grips[side]
			if g.wanted and g.travel >= 1.0:
				holding.append(side)
			if travels[side] < 1.0 and g.travel >= 1.0:
				landed_at = i
			travels[side] = g.travel
		if holding.size() == 1 and absf(off.x) > 0.005:
			one_handed += 1
			var side_x: float = (cam.global_transform.affine_inverse() * contacts.hand(holding[0]).origin).x
			if signf(off.x) == signf(side_x):
				toward += 1
		if i - landed_at >= 0 and i - landed_at <= 8:
			jolt = minf(jolt, off.y)
		var m = player.current_move
		if m != null and m.label == &"reach":
			if player.move_progress < 0.3 and off.y < -0.01:
				lagged = true
			if player.move_progress > 0.5 and off.y > 0.004:
				overshot = true
	_release_all()
	# (A pendulum lags as the holding hand changes side: most, not all.)
	_check("FR57 with one hand holding, the body swings under it", one_handed >= 5 and toward >= one_handed * 0.55 and biggest >= 0.02,
		"%d of %d one-handed frames toward the hold, biggest sway %.3f m" % [toward, one_handed, biggest])
	_check("FR58 a hand landing jolts the body down", jolt <= -0.015, "jolt %.3f m" % jolt)
	_check("FR59 the body lags the pull and carries past it", lagged and overshot, "lag %s overshoot %s" % [lagged, overshot])
	await _frames(10)

	# Drawn where they hold: each drawn hand on screen where its grip is.
	column = await _sill_column(570)
	await _hang_on(column[0])
	var arms = player.hand._arms
	var size: Vector2 = get_viewport().get_visible_rect().size
	Input.action_press("sprint")
	Input.action_press("move_forward")
	var looked := 0
	var close := 0
	var worst_px := 0.0
	for i in 300:
		await _frames(1)
		if player.movement_state == 0:
			break
		if player.current_move != null and player.current_move.label == &"pull up":
			continue
		for side in [0, 1]:
			var g = contacts.grips[side]
			if not g.wanted or g.travel < 1.0 or g.weight < 0.9:
				continue
			looked += 1
			# (The wrist for that grip: the palm is on the hold, a hand's length on.)
			var wrist: Vector3 = arms.man.global_transform * arms.reach.targets[side].origin
			var gap: float = cam.unproject_position(wrist).distance_to(cam.unproject_position(arms.hand_position(side)))
			worst_px = maxf(worst_px, gap)
			if gap <= size.x * 0.06:
				close += 1
	_release_all()
	_check("FR61 each hand is drawn on screen where it holds", looked > 40 and close >= looked * 0.85,
		"%d of %d held hand-frames within %.0f px (worst %.0f px)" % [close, looked, size.x * 0.06, worst_px])
	await _frames(30)

	# Shifting along a ledge goes in steps with the hands, not a glide.
	_box(Vector3(580, 4.5, -4.5), Vector3(12, 9, 3))
	var ledge := _hold(HANDHOLD.Kind.LEDGE, Vector3(580, 3.0, -3), 0.0, 10.0)
	await _frames(2)
	await _hang_on(ledge)
	var grips_before: int = player.juice.grip_count
	Input.action_press("move_right")
	var speeds := []
	var was: float = player.global_position.x
	for i in 150:
		await _frames(1)
		var v: float = absf(player.global_position.x - was) * 60.0
		was = player.global_position.x
		if i > 20:
			speeds.append(v)
	_release_all()
	var moving: Array = speeds.filter(func(v): return v > 0.02)
	var slow: float = moving.min() if not moving.is_empty() else 0.0
	var fast: float = moving.max() if not moving.is_empty() else 0.0
	_check("FR60 shifting along a ledge goes hand by hand", fast >= 2.0 * maxf(slow, 0.01) and player.juice.grip_count - grips_before >= 3,
		"speed %.2f to %.2f m/s, %d hand landings" % [slow, fast, player.juice.grip_count - grips_before])
	player._drop_from_hang()
	await _frames(60)


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
	for action in ["move_forward", "move_back", "move_left", "move_right", "jump", "crouch", "sprint", "block", "throw"]:
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
