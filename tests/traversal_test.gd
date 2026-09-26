extends Node3D

const PLAYER := preload("res://Player.tscn")
const CLIMB := preload("res://scripts/PlayerUtils/ClimbVolume.gd")
const ROPE := preload("res://scripts/PlayerUtils/VerletRope.gd")

var player: CharacterBody3D
var results: Array[String] = []
var labels: Array[String] = []
var _last_move = null


func _ready() -> void:
	_box(Vector3(60, -0.5, -5), Vector3(220, 1, 70))           # floor, top at y=0
	_box(Vector3(0, 0.6, -4.5), Vector3(3, 1.2, 3))            # A mantle 1.2
	_box(Vector3(6, 0.3, -4.5), Vector3(3, 0.6, 3))            # B step-up 0.6
	_box(Vector3(12, 0.45, -6.1), Vector3(3, 0.9, 0.2))        # C fence 0.9 x 0.2
	_box(Vector3(18, 0.45, -6.1), Vector3(3, 0.9, 0.2))        # D fence for sneaking
	_box(Vector3(24, 1.8, -4.5), Vector3(4, 3.6, 3))           # E wall 3.6 (hang, lower)
	_box(Vector3(30, 2.5, -3.0), Vector3(3, 5.0, 8))           # G platform 5 m, far edge at z=-7
	_box(Vector3(30, 5.45, -6.9), Vector3(3, 0.9, 0.2))        # G fence at the far edge, pit beyond
	_box(Vector3(36, 0.6, -4.5), Vector3(3, 1.2, 3))           # H ledge 1.2
	_box(Vector3(36, 2.7, -4.5), Vector3(3, 0.2, 3))           # H ceiling, underside at 2.6
	_box(Vector3(42, 2.5, -4.5), Vector3(3, 5.0, 3))           # I wall 5.0 with ladder
	_box(Vector3(48, 1.0, -4.5), Vector3(3, 2.0, 3))           # J wall 2.0
	_box(Vector3(54, 1.5, -4.5), Vector3(3, 3.0, 3))           # K wall 3.0
	_box(Vector3(60, 0.45, -6.1), Vector3(3, 0.9, 0.2))        # L two fences, 3 m apart
	_box(Vector3(60, 0.45, -9.1), Vector3(3, 0.9, 0.2))
	_box(Vector3(66, 0.45, -6.1), Vector3(3, 0.9, 0.2))        # M three fences
	_box(Vector3(66, 0.45, -9.1), Vector3(3, 0.9, 0.2))
	_box(Vector3(66, 0.45, -12.1), Vector3(3, 0.9, 0.2))
	_box(Vector3(72, 4.0, -4.5), Vector3(3, 8.0, 3))           # N wall 8.0 for the kick
	_box(Vector3(77, 1.8, -4.5), Vector3(2, 3.6, 3))           # O ledge A, x 76..78
	_box(Vector3(80.5, 1.8, -4.5), Vector3(2, 3.6, 3))         # O ledge B, x 79.5..81.5, 1.5 m gap
	_box(Vector3(86, 1.8, -4.5), Vector3(3, 3.6, 3))           # P wall facing +Z, face at z=-3
	_box(Vector3(86, 1.8, 1.5), Vector3(3, 3.6, 3))            # P wall facing -Z, face at z=0
	_box(Vector3(92, 1.0, 1.0), Vector3(3, 2.0, 6))            # Q platform 1, top 2, z -2..4
	_box(Vector3(92, 1.0, -7.8), Vector3(3, 2.0, 4))           # Q platform 2, z -9.8..-5.8
	for i in 8:                                                # R stairs 0.2 x 0.3
		var top := 0.2 * (i + 1)
		_box(Vector3(98, top * 0.5, -3.0 - 0.3 * i - 0.15), Vector3(3, top, 0.3))
	_box(Vector3(98, 0.8, -6.4), Vector3(3, 1.6, 2.0))         # R landing at 1.6, z -7.4..-5.4
	for i in 6:                                                # S stairs 0.3 x 0.3
		var top2 := 0.3 * (i + 1)
		_box(Vector3(104, top2 * 0.5, -3.0 - 0.3 * i - 0.15), Vector3(3, top2, 0.3))
	_box(Vector3(104, 0.9, -5.8), Vector3(3, 1.8, 2.0))        # S landing at 1.8, z -6.8..-4.8
	_box(Vector3(110, 2.25, -6.0), Vector3(3, 4.5, 3))         # T ledge 4.5 beside the rope, face at z=-4.5

	var rope := Area3D.new()
	rope.set_script(CLIMB)
	rope.rope = true
	var rope_shape := CollisionShape3D.new()
	var rope_box := BoxShape3D.new()
	rope_box.size = Vector3(1.0, 6.0, 1.0)
	rope_shape.shape = rope_box
	rope.add_child(rope_shape)
	add_child(rope)
	rope.global_position = Vector3(110, 4.0, -3.5)             # rope from y 1 to 7

	# U facade: 8 m wall with thin moldings at 3.5 (x 0), 4.7 (x +1.0), 5.9 (x -0.3)
	_box(Vector3(116, 4.0, -4.5), Vector3(5, 8.0, 3))
	_box(Vector3(116.0, 3.375, -2.85), Vector3(1.2, 0.25, 0.3))
	_box(Vector3(117.0, 4.575, -2.85), Vector3(1.2, 0.25, 0.3))
	_box(Vector3(115.7, 5.775, -2.85), Vector3(1.2, 0.25, 0.3))

	# W walls facing different ways. A faces +Z. B faces -X across a 1.5 m alley
	# that starts past A's end. C faces -X too, in plain view but far away.
	_box(Vector3(130, 1.8, -4.5), Vector3(4, 3.6, 3))          # A: x 128..132, face z=-3
	_box(Vector3(135, 1.8, -5.6), Vector3(3, 3.6, 4.8))        # B: face x=133.5, z -8..-3.2
	_box(Vector3(139.5, 1.8, 0.0), Vector3(3, 3.6, 6))         # C: face x=138, z -3..3

	# V simulated rope from y 7 down 6 m, ledge 4.5 with its face 0.9 m from the rope
	var vrope := Area3D.new()
	vrope.set_script(ROPE)
	vrope.length = 6.0
	add_child(vrope)
	vrope.global_position = Vector3(122, 7.0, -3.5)
	_box(Vector3(122, 2.25, -5.9), Vector3(3, 4.5, 3))

	var ladder := Area3D.new()
	ladder.set_script(CLIMB)
	var ladder_shape := CollisionShape3D.new()
	var ladder_box := BoxShape3D.new()
	ladder_box.size = Vector3(1.4, 5.0, 0.7)
	ladder_shape.shape = ladder_box
	ladder.add_child(ladder_shape)
	add_child(ladder)
	ladder.global_position = Vector3(42, 2.5, -2.65)

	player = PLAYER.instantiate()
	add_child(player)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.debug_traversal = false
	if player.has_node("LightGem"):
		player.get_node("LightGem").queue_free()

	await _frames(5)
	await _run()

	print("\n==== RESULTS ====")
	for r in results:
		print(r)
	get_tree().quit()


