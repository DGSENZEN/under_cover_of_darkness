extends Node3D
## The Prosecutor's own first-person arms (FPArms), behind the F12 switch:
## real proportions, the solver's fist from their own poses, held hands drawn
## where they hold, the old body kept only for the kick's leg
## (docs/superpowers/plans/2026-10-16-prosecutor-fp-arms.md, piece 1 Task 2).

const PLAYER := preload("res://Player.tscn")
const HANDHOLD := preload("res://scripts/PlayerUtils/Handhold.gd")
const ViewArmsScript := preload("res://scripts/Interaction/ViewArms.gd")
const PROPS := preload("res://scripts/Interaction/Props.gd")
const HumanoidScript := preload("res://scripts/Visual/Humanoid.gd")

const BONES := [&"root", &"clavicle", &"upperarm", &"lowerarm", &"hand"]
const FINGERS := [&"index", &"middle", &"ring", &"pinky", &"thumb"]

var player: CharacterBody3D
var results: Array[String] = []
var failed := false


func _ready() -> void:
	# The new arms, as F12 or FP_ARMS=new give them, before the player is made.
	ViewArmsScript.new_arms = true
	_box(Vector3(0, -0.5, 0), Vector3(120, 1, 40))
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
	_rig_checks()
	await _pose_checks()
	await _held_checks()
	await _grip_pose_checks()
	await _shoulder_checks()
	await _near_checks()
	await _kick_checks()
	await _switch_checks()
	await _sword_checks()


func _rig_checks() -> void:
	var arms = player.hand._arms
	var man = arms.man
	var skeleton: Skeleton3D = man.get("skeleton") if man != null else null
	var missing := []
	if skeleton != null:
		for side in ["l", "r"]:
			for bone in BONES:
				var name := String(bone) if bone == &"root" else "%s_%s" % [bone, side]
				if skeleton.find_bone(name) < 0:
					missing.append(name)
			for finger in FINGERS:
				for joint in ["01", "02", "03"]:
					var name := "%s_%s_%s" % [finger, joint, side]
					if skeleton.find_bone(name) < 0:
						missing.append(name)
	var is_new: bool = man != null and man.get_script() != null and String(man.get_script().resource_path).ends_with("FPArms.gd")
	_check("FA1 the new arms load, every bone the solver needs is there", is_new and skeleton != null and missing.is_empty() and skeleton.get_bone_count() == 39,
		"FPArms %s bones %d missing %s" % [is_new, skeleton.get_bone_count() if skeleton != null else 0, missing])
	if not is_new:
		return

	var length := 0.0
	for side in ["l", "r"]:
		var shoulder := skeleton.get_bone_global_rest(skeleton.find_bone("upperarm_" + side)).origin
		var elbow := skeleton.get_bone_global_rest(skeleton.find_bone("lowerarm_" + side)).origin
		var wrist := skeleton.get_bone_global_rest(skeleton.find_bone("hand_" + side)).origin
		length = maxf(length, shoulder.distance_to(elbow) + elbow.distance_to(wrist))
	_check("FA2 shoulder to wrist is a real arm's length", absf(length - 0.65) <= 0.02, "%.3f m" % length)

	var library: AnimationLibrary = man.library()
	var poses: bool = library != null and library.has_animation(&"Open") and library.has_animation(&"Fist") and library.has_animation(&"Hook")
	_check("FA3 the new arms carry their poses", poses, str(library.get_animation_list() if library != null else []))

	var fingers: Dictionary = arms.reach._fingers
	var closed := 0.0
	if fingers.has(&"index_02_l"):
		closed = rad_to_deg((fingers[&"index_02_l"][0] as Quaternion).angle_to(fingers[&"index_02_l"][1]))
	_check("FA4 the solver's fist is the new arms' own", fingers.size() >= 30 and closed > 25.0,
		"%d finger joints learned, index_02 closes %.0f deg" % [fingers.size(), closed])
	_check("FA6 the new arms are not stretched", is_zero_approx(arms.reach.arm_length), "arm_length %.2f" % arms.reach.arm_length)

	# Every hold and held item turns a hand by its bone's axes, set for the old
	# hands: the new ones must have the palm on the same axis.
	var old = HumanoidScript.new()
	old.build(&"player")
	add_child(old)
	var worst := 1.0
	var axes := []
	for bone in [&"hand_l", &"hand_r", &"lowerarm_l", &"lowerarm_r"]:
		var palms := []
		for rig in [old, man]:
			var rest: Transform3D = rig.skeleton.get_bone_global_rest(rig.skeleton.find_bone(bone))
			var basis: Basis = (rig.global_transform.affine_inverse() * rig.skeleton.global_transform * rest).basis.orthonormalized()
			palms.append((basis.inverse() * Vector3.DOWN).normalized())
		worst = minf(worst, palms[0].dot(palms[1]))
		axes.append("%s %s/%s" % [bone, palms[0].snapped(Vector3.ONE * 0.1), palms[1].snapped(Vector3.ONE * 0.1)])
	old.queue_free()
	_check("FA11 the new hands' bones turn as the old ones do (the palm on the same axis)", worst > 0.9, "; ".join(axes))


