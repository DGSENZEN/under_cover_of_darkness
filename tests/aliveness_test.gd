extends Node3D
## What makes a man look alive: the rig's upper-body layer and the small
## turns laid over the animation (Humanoid, Posture), his expression (gaze,
## posture by temperament, breathing, gestures: Expression), his pastimes
## (GuardPastimes), and the air about him (Atmosphere).
##
##   Godot --headless --fixed-fps 60 --quit-after 3000000 --path . res://tests/aliveness_test.tscn

const HumanoidScript := preload("res://scripts/Visual/Humanoid.gd")
const ExpressionScript := preload("res://scripts/Visual/Expression.gd")
const TalkScript := preload("res://scripts/AISystem/Talk/TalkScript.gd")
const TalkDirector := preload("res://scripts/AISystem/Talk/TalkDirector.gd")
const PLAYER := preload("res://Player.tscn")
const GUARD := preload("res://Guard.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const NavBakerScript := preload("res://scripts/AISystem/NavBaker.gd")
const SquadScript := preload("res://scripts/AISystem/Squad.gd")
const GarrisonScript := preload("res://scripts/AISystem/Garrison.gd")
const TemperamentScript := preload("res://scripts/AISystem/Temperament.gd")
const GuardScript := preload("res://scripts/AISystem/Guard.gd")
const GuardStationScript := preload("res://scripts/AISystem/GuardStation.gd")
const LightProbe := preload("res://scripts/StimuliSystem/LightProbe.gd")

const FIXTURES := """
== talk_pair
cast: A = any; B = any
cooldown: 0s
A: A good long first line, so there is time to look at him.
B: A good long second line, so there is time to look back.
A: A third.
B: A fourth.

== nodding
cast: A = any; B = any
cooldown: 0s
A: A first line, and the other nods at the end of it.
B [nods]: Aye.
"""

var results: Array[String] = []
var player: CharacterBody3D


func _ready() -> void:
	await _run()
	print("\n==== RESULTS ====")

	for r in results:
		print(r)

	get_tree().quit()


func _run() -> void:
	await _rig()
	await _yard()
	seed(2027)
	GuardScript.randomize_on = false
	await _expression()
	GuardScript.randomize_on = true


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


# ---------------------------------------------------------------------------
# Expression
# ---------------------------------------------------------------------------

func _expression() -> void:
	# A4 a listener's head turns to the man speaking
	await _fresh()
	_use(["talk_pair"])
	var seat: Node3D = GuardStationScript.new()
	seat.kind = &"sit"
	add_child(seat)
	seat.global_position = Vector3(0, 0, 0)
	seat.rotation.y = -PI * 0.5
	var sitter := _guard(Vector3(0, 0, 0.3), -PI * 0.5, &"steady", "", [seat])
	var stander := _guard(Vector3(-0.2, 0, -2.2), 0.0)
	var director: RefCounted = TalkDirector.of(self)
	await _until(func(): return director.speaking(stander), 1800)
	await _frames(20)
	var pose: Dictionary = await _posed_global(sitter, [&"Head"])
	var axis := _rest_forward_axis(sitter)
	var facing: Vector3 = ((pose[&"Head"] as Transform3D).basis * axis).normalized()
	var to_him: Vector3 = (stander.eye_position() - (pose[&"Head"] as Transform3D).origin).normalized()
	var flat_facing := Vector2(facing.x, facing.z).normalized()
	var flat_to := Vector2(to_him.x, to_him.z).normalized()
	var angle := rad_to_deg(acos(clampf(flat_facing.dot(flat_to), -1.0, 1.0)))
	_check("A4 a man sitting turns his head to the man speaking to him", director.speaking(stander) and angle < 35.0,
		"speaking %s, head %.0f deg off him, sitter doing %s" % [director.speaking(stander), angle, sitter.activity()])

	# A5 posture differs by temperament
	await _fresh()
	_use([])
	var craven := _guard(Vector3(10, 0, 0), 0.0, &"craven")
	var steady := _guard(Vector3(14, 0, 0), 0.0, &"steady")
	for g in [craven, steady]:
		g._life._talk_rest = 99.0
	await _frames(90)
	var bones := [&"Head", &"upperarm_l", &"upperarm_r", &"pelvis"]
	var pc: Dictionary = await _posed(craven._rig.man, bones)
	var ps: Dictionary = await _posed(steady._rig.man, bones)
	var hunch: float = (((pc[&"upperarm_l"] as Transform3D).origin.y + (pc[&"upperarm_r"] as Transform3D).origin.y) - ((ps[&"upperarm_l"] as Transform3D).origin.y + (ps[&"upperarm_r"] as Transform3D).origin.y)) * 0.5 \
		- ((pc[&"pelvis"] as Transform3D).origin.y - (ps[&"pelvis"] as Transform3D).origin.y)
	var bowed: float = _forward_y(ps[&"Head"]) - _forward_y(pc[&"Head"])
	_check("A5 a craven man stands hunched, shoulders up and head down; a steady one does not",
		hunch > 0.01 and bowed > 0.05, "shoulders %.3f m higher, head forward %.3f lower" % [hunch, bowed])

	# A6 two men of one kind do not move alike
	var v1 := ExpressionScript.variation(1, &"", &"steady")
	var v2 := ExpressionScript.variation(2, &"", &"steady")
	await _fresh()
	var w21 := _guard(Vector3(20, 0, 0), 0.0, &"steady", "", [], 21)
	var w22 := _guard(Vector3(24, 0, 0), 0.0, &"steady", "", [], 22)
	var speeds := absf(w21.patrol_speed - w22.patrol_speed) / maxf(w21.patrol_speed, 0.01)
	_check("A6 two men of one kind walk at their own pace and rhythm",
		v1["walk"] != v2["walk"] and speeds >= 0.005 and w21._rig.expression.traits["rhythm"] != w22._rig.expression.traits["rhythm"],
		"walk %.3f/%.3f, patrol %.3f/%.3f, rhythm %.3f/%.3f" % [v1["walk"], v2["walk"], w21.patrol_speed, w22.patrol_speed, w21._rig.expression.traits["rhythm"], w22._rig.expression.traits["rhythm"]])

	# A7 his breathing moves his chest, at his breath's pace
	await _fresh()
	var breather := _guard(Vector3(30, 0, 0), 0.0)
	breather._life._talk_rest = 99.0
	breather._voice.hold_heart(100.0)
	await _frames(30)
	var peaks := [0]
	var last := [0.0, 0.0]
	for f in 600:
		var b: float = float(breather._rig.man.posture.get("breath"))
		if last[1] < last[0] and last[0] > b and last[0] > 0.3:
			peaks[0] += 1
		last[1] = last[0]
		last[0] = b
		await get_tree().physics_frame
	var expected: float = breather._voice.breath_rate() * 10.0
	breather._voice.hold_heart(-1.0)
	_check("A7 his chest rises and falls with his breath", absf(float(peaks[0]) - expected) <= 1.5, "peaks %d in 10 s, expected %.1f" % [peaks[0], expected])

	# A8 speaking, his hands talk; his legs are his own
	await _fresh()
	_use(["talk_pair"])
	director = TalkDirector.of(self)
	var s1 := _guard(Vector3(40, 0, 0), -PI * 0.5)
	var s2 := _guard(Vector3(42.6, 0, 0), PI * 0.5)
	await _until(func(): return director.speaking(s1) or director.speaking(s2), 1800)
	await _frames(24)
	var talker: Node = s1 if director.speaking(s1) else s2
	_check("A8 a man speaking gestures with his upper body alone", talker._rig.man.upper_weight() > 0.3 and not talker._rig.man.is_acting(),
		"upper %.2f, whole-body action %s" % [talker._rig.man.upper_weight(), talker._rig.man.is_acting()])

	# A9 the captain's formal walk
	await _fresh()
	var captain := _guard(Vector3(50, 0, 0), 0.0, &"steady", "Mirelle")
	var space := captain._rig.man._root.get_node(&"relaxed") as AnimationNodeBlendSpace1D
	_check("A9 the captain walks her formal walk", (space.get_blend_point_node(1) as AnimationNodeAnimation).animation == &"Walk_Formal",
		"walk %s" % (space.get_blend_point_node(1) as AnimationNodeAnimation).animation)

	# A10 a nod, and a listener who nods at the end of a line
	await _fresh()
	var nodder := _guard(Vector3(60, 0, 0), 0.0)
	nodder._life._talk_rest = 99.0
	nodder.emote("nods")
	await _frames(6)
	var clip: StringName = (nodder._rig.man._root.get_node(&"upper_clip") as AnimationNodeAnimation).animation
	await _frames(84)
	var gone: bool = nodder._rig.man.upper_weight() < 0.05
	_use(["nodding"])
	director = TalkDirector.of(self)
	var n1 := _guard(Vector3(64, 0, 0), -PI * 0.5)
	var n2 := _guard(Vector3(66.6, 0, 0), PI * 0.5)
	for g in [n1, n2]:
		g._life._talk_rest = 99.0
	director.play("nodding", {"A": n1, "B": n2})
	await _until(func(): return director.speaking(n1), 600)
	await _until(func(): return not director.speaking(n1), 600)
	await _frames(6)
	var reacted: StringName = (n2._rig.man._root.get_node(&"upper_clip") as AnimationNodeAnimation).animation
	_check("A10 a nod plays on his upper body and passes; the man to answer nods as the line ends",
		clip == &"Yes" and gone and reacted == &"Yes" and n2._rig.man.upper_weight() > 0.2, "clip %s, gone %s, the listener %s (%.2f)" % [clip, gone, reacted, n2._rig.man.upper_weight()])


# ---------------------------------------------------------------------------
# The yard
# ---------------------------------------------------------------------------

func _yard() -> void:
	TemperamentScript.rolling = false
	Props.block(self, Vector3(60, -0.5, 0), Vector3(200, 1, 60))
	var baker := NavigationRegion3D.new()
	baker.set_script(NavBakerScript)
	add_child(baker)
	player = PLAYER.instantiate()
	add_child(player)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.debug_traversal = false
	player.invulnerable = true
	player.reload_on_death = false

	if player.has_node("LightGem"):
		player.get_node("LightGem").queue_free()

	player.debug_light_level = 0.0
	player.global_position = Vector3(60, 1.05, 28)
	await baker.baked
	await _frames(5)


func _use(ids: Array) -> void:
	var lib := TalkScript.parse(FIXTURES, "fixtures")
	lib["conversations"] = (lib["conversations"] as Array).filter(func(c): return ids.has(c["id"]))
	TalkDirector.of(self).use_library(lib)


func _guard(at: Vector3, yaw := 0.0, preset: StringName = &"steady", name := "", stations := [], look := -1) -> CharacterBody3D:
	var g: CharacterBody3D = GUARD.instantiate()
	g.temperament = preset
	g.debug_ai = false
	g.given_name = name

	if look >= 0:
		g.look_seed = look

	if not stations.is_empty():
		var paths: Array[NodePath] = []

		for station in stations:
			paths.append((station as Node).get_path())

		g.stations = paths

	g.position = at
	g.rotation.y = yaw
	add_child(g)
	g._attack_timer = 999.0
	g.attack_cooldown = 999.0
	g._life._talk_rest = 0.0
	return g


func _fresh() -> void:
	for g in get_tree().get_nodes_in_group(&"guards"):
		g.remove_from_group(&"guards")
		g.set_physics_process(false)
		g.queue_free()

	for group in [&"bodies", &"dropped_weapons", &"dropped_lights", &"stray_arrows", &"guard_stations"]:
		for thing in get_tree().get_nodes_in_group(group):
			thing.queue_free()

	SquadScript.clear_all()
	GarrisonScript.clear_all()
	await _frames(5)
	LightProbe.invalidate()


## A man's Head axis that points to his front when he stands at rest.
func _rest_forward_axis(guard: Node3D) -> Vector3:
	var man: Node3D = guard._rig.man
	var rest: Transform3D = man.skeleton.global_transform * man.skeleton.get_bone_global_rest(man.skeleton.find_bone(&"Head"))
	var front := -guard.global_basis.z
	var best := Vector3.ZERO
	var best_dot := -INF

	for axis in [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.FORWARD, Vector3.BACK]:
		var dot: float = (rest.basis * axis).normalized().dot(front)

		if dot > best_dot:
			best_dot = dot
			best = axis

	return best


## `bones` of a man (a guard's) in the world as posed this frame.
func _posed_global(guard: Node3D, bones: Array) -> Dictionary:
	var man: Node3D = guard._rig.man
	var got := {}
	man.skeleton.skeleton_updated.connect(func():
		for bone in bones:
			got[bone] = man.bone_global(bone), CONNECT_ONE_SHOT)

	while got.is_empty():
		await get_tree().process_frame

	return got


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _until(cond: Callable, max_frames: int) -> void:
	for i in max_frames:
		if cond.call():
			return

		await get_tree().physics_frame


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
