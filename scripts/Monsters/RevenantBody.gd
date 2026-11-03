extends Node3D
## How a revenant moves: presentation only. Sprung poses and solved limbs on its own rig: long heavy steps with its feet planted, its arms
## hanging past its knees until it wants you with them, its head always on you. `Revenant.gd` says what it is doing.

const MODEL := preload("res://assets/monsters/revenant.glb")
const RevenantLook := preload("res://scripts/Monsters/RevenantLook.gd")
const FLOOR_MASK := 1

## What it is doing, as sprung values. lean: forward (rad), twist: its trunk round (rad), drop: its hips down (m), head: nodded down (rad),
## jaw: open 0..1, shut: fingers closed (rad, on its rest), l/r: a wrist from where it hangs, along the body's own x, y, z (m),
## reach_l/r: 0 that, 1 at you. limp: its arms given up to the floor. snap: how quick it gets there. arms: how fast its wrists may go (m/s).
const POSES := {
	&"walk": {"lean": 0.0, "snap": 1.4, "arms": 5.0},
	&"surge_tell": {"lean": -0.14, "drop": 0.16, "twist": 0.1, "head": -0.1, "jaw": 0.7, "l": Vector3(-0.1, 0.1, 0.32), "r": Vector3(0.1, 0.1, 0.34), "shut": -0.3, "snap": 2.6, "arms": 4.0},
	&"surge": {"lean": 0.6, "drop": 0.2, "head": -0.36, "jaw": 0.9, "l": Vector3(-0.1, 0.2, 0.62), "r": Vector3(0.1, 0.25, 0.7), "shut": -0.3, "snap": 3.4, "arms": 8.0},
	&"swipe_wind": {"lean": -0.1, "twist": 0.62, "drop": 0.08, "head": -0.1, "jaw": 0.6, "r": Vector3(0.62, 1.0, 0.25), "shut": -0.5, "snap": 2.2, "arms": 4.5},
	&"swipe": {"lean": 0.4, "twist": -0.6, "drop": 0.14, "jaw": 0.85, "r": Vector3(-0.8, 0.55, -1.0), "shut": 0.15, "snap": 7.0, "arms": 13.0},
	&"rake_wind": {"lean": -0.3, "drop": 0.04, "head": -0.25, "jaw": 0.9, "l": Vector3(-0.42, 1.25, 0.1), "r": Vector3(0.42, 1.25, 0.1), "shut": -0.6, "snap": 1.7, "arms": 4.0},
	&"rake": {"lean": 0.72, "drop": 0.28, "head": -0.5, "jaw": 1.0, "l": Vector3(0.1, 0.1, -1.1), "r": Vector3(-0.1, 0.1, -1.1), "shut": 0.2, "snap": 6.0, "arms": 13.0},
	&"grasp_wind": {"lean": 0.16, "twist": 0.2, "drop": 0.1, "head": -0.2, "jaw": 0.35, "r": Vector3(0.2, 0.6, -0.15), "reach_r": 0.36, "shut": -0.75, "snap": 1.5, "arms": 3.4},
	&"grasp": {"lean": 0.58, "twist": -0.25, "drop": 0.16, "head": -0.34, "jaw": 1.0, "reach_r": 1.0, "shut": -0.3, "snap": 6.0, "arms": 13.0},
	&"hold": {"lean": 0.5, "drop": 0.2, "head": -0.34, "jaw": 1.0, "reach_r": 1.0, "reach_l": 0.85, "shut": 0.3, "snap": 5.0, "arms": 8.0},
	&"shove": {"lean": -0.05, "drop": 0.05, "jaw": 0.5, "l": Vector3(-0.1, 0.55, -0.85), "r": Vector3(0.1, 0.55, -0.9), "shut": -0.6, "snap": 5.0, "arms": 11.0},
	&"stagger": {"lean": -0.36, "twist": 0.26, "drop": 0.12, "head": 0.3, "jaw": 0.8, "l": Vector3(-0.3, 0.3, 0.3), "r": Vector3(0.36, 0.42, 0.25), "shut": -0.4, "snap": 3.2, "arms": 7.0},
	&"fall": {"lean": 1.05, "drop": 0.82, "head": -0.1, "jaw": 0.6, "limp": 1.0, "shut": 0.25, "snap": 1.5, "arms": 6.0},
	&"down": {"lean": 1.2, "drop": 0.92, "head": 0.0, "jaw": 0.3, "limp": 1.0, "shut": 0.3, "snap": 1.2, "arms": 3.0},
	&"rise": {"lean": 0.72, "drop": 0.5, "head": -0.4, "jaw": 0.8, "limp": 0.65, "shut": 0.05, "snap": 0.9, "arms": 2.4},
	&"dying_a": {"lean": 0.3, "drop": 0.55, "twist": 0.3, "head": -0.5, "jaw": 1.0, "reach_r": 0.9, "shut": -0.7, "snap": 1.1, "arms": 3.0},
	&"dying_b": {"lean": -0.5, "drop": 0.5, "head": -0.8, "jaw": 1.0, "l": Vector3(-0.3, 1.1, 0.0), "r": Vector3(0.3, 1.2, 0.0), "shut": -0.6, "snap": 1.3, "arms": 3.0},
	&"dying_c": {"lean": 1.15, "drop": 0.9, "twist": -0.3, "head": 0.1, "jaw": 0.8, "limp": 1.0, "shut": 0.4, "snap": 0.8, "arms": 2.5},
}
## How quick its trunk can go at its quickest; its stride: how far a foot lets the body get before it moves (m); how long a step takes at a walk and at its quickest (s); how high it lifts.
const TRUNK_SNAP := 1.7
const STRIDE := 0.55
const STRIDE_RUNS := 0.22
const STEP_TAKES := 0.62
const STEP_QUICKEST := 0.2
const STEP_LIFTS := 0.16
## How a walking body rides on its legs: the rise and roll with a step (m, rad), as felt: never read straight off a foot.
const STEP_HEAVES := 0.05
const STEP_ROLLS := 0.07
const HEAVE_EASES := 5.0
## Arms swing at the walk, off opposite legs (m).
const ARMS_SWING := 0.22
## How far past their length its arms may draw out, wanting you (m, at each joint).
const ARM_DRAWS := 0.42
## How fast a hand and an elbow come round (rad/s).
const HAND_TURNS := 6.0
const ELBOW_TURNS := 7.0
## How far its head turns to you, and how fast (rad, rad/s).
const HEAD_REACHES := 1.1
const HEAD_TURNS := 2.6
const JAW_OPENS := 0.6
## At the floor, what a hand keeps above it (m).
const HAND_FLOOR := 0.09
const SIDES := ["_l", "_r"]
const FINGERS := ["thumb", "finger_1", "finger_2", "finger_3", "finger_4"]

