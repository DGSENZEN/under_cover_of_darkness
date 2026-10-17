extends Node3D
## The Prosecutor's own first-person arms (FPArms), behind the F12 switch:
## real proportions, the solver's fist from their own poses, held hands drawn
## where they hold, the old body kept only for the kick's leg
## (docs/superpowers/plans/2026-10-16-prosecutor-fp-arms.md, piece 1 Task 2).

const PLAYER := preload("res://Player.tscn")
const HANDHOLD := preload("res://scripts/PlayerUtils/Handhold.gd")
const ViewArmsScript := preload("res://scripts/Interaction/ViewArms.gd")
const PROPS := preload("res://scripts/Interaction/Props.gd")

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
	await _held_checks()
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


func _kick_checks() -> void:
	var arms = player.hand._arms
	var legs = arms.get("_leg_reach")
	var body = arms.get("_leg_body")
	var folded: bool = legs != null and &"spine_01" in legs.folded and &"thigh_l" in legs.folded
	var travel := 0.0
	if legs != null:
		player.hand.play_kick()
		var start := Vector3.INF
		for i in 30:
			await _frames(1)
			if legs.foot_weight > 0.5:
				if start == Vector3.INF:
					start = legs.solved_foot
				travel = maxf(travel, legs.solved_foot.distance_to(start))
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
