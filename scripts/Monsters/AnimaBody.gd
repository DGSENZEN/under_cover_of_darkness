extends Node3D
## What a ravenous ánima looks like, and how it moves. The hands are a real model, walking
## on their fingertips: each finger reaches for its place on the floor (a two-joint
## solve), stance and swing in turn, so they plant and don't slide; the palm arched up,
## the arm dragged behind. At rest they lie down on the palm, flexing. The face is a small
## dried skull (AnimaSkull.gd) floating behind two great hands: hung and slack at rest, its
## hands dangling; hauling itself through the air after you; drawn back and gaping in its
## tell, then hands and teeth thrown at you; biting on nothing when it misses. Its pose runs
## on springs, so each change overshoots and settles. On you, it is on your face instead
## (LeechFace.gd). The torso is a stand-in shape until its model is made and approved (the
## plan's Task 12).

const Fx := preload("res://scripts/Visual/Fx.gd")
const FleshShader := preload("res://scripts/Monsters/anima_flesh.gdshader")
const BRUSH := preload("res://textures/painted/eclipse/brush.png")
const HANDS_MODEL := "res://assets/monsters/anima_hands.glb"
const LEFT_MODEL := "res://assets/monsters/anima_hands_left.glb"
const AnimaSkullScript := preload("res://scripts/Monsters/AnimaSkull.gd")
const AnimaFire := preload("res://scripts/Monsters/AnimaFire.gd")

const FINGER_NAMES := ["index", "middle", "ring", "pinky", "thumb"]
## Each finger's place in the walk (of a whole cycle): opposite fingers together.
const PHASES := [0.0, 0.5, 0.05, 0.55, 0.3]
## How far ahead of its knuckle each sets down (m), and how far out to the side.
const REACH := [0.2, 0.23, 0.2, 0.15, 0.04]
const SPLAY := [0.08, 0.01, 0.07, 0.17, 0.34]
## The share of a cycle a finger is off the floor, how high it lifts, how long a step
## is (m) at a run, and how many steps a metre.
const SWING := 0.32
const LIFT := 0.1
const STEP := 0.22
## The palm: how high it stands off the floor, how the hand is tipped (radians: wrist
## up), and how far it rears in a tell.
const MOST_STEPS := 3.4
const PALM_HIGH := 0.34
const TIP := 0.16
const REAR := 0.26
## How it holds its arm, against the hand's tip: out behind it, then down to the floor.
const ARM_OUT := -0.62
const ARM_DOWN := -0.42
## Fire at the end of the arm, nearly out.
## The hands, down on the palm at rest: how high it lies; thrown down by a miss, for how long.
const REST_HIGH := 0.13
const SLAM_FOR := 0.34
## The face's hands: how big, against the walking hands.
const FACE_HAND_SIZE := 0.86
## How its fingers open and spread, against what they rest at.
const FACE_FAN := 0.13
## Its poses. nod: + chin up. lift, back: of the head (+ back is away from you). jaw: 0..1.
## hand: where the wrists are (x out to the side, y up, z ahead is -). pitch: of the hands (-
## fingers down, + palm up at you). shut: of the fingers. fan: of their spread. snap: how
## quickly it gets there, in cycles a second.
const POSES := {
	&"rest": {"nod": -0.62, "lift": -0.2, "back": 0.03, "jaw": 0.3, "hand": Vector3(0.2, -0.5, -0.03), "pitch": -1.25, "shut": 0.56, "fan": 0.5, "snap": 1.6},
	&"wake": {"nod": 0.26, "lift": 0.07, "back": 0.1, "jaw": 0.95, "hand": Vector3(0.38, 0.1, -0.2), "pitch": 0.5, "shut": 0.08, "fan": 1.6, "snap": 7.0},
	&"rise": {"nod": -0.5, "lift": -0.3, "back": 0.06, "jaw": 0.55, "hand": Vector3(0.32, 0.16, -0.22), "pitch": 0.1, "shut": 0.2, "fan": 1.3, "snap": 3.0},
	&"rush": {"nod": -0.2, "lift": 0.0, "back": 0.0, "jaw": 0.36, "hand": Vector3(0.3, -0.12, -0.34), "pitch": -0.2, "shut": 0.5, "fan": 1.0, "snap": 4.0},
	&"circle": {"nod": -0.04, "lift": 0.03, "back": 0.02, "jaw": 0.3, "hand": Vector3(0.32, -0.22, -0.24), "pitch": -0.35, "shut": 0.62, "fan": 1.0, "snap": 3.0},
	&"tell": {"nod": 0.24, "lift": 0.1, "back": 0.15, "jaw": 1.0, "hand": Vector3(0.47, 0.27, -0.14), "pitch": 1.0, "shut": 0.0, "fan": 1.9, "snap": 6.0},
	&"leap": {"nod": -0.28, "lift": -0.02, "back": -0.2, "jaw": 1.0, "hand": Vector3(0.2, -0.02, -0.74), "pitch": -0.08, "shut": 0.26, "fan": 1.2, "snap": 9.0},
	&"missed": {"nod": -0.52, "lift": -0.12, "back": -0.06, "jaw": 0.0, "hand": Vector3(0.3, -0.36, -0.42), "pitch": -0.75, "shut": 1.05, "fan": 0.6, "snap": 11.0},
	&"thrown": {"nod": 0.7, "lift": 0.05, "back": 0.16, "jaw": 0.7, "hand": Vector3(0.48, 0.14, 0.18), "pitch": 0.9, "shut": 0.2, "fan": 1.6, "snap": 7.0},
	&"on": {"nod": 0.0, "lift": 0.0, "back": 0.0, "jaw": 0.6, "hand": Vector3(0.3, 0.0, -0.3), "pitch": 0.0, "shut": 0.5, "fan": 1.0, "snap": 5.0},
}
## Hauling itself along: how far each hand reaches and pulls, up and over; how fast.
const PAW_REACH := 0.13
const PAW_LIFT := 0.06
const PAW_RATE := 1.0
## At rest: how long between its starts, and what one does to its head.
const TIC_EVERY := Vector2(1.4, 3.8)
const TIC_KICK := 1.5
## Where its arms grow from, on the skull: behind the jaw, each side (m). How long they are, a
## length to each bone, as the model is cut.
const SHOULDER := Vector3(0.078, -0.07, 0.05)
const ARM_BONE := 0.42
## The way its elbows go, each side, out and up.
const ELBOW_OUT := Vector3(0.75, 0.55, 0.3)
## How long a miss's bite lasts before it opens again and looks for you.
const BITE_HOLDS := 0.28
const LOOKS_ABOUT := 0.34
const FIRE_CORE := Color("#8E9C3C")
const FIRE_BODY := Color("#3E4624")
const FIRE_EDGE := Color("#16160E")