func _pose_checks() -> void:
	var arms = player.hand._arms
	var all := true
	for pose in [&"Open", &"Fist", &"Hook", &"Wrap", &"Push", &"SwordGrip"]:
		all = all and arms.has_pose(pose)
	_check("FA12 the new arms have the whole pose library", all, "")

	# The hands out of HandSlot's: one asked for a pose, then another.
	player.hand.set_process(false)
	for i in 30:
		arms.set_hand(0, Transform3D(Basis.IDENTITY, Vector3(-0.2, -0.2, -0.4)), 1.0, 1.0, &"Wrap")
		await _frames(1)
	var wrapped: float = arms.reach.pose_weights[0].get(&"Wrap", 0.0)
	_check("FA13 a hand asked to wrap takes the Wrap pose", wrapped > 0.99, "Wrap share %.2f" % wrapped)
	var mid := {}
	for i in 30:
		arms.set_hand(0, Transform3D(Basis.IDENTITY, Vector3(-0.2, -0.2, -0.4)), 1.0, 1.0, &"Push")
		await _frames(1)
		if i == 2:
			mid = arms.reach.pose_weights[0].duplicate()
	var pushed: float = arms.reach.pose_weights[0].get(&"Push", 0.0)
	var between: bool = mid.get(&"Push", 0.0) > 0.05 and mid.get(&"Push", 0.0) < 0.95 and mid.get(&"Wrap", 0.0) > 0.05
	player.hand.set_process(true)
	_check("FA14 a hand changing pose cross-fades, no pop", between and pushed > 0.99,
		"2 frames in %s, then Push %.2f" % [mid, pushed])