var _model: Node3D
var _bones: Skeleton3D
var _mesh: MeshInstance3D
var _rest := {}
var _parent := {}
var _now := {}
var _springs := {}
var _placed := false
## Per side.
var _foot_at: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _foot_from: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _foot_to: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _step_t: Array[float] = [-1.0, -1.0]
var _step_takes: Array[float] = [STEP_TAKES, STEP_TAKES]
var _foot_out: Array[float] = [0.0, 0.0]
var _ankle_up := 0.1
var _wrist: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _elbow_way: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _hand_way: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _stretch: Array[float] = [0.0, 0.0]
var _head_turn := Quaternion.IDENTITY
var _heave := 0.0
var _roll := 0.0
var _floor_y := 0.0
var _rng := RandomNumberGenerator.new()
var _stride_of: Array[float] = [1.0, 1.0]


func _ready() -> void:
	_model = MODEL.instantiate()
	add_child(_model)
	_mesh = RevenantLook.dress(_model)
	_bones = _model.find_children("*", "Skeleton3D", true, false)[0]

	for i in _bones.get_bone_count():
		var name_of := StringName(_bones.get_bone_name(i))
		_rest[name_of] = _bones.get_bone_global_rest(i)
		var up := _bones.get_bone_parent(i)
		_parent[name_of] = StringName(_bones.get_bone_name(up)) if up >= 0 else &""

	_ankle_up = (_rest[&"foot_l"] as Transform3D).origin.y

	for side in 2:
		_foot_out[side] = (_rest[StringName("foot" + SIDES[side])] as Transform3D).origin.x

	_rng.seed = hash(name) + 7
	_now = _rest.duplicate()