var form: StringName = &"hands"
## How much it has drunk, shown, 0..1.
var fed_shown := 0.0
var hurt := 0.0
## Resin burning on it while it is smoked, 0..1.
var smoulder := 0.0

var _parts := {}
var _skeleton: Skeleton3D
var _clock := 0.0
var _walk := 0.0
var _rear := 0.0
var _floor_y := -0.25
## How far over on its back it is, thrown off, 0..1.
var _flip := 0.0
var _ember_flare := 0.0
var _left_hand: Skeleton3D
var _right_hand: Skeleton3D
var _rig: Node3D
var _doing: StringName = &""
var _doing_for := 0.0
var _springs := {}
var _rest := 0.0
var _tic_in := 1.0
var _nod := 0.0
var _back := 0.0
var _embers: Array[MeshInstance3D] = []
var _face_hands: Array[MeshInstance3D] = []
var _face_roots: Array[Node3D] = []
var _bones := {}
var _tips: Array[Vector3] = []
var _look: StandardMaterial3D
var _flesh: ShaderMaterial
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_clock = _rng.randf() * 10.0

	if form == &"hands":
		_build_hands()
	elif form == &"face":
		_build_face()
	else:
		_build_stand_in()


func part(id: StringName) -> MeshInstance3D:
	return _parts.get(id)


func skeleton() -> Skeleton3D:
	return _skeleton


## The face's hand on that side (-1 its left, 1 its right).
func hand_on(side: float) -> Skeleton3D:
	return _left_hand if side < 0.0 else _right_hand


## How far its jaw has dropped, 0..1.
func jaw_open() -> float:
	return _rig.jaw_open() if _rig != null else 0.0


## The face: how far its chin is up, in radians (- it hangs).
func head_nod() -> float:
	return _nod


## The face: how far back its head is drawn, in metres (- it is thrown at you).
func head_back() -> float:
	return _back


## The face: how high its hands are.
func hands_up() -> float:
	return (_face_roots[0].position.y + _face_roots[1].position.y) * 0.5


## The face: how far ahead its hands are.
func hands_ahead() -> float:
	return -(_face_roots[0].position.z + _face_roots[1].position.z) * 0.5


## The face: how far the end of its arm on that side is from the base of its skull (m).
func arm_gap(side: float) -> float:
	var hand := hand_on(side)
	var end := hand.get_bone_global_pose(hand.find_bone("arm_2")) * Vector3(0.0, ARM_BONE, 0.0)
	return (hand.global_transform * end).distance_to(_rig.skull().global_transform * _shoulder(side))


func _shoulder(side: float) -> Vector3:
	return Vector3(SHOULDER.x * side, SHOULDER.y, SHOULDER.z)