func _held_checks() -> void:
	var arms = player.hand._arms
	var contacts = player.hand._contacts
	var cam: Camera3D = player.camera
	var size: Vector2 = get_viewport().get_visible_rect().size
	var column := _sill_column(10.0)
	await _frames(2)
	await _hang_on(column[0])
	await _frames(30)
	var drawn_off := 0.0
	var depth_off := 0.0
	for side in [0, 1]:
		var wrist: Vector3 = arms.man.global_transform * arms.reach.targets[side].origin
		drawn_off = maxf(drawn_off, cam.unproject_position(wrist).distance_to(cam.unproject_position(arms.hand_position(side))))
		var real: Vector3 = player.hand.global_transform * player.hand._held_wrists[side]
		depth_off = maxf(depth_off, arms.hand_position(side).distance_to(real))
	var held: bool = contacts.grips[0].wanted and contacts.grips[1].wanted
	_check("FA5 hanging, each new hand is drawn where it holds, at true size and depth", held and drawn_off <= size.x * 0.06 and depth_off <= 0.03,
		"held %s, worst %.0f px on screen, %.3f m from the grip" % [held, drawn_off, depth_off])
	var lengths: Array = arms.reach.solved_lengths
	_check("FA6b hanging, the solver uses the arms' own length", absf(lengths[0] - 0.65) <= 0.02 and absf(lengths[1] - 0.65) <= 0.02,
		"%.3f / %.3f m" % [lengths[0], lengths[1]])

	var sk: Skeleton3D = arms.man.skeleton
	var mid: Vector3 = (sk.global_transform * sk.get_bone_global_pose(sk.find_bone(&"upperarm_l")).origin + sk.global_transform * sk.get_bone_global_pose(sk.find_bone(&"upperarm_r")).origin) * 0.5
	var chest_rel: Vector3 = cam.global_transform.affine_inverse() * mid
	var chest_below: float = rad_to_deg(atan2(-chest_rel.y, maxf(-chest_rel.z, 0.001)))
	_check("FA7 hanging, his chest is below the view", chest_rel.z > -0.05 or chest_below > cam.fov * 0.5 + 5.0,
		"chest at %s, %.0f deg below" % [chest_rel, chest_below])
	player._drop_from_hang()
	await _frames(60)


func _grip_pose_checks() -> void:
	var arms = player.hand._arms
	var shares: Array = arms.reach.pose_weights

	# A sill: both hands hook over it.
	var column := _sill_column(30.0)
	await _frames(2)
	await _hang_on(column[0])
	await _frames(30)
	var hooked: float = minf(shares[0].get(&"Hook", 0.0), shares[1].get(&"Hook", 0.0))
	player._drop_from_hang()
	await _frames(60)

	# A drainpipe: the hands wrap round it.
	_box(Vector3(40, 3, -4.5), Vector3(4, 6, 3))
	var pole: Node3D = HANDHOLD.new()
	pole.kind = HANDHOLD.Kind.POLE
	pole.length = 6.0
	add_child(pole)
	pole.global_position = Vector3(40, 0, -2.9)
	await _frames(2)
	await _place(Vector3(40, 1.03, -1.6))
	Input.action_press("move_forward")
	var wrapped := 1.0
	var looked := 0
	var on_pole := 0
	# Upright: each held hand's palm faces in across the pipe (thumb up), not
	# down as on a ledge.
	var flat_palm := 0.0
	var wrong_way := 0
	for i in 200:
		await _frames(1)
		on_pole = on_pole + 1 if player.movement_state == 3 else 0
		# (Past the first moments on it: a hand crossing over to the wrap.)
		if on_pole > 15 and i % 5 == 0:
			for side in [0, 1]:
				if arms.reach.weights[side] > 0.9 and player.hand._contacts.weight(side) > 0.95:
					wrapped = minf(wrapped, shares[side].get(&"Wrap", 0.0))
					looked += 1
					# The palm: the hand bone's -X (right hand), +X (left).
					var basis: Basis = arms.man.global_basis * arms.reach.targets[side].basis
					var palm: Vector3 = (basis.x * (-1.0 if side == 1 else 1.0)).normalized()
					var inward: float = palm.dot(player.camera.global_basis.x) * (-1.0 if side == 1 else 1.0)
					flat_palm = maxf(flat_palm, absf(palm.y))
					if inward < 0.6:
						wrong_way += 1
		if looked > 20:
			break
	_release_all()
	_check("FA15 a sill is hooked, a drainpipe wrapped", hooked > 0.95 and looked > 10 and wrapped > 0.95,
		"Hook %.2f; Wrap %.2f over %d held hand-frames" % [hooked, wrapped, looked])
	_check("FA21 on a drainpipe the palms face in across it, thumbs up", looked > 10 and flat_palm < 0.4 and wrong_way == 0,
		"palm up/down at most %.2f, %d of %d hand-frames not facing in" % [flat_palm, wrong_way, looked])
	await _place(Vector3(50, 0.1, 0))
	await _frames(30)

	# Pulling up onto a top: the hands press flat on it.
	_box(Vector3(60, 1.2, -4.5), Vector3(4, 2.4, 3))
	var lip: Node3D = HANDHOLD.new()
	lip.kind = HANDHOLD.Kind.LEDGE
	lip.length = 1.0
	add_child(lip)
	lip.global_position = Vector3(60, 2.4, -3)
	await _frames(2)
	await _hang_on(lip)
	await _frames(20)
	Input.action_press("jump")
	var since := -1
	var pushed := 0.0
	for i in 120:
		await _frames(1)
		var label: String = String(player.current_move.label) if player.current_move != null else ""
		if label == "pull up" and since < 0:
			since = i
		if since >= 0 and i - since <= 20:
			pushed = maxf(pushed, minf(shares[0].get(&"Push", 0.0), shares[1].get(&"Push", 0.0)))
	_release_all()
	_check("FA16 pulling up, the hands press flat on the top", since >= 0 and pushed > 0.9,
		"pull up from frame %d, Push %.2f" % [since, pushed])
	await _place(Vector3(70, 0.1, 0))
	await _frames(30)