## Where it stands now becomes where its feet are: as it arrives, or comes back from being out of sight.
func come_back() -> void:
	_placed = true
	_floor_y = global_position.y

	for side in 2:
		_foot_at[side] = _world_of((_rest[StringName("foot" + SIDES[side])] as Transform3D).origin)
		_foot_at[side].y = _floor_y + _ankle_up
		_step_t[side] = -1.0
		_wrist[side] = _world_of((_rest[StringName("hand" + SIDES[side])] as Transform3D).origin)
		_elbow_way[side] = Vector3.ZERO
		_hand_way[side] = Vector3.ZERO


## The floor it stands on, as the brain finds it.
func lie_at(floor_y: float) -> void:
	_floor_y = floor_y


func wrist(side: int) -> Vector3:
	return _world_of(_now_at(&"hand", side))


func elbow(side: int) -> Vector3:
	return _world_of(_now_at(&"arm_2", side))


func foot(side: int) -> Vector3:
	return _foot_at[side]


func foot_planted(side: int) -> bool:
	return _step_t[side] < 0.0


func head_at() -> Vector3:
	return _world_of((_now[&"head"] as Transform3D).origin)


func arm_stretch(side: int) -> float:
	return _stretch[side]


## The hand that grasps: where it is.
func grasp_point() -> Vector3:
	return wrist(1)


func _now_at(stem: StringName, side: int) -> Vector3:
	return (_now[StringName(String(stem) + SIDES[side])] as Transform3D).origin


func _world_of(at: Vector3) -> Vector3:
	return _bones.global_transform * at


func _spring(id: StringName, to: float, rate: float, damp: float, delta: float) -> float:
	if not _springs.has(id):
		_springs[id] = [to, 0.0]

	var state: Array = _springs[id]
	var w := minf(TAU * rate, 0.8 / delta)
	state[1] += (w * w * (to - state[0]) - 2.0 * damp * w * state[1]) * delta
	state[0] += state[1] * delta
	return state[0]


## Each tick, after it has moved: what it is doing, how it is moving (m/s, world), where you are.
func tick(delta: float, doing: StringName, moving: Vector3, you_at: Vector3, burn: float, seared: float, eyes: float) -> void:
	if not _placed:
		come_back()

	var pose: Dictionary = POSES.get(doing, POSES[&"walk"])
	var snap: float = float(pose.get("snap", 2.0))
	# (Its arms can be quick. The mass of it never is: its head is on the end of a long lever.)
	var heavy := minf(snap, TRUNK_SNAP)
	var lean := _spring(&"lean", float(pose.get("lean", 0.0)), heavy, 0.85, delta)
	var twist := _spring(&"twist", float(pose.get("twist", 0.0)), heavy, 0.85, delta)
	var drop := _spring(&"drop", float(pose.get("drop", 0.0)), heavy, 0.9, delta)
	var nod := _spring(&"head", float(pose.get("head", 0.0)), snap, 0.8, delta)
	var jaw := _spring(&"jaw", float(pose.get("jaw", 0.12)), snap * 1.4, 0.8, delta)
	var shut := _spring(&"shut", float(pose.get("shut", 0.0)), snap * 1.6, 0.8, delta)
	var limp := _spring(&"limp", float(pose.get("limp", 0.0)), snap, 0.9, delta)
	var reach := [_spring(&"reach_l", float(pose.get("reach_l", 0.0)), snap, 0.85, delta), _spring(&"reach_r", float(pose.get("reach_r", 0.0)), snap, 0.85, delta)]
	var off_l := Vector3(_spring(&"lx", (pose.get("l", Vector3.ZERO) as Vector3).x, snap, 0.8, delta), _spring(&"ly", (pose.get("l", Vector3.ZERO) as Vector3).y, snap, 0.8, delta), _spring(&"lz", (pose.get("l", Vector3.ZERO) as Vector3).z, snap, 0.8, delta))
	var off_r := Vector3(_spring(&"rx", (pose.get("r", Vector3.ZERO) as Vector3).x, snap, 0.8, delta), _spring(&"ry", (pose.get("r", Vector3.ZERO) as Vector3).y, snap, 0.8, delta), _spring(&"rz", (pose.get("r", Vector3.ZERO) as Vector3).z, snap, 0.8, delta))
	var arms_fastest: float = float(pose.get("arms", 5.0))
	_walk_feet(delta, moving, limp, drop)
	_pose_trunk(delta, lean, twist, drop, nod, jaw, you_at)

	for side in 2:
		_pose_arm(delta, side, off_l if side == 0 else off_r, reach[side], limp, shut, you_at, arms_fastest, moving)
		_pose_leg(side)

	_mesh.set_instance_shader_parameter(&"burn", burn)
	_mesh.set_instance_shader_parameter(&"seared", seared)
	_mesh.set_instance_shader_parameter(&"eyes", eyes)
	_mesh.set_instance_shader_parameter(&"wrath", clampf(jaw, 0.0, 1.0) * 0.6)