## The face, as a piece (AnimaSkull.gd).
func skull_rig() -> Node3D:
	return _rig


func _build_hands() -> void:
	var made: Node3D = (load(HANDS_MODEL) as PackedScene).instantiate()
	add_child(made)
	_skeleton = made.find_children("*", "Skeleton3D", true, false)[0]

	for mesh in made.find_children("*", "MeshInstance3D", true, false):
		_parts[StringName(mesh.name)] = mesh

	_flesh = ShaderMaterial.new()
	_flesh.shader = FleshShader
	_flesh.set_shader_parameter(&"stroke_sheet", BRUSH)
	_flesh.set_shader_parameter(&"wet", 0.0)
	_flesh.set_shader_parameter(&"fill", 0.46)
	_flesh.set_shader_parameter(&"rim", 0.34)
	part(&"Hand").set_surface_override_material(0, _flesh)
	_tips.resize(FINGER_NAMES.size())

	for i in FINGER_NAMES.size():
		var chain: Array[int] = []

		for k in range(1, 4):
			chain.append(_skeleton.find_bone("%s_%02d" % [FINGER_NAMES[i], k]))

		_bones[i] = chain

	_build_fire()
	_parts[&"Ember"] = AnimaFire.ember_on(part(&"Hand"), 0.01)


func _build_face() -> void:
	_flesh = _new_flesh()
	# Bone stays bone: not the red the painted fill gives things in the dark.
	_flesh.set_shader_parameter(&"fill_sky", Color(0.42, 0.42, 0.37))
	_flesh.set_shader_parameter(&"fill_ground", Color(0.42, 0.34, 0.26))
	_rig = AnimaSkullScript.new(_flesh)
	add_child(_rig)

	for id in [&"Skull", &"Jaw", &"Gullet", &"Tongue"]:
		_parts[id] = _rig.part(id)

	_right_hand = _face_hand(HANDS_MODEL, 1.0)
	_left_hand = _face_hand(LEFT_MODEL, -1.0)
	_parts[&"Ember"] = _embers[0]
	# What is left of its fire, trailing from the end of its gullet.
	var flame := MeshInstance3D.new()
	flame.mesh = MeshVfx.flame(0.3, 0.05, 8, 8)
	flame.material_override = MeshVfx.look(FIRE_CORE, FIRE_BODY, FIRE_EDGE, 0.7, 0.5, 1.1)
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flame.transform = Transform3D(Basis(Vector3.RIGHT, PI), Vector3(0.0, -0.25, 0.04))
	_rig.skull().add_child(flame)


func _new_flesh() -> ShaderMaterial:
	var flesh := ShaderMaterial.new()
	flesh.shader = FleshShader
	flesh.set_shader_parameter(&"stroke_sheet", BRUSH)
	flesh.set_shader_parameter(&"wet", 0.0)
	flesh.set_shader_parameter(&"fill", 0.46)
	flesh.set_shader_parameter(&"rim", 0.34)
	return flesh


func _face_hand(model: String, side: float) -> Skeleton3D:
	var hand: Node3D = (load(model) as PackedScene).instantiate()
	hand.name = "HandRight" if side > 0.0 else "HandLeft"
	hand.scale = Vector3.ONE * FACE_HAND_SIZE
	add_child(hand)
	var mesh: MeshInstance3D = hand.find_children("*", "MeshInstance3D", true, false)[0]
	mesh.set_surface_override_material(0, _flesh)
	_face_hands.append(mesh)
	_face_roots.append(hand)
	_embers.append(AnimaFire.ember_on(mesh, 0.007))
	return hand.find_children("*", "Skeleton3D", true, false)[0]


## What is left of its fire, where its arm ends.
func _build_fire() -> void:
	var at := BoneAttachment3D.new()
	at.bone_name = "arm_2"
	_skeleton.add_child(at)
	var flame := MeshInstance3D.new()
	flame.mesh = MeshVfx.flame(0.3, 0.05, 8, 8)
	var look := MeshVfx.look(FIRE_CORE, FIRE_BODY, FIRE_EDGE, 0.7, 0.5, 1.1)
	flame.material_override = look
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flame.position = Vector3(0.0, float(_skeleton.get_bone_rest(_skeleton.find_bone("arm_2")).origin.length()), 0.0)
	at.add_child(flame)