func _shoulder_checks() -> void:
	# Free (the viewmodel): his shoulders where the old body's were, standing
	# easy (its Idle).
	await _place(Vector3(80, 0.1, 0))
	await _frames(20)
	var arms = player.hand._arms
	var old = arms.get("_leg_body")
	# (Their middle: the old stood easy, one shoulder a little forward.)
	var worst := INF
	if old != null:
		var middles := []
		for body in [arms.man, old]:
			var sk: Skeleton3D = body.skeleton
			var sum := Vector3.ZERO
			for bone in [&"upperarm_l", &"upperarm_r"]:
				var index := sk.find_bone(bone)
				var at: Transform3D = sk.get_bone_global_rest(index) if body == arms.man else sk.get_bone_global_pose(index)
				sum += sk.global_transform * at.origin
			middles.append(sum * 0.5)
		worst = middles[0].distance_to(middles[1])
	_check("FA19 the new shoulders sit where the old body's did", old != null and worst <= 0.03, "worst %.3f m apart" % worst)

	# Pulling up onto a top, looking down at the hands: the coat's shoulders
	# (their caps, 7 cm round; the yoke's collar and shoulder tops) stay below
	# the view.
	_box(Vector3(90, 1.2, -4.5), Vector3(4, 2.4, 3))
	var lip: Node3D = HANDHOLD.new()
	lip.kind = HANDHOLD.Kind.LEDGE
	lip.length = 1.0
	add_child(lip)
	lip.global_position = Vector3(90, 2.4, -3)
	await _frames(2)
	await _hang_on(lip)
	await _frames(20)
	Input.action_press("jump")
	var cam: Camera3D = player.camera
	var bottom: float = get_viewport().get_visible_rect().size.y
	var highest := INF
	for i in 50:
		await _frames(1)
		if arms.held() < 0.5:
			continue
		var sk: Skeleton3D = arms.man.skeleton
		var tops: Array[Vector3] = []
		for bone in [&"upperarm_l", &"upperarm_r"]:
			var cap: Vector3 = sk.global_transform * sk.get_bone_global_pose(sk.find_bone(bone)).origin
			tops.append(cap + cam.global_transform.basis.y * 0.07)
		# The coat's collar and the tops of its shoulders (sleeve_form.YOKE).
		for at in [Vector3(0.0, 1.55, 0.01), Vector3(-0.2, 1.51, 0.01), Vector3(0.2, 1.51, 0.01)]:
			tops.append(arms.man.global_transform * at)
		for top in tops:
			if not cam.is_position_behind(top):
				highest = minf(highest, cam.unproject_position(top).y)
	_release_all()
	_check("FA20 pulling up, the coat's shoulders stay below the view", highest > bottom,
		"highest cap top at %.0f px, the view ends at %.0f px" % [highest, bottom])
	await _place(Vector3(100, 0.1, 0))
	await _frames(30)