func _walk_feet(delta: float, moving: Vector3, limp: float, drop: float) -> void:
	var speed := Vector2(moving.x, moving.z).length()
	var going := moving / maxf(speed, 0.01)
	going.y = 0.0
	var felt := 0.0
	var felt_roll := 0.0
	var out := global_basis.x

	for side in 2:
		if _step_t[side] >= 0.0:
			_step_t[side] += delta / _step_takes[side]
			var t := minf(_step_t[side], 1.0)
			var eased := t * t * (3.0 - 2.0 * t)
			_foot_at[side] = _foot_from[side].lerp(_foot_to[side], eased) + Vector3.UP * sin(t * PI) * STEP_LIFTS * (1.0 + speed * 0.12)
			felt = maxf(felt, sin(t * PI))
			felt_roll += sin(t * PI) * (-1.0 if side == 0 else 1.0)

			if t >= 1.0:
				_foot_at[side] = _foot_to[side]
				_step_t[side] = -1.0

	# (Down on its knees it doesn't step.)
	if drop < 0.45 and limp < 0.4:
		var other_stepping := [_step_t[1] >= 0.0, _step_t[0] >= 0.0]
		var wants := [_foot_wants(0, going, speed, out), _foot_wants(1, going, speed, out)]
		var off_by := [_foot_at[0].distance_to(wants[0]), _foot_at[1].distance_to(wants[1])]
		var first := 0 if off_by[0] >= off_by[1] else 1

		for order in 2:
			var side: int = first if order == 0 else 1 - first
			var far_enough := STRIDE * _stride_of[side] + speed * STRIDE_RUNS * 0.2

			# One at a time at a walk; running, it can't wait.
			if _step_t[side] < 0.0 and off_by[side] > far_enough and (not other_stepping[side] or speed > 3.0):
				_foot_from[side] = _foot_at[side]
				_foot_to[side] = _ground_under(wants[side])
				_step_t[side] = 0.0
				_step_takes[side] = lerpf(STEP_TAKES, STEP_QUICKEST, clampf(speed / 6.0, 0.0, 1.0)) * _rng.randf_range(0.9, 1.15)
				_stride_of[side] = _rng.randf_range(0.85, 1.2)
				other_stepping[1 - side] = true

	_heave = move_toward(_heave, felt, HEAVE_EASES * delta)
	_roll = move_toward(_roll, felt_roll, HEAVE_EASES * delta)


func _foot_wants(side: int, going: Vector3, speed: float, out: Vector3) -> Vector3:
	var ahead := going * (0.25 + speed * STRIDE_RUNS) * (1.0 if speed > 0.1 else 0.0)
	var at := global_position + out * _foot_out[side] + ahead
	at.y = _floor_y + _ankle_up
	return at


func _ground_under(at: Vector3) -> Vector3:
	if not is_inside_tree():
		return at

	var ray := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.9, at + Vector3.DOWN * 1.2, FLOOR_MASK)
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	return (hit["position"] as Vector3) + Vector3.UP * _ankle_up if not hit.is_empty() else at