func _build_stand_in() -> void:
	_look = StandardMaterial3D.new()
	_look.albedo_color = Color(0.13, 0.12, 0.1)
	_look.emission_enabled = true
	_look.emission = Color(0.38, 0.5, 0.08)
	_look.emission_energy_multiplier = 0.25

	match form:
		&"face":
			_piece(Vector3(0.34, 0.42, 0.26), Vector3.ZERO)
			for x in [-0.34, 0.34]:
				_piece(Vector3(0.1, 0.1, 0.6), Vector3(x, -0.1, -0.3))
		_:
			_piece(Vector3(0.5, 0.42, 0.56), Vector3(0.0, 0.15, 0.2))
			_piece(Vector3(0.26, 0.3, 0.26), Vector3(0.0, 0.4, -0.1))
			for x in [-0.42, 0.42]:
				_piece(Vector3(0.12, 0.12, 0.9), Vector3(x, 0.0, -0.45))


func _piece(size: Vector3, at: Vector3) -> void:
	var piece := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = _look
	piece.mesh = box
	piece.position = at
	add_child(piece)


## Each tick: what it is doing, whom at, how it moves, how much it has drunk (0..1).
func tick(delta: float, doing: StringName, you: Node3D, moving: Vector3, fed: float, exposed: bool, smoked: bool) -> void:
	_clock += delta

	if doing != _doing:
		_doing = doing
		_doing_for = 0.0

	_doing_for += delta
	fed_shown = fed
	hurt = move_toward(hurt, 0.0, delta / 0.25)
	smoulder = move_toward(smoulder, 1.0 if smoked else 0.0, delta * (6.0 if smoked else 3.0))
	var flat := Vector3(moving.x, 0.0, moving.z)

	if you != null and doing != &"rest" and (flat.length() < 0.2 or doing == &"tell" or doing == &"on"):
		var way := you.global_position - global_position
		way.y = 0.0

		if way.length() > 0.01:
			flat = way

	if flat.length() > 0.01 and doing != &"thrown":
		var wanted := Basis.looking_at(flat.normalized(), Vector3.UP)
		global_basis = global_basis.orthonormalized().slerp(wanted, 1.0 - exp(-12.0 * delta))

	if form == &"hands":
		_walk_hand(delta, doing, Vector3(moving.x, 0.0, moving.z).length(), fed, exposed)
		return

	if form == &"face":
		# On you, it is on your face: LeechFace.gd is what you see.
		visible = doing != &"on"
		_work_face(delta, doing, Vector3(moving.x, 0.0, moving.z).length(), fed)
		return

	position.y = 0.16 + sin(_clock * 40.0) * 0.015 if doing == &"tell" else 0.0
	_look.emission_energy_multiplier = 0.2 + fed * 0.5 + (0.3 if exposed else 0.0)
	_look.emission = Color(1.0, 0.5, 0.1) if smoked else Color(0.38, 0.5, 0.08)


## How far its fire is up, 0..1.
func ember_flare() -> float:
	return _ember_flare


## How far over on its back it is, 0..1.
func flipped() -> float:
	return _flip


func _walk_hand(delta: float, doing: StringName, speed: float, fed: float, exposed: bool) -> void:
	var part_hand := part(&"Hand")
	part_hand.set_instance_shader_parameter(&"fed", fed)
	part_hand.set_instance_shader_parameter(&"hurt", hurt)
	part_hand.set_instance_shader_parameter(&"smoulder", smoulder)
	# Its fire, up as it drinks and as it rears.
	_ember_flare = clampf(fed * 0.7 + _rear * 0.25, 0.0, 0.95)
	part(&"Ember").set_instance_shader_parameter(&"flare", _ember_flare)
	# A step per stride, faster the faster it goes, up to what can still be seen as
	# fingers; at rest, they still work.
	_walk += delta * minf(speed * (1.0 - SWING) / STEP + 0.35, MOST_STEPS)
	var rear_wanted := 1.0 if doing == &"tell" or doing == &"wake" else (0.6 if doing == &"leap" else 0.0)
	_rear = lerpf(_rear, rear_wanted, 1.0 - exp(-14.0 * delta))
	_rest = lerpf(_rest, 1.0 if doing == &"rest" else 0.0, 1.0 - exp(-(3.5 if doing == &"rest" else 12.0) * delta))
	# A miss throws it flat, and it gathers itself up again.
	var slam := 1.0 - smoothstep(SLAM_FOR * 0.6, SLAM_FOR, _doing_for) if doing == &"missed" else 0.0
	var low := maxf(_rest * (1.0 - sin(_clock * 1.3) * 0.08), slam)
	var hand_at := Vector3(0.0, lerpf(PALM_HIGH + _rear * REAR + sin(_walk * TAU * 2.0) * 0.016, REST_HIGH, low) - 0.25, 0.22 - _rear * 0.1)
	# It never holds still: a palsy all the time, worse when it rears. Hungry.
	var shake := sin(_clock * 46.0) * 0.012 * rear_wanted + (sin(_clock * 23.0) * 0.012 + sin(_clock * 37.0) * 0.008) * (1.0 - _rest * 0.8)
	# Thrown, it goes over on its back, scrabbling at the air, and rights itself.
	_flip = move_toward(_flip, 1.0 if doing == &"thrown" else 0.0, delta * (6.0 if doing == &"thrown" else 3.2))
	hand_at.y -= smoothstep(0.0, 1.0, _flip) * 0.1
	# It rolls with each step, and drops its head into a surge.
	var surging := smoothstep(2.4, 4.5, speed)
	var roll := sin(_walk * TAU) * 0.1 + shake + smoothstep(0.0, 1.0, _flip) * PI
	var tilt := Basis(Vector3.RIGHT, (-TIP - _rear * 0.5 - surging * 0.16) * (1.0 - low * 0.9) + slam * 0.2) * Basis(Vector3.BACK, roll * (1.0 - _rest * 0.7))
	var hand_bone := _skeleton.find_bone("hand")
	var rest: Transform3D = _skeleton.get_bone_rest(hand_bone)
	_skeleton.set_bone_pose_position(hand_bone, hand_at)
	_skeleton.set_bone_pose_rotation(hand_bone, (tilt * rest.basis).get_rotation_quaternion())
	_skeleton.set_bone_pose_rotation(_skeleton.find_bone("arm_1"), _arm_turn("arm_1", ARM_OUT + sin(_clock * 2.3) * 0.05))
	_skeleton.set_bone_pose_rotation(_skeleton.find_bone("arm_2"), _arm_turn("arm_2", ARM_DOWN + sin(_clock * 3.1) * 0.08))
	var hand_pose := _skeleton.get_bone_global_pose(hand_bone)

	for i in FINGER_NAMES.size():
		var chain: Array[int] = _bones[i]
		var knuckle_rest: Transform3D = _skeleton.get_bone_rest(chain[0])
		var frame: Transform3D = hand_pose * knuckle_rest
		var target := _foot_for(i, knuckle_rest, hand_pose, doing)
		_tips[i] = target
		_reach_to(chain, frame, target)