func _physics_process(_d: float) -> void:
	if player == null:
		return
	if player.current_move != _last_move:
		_last_move = player.current_move
		if _last_move != null:
			labels.append(String(_last_move.label))


# --------------------------------------------------------------------------
func _run() -> void:
	# T0 plain jump
	await _place(Vector3(-8, 1.05, 6), 0.0)
	Input.action_press("jump")
	var peak := 0.0
	for i in 60:
		await _frames(1)
		peak = maxf(peak, _feet_y())
	_check("T0 plain jump", peak > 1.0 and labels.is_empty(), "peak %.2f labels %s" % [peak, labels])

	# T1 mantle 1.2 from standstill against the wall
	await _place(Vector3(0, 1.05, -1.0), 0.0)
	Input.action_press("move_forward")
	await _frames(45)
	await _tap("jump")
	await _until_locomotion(180)
	_check("T1 mantle 1.2", labels == ["mantle"] and _near(_feet_y(), 1.2, 0.1) and player.global_position.z < -3.0,
		"labels %s feet %.2f z %.2f" % [labels, _feet_y(), player.global_position.z])

	# T2 step-up 0.6 at a run
	await _place(Vector3(6, 1.05, 3.0), 0.0)
	Input.action_press("move_forward")
	await _until(func(): return player.global_position.z < -1.5, 240)
	await _tap("jump")
	await _until_locomotion(120)
	_check("T2 step-up 0.6", labels == ["step-up"] and _near(_feet_y(), 0.6, 0.1),
		"labels %s feet %.2f speed %.1f" % [labels, _feet_y(), _hspeed()])

	# T3 vault, sprinting
	await _place(Vector3(12, 1.05, 4.0), 0.0)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _until(func(): return player.global_position.z < -4.4, 240)
	var speed_in := _hspeed()
	await _tap("jump")
	var vault_pose_seen := false
	var vault_right := 0.0
	var vault_left := 0.0
	for i in 120:
		await _frames(1)
		if player.movement_state == 1:
			if String(player.body_pose.pose) == "vault":
				vault_pose_seen = true
			vault_right = maxf(vault_right, player.body_pose.right_weight)
			vault_left = maxf(vault_left, player.body_pose.left_weight)
		elif i > 3:
			break
	await _frames(15)
	var speed_out := _hspeed()
	await _frames(10)
	_check("P2 vault plants one hand", vault_pose_seen and vault_right > 0.5 and vault_left < 0.05,
		"pose seen %s right %.2f left %.2f" % [vault_pose_seen, vault_right, vault_left])
	_check("T3 vault", labels == ["vault"] and player.global_position.z < -6.7 and _feet_y() < 0.2 and speed_out > 6.0,
		"labels %s z %.2f feet %.2f speed in %.1f out %.1f" % [labels, player.global_position.z, _feet_y(), speed_in, speed_out])

	# T4 same fence, sneaking
	await _place(Vector3(18, 1.05, -3.0), 0.0)
	Input.action_press("crouch")
	Input.action_press("move_forward")
	await _until(func(): return player.global_position.z < -5.0, 300)
	await _tap("jump")
	Input.action_release("move_forward")
	await _until_locomotion(180)
	_check("T4 sneak onto fence", labels == ["quiet step-up"] and _near(_feet_y(), 0.9, 0.1),
		"labels %s feet %.2f" % [labels, _feet_y()])

	# T5 jump, hold, catch the 3.6 m ledge
	await _place(Vector3(24, 1.05, -1.5), 0.0)
	Input.action_press("move_forward")
	await _frames(40)
	Input.action_press("jump")
	await _until(func(): return player.movement_state == 2, 120)
	var hanging: bool = player.movement_state == 2
	_check("T5 hang", hanging and labels == ["hang"] and _near(player.global_position.y, 3.6 - 1.05, 0.05),
		"state %d labels %s origin y %.2f" % [player.movement_state, labels, player.global_position.y])
	_release_all()
	await _frames(30)
	var pose = player.body_pose
	var lh: Vector3 = pose.left_target.origin
	var rh: Vector3 = pose.right_target.origin
	_check("P1 hang puts both hands on the lip", String(pose.pose) == "hang" and pose.left_weight > 0.95 and pose.right_weight > 0.95
		and _near(lh.y, 3.6, 0.01) and _near(rh.y, 3.6, 0.01) and _near(lh.z, -3.0, 0.02) and _near(rh.z, -3.0, 0.02) and _near(lh.distance_to(rh), 0.48, 0.01),
		"pose %s L %.2f R %.2f left %s right %s" % [pose.pose, pose.left_weight, pose.right_weight, lh, rh])

	# T5b shimmy right
	var x0 := player.global_position.x
	Input.action_press("move_right")
	await _frames(30)
	Input.action_release("move_right")
	_check("T5b shimmy", player.global_position.x - x0 > 0.4 and player.movement_state == 2,
		"dx %.2f state %d" % [player.global_position.x - x0, player.movement_state])

	# T5c peek
	var neck: Node3D = player.get_node("Neck")
	Input.action_press("move_forward")
	await _frames(40)
	var peek_y := neck.position.y
	Input.action_release("move_forward")
	_check("T5c peek", peek_y > 1.1, "neck y %.2f" % peek_y)
	await _frames(20)

	# T5d pull up
	labels.clear()
	await _tap("jump")
	await _until_locomotion(180)
	_check("T5d pull up", labels == ["pull up"] and _near(_feet_y(), 3.6, 0.1),
		"labels %s feet %.2f" % [labels, _feet_y()])

	# T6 turn around, crouch, lower over the edge, then drop
	labels.clear()
	player.rotation.y = PI
	Input.action_press("crouch")
	await _frames(10)
	Input.action_press("move_forward")
	await _frames(2)
	await _tap("jump")
	await _until(func(): return player.movement_state == 2, 180)
	var facing: Vector3 = -player.global_transform.basis.z
	_check("T6 lower", player.movement_state == 2 and labels == ["lower"] and facing.z < -0.95,
		"state %d labels %s facing %s y %.2f" % [player.movement_state, labels, facing, player.global_position.y])
	_release_all()
	await _frames(5)
	await _tap("crouch")
	await _frames(90)
	_check("T6b drop", player.movement_state == 0 and _feet_y() < 0.1, "state %d feet %.2f" % [player.movement_state, _feet_y()])

	# T7 fence with a pit beyond: must not vault
	await _place(Vector3(30, 6.05, 0.5), 0.0)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _until(func(): return player.global_position.z < -5.2, 240)
	await _tap("jump")
	_release_all()
	await _frames(90)
	_check("T7 pit: no vault, balanced on rail", not labels.has("vault") and _near(_feet_y(), 5.9, 0.1),
		"labels %s feet %.2f z %.2f" % [labels, _feet_y(), player.global_position.z])

	# T8 ledge under a low ceiling: crouched mantle, stays crouched
	await _place(Vector3(36, 1.05, -1.0), 0.0)
	Input.action_press("move_forward")
	await _frames(45)
	await _tap("jump")
	await _until_locomotion(180)
	await _frames(20)
	_check("T8 low ceiling", labels == ["mantle"] and player.is_crouched and _near(_feet_y(), 1.2, 0.1),
		"labels %s crouched %s feet %.2f" % [labels, player.is_crouched, _feet_y()])

	# T9 ladder to the top of a 5 m wall
	await _place(Vector3(42, 1.05, 0.0), 0.0)
	Input.action_press("move_forward")
	await _until(func(): return player.movement_state == 3, 180)
	var climbed: bool = player.movement_state == 3
	await _frames(30)
	var ladder_pose: String = String(player.body_pose.pose)
	var rung_gap: float = absf(player.body_pose.left_target.origin.y - player.body_pose.right_target.origin.y)
	_check("P3 ladder hands sit a rung apart", ladder_pose == "climb_ladder" and _near(rung_gap, 0.3, 0.001) and player.body_pose.left_weight > 0.9,
		"pose %s rung gap %.2f weight %.2f" % [ladder_pose, rung_gap, player.body_pose.left_weight])
	await _until(func(): return player.movement_state == 0 and _feet_y() > 4.8, 600)
	_check("T9 ladder", climbed and _near(_feet_y(), 5.0, 0.15),
		"climbed %s labels %s feet %.2f" % [climbed, labels, _feet_y()])

	# T11 2.0 m wall from the ground
	await _place(Vector3(48, 1.05, -1.0), 0.0)
	Input.action_press("move_forward")
	await _frames(45)
	await _tap("jump")
	await _until_locomotion(240)
	_check("T11 high mantle 2.0", labels == ["high mantle"] and _near(_feet_y(), 2.0, 0.1),
		"labels %s feet %.2f" % [labels, _feet_y()])

	# T12 3.0 m wall: jump, keep holding, mantle out of the air
	await _place(Vector3(54, 1.05, -1.5), 0.0)
	Input.action_press("move_forward")
	await _frames(40)
	Input.action_press("jump")
	await _until(func(): return player.movement_state == 1, 120)
	await _until_locomotion(240)
	_check("T12 air mantle 3.0", labels.size() == 1 and _near(_feet_y(), 3.0, 0.1),
		"labels %s feet %.2f state %d" % [labels, _feet_y(), player.movement_state])

	# T13 held jump must not chain a second move
	await _frames(30)
	_check("T13 no chaining while jump is held", labels.size() == 1 and player.movement_state == 0,
		"labels %s" % [labels])

	# T14 chained vaults
	await _place(Vector3(60, 1.05, 4.0), 0.0)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _until(func(): return player.global_position.z < -4.4, 240)
	await _tap("jump")
	await _until(func(): return player.movement_state == 1, 30)
	await _frames(6)
	await _tap("jump")
	await _until(func(): return labels.size() >= 2, 60)
	await _until_locomotion(120)
	var chain_speed := _hspeed()
	_check("T14 chained vaults", labels == ["vault", "vault"] and player.global_position.z < -9.6 and chain_speed > 6.0,
		"labels %s z %.2f speed %.1f" % [labels, player.global_position.z, chain_speed])

	# T15 no chaining while sneaking
	await _place(Vector3(60, 1.05, -3.0), 0.0)
	Input.action_press("crouch")
	Input.action_press("move_forward")
	await _until(func(): return player.global_position.z < -5.0, 300)
	await _tap("jump")
	await _until(func(): return player.movement_state == 1, 30)
	await _frames(6)
	await _tap("jump")
	await _frames(12)
	await _tap("jump")
	await _until_locomotion(180)
	_check("T15 sneaking never chains", labels == ["quiet step-up"], "labels %s" % [labels])

	# T16 the chain cap: three fences, three presses, two moves
	await _place(Vector3(66, 1.05, 4.0), 0.0)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _until(func(): return player.global_position.z < -4.4, 240)
	await _tap("jump")
	await _until(func(): return player.movement_state == 1, 30)
	await _frames(6)
	await _tap("jump")
	await _until(func(): return labels.size() >= 2, 60)
	await _frames(6)
	await _tap("jump")
	await _until_locomotion(120)
	_release_all()
	await _frames(30)
	_check("T16 chain capped at one link", labels == ["vault", "vault"] and player.global_position.z > -11.6,
		"labels %s z %.2f" % [labels, player.global_position.z])

	# T17 wall kick: tall wall, second press in the air beside it
	await _place(Vector3(74, 1.05, -0.5), 0.7)
	Input.action_press("move_forward")
	await _until(func(): return player.global_position.z < -1.8, 240)
	Input.action_press("jump")
	await _frames(4)
	await _until(func(): return player.velocity.y < 1.0, 60)
	Input.action_release("jump")
	await _frames(1)
	var pre_kick_vy: float = player.velocity.y
	await _tap("jump")
	var kicked: int = player._kicks_this_airtime
	var kick_peak := 0.0
	for i in 70:
		await _frames(1)
		kick_peak = maxf(kick_peak, _feet_y())
	_check("T17 wall kick", kicked == 1 and kick_peak > 1.75 and labels.is_empty(),
		"kicks %d peak %.2f vy before %.1f labels %s" % [kicked, kick_peak, pre_kick_vy, labels])

	# T18 sideways leap across a gap in the ledge
	await _place(Vector3(77.6, 1.05, -1.5), 0.0)
	Input.action_press("move_forward")
	await _frames(40)
	Input.action_press("jump")
	await _until(func(): return player.movement_state == 2, 120)
	_release_all()
	await _frames(5)
	labels.clear()
	Input.action_press("move_right")
	await _frames(3)
	await _tap("jump")
	await _until(func(): return player.movement_state == 1, 30)
	Input.action_release("move_right")
	await _until(func(): return player.movement_state == 2, 120)
	_check("T18 sideways leap", labels == ["leap"] and player.movement_state == 2 and player.global_position.x > 79.3,
		"labels %s state %d x %.2f" % [labels, player.movement_state, player.global_position.x])

	# T19 corner: shimmy off the end of ledge B and around its side
	labels.clear()
	Input.action_press("move_right")
	await _until(func(): return labels.has("corner"), 240)
	await _until(func(): return player.movement_state == 2, 120)
	Input.action_release("move_right")
	var n: Vector3 = player.hang_normal
	_check("T19 corner", labels.has("corner") and player.movement_state == 2 and n.x > 0.9 and player.global_position.x > 81.9,
		"labels %s normal %s pos %s" % [labels, n, player.global_position])

	# T20 leap to the wall behind you
	await _place(Vector3(86, 1.05, -1.0), 0.0)
	Input.action_press("move_forward")
	await _frames(40)
	Input.action_press("jump")
	await _until(func(): return player.movement_state == 2, 120)
	_release_all()
	await _frames(5)
	labels.clear()
	player.rotation.y = PI
	await _frames(3)
	await _tap("jump")
	await _until(func(): return player.movement_state == 1, 30)
	await _until(func(): return player.movement_state == 2, 120)
	var n2: Vector3 = player.hang_normal
	_check("T20 leap across", labels == ["leap"] and player.movement_state == 2 and n2.z < -0.9 and _near(player.global_position.z, -0.52, 0.1),
		"labels %s normal %s z %.2f" % [labels, n2, player.global_position.z])

	# T21 assisted jump over a gap a plain jump would miss
	await _place(Vector3(92, 3.05, 3.0), 0.0)
	Input.action_press("move_forward")
	await _until(func(): return player.global_position.z < -1.4, 240)
	Input.action_press("jump")
	await _frames(2)
	var assisted: bool = player._assist_active
	await _frames(70)
	_check("T21 assisted jump", assisted and _near(_feet_y(), 2.0, 0.1) and player.global_position.z < -5.8,
		"assisted %s feet %.2f z %.2f" % [assisted, _feet_y(), player.global_position.z])

	# T22 stairs 0.2 x 0.3, walking
	await _place(Vector3(98, 1.05, 0.0), 0.0)
	Input.action_press("move_forward")
	var neck_node: Node3D = player.get_node("Neck")
	var eye_prev: float = neck_node.global_position.y
	var eye_drops := 0
	var eye_max_jump := 0.0
	var slow_frames := 0
	var climbing := false
	for i in 300:
		await _frames(1)
		var eye_y: float = neck_node.global_position.y
		var dz: float = player.global_position.z
		if dz < -3.2 and dz > -5.2:
			climbing = true
			if eye_y < eye_prev - 0.003:
				eye_drops += 1
			eye_max_jump = maxf(eye_max_jump, absf(eye_y - eye_prev))
			if _hspeed() < 5.0:
				slow_frames += 1
		eye_prev = eye_y
		if dz < -6.0:
			break
	await _frames(10)
	_check("T22 stairs 0.2", _near(_feet_y(), 1.6, 0.08) and labels.is_empty() and player.global_position.z < -6.0,
		"feet %.2f z %.2f labels %s" % [_feet_y(), player.global_position.z, labels])
	# A 6.5 m/s walk up a 0.2 x 0.3 staircase raises the eyes 0.072 m per
	# frame if it is a perfect ramp. Allow a little over that, and no dips.
	_check("T22s stairs feel smooth", climbing and eye_drops == 0 and eye_max_jump < 0.11 and slow_frames <= 2,
		"eye drops %d max eye jump %.3f slow frames %d" % [eye_drops, eye_max_jump, slow_frames])

	# T22b back down them without leaving the ground
	player.rotation.y = PI
	var airborne_frames := 0
	for i in 150:
		await _frames(1)
		if not player.is_on_floor():
			airborne_frames += 1
	_check("T22b down the stairs", _near(_feet_y(), 0.0, 0.05) and airborne_frames <= 10,
		"feet %.2f airborne frames %d z %.2f" % [_feet_y(), airborne_frames, player.global_position.z])

	# T22j jump pressed on the stairs is a jump, not a mantle
	await _place(Vector3(98, 1.05, 0.0), 0.0)
	Input.action_press("move_forward")
	await _until(func(): return player.global_position.z < -3.6, 240)
	await _tap("jump")
	await _frames(40)
	_check("T22j no mantle on stairs", labels.is_empty(), "labels %s" % [labels])

	# T23 steeper stairs 0.3 x 0.3
	await _place(Vector3(104, 1.05, 0.0), 0.0)
	Input.action_press("move_forward")
	await _until(func(): return player.global_position.z < -5.4, 300)
	await _frames(10)
	_check("T23 stairs 0.3", _near(_feet_y(), 1.8, 0.08) and labels.is_empty(),
		"feet %.2f z %.2f labels %s" % [_feet_y(), player.global_position.z, labels])

	# T24 rope: climb it and mantle onto the ledge beside it
	await _place(Vector3(110, 1.05, -1.0), 0.0)
	Input.action_press("move_forward")
	await _until(func(): return player.movement_state == 3, 180)
	var on_rope: bool = player.movement_state == 3
	await _until(func(): return player.movement_state == 0 and _feet_y() > 4.3, 600)
	_check("T24 rope", on_rope and _near(_feet_y(), 4.5, 0.15),
		"on rope %s labels %s feet %.2f state %d" % [on_rope, labels, _feet_y(), player.movement_state])

	# T25 facade: hang, look at the next molding up and to the right, leap to it
	await _place(Vector3(116, 1.05, -1.5), 0.0)
	Input.action_press("move_forward")
	await _frames(40)
	Input.action_press("jump")
	await _until(func(): return player.movement_state == 2, 120)
	_release_all()
	await _frames(5)
	var first_lip: float = player.hang_lip_y
	labels.clear()
	_aim(Vector3(117.0, 4.6, -2.7))
	await _frames(3)
	var facade_target: Dictionary = player.hang_target
	await _tap("jump")
	await _until(func(): return player.movement_state == 1, 30)
	await _until(func(): return player.movement_state == 2, 120)
	_check("T25 facade leap", _near(first_lip, 3.5, 0.05) and not facade_target.is_empty() and labels == ["leap"] and _near(player.hang_lip_y, 4.7, 0.05) and _near(player.global_position.x, 117.0, 0.3),
		"first lip %.2f target %s labels %s lip %.2f x %.2f" % [first_lip, not facade_target.is_empty(), labels, player.hang_lip_y, player.global_position.x])

	# T25b then up and to the left
	labels.clear()
	_aim(Vector3(115.7, 5.8, -2.7))
	await _frames(3)
	await _tap("jump")
	await _until(func(): return player.movement_state == 1, 30)
	await _until(func(): return player.movement_state == 2, 120)
	_check("T25b second facade leap", labels == ["leap"] and _near(player.hang_lip_y, 5.9, 0.05),
		"labels %s lip %.2f x %.2f" % [labels, player.hang_lip_y, player.global_position.x])

	# T25c look down-right at the first molding and drop onto it
	labels.clear()
	_aim(Vector3(116.0, 3.4, -2.7))
	await _frames(3)
	var drop_seen: bool = not player.hang_target.is_empty()
	await _tap("jump")
	await _until(func(): return player.movement_state == 2 and player.hang_lip_y < 4.0, 180)
	_check("T25c drop to a lower ledge", drop_seen and labels == ["let go", "catch"] and player.movement_state == 2 and _near(player.hang_lip_y, 3.5, 0.05),
		"target %s labels %s state %d lip %.2f" % [drop_seen, labels, player.movement_state, player.hang_lip_y])

	# T29 lower from the roof, look straight down the wall, drop to the molding below
	await _place(Vector3(115.7, 9.05, -3.5), PI)
	Input.action_press("crouch")
	await _frames(10)
	Input.action_press("move_forward")
	await _frames(2)
	await _tap("jump")
	await _until(func(): return player.movement_state == 2, 180)
	_release_all()
	await _frames(5)
	var roof_lip: float = player.hang_lip_y
	labels.clear()
	_aim(Vector3(115.7, 5.85, -2.8))
	await _frames(3)
	var roof_target: bool = not player.hang_target.is_empty()
	await _tap("jump")
	await _until(func(): return player.movement_state == 2 and player.hang_lip_y < 7.0, 180)
	_check("T29 drop from the roof edge", _near(roof_lip, 8.0, 0.05) and roof_target and labels == ["let go", "catch"] and _near(player.hang_lip_y, 5.9, 0.05),
		"roof lip %.2f target %s labels %s state %d lip %.2f" % [roof_lip, roof_target, labels, player.movement_state, player.hang_lip_y])

	# T30 standing at the roof edge, look down, press crouch: climb down into a hang
	await _place(Vector3(115.7, 9.05, -3.5), PI)
	await _frames(5)
	player.get_node("Neck").rotation.x = -0.9
	await _frames(2)
	await _tap("crouch")
	await _until(func(): return player.movement_state == 2, 180)
	_check("T30 look down + crouch lowers", labels == ["lower"] and player.movement_state == 2 and _near(player.hang_lip_y, 8.0, 0.05) and not player.is_crouched,
		"labels %s state %d lip %.2f crouched %s" % [labels, player.movement_state, player.hang_lip_y, player.is_crouched])
	_release_all()
	await _tap("crouch")
	await _frames(60)

	# T31/T32 a ledge that faces a different way
	await _place(Vector3(131.5, 1.05, -1.5), 0.0)
	Input.action_press("move_forward")
	await _frames(40)
	Input.action_press("jump")
	await _until(func(): return player.movement_state == 2, 120)
	_release_all()
	await _frames(5)
	var on_a: bool = player.movement_state == 2 and player.hang_normal.z > 0.9

	# T32 aim at a ledge on the other wall that is out of reach: jump must not pull up
	labels.clear()
	_aim(Vector3(138.0, 3.45, -1.0))
	await _frames(3)
	var elsewhere: bool = player.hang_aiming_elsewhere
	await _tap("jump")
	await _frames(40)
	_check("T32 out-of-reach ledge elsewhere: refused, no pull up", on_a and elsewhere and labels.is_empty() and player.movement_state == 2 and player.hang_normal.z > 0.9,
		"on A %s aiming elsewhere %s labels %s state %d reject '%s'" % [on_a, elsewhere, labels, player.movement_state, player._last_reject])

	# T33 looking at our own wall still pulls up, as before
	_aim(Vector3(131.0, 3.5, -3.0))
	await _frames(3)
	var own_wall: bool = not player.hang_aiming_elsewhere and player.hang_target.is_empty()
	_check("T33 own wall is not elsewhere", own_wall, "elsewhere %s target %s" % [player.hang_aiming_elsewhere, player.hang_target])

	# T31 aim at a reachable ledge on the perpendicular wall, ahead and to the side
	if player.movement_state != 2:
		await _place(Vector3(131.5, 1.05, -1.5), 0.0)
		Input.action_press("move_forward")
		await _frames(40)
		Input.action_press("jump")
		await _until(func(): return player.movement_state == 2, 120)
		_release_all()
		await _frames(5)
	labels.clear()
	_aim(Vector3(133.5, 3.45, -4.2))
	# The hang target refreshes ten times a second.
	await _frames(8)
	var cross_target: Dictionary = player.hang_target
	await _tap("jump")
	await _until(func(): return player.movement_state == 1, 30)
	await _until(func(): return player.movement_state == 2, 120)
	await _frames(5)
	_check("T31 leap to a ledge facing another way", not cross_target.is_empty() and labels == ["leap"] and player.movement_state == 2 and player.hang_normal.x < -0.9 and _near(player.global_position.z, -4.2, 0.3),
		"target %s labels %s state %d normal %s pos %s reject '%s'" % [not cross_target.is_empty(), labels, player.movement_state, player.hang_normal, player.global_position, player._last_reject])

	# T26 simulated rope: climb it and mantle onto the ledge
	await _place(Vector3(122, 1.05, -1.0), 0.0)
	Input.action_press("move_forward")
	await _until(func(): return player.movement_state == 3, 180)
	var on_vrope: bool = player.movement_state == 3
	await _until(func(): return player.movement_state == 0 and _feet_y() > 4.3, 600)
	_check("T26 verlet rope", on_vrope and _near(_feet_y(), 4.5, 0.15),
		"on rope %s labels %s feet %.2f state %d" % [on_vrope, labels, _feet_y(), player.movement_state])

	# T27 swing on the rope, then let go with the swing
	await _place(Vector3(122, 1.05, -1.0), 0.0)
	Input.action_press("move_forward")
	await _until(func(): return player.movement_state == 3, 180)
	_release_all()
	Input.action_press("move_right")
	await _frames(70)
	var swung_x: float = player.global_position.x - 122.0
	await _tap("jump")
	await _frames(3)
	var vx: float = player.velocity.x
	_release_all()
	_check("T27 rope swing", swung_x > 0.4 and vx > 0.5 and player.movement_state == 0,
		"swing dx %.2f vx after jump %.2f state %d" % [swung_x, vx, player.movement_state])

	# P4 locomotion pose names, and hands let go when nothing is held
	await _place(Vector3(-8, 1.05, 6), 0.0)
	await _frames(20)
	var idle_pose: String = String(player.body_pose.pose)
	Input.action_press("move_forward")
	await _frames(30)
	var walk_pose: String = String(player.body_pose.pose)
	Input.action_press("sprint")
	await _frames(40)
	var sprint_pose: String = String(player.body_pose.pose)
	_release_all()
	Input.action_press("crouch")
	await _frames(30)
	var crouch_pose: String = String(player.body_pose.pose)
	_release_all()
	await _frames(10)
	_check("P4 locomotion poses", idle_pose == "idle" and walk_pose == "walk" and sprint_pose == "sprint" and crouch_pose == "crouch_idle" and player.body_pose.left_weight < 0.05,
		"%s / %s / %s / %s  L %.2f" % [idle_pose, walk_pose, sprint_pose, crouch_pose, player.body_pose.left_weight])

	# T10 crouch and stand
	await _place(Vector3(-8, 1.05, 6), 0.0)
	Input.action_press("crouch")
	await _frames(10)
	var crouched_h: float = player.collider.shape.height
	Input.action_release("crouch")
	await _frames(10)
	_check("T10 crouch", _near(crouched_h, 1.2, 0.01) and _near(player.collider.shape.height, 2.0, 0.01) and _near(_feet_y(), 0.0, 0.06),
		"crouched h %.2f standing h %.2f feet %.2f" % [crouched_h, player.collider.shape.height, _feet_y()])