# The playtest (Oct 17): "the hands are a bit too far away from the camera,
# they should feel closer", both everyday and climbing.
func _near_checks() -> void:
	var arms = player.hand._arms
	var cam: Camera3D = player.camera
	var size: Vector2 = get_viewport().get_visible_rect().size

	# Empty-handed: carried near, in the bottom of the view.
	await _place(Vector3(110, 0.1, 0))
	await _frames(40)
	var far := 0.0
	var off := 0
	for side in [0, 1]:
		var at: Vector3 = arms.hand_position(side)
		far = maxf(far, cam.global_position.distance_to(at))
		var seen: Vector2 = cam.unproject_position(at)
		if cam.is_position_behind(at) or seen.y > size.y or seen.x < 0.0 or seen.x > size.x:
			off += 1
	var standing_lean: float = player.wall_lean.length()
	_check("FA22 empty-handed, the hands are carried near and in view", far <= 0.42 and off == 0 and standing_lean < 0.001,
		"farthest %.2f m, %d out of view, lean %.3f" % [far, off, standing_lean])

	# Hanging: the view leans in to the wall, the hands near the eye.
	var column := _sill_column(120.0)
	await _frames(2)
	await _hang_on(column[0])
	await _frames(40)
	var eye_to_wall: float = cam.global_position.z - (-3.0)
	var reach := 0.0
	for side in [0, 1]:
		reach = maxf(reach, cam.global_position.distance_to(arms.hand_position(side)))
	_check("FA23 hanging, the view leans in to the wall and the hands are near", eye_to_wall <= 0.36 and eye_to_wall >= 0.2 and reach <= 0.47,
		"eye %.2f m from the wall, hands at most %.2f m from the eye" % [eye_to_wall, reach])
	player._drop_from_hang()
	await _frames(60)
	_check("FA23b off the wall, the lean is gone", player.wall_lean.length() < 0.01, "lean %.3f" % player.wall_lean.length())


func _kick_checks() -> void:
	var arms = player.hand._arms
	var legs = arms.get("_leg_reach")
	var body = arms.get("_leg_body")
	var folded: bool = legs != null and &"spine_01" in legs.folded and &"thigh_l" in legs.folded
	var travel := 0.0
	if legs != null:
		var before: Vector3 = legs.solved_foot
		player.hand.play_kick()
		var start := Vector3.INF
		for i in 30:
			await _frames(1)
			# The foot as you see it (camera space), once it has been solved.
			if legs.foot_weight > 0.5 and legs.solved_foot != before:
				var seen: Vector3 = player.camera.global_transform.affine_inverse() * legs.solved_foot
				if start == Vector3.INF:
					start = seen
				travel = maxf(travel, seen.distance_to(start))
	var separate: bool = body != null and body != arms.man
	_check("FA8 the kick swings the old body's leg, the rest of it folded away", separate and folded and travel > 0.2 * ViewArmsScript.SCALE,
		"leg body %s folded %s foot travel %.3f m" % [separate, folded, travel])
	await _frames(30)