## A value going after where it should be, with the weight to overshoot and settle.
func _spring(id: StringName, to: float, rate: float, damp: float, delta: float) -> float:
	if not _springs.has(id):
		_springs[id] = [to, 0.0]

	var state: Array = _springs[id]
	# (Past this, a step overshoots by more than it corrects, and it shakes itself apart.)
	var w := minf(TAU * rate, 0.8 / delta)
	state[1] += (w * w * (to - state[0]) - 2.0 * damp * w * state[1]) * delta
	state[0] += state[1] * delta
	return state[0]


## Gives a value a shove.
func _kick(id: StringName, by: float) -> void:
	if _springs.has(id):
		_springs[id][1] += by


## The face: it runs from pose to pose (POSES), with what each moment adds on top.
func _work_face(delta: float, doing: StringName, speed: float, fed: float) -> void:
	var pose: Dictionary = POSES.get(doing, POSES[&"rush"])
	var snap: float = pose["snap"]
	var surging := smoothstep(2.0, 3.8, speed) if doing == &"rush" else 0.0
	var nod_to: float = pose["nod"]
	var jaw_to: float = pose["jaw"]
	var back_to: float = pose["back"]
	var yaw_to := 0.0
	var roll_to := 0.0
	var hand_to: Vector3 = pose["hand"]
	var shut_to: float = pose["shut"]
	var jaw_rate := snap * 1.4
	_flip = move_toward(_flip, 1.0 if doing == &"thrown" else 0.0, delta * 5.0)

	match doing:
		&"rest":
			# Hung, swaying a little; and now and then something starts in it.
			nod_to += sin(_clock * 0.7) * 0.05
			yaw_to = sin(_clock * 0.43) * 0.16
			roll_to = sin(_clock * 0.31) * 0.14
			jaw_to += sin(_clock * 1.1) * 0.05
			_tic_in -= delta

			if _tic_in <= 0.0:
				_tic_in = _rng.randf_range(TIC_EVERY.x, TIC_EVERY.y)
				_kick(&"nod", TIC_KICK * _rng.randf_range(0.5, 1.0))
				_kick(&"yaw", TIC_KICK * _rng.randf_range(-1.0, 1.0))
				_kick(&"jaw", -TIC_KICK * 1.2)
		&"rush":
			# Hauling itself through the air: its head down into a surge, teeth going.
			nod_to -= surging * 0.16
			back_to -= surging * 0.08
			jaw_to += sin(_clock * 3.1) * 0.08 + surging * 0.3 + sin(_clock * 31.0) * 0.1 * surging
			roll_to = sin(_walk * TAU) * 0.09
			shut_to -= surging * 0.22
			hand_to.z -= surging * 0.14
		&"circle":
			# Waiting its turn, chewing on nothing, its eyes on you.
			jaw_to += abs(sin(_clock * 4.3)) * 0.2
			yaw_to = sin(_clock * 1.1) * 0.08
		&"tell":
			# It shakes harder the nearer it is to letting go.
			var build := minf(_doing_for / 0.6, 1.0)
			nod_to += sin(_clock * 37.0) * 0.022 * build
			yaw_to = sin(_clock * 29.0) * 0.024 * build
		&"missed":
			# The bite on nothing, and it opens, and looks for you.
			if _doing_for > BITE_HOLDS:
				jaw_to = 0.3 + sin(_clock * 14.0) * 0.12
				jaw_rate = 5.0

			if _doing_for > LOOKS_ABOUT:
				yaw_to = sin((_doing_for - LOOKS_ABOUT) * 7.0) * 0.42
				nod_to = -0.3

			jaw_rate = maxf(jaw_rate, 5.0)
		&"thrown":
			# Knocked loose: its jaw flapping.
			jaw_to = 0.5 + sin(_clock * 21.0) * 0.4
			roll_to = sin(_clock * 11.0) * 0.5 * (1.0 - minf(_doing_for / 1.2, 1.0))

	_walk += delta * (PAW_RATE + surging * 1.8)
	_nod = _spring(&"nod", nod_to, snap, 0.55, delta)
	_back = _spring(&"back", back_to, snap, 0.6, delta)
	var lift := _spring(&"lift", pose["lift"], snap, 0.55, delta)
	var yaw := _spring(&"yaw", yaw_to, snap, 0.5, delta)
	var roll := _spring(&"roll", roll_to, snap, 0.5, delta)
	var jaw := _spring(&"jaw", clampf(jaw_to, 0.0, 1.0), jaw_rate, 0.75, delta)
	_rig.open_to(clampf(jaw, 0.0, 1.0), clampf(0.2 + sin(_clock * 2.6) * 0.15 + (jaw_to - 0.3) * 0.5, 0.0, 1.0))
	var skull: Node3D = _rig.skull()
	skull.rotation = Vector3(_nod, yaw, roll)
	skull.position = Vector3(0.0, lift, _back)
	var flare := clampf(fed * 0.7 + _rear * 0.08, 0.0, 0.95)
	_ember_flare = flare
	_rig.throat_to(clampf(fed * 0.35, 0.0, 0.5))
	_rig.paint(fed, hurt, smoulder)

	for mesh in _face_hands:
		mesh.set_instance_shader_parameter(&"fed", fed)
		mesh.set_instance_shader_parameter(&"hurt", hurt)
		mesh.set_instance_shader_parameter(&"smoulder", smoulder)

	for ember in _embers:
		ember.set_instance_shader_parameter(&"flare", flare)

	for side in [-1.0, 1.0]:
		_work_hand(float(side), doing, pose, hand_to, shut_to, surging, snap, delta)