# --------------------------------------------------------------------------
func _box(center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	add_child(body)
	body.global_position = center


func _place(pos: Vector3, yaw: float) -> void:
	_release_all()
	await _frames(2)
	player.movement_state = 0
	player.current_move = null
	player.current_climb = null
	player.velocity = Vector3.ZERO
	player.global_position = pos
	player.rotation.y = yaw
	player.get_node("Neck").rotation.x = 0.0
	await _frames(20)
	labels.clear()
	_last_move = null


func _release_all() -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "jump", "sprint", "crouch"]:
		Input.action_release(a)


func _tap(action: String) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _until(cond: Callable, max_frames: int) -> void:
	for i in max_frames:
		if cond.call():
			return
		await get_tree().physics_frame


func _until_locomotion(max_frames: int) -> void:
	await _frames(3)
	await _until(func(): return player.movement_state == 0, max_frames)
	await _frames(15)


## Point the body yaw and neck pitch at a world point, from the eye.
func _aim(target: Vector3) -> void:
	var eye: Vector3 = player.get_node("Neck").global_position
	var d := target - eye
	player.rotation.y = atan2(-d.x, -d.z)
	player.get_node("Neck").rotation.x = atan2(d.y, Vector2(d.x, d.z).length())


func _feet_y() -> float:
	return player.global_position.y - 1.0


func _hspeed() -> float:
	return Vector3(player.velocity.x, 0, player.velocity.z).length()


func _near(a: float, b: float, tol: float) -> bool:
	return absf(a - b) <= tol


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