func _switch_checks() -> void:
	var column := _sill_column(20.0)
	await _frames(2)
	await _hang_on(column[0])
	await _frames(20)
	var arms = player.hand._arms
	var before = arms.man
	_press(KEY_F12)
	var regripped := -1
	for i in 10:
		await _frames(1)
		if arms.reach != null and arms.reach.weights[0] > 0.9 and arms.reach.weights[1] > 0.9:
			regripped = i
			break
	var old_now: bool = not ViewArmsScript.new_arms and arms.man != before and arms.get("_leg_body") == null
	var gone: bool = not is_instance_valid(before) or before.get_parent() == null
	await _frames(10)
	var contacts = player.hand._contacts
	var as_today: bool = absf(arms.reach.curls[0] - contacts.curl(0)) <= 0.01 and absf(arms.reach.curls[1] - contacts.curl(1)) <= 0.01
	_check("FA18 the old arms hang with today's curls", as_today,
		"curls %.2f/%.2f, contacts %.2f/%.2f" % [arms.reach.curls[0], arms.reach.curls[1], contacts.curl(0), contacts.curl(1)])
	var old_poses: bool = not arms.has_pose(&"Hook") and not arms.has_pose(&"Wrap") and arms.has_pose(&"Fist")
	_check("FA17 the old arms have only their fist", old_poses, "Hook %s Fist %s" % [arms.has_pose(&"Hook"), arms.has_pose(&"Fist")])
	_press(KEY_F12)
	await _frames(10)
	var back: bool = ViewArmsScript.new_arms and arms.man != null and String(arms.man.get_script().resource_path).ends_with("FPArms.gd")
	var held_again: bool = arms.reach.weights[0] > 0.9 and arms.reach.weights[1] > 0.9
	_check("FA9 F12 while hanging switches the arms, the hands hold on", old_now and gone and regripped >= 0 and back and held_again,
		"to old %s, new arms freed %s, re-gripped at frame %d, back to new %s, held %s" % [old_now, gone, regripped, back, held_again])
	player._drop_from_hang()
	await _frames(60)


func _sword_checks() -> void:
	await _place(Vector3(-20, 0.1, 0))
	PROPS.give_weapons(player)
	player.inventory.select_by_id(&"sword")
	await _frames(90)
	var arms = player.hand._arms
	var grip: Vector3 = player.hand._main.global_position
	var gap: float = arms.hand_position(1).distance_to(grip)
	_check("FA10 the sword is held in the new right hand", player.hand._main_item != null and arms.reach.weights[1] > 0.5 and gap <= 0.12,
		"item %s weight %.2f hand to grip %.3f m" % [player.hand._main_item != null, arms.reach.weights[1], gap])
	var sword_grip: float = arms.reach.pose_weights[1].get(&"SwordGrip", 0.0)
	_check("FA16b the sword hand takes the sword grip", sword_grip > 0.95, "SwordGrip %.2f" % sword_grip)


func _sill_column(x: float) -> Array:
	_box(Vector3(x, 4.5, -4.5), Vector3(4, 9, 3))
	var column := []
	for i in 4:
		var hold: Node3D = HANDHOLD.new()
		hold.kind = HANDHOLD.Kind.LEDGE
		hold.length = 1.0
		add_child(hold)
		hold.global_position = Vector3(x, 2.4 + 0.9 * i, -3)
		column.append(hold)
	return column


func _hang_on(hold: Node3D) -> void:
	var lip: float = hold.global_position.y
	var anchor: Vector3 = player.planner.hang_anchor(hold.global_position, Vector3.BACK, lip)
	await _place(anchor)
	player.global_position = anchor
	player._enter_hang(Vector3.BACK, lip, false, &"", hold)
	await _frames(2)


func _place(at: Vector3, yaw := 0.0) -> void:
	_release_all()
	player.teleport(Transform3D(Basis(Vector3.UP, yaw), at))
	player._set_crouched(false)
	player.neck.rotation.x = 0.0
	await _frames(3)


func _press(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	var up := InputEventKey.new()
	up.keycode = key
	up.pressed = false
	Input.parse_input_event(up)


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


func _release_all() -> void:
	for action in ["move_forward", "move_back", "move_left", "move_right", "jump", "crouch", "sprint", "block", "throw"]:
		Input.action_release(action)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(label: String, ok: bool, detail: String) -> void:
	failed = failed or not ok
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", label, detail])