func _work_hand(side: float, doing: StringName, pose: Dictionary, hand_to: Vector3, shut_to: float, surging: float, snap: float, delta: float) -> void:
	# (The model's own root, which holds its size: the skeleton sits inside it.)
	var root: Node3D = _face_roots[0 if side > 0.0 else 1]
	var hand := hand_on(side)
	var seed := 0.0 if side > 0.0 else 2.3
	var id := "r" if side > 0.0 else "l"
	var at := Vector3(hand_to.x * side, hand_to.y, hand_to.z)
	var pawing := 1.0 if doing == &"rush" or doing == &"circle" else 0.0
	# Each reaches in turn, up and over, and pulls back and down, closing on the air.
	var paw := sin(_walk * TAU + (0.0 if side > 0.0 else PI))
	var over := cos(_walk * TAU + (0.0 if side > 0.0 else PI))
	at += Vector3(0.0, over * PAW_LIFT, -paw * PAW_REACH) * pawing
	# Limp at rest, they drift; awake, they tremble.
	var drift := 0.4 if doing == &"rest" else 1.0
	at += Vector3(sin(_clock * 3.1 * drift + seed) * 0.018, sin(_clock * 2.3 * drift + seed) * 0.022, sin(_clock * 4.3 * drift + seed) * 0.024)
	root.position = Vector3(_spring(StringName(id + "x"), at.x, snap, 0.6, delta), _spring(StringName(id + "y"), at.y, snap, 0.55, delta), _spring(StringName(id + "z"), at.z, snap, 0.55, delta))
	var pitch_to: float = float(pose["pitch"]) + paw * 0.28 * pawing
	var pitch := _spring(StringName(id + "p"), pitch_to, snap, 0.6, delta)
	# Palms down and thrust ahead; up and out, showing you the palm, as it rears. Thrown, flung back.
	var aim := Basis(Vector3.UP, side * -0.16) * Basis(Vector3.RIGHT, pitch) * Basis(Vector3.BACK, side * (0.3 + sin(_clock * 1.7 * drift + seed) * 0.07))
	root.basis = aim.scaled(Vector3.ONE * FACE_HAND_SIZE)
	_reach_shoulder(hand, side)
	var fan := _spring(StringName(id + "f"), float(pose["fan"]) * FACE_FAN, snap, 0.7, delta)
	var shut_base := _spring(StringName(id + "s"), shut_to + paw * 0.28 * pawing, snap * 1.3, 0.7, delta)
	var palsy_size := 0.05 if doing == &"rest" else (0.32 if doing == &"thrown" else 0.17)

	for f in FINGER_NAMES.size():
		var finger_seed := float(f) * 1.9 + seed
		var palsy := sin(_clock * 13.0 * drift + finger_seed) * 0.6 + sin(_clock * 21.3 * drift + finger_seed * 2.0) * 0.4
		var jerk := sin(floor(_clock * 6.0 * drift + finger_seed) * 12.9898) * 0.5
		var shut := shut_base + (palsy + jerk) * palsy_size
		var out_of_middle := (float(f) - 1.5) * fan if f < 4 else fan * 2.2

		for k in range(1, 4):
			var bone := hand.find_bone("%s_%02d" % [FINGER_NAMES[f], k])
			var rest: Basis = hand.get_bone_rest(bone).basis
			var turn := Basis(Vector3.RIGHT, -shut * [0.7, 1.0, 1.25][k - 1])

			if k == 1:
				turn = Basis(Vector3.BACK, -out_of_middle * side) * turn

			hand.set_bone_pose_rotation(bone, (rest * turn).get_rotation_quaternion())


