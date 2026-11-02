extends Node3D
## What a ravenous ánima looks like, and how it moves. The hands are a real model, walking
## on their fingertips: each finger reaches for its place on the floor (a two-joint
## solve), stance and swing in turn, so they plant and don't slide; the palm arched up,
## the arm dragged behind. The face and torso are stand-in shapes until their models
## are made and approved (the plan's Tasks 11 and 12).

const Fx := preload("res://scripts/Visual/Fx.gd")
const FleshShader := preload("res://scripts/Monsters/anima_flesh.gdshader")
const BRUSH := preload("res://textures/painted/eclipse/brush.png")
const HANDS_MODEL := "res://assets/monsters/anima_hands.glb"

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
	else:
		_build_stand_in()


func part(id: StringName) -> MeshInstance3D:
	return _parts.get(id)


func skeleton() -> Skeleton3D:
	return _skeleton


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
	fed_shown = fed
	hurt = move_toward(hurt, 0.0, delta / 0.25)
	smoulder = move_toward(smoulder, 1.0 if smoked else 0.0, delta * (6.0 if smoked else 3.0))
	var flat := Vector3(moving.x, 0.0, moving.z)

	if you != null and (flat.length() < 0.2 or doing == &"tell" or doing == &"on"):
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

	position.y = 0.16 + sin(_clock * 40.0) * 0.015 if doing == &"tell" else 0.0
	_look.emission_energy_multiplier = 0.2 + fed * 0.5 + (0.3 if exposed else 0.0)
	_look.emission = Color(1.0, 0.5, 0.1) if smoked else Color(0.38, 0.5, 0.08)


func _walk_hand(delta: float, doing: StringName, speed: float, fed: float, exposed: bool) -> void:
	var part_hand := part(&"Hand")
	part_hand.set_instance_shader_parameter(&"fed", fed)
	part_hand.set_instance_shader_parameter(&"hurt", hurt)
	part_hand.set_instance_shader_parameter(&"smoulder", smoulder)
	# A step per stride, faster the faster it goes, up to what can still be seen as
	# fingers; at rest, they still work.
	_walk += delta * minf(speed * (1.0 - SWING) / STEP + 0.35, MOST_STEPS)
	var rear_wanted := 1.0 if doing == &"tell" else (0.6 if doing == &"leap" else 0.0)
	_rear = lerpf(_rear, rear_wanted, 1.0 - exp(-14.0 * delta))
	var hand_at := Vector3(0.0, PALM_HIGH - 0.25 + _rear * REAR + sin(_walk * TAU * 2.0) * 0.016, 0.22 - _rear * 0.1)
	# It never holds still: a palsy all the time, worse when it rears. Hungry.
	var shake := sin(_clock * 46.0) * 0.012 * rear_wanted + sin(_clock * 23.0) * 0.012 + sin(_clock * 37.0) * 0.008
	var tilt := Basis(Vector3.RIGHT, -TIP - _rear * 0.5 + (0.4 if doing == &"thrown" else 0.0)) * Basis(Vector3.BACK, shake)
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


func _arm_turn(bone_name: String, angle: float) -> Quaternion:
	var rest: Basis = _skeleton.get_bone_rest(_skeleton.find_bone(bone_name)).basis
	return (rest * Basis(Vector3.RIGHT, angle)).get_rotation_quaternion()


## Where a finger's tip wants to be, in the skeleton's space: stance, going back along
## the floor under it; swing, up and over to the next place.
func _foot_for(i: int, knuckle_rest: Transform3D, hand_pose: Transform3D, doing: StringName) -> Vector3:
	var knuckle: Vector3 = hand_pose * knuckle_rest.origin
	var side := signf(knuckle.x) if absf(knuckle.x) > 0.001 else 0.0
	var home := Vector3(knuckle.x + side * SPLAY[i], _floor_y, knuckle.z - REACH[i])

	if doing == &"tell" or doing == &"leap" or doing == &"on":
		# Up, spread, and hooked at you.
		return Vector3(knuckle.x * 1.5 + side * SPLAY[i], knuckle.y + 0.02 + sin(_clock * 30.0 + float(i)) * 0.012, knuckle.z - REACH[i] * 1.25)

	if doing == &"thrown":
		return Vector3(knuckle.x * 1.3, knuckle.y - 0.08 + sin(_clock * 22.0 + float(i) * 1.7) * 0.05, knuckle.z - REACH[i] * 0.8)

	var phase := fposmod(_walk + PHASES[i], 1.0)

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