## Everything from its hips to its head: bent over, twisted, sunk. Fills _now for those bones.
func _pose_trunk(delta: float, lean: float, twist: float, drop: float, nod: float, jaw: float, you_at: Vector3) -> void:
	_turn_bone(&"root", Quaternion.IDENTITY)
	var ride := Vector3(0.0, -drop + (_heave - 0.5) * STEP_HEAVES, 0.0)
	var over := Quaternion(Vector3.FORWARD, _roll * STEP_ROLLS)
	var hips_turn := over * Quaternion(Vector3.RIGHT, -lean * 0.35) * Quaternion(Vector3.UP, twist * 0.3)
	_turn_bone(&"hips", hips_turn, ride)
	var spine_turn := hips_turn * Quaternion(Vector3.RIGHT, -lean * 0.3) * Quaternion(Vector3.UP, twist * 0.35)
	_turn_bone(&"spine", spine_turn)
	var chest_turn := spine_turn * Quaternion(Vector3.RIGHT, -lean * 0.35) * Quaternion(Vector3.UP, twist * 0.35)
	_turn_bone(&"chest", chest_turn)
	var neck_turn := chest_turn * Quaternion(Vector3.RIGHT, lean * 0.3)
	_turn_bone(&"neck_1", neck_turn)
	_turn_bone(&"neck_2", neck_turn * Quaternion(Vector3.RIGHT, lean * 0.2))
	# Always on you, within what its neck lets it.
	var head_rest: Transform3D = _rest[&"head"]
	var flat_turn := neck_turn * Quaternion(Vector3.RIGHT, lean * 0.45 - nod)
	var head_at_now := (_now[&"neck_2"] as Transform3D) * ((_rest[&"neck_2"] as Transform3D).affine_inverse() * head_rest.origin)
	var to_you := _bones.global_transform.affine_inverse().basis * (you_at - _world_of(head_at_now))
	var looking: Vector3 = flat_turn * Vector3.FORWARD
	var turn := Quaternion.IDENTITY

	if to_you.length() > 0.2 and looking.angle_to(to_you) < 2.6:
		var angle := minf(looking.angle_to(to_you), HEAD_REACHES)
		var axis := looking.cross(to_you)

		if axis.length() > 0.001:
			turn = Quaternion(axis.normalized(), angle)

	_head_turn = _head_turn.slerp(turn, 1.0 - exp(-HEAD_TURNS * delta))
	_turn_bone(&"head", _head_turn * flat_turn)
	_turn_bone(&"eye_l", _head_turn * flat_turn)
	_turn_bone(&"eye_r", _head_turn * flat_turn)
	_set_local_turn(&"jaw", Quaternion(Vector3.RIGHT, jaw * JAW_OPENS))


## A bone by how far it has turned from its rest, in the skeleton's space; `moved`, how far its head has shifted from where its parent carries it.
func _turn_bone(bone: StringName, turned: Quaternion, moved := Vector3.ZERO) -> void:
	var rest: Transform3D = _rest[bone]
	var up: StringName = _parent[bone]
	var origin := rest.origin

	if up != &"":
		var up_rest: Transform3D = _rest[up]
		origin = (_now[up] as Transform3D) * (up_rest.affine_inverse() * rest.origin)

	var now := Transform3D(Basis(turned) * rest.basis, origin + moved)
	_now[bone] = now
	_apply(bone, now)


func _set_local_turn(bone: StringName, turned: Quaternion) -> void:
	var rest: Transform3D = _rest[bone]
	var up: StringName = _parent[bone]
	var up_rest: Transform3D = _rest[up]
	var origin: Vector3 = (_now[up] as Transform3D) * (up_rest.affine_inverse() * rest.origin)
	var up_turn: Basis = (_now[up] as Transform3D).basis * up_rest.basis.inverse()
	var now := Transform3D(up_turn * Basis(turned) * rest.basis, origin)
	_now[bone] = now
	_apply(bone, now)


func _apply(bone: StringName, now: Transform3D) -> void:
	var i := _bones.find_bone(bone)
	var up: StringName = _parent[bone]
	var local: Transform3D = (_now[up] as Transform3D).affine_inverse() * now if up != &"" else now
	_bones.set_bone_pose_position(i, local.origin)
	_bones.set_bone_pose_rotation(i, local.basis.get_rotation_quaternion())