## The arm, from the wrist back to the base of the skull: a two-joint solve, its elbow out and
## up. Past what it can reach, it strains straight at it.
func _reach_shoulder(hand: Skeleton3D, side: float) -> void:
	var arm_1 := hand.find_bone("arm_1")
	var arm_2 := hand.find_bone("arm_2")
	var hand_pose: Transform3D = hand.get_bone_global_pose(hand.find_bone("hand"))
	var from: Vector3 = hand_pose * hand.get_bone_rest(arm_1).origin
	var target: Vector3 = hand.global_transform.affine_inverse() * (_rig.skull().global_transform * _shoulder(side))
	var way := target - from
	var far := clampf(way.length(), 0.02, ARM_BONE * 1.99)
	var along := way.normalized()
	# The pole, in the wrist's space: the elbow's way, as the body has it.
	var pole: Vector3 = (hand.global_basis.inverse() * (global_basis * Vector3(ELBOW_OUT.x * side, ELBOW_OUT.y, ELBOW_OUT.z))).normalized()
	var out := (pole - along * pole.dot(along)).normalized()
	var height := sqrt(maxf(ARM_BONE * ARM_BONE - far * far * 0.25, 0.0))
	var elbow := from + along * far * 0.5 + out * height
	var first := _aim_bone(hand, arm_1, hand_pose.basis, (elbow - from).normalized())
	_aim_bone(hand, arm_2, first, (from + along * far - elbow).normalized())


## Turns a bone so it runs along `wanted`, in the skeleton's space, the least it can from how
## it rests. Returns where that leaves it.
func _aim_bone(hand: Skeleton3D, bone: int, parent: Basis, wanted: Vector3) -> Basis:
	var rest: Basis = parent * hand.get_bone_rest(bone).basis
	var turn := Quaternion(rest.y.normalized(), wanted)
	var aimed := Basis(turn) * rest
	hand.set_bone_pose_rotation(bone, (parent.inverse() * aimed).get_rotation_quaternion())
	return aimed


func _arm_turn(bone_name: String, angle: float) -> Quaternion:
	var rest: Basis = _skeleton.get_bone_rest(_skeleton.find_bone(bone_name)).basis
	return (rest * Basis(Vector3.RIGHT, angle)).get_rotation_quaternion()


