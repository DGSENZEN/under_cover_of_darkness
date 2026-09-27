extends Node3D
## What makes a man look alive: the rig's upper-body layer and the small
## turns laid over the animation (Humanoid, Posture), his expression (gaze,
## posture by temperament, breathing, gestures: Expression), his pastimes
## (GuardPastimes), and the air about him (Atmosphere).
##
##   Godot --headless --fixed-fps 60 --quit-after 3000000 --path . res://tests/aliveness_test.tscn

const HumanoidScript := preload("res://scripts/Visual/Humanoid.gd")

var results: Array[String] = []


func _ready() -> void:
	await _run()
	print("\n==== RESULTS ====")

	for r in results:
		print(r)

	get_tree().quit()


func _run() -> void:
	await _rig()


# ---------------------------------------------------------------------------
# The rig
# ---------------------------------------------------------------------------

func _rig() -> void:
	var a := _man(Vector3(-2, 0, 0))
	var b := _man(Vector3(2, 0, 0))
	var walking := Vector3(0, 0, -1.1)

	# A1 the upper layer plays over walking
	for f in 60:
		a.set_motion(walking, false, 1.0 / 60.0)
		b.set_motion(walking, false, 1.0 / 60.0)
		b.show_upper(&"Consume", f / 60.0)
		await get_tree().physics_frame

	await get_tree().process_frame
	var hand_gap := _local(a, &"hand_r").origin.distance_to(_local(b, &"hand_r").origin)
	var thigh_gap := _local(a, &"thigh_l").basis.get_rotation_quaternion().angle_to(_local(b, &"thigh_l").basis.get_rotation_quaternion())
	_check("A1 the upper layer plays a clip over walking: the hand moves, the legs keep walking",
		hand_gap > 0.08 and thigh_gap < 0.02 and b.upper_weight() > 0.8, "hand %.3f m apart, thigh %.3f rad, weight %.2f" % [hand_gap, thigh_gap, b.upper_weight()])

	# A2 cleared, it fades back to the walk
	b.clear_upper(0.25)

	for f in 27:
		a.set_motion(walking, false, 1.0 / 60.0)
		b.set_motion(walking, false, 1.0 / 60.0)
		await get_tree().physics_frame

	await get_tree().process_frame
	hand_gap = _local(a, &"hand_r").origin.distance_to(_local(b, &"hand_r").origin)
	_check("A2 cleared, the upper layer fades back to the walk", hand_gap < 0.02 and b.upper_weight() < 0.01, "hand %.3f m apart, weight %.2f" % [hand_gap, b.upper_weight()])

	# A3 the new turns: head pitch, shoulders, breath
	for f in 40:
		a.set_motion(Vector3.ZERO, false, 1.0 / 60.0)
		b.set_motion(Vector3.ZERO, false, 1.0 / 60.0)
		b.posture.set("head_pitch", 0.4)
		b.posture.set("shoulders", 1.0)
		await get_tree().physics_frame

	var bones := [&"Head", &"upperarm_l", &"upperarm_r", &"pelvis", &"spine_03"]
	var pa := await _posed(a, bones)
	var pb := await _posed(b, bones)
	var down := _forward_y(pa[&"Head"]) - _forward_y(pb[&"Head"])
	# The clavicle turns about its own root: its far end (the shoulder, where
	# the upper arm starts) is what rises, both sides.
	var shrug_l := ((pb[&"upperarm_l"] as Transform3D).origin.y - (pb[&"pelvis"] as Transform3D).origin.y) - ((pa[&"upperarm_l"] as Transform3D).origin.y - (pa[&"pelvis"] as Transform3D).origin.y)
	var shrug_r := ((pb[&"upperarm_r"] as Transform3D).origin.y - (pb[&"pelvis"] as Transform3D).origin.y) - ((pa[&"upperarm_r"] as Transform3D).origin.y - (pa[&"pelvis"] as Transform3D).origin.y)
	var shrug := minf(shrug_l, shrug_r)
	b.posture.set("head_pitch", 0.0)
	b.posture.set("shoulders", 0.0)
	b.posture.set("breath", 0.0)

	for f in 30:
		b.set_motion(Vector3.ZERO, false, 1.0 / 60.0)
		await get_tree().physics_frame

	var out := ((await _posed(b, bones))[&"spine_03"] as Transform3D).basis.get_rotation_quaternion()
	b.posture.set("breath", 1.0)
	var inn := ((await _posed(b, bones))[&"spine_03"] as Transform3D).basis.get_rotation_quaternion()
	var breath := out.angle_to(inn)
	_check("A3 posture's new turns: the head bows, the shoulders rise, the chest breathes",
		down > 0.2 and shrug > 0.015 and breath >= 0.03, "head forward dropped %.3f, shoulders up %.3f/%.3f m, breath %.3f rad" % [down, shrug_l, shrug_r, breath])
	a.queue_free()
	b.queue_free()


## A man, built as a guard's rig builds one.
func _man(at: Vector3) -> Node3D:
	var man: Node3D = HumanoidScript.new()
	add_child(man)
	man.build(&"watchman", false, &"Sword_Idle")
	man.global_position = at
	return man


## `bones` of `man` in his own frame as posed this frame, Posture's turns and
## all (read while the skeleton says it is posed: after that the turns are
## gone until the next).
func _posed(man: Node3D, bones: Array) -> Dictionary:
	var got := {}
	man.skeleton.skeleton_updated.connect(func():
		for bone in bones:
			got[bone] = _local(man, bone), CONNECT_ONE_SHOT)

	while got.is_empty():
		await get_tree().process_frame

	return got


## A bone of `man` in his own frame.
func _local(man: Node3D, bone: StringName) -> Transform3D:
	return man.global_transform.affine_inverse() * man.bone_global(bone)


## How far up (y, in his frame) the way a bone faces points: its axis
## nearest his front.
func _forward_y(pose: Transform3D) -> float:
	var best := Vector3.ZERO
	var best_dot := -INF

	for axis in [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.FORWARD, Vector3.BACK]:
		var dir: Vector3 = pose.basis * axis
		var dot := dir.dot(Vector3.FORWARD)

		if dot > best_dot:
			best_dot = dot
			best = dir.normalized()

	return best.y


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