## A bone laid along a way, from wherever its parent has left it, drawn out from it by `drawn`.
func _along(bone: StringName, way: Vector3, drawn := 0.0) -> void:
	var rest: Transform3D = _rest[bone]
	var up: StringName = _parent[bone]
	var up_rest: Transform3D = _rest[up]
	var origin: Vector3 = (_now[up] as Transform3D) * (up_rest.affine_inverse() * rest.origin)
	var rest_way: Vector3 = rest.basis.y.normalized()
	var turned := Quaternion(rest_way, way.normalized()) if rest_way.dot(way.normalized()) > -0.999 else Quaternion(Vector3.RIGHT, PI)
	var up_way: Vector3 = (_now[up] as Transform3D).basis.y.normalized()
	var now := Transform3D(Basis(turned) * rest.basis, origin + up_way * drawn)
	_now[bone] = now
	_apply(bone, now)


func _pose_arm(delta: float, side: int, off: Vector3, reach: float, limp: float, shut: float, you_at: Vector3, fastest: float, moving: Vector3) -> void:
	var tag: String = SIDES[side]
	var clavicle := StringName("clavicle" + tag)
	var arm_1 := StringName("arm_1" + tag)
	var arm_2 := StringName("arm_2" + tag)
	var hand := StringName("hand" + tag)
	var chest_turn: Basis = (_now[&"chest"] as Transform3D).basis * (_rest[&"chest"] as Transform3D).basis.inverse()
	_turn_bone(clavicle, chest_turn.get_rotation_quaternion())
	var into := _bones.global_transform.affine_inverse()
	var shoulder: Vector3 = (_now[clavicle] as Transform3D) * ((_rest[clavicle] as Transform3D).affine_inverse() * (_rest[arm_1] as Transform3D).origin)
	var rest_shoulder: Vector3 = (_rest[arm_1] as Transform3D).origin
	var rest_wrist: Vector3 = (_rest[hand] as Transform3D).origin
	# Where it hangs: off the shoulder as it stands now, with the pose's offset, and a swing off the other leg.
	var speed := Vector2(moving.x, moving.z).length()
	var swing := Vector3(0.0, 0.0, (1.0 if foot_planted(side) else -1.0) * ARMS_SWING * clampf(speed / 1.6, 0.0, 1.0))
	var wanted_local: Vector3 = shoulder + (rest_wrist - rest_shoulder) + off + swing
	var wanted: Vector3 = _bones.global_transform * wanted_local
	wanted = wanted.lerp(you_at + Vector3.DOWN * 0.25, clampf(reach, 0.0, 1.0))

	if limp > 0.01:
		# Given up to the floor: out ahead of it, wherever its shoulders have got to.
		var on_floor: Vector3 = _bones.global_transform * Vector3(rest_wrist.x * 1.1, 0.0, shoulder.z - 0.35)
		on_floor.y = _floor_y + HAND_FLOOR
		wanted = wanted.lerp(on_floor, limp)

	wanted.y = maxf(wanted.y, _floor_y + HAND_FLOOR)
	var going_to: Vector3 = _wrist[side].lerp(wanted, 1.0 - exp(-11.0 * delta))
	_wrist[side] = _wrist[side].move_toward(going_to, fastest * delta)
	var wrist_at: Vector3 = into * _wrist[side]
	var upper: float = (_rest[arm_2] as Transform3D).origin.distance_to(rest_shoulder)
	var lower: float = rest_wrist.distance_to((_rest[arm_2] as Transform3D).origin)
	var span := wrist_at - shoulder
	var far := span.length()
	var whole := upper + lower
	# Past its length it draws out at each joint: it wants you more than its bones allow.
	var drawn := clampf(far - whole * 0.97, 0.0, ARM_DRAWS * 2.0)
	_stretch[side] = 1.0 + drawn / whole
	var a := upper + drawn * 0.5
	var b := lower + drawn * 0.5
	far = minf(far, (a + b) * 0.995)
	var along := span.normalized() if span.length() > 0.001 else Vector3.DOWN
	# Elbow out, and back: it comes round to that, and never flips over the line of the arm.
	var out := Vector3.RIGHT * (-1.0 if side == 0 else 1.0)
	var pole := (out * 0.9 + Vector3.BACK * 0.6 + Vector3.UP * 0.2).normalized()
	pole -= along * pole.dot(along)

	if pole.length() < 0.2:
		pole = out - along * out.dot(along)

	pole = pole.normalized()
	var had: Vector3 = _elbow_way[side] - along * _elbow_way[side].dot(along)
	_elbow_way[side] = pole if had.length() < 0.05 else _come_round(had.normalized(), pole, ELBOW_TURNS * delta)
	var height := sqrt(maxf(a * a - pow((a * a - b * b + far * far) / (2.0 * far), 2.0), 0.0))
	var elbow_at: Vector3 = shoulder + along * ((a * a - b * b + far * far) / (2.0 * far)) + _elbow_way[side] * height
	_along(arm_1, elbow_at - shoulder)
	_along(arm_2, wrist_at - elbow_at, drawn * 0.5)
	# Its hand goes on from its forearm, drooping with it, or spread at you.
	var fore := (wrist_at - elbow_at).normalized()
	var pointing := fore.lerp(Vector3.DOWN, 0.4 * (1.0 - reach)).normalized()
	_hand_way[side] = pointing if _hand_way[side] == Vector3.ZERO else _come_round(_hand_way[side], pointing, HAND_TURNS * delta)
	_along(hand, _hand_way[side], drawn * 0.5)

	for finger in FINGERS:
		var curl := Quaternion(Vector3.RIGHT, shut * (0.6 if finger == "thumb" else 1.0))
		_set_local_turn(StringName(finger + tag), curl)
		_set_local_turn(StringName(finger + "_b" + tag), curl)