## Where a finger's tip wants to be, in the skeleton's space: stance, going back along
## the floor under it; swing, up and over to the next place.
func _foot_for(i: int, knuckle_rest: Transform3D, hand_pose: Transform3D, doing: StringName) -> Vector3:
	var knuckle: Vector3 = hand_pose * knuckle_rest.origin
	var side := signf(knuckle.x) if absf(knuckle.x) > 0.001 else 0.0
	var home := Vector3(knuckle.x + side * SPLAY[i], _floor_y, knuckle.z - REACH[i])

	if doing == &"rest":
		# Lying on them, curled under it; a finger gathers in and taps now and then.
		var tap: float = fposmod(_clock * 0.31 + float(i) * 0.37, 1.0)
		var lifted := sin(tap / 0.14 * PI) * 0.05 if tap < 0.14 else 0.0
		return Vector3(knuckle.x + side * SPLAY[i] * 0.6, _floor_y + lifted, knuckle.z - REACH[i] * 0.72 + sin(_clock * 1.1 + float(i) * 1.7) * 0.022 + lifted * 0.5)

	if doing == &"tell" or doing == &"leap" or doing == &"on" or doing == &"wake":
		# Up, spread, and hooked at you.
		return Vector3(knuckle.x * 1.5 + side * SPLAY[i], knuckle.y + 0.02 + sin(_clock * 30.0 + float(i)) * 0.012, knuckle.z - REACH[i] * 1.25)

	if doing == &"thrown":
		return Vector3(knuckle.x * 1.3, knuckle.y - 0.08 + sin(_clock * 22.0 + float(i) * 1.7) * 0.05, knuckle.z - REACH[i] * 0.8)

	var phase: float = fposmod(_walk + float(PHASES[i]), 1.0)
	# No two steps alike: each sets down a little off from the last.
	var step_number: float = floor(_walk + float(PHASES[i])) + float(i) * 7.0
	home.x += sin(step_number * 12.9898) * 0.022
	home.z += sin(step_number * 78.233) * 0.03

	if phase < SWING:
		var u := phase / SWING
		home.z += lerpf(STEP * 0.5, -STEP * 0.5, u)
		home.y += sin(u * PI) * LIFT
	else:
		var u := (phase - SWING) / (1.0 - SWING)
		home.z += lerpf(-STEP * 0.5, STEP * 0.5, u)

	return home


## Bends a finger's three bones so its tip comes to `target`: a two-joint solve, its
## last bone following its middle one, the knuckle up, as a walking finger's is.
func _reach_to(chain: Array[int], frame: Transform3D, target: Vector3) -> void:
	var length_1: float = _skeleton.get_bone_rest(chain[1]).origin.length()
	var length_2: float = _skeleton.get_bone_rest(chain[2]).origin.length()
	var length_3 := length_2 * 0.82
	var lower := (length_2 + length_3) * 0.95
	var t: Vector3 = frame.affine_inverse() * target
	# In the bone's frame: +Y along it, +Z its back, +X what it bends about.
	var yaw := atan2(-t.x, t.y)
	var forward := Vector2(t.x, t.y).length()
	var reach := clampf(Vector2(forward, t.z).length(), 0.02, (length_1 + lower) * 0.995)
	var line := atan2(t.z, forward)
	var at_knuckle := acos(clampf((length_1 * length_1 + reach * reach - lower * lower) / (2.0 * length_1 * reach), -1.0, 1.0))
	var at_tip := acos(clampf((lower * lower + reach * reach - length_1 * length_1) / (2.0 * lower * reach), -1.0, 1.0))
	var bend := at_knuckle + at_tip
	var rest_1: Basis = _skeleton.get_bone_rest(chain[0]).basis
	_skeleton.set_bone_pose_rotation(chain[0], (rest_1 * Basis(Vector3.BACK, yaw) * Basis(Vector3.RIGHT, line + at_knuckle)).get_rotation_quaternion())
	var rest_2: Basis = _skeleton.get_bone_rest(chain[1]).basis
	_skeleton.set_bone_pose_rotation(chain[1], (rest_2 * Basis(Vector3.RIGHT, -bend * 0.62)).get_rotation_quaternion())
	var rest_3: Basis = _skeleton.get_bone_rest(chain[2]).basis
	_skeleton.set_bone_pose_rotation(chain[2], (rest_3 * Basis(Vector3.RIGHT, -bend * 0.38)).get_rotation_quaternion())


## How low its lowest fingertip is, above the floor it stands on.
func lowest_tip() -> float:
	var lowest := INF

	for i in FINGER_NAMES.size():
		var chain: Array[int] = _bones[i]
		var last := _skeleton.get_bone_global_pose(chain[2])
		var length := float(_skeleton.get_bone_rest(chain[2]).origin.length()) * 0.82
		lowest = minf(lowest, (last * Vector3(0.0, length, 0.0)).y)

	return lowest - _floor_y


## How high the palm stands off the floor.
func palm_height() -> float:
	return _skeleton.get_bone_global_pose(_skeleton.find_bone("hand")).origin.y - _floor_y


func struck(point: Vector3, direction: Vector3, result: StringName) -> void:
	hurt = 1.0 if result != &"resisted" else 0.25
	Fx.blood(self, point, -direction.normalized(), 0.2 if result == &"resisted" else 0.7)


func burst(_context: Node, _at: Vector3, _push: Vector3) -> void:
	visible = false