func _pose_leg(side: int) -> void:
	var tag: String = SIDES[side]
	var leg_1 := StringName("leg_1" + tag)
	var leg_2 := StringName("leg_2" + tag)
	var foot_bone := StringName("foot" + tag)
	var into := _bones.global_transform.affine_inverse()
	var hip: Vector3 = (_now[&"hips"] as Transform3D) * ((_rest[&"hips"] as Transform3D).affine_inverse() * (_rest[leg_1] as Transform3D).origin)
	var ankle: Vector3 = into * _foot_at[side]
	var upper: float = (_rest[leg_2] as Transform3D).origin.distance_to((_rest[leg_1] as Transform3D).origin)
	var lower: float = (_rest[foot_bone] as Transform3D).origin.distance_to((_rest[leg_2] as Transform3D).origin)
	var span := ankle - hip
	var far := minf(span.length(), (upper + lower) * 0.995)
	var along := span.normalized() if span.length() > 0.001 else Vector3.DOWN
	# Knees go forward and a little out.
	var pole := (Vector3.FORWARD + Vector3.RIGHT * (-0.25 if side == 0 else 0.25)).normalized()
	pole -= along * pole.dot(along)
	pole = pole.normalized() if pole.length() > 0.05 else Vector3.FORWARD
	var offset := (upper * upper - lower * lower + far * far) / (2.0 * far)
	var knee := hip + along * offset + pole * sqrt(maxf(upper * upper - offset * offset, 0.0))
	_along(leg_1, knee - hip)
	_along(leg_2, (hip + along * far) - knee)
	var foot_rest: Transform3D = _rest[foot_bone]
	var lifted := 0.0 if _step_t[side] < 0.0 else sin(minf(_step_t[side], 1.0) * PI) * 0.35
	var flat := Quaternion(Vector3.RIGHT, lifted)
	var up_now: Transform3D = _now[leg_2]
	var origin: Vector3 = up_now * ((_rest[leg_2] as Transform3D).affine_inverse() * foot_rest.origin)
	var now := Transform3D(Basis(flat) * foot_rest.basis, origin)
	_now[foot_bone] = now
	_apply(foot_bone, now)


func _come_round(from: Vector3, to: Vector3, most: float) -> Vector3:
	var angle := from.angle_to(to)

	if angle < 0.0005 or most >= angle:
		return to

	var axis := from.cross(to)

	if axis.length() < 0.001:
		axis = from.cross(Vector3.RIGHT if absf(from.x) < 0.9 else Vector3.UP)

	return from.rotated(axis.normalized(), most).normalized()
