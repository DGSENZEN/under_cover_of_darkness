extends SkeletonModifier3D
## Two-bone arm/leg IK and animation-derived finger curls layered over the current pose.
## Targets use the owning Humanoid's full-size space, facing -Z; zero limb weight preserves its animation.
## ViewArms drives this modifier for first-person arms.

## Where the elbow points, as a direction from the shoulder, and where the
## knee does, from the hip.
const ELBOW_HINT := [Vector3(-0.9, -1.0, 0.35), Vector3(0.9, -1.0, 0.35)]
const KNEE_HINT := Vector3(0.1, 0.4, -1.0)
## Bones: [clavicle, upper arm, forearm, hand] for the left and right.
const ARMS := [[&"clavicle_l", &"upperarm_l", &"lowerarm_l", &"hand_l"], [&"clavicle_r", &"upperarm_r", &"lowerarm_r", &"hand_r"]]
const LEG := [&"thigh_r", &"calf_r", &"foot_r"]
const FINGERS := [&"index", &"middle", &"ring", &"pinky", &"thumb"]
## Where each hand's closed pose comes from, left then right: [animation,
## seconds]. Fists all round (a pistol grip would leave a finger out).
const FIST_FROM := [[&"Idle", 0.3], [&"Sword_Idle", 0.3]]
## How far a shoulder may come forward to lend an arm reach, metres. Your
## own arms hold things further out than an arm is long (a sword is held out
## where you can see it), so the shoulder, which is behind and below the view,
## slides out to meet it.
const SHOULDER_GIVE := 0.45
## How straight an arm is when it reaches its furthest: a little bent.
const REACH := 0.88
## How much of a hand's roll the forearm takes (a forearm turns; a wrist
## hardly does): the rest stays in the wrist.
const FOREARM_ROLL := 0.7

## The person this belongs to.
var man: Node3D
## Per hand, left then right: where it goes (his space), how much it goes
## there (0 leaves the animation's), and how closed the fingers are.
var targets: Array[Transform3D] = [Transform3D.IDENTITY, Transform3D.IDENTITY]
var weights: Array[float] = [0.0, 0.0]
var curls: Array[float] = [0.0, 0.0]
## The right foot, for a kick.
var foot_target := Transform3D.IDENTITY
var foot_weight := 0.0
## Bones folded away to nothing (a head you are inside of).
var folded: Array[StringName] = []
## Only a hand that is reaching has its fingers closed by `curls`; the other
## keeps the animation's (a guard's own hand, holding what it holds).
var curl_only_reaching := false
## Where each elbow points (as ELBOW_HINT, which it starts as): a reach
## across the body wants the elbow out in front, not back.
var elbow_hints: Array[Vector3] = [ELBOW_HINT[0], ELBOW_HINT[1]]

## How far each wrist is bent off straight, degrees, and where each hand
## was put (world space), at the last solve. The skeleton's own pose is
## restored after drawing, so this is the only record of it.
var wrist_bend: Array[float] = [0.0, 0.0]
var solved_hands: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]

var _index := {}
## Finger bone -> [open rotation (rest), closed rotation].
var _fingers := {}


func _ready() -> void:
	_learn_fist()


## The closed hand, read once from an animation where the hands grip.
func _learn_fist() -> void:
	var skeleton := get_skeleton()

	if skeleton == null or man == null:
		return

	var library: AnimationLibrary = man.library()

	for side in range(2):
		var source: Array = FIST_FROM[side]

		if not library.has_animation(source[0]):
			continue

		var clip := library.get_animation(source[0])
		var tracks := {}

		for i in range(clip.get_track_count()):
			if clip.track_get_type(i) == Animation.TYPE_ROTATION_3D:
				var path := clip.track_get_path(i)

				if path.get_subname_count() > 0:
					tracks[StringName(path.get_subname(0))] = i

		for finger in FINGERS:
			for joint in ["01", "02", "03"]:
				var bone := StringName("%s_%s_%s" % [finger, joint, "l" if side == 0 else "r"])
				var index := skeleton.find_bone(bone)

				if index < 0 or not tracks.has(bone):
					continue

				var closed: Quaternion = clip.rotation_track_interpolate(tracks[bone], source[1])
				_fingers[bone] = [skeleton.get_bone_rest(index).basis.get_rotation_quaternion(), closed]


func _process_modification() -> void:
	var skeleton := get_skeleton()

	if skeleton == null or man == null:
		return

	if _fingers.is_empty():
		_learn_fist()

	for bone in folded:
		var index := _bone(skeleton, bone)

		if index >= 0:
			skeleton.set_bone_pose_scale(index, Vector3.ONE * 0.001)

	# His space to the skeleton's.
	var into := skeleton.global_transform.affine_inverse() * man.global_transform

	for side in range(2):
		if weights[side] > 0.001:
			_reach(skeleton, side, into)

		if weights[side] > 0.001 or not curl_only_reaching:
			_curl(skeleton, side)

	if foot_weight > 0.001:
		var knee := into.basis * KNEE_HINT
		_solve(skeleton, LEG[0], LEG[1], LEG[2], into * foot_target, foot_weight, knee, 0.0)


func _reach(skeleton: Skeleton3D, side: int, into: Transform3D) -> void:
	var bones: Array = ARMS[side]
	var target: Transform3D = into * targets[side]
	var hint: Vector3 = into.basis * elbow_hints[side]
	_solve(skeleton, bones[1], bones[2], bones[3], target, weights[side], hint, SHOULDER_GIVE, bones[0])
	var forearm := skeleton.get_bone_global_pose(_bone(skeleton, bones[2])).basis.y.normalized()
	var hand_pose := skeleton.get_bone_global_pose(_bone(skeleton, bones[3]))
	wrist_bend[side] = rad_to_deg(forearm.angle_to(hand_pose.basis.y.normalized()))
	solved_hands[side] = skeleton.global_transform * hand_pose.origin


## Two-bone IK: `root` and `mid` bend so the end of `mid` (the `tip` bone's
## joint) comes to `target`, bending toward `hint`; then `tip` takes the
## target's turn. Out of reach, the limb straightens, and a clavicle, if
## given, brings the root forward by up to `give`.
func _solve(skeleton: Skeleton3D, root_name: StringName, mid_name: StringName, tip_name: StringName,
		target: Transform3D, weight: float, hint: Vector3, give: float, base_name: StringName = &"") -> void:
	var root := _bone(skeleton, root_name)
	var mid := _bone(skeleton, mid_name)
	var tip := _bone(skeleton, tip_name)

	if root < 0 or mid < 0 or tip < 0:
		return

	var start := skeleton.get_bone_global_pose(tip)
	var goal := start.origin.lerp(target.origin, weight)
	var a := skeleton.get_bone_global_pose(root).origin.distance_to(skeleton.get_bone_global_pose(mid).origin)
	var b := skeleton.get_bone_global_pose(mid).origin.distance_to(start.origin)

	# A shoulder comes forward for a long reach.
	var base := _bone(skeleton, base_name) if base_name != &"" else -1

	if base >= 0 and give > 0.0:
		var shoulder := skeleton.get_bone_global_pose(root).origin
		var short := shoulder.distance_to(goal) - (a + b) * REACH

		if short > 0.0:
			var slide := (goal - shoulder).normalized() * minf(short, give) * weight
			var parent_basis := skeleton.get_bone_global_pose(base).basis
			skeleton.set_bone_pose_position(root, skeleton.get_bone_pose_position(root) + parent_basis.inverse() * slide)

	var s := skeleton.get_bone_global_pose(root).origin
	var e := skeleton.get_bone_global_pose(mid).origin
	var w := skeleton.get_bone_global_pose(tip).origin
	var to := goal - s
	var d := clampf(to.length(), absf(a - b) + 0.01, (a + b) * 0.999)
	var along := to.normalized() if to.length() > 0.0001 else (w - s).normalized()

	# The elbow's plane: the reach and the hint.
	var side := hint - along * hint.dot(along)

	if side.length() < 0.0001:
		side = (e - s) - along * (e - s).dot(along)

	side = side.normalized()
	var cos_a := clampf((a * a + d * d - b * b) / (2.0 * a * d), -1.0, 1.0)
	var elbow := s + along * (a * cos_a) + side * (a * sqrt(1.0 - cos_a * cos_a))
	_aim(skeleton, root, e - s, elbow - s)

	# The forearm, from where the elbow now is, to the goal.
	var e2 := skeleton.get_bone_global_pose(mid).origin
	var w2 := skeleton.get_bone_global_pose(tip).origin
	_aim(skeleton, mid, w2 - e2, (s + along * d) - e2)

	# The hand (or foot) turned as asked. Its roll about the forearm is
	# mostly the forearm's: turned first, so the wrist does not wring.
	var now := skeleton.get_bone_global_pose(tip)
	var turn := Basis(now.basis.get_rotation_quaternion().slerp(target.basis.get_rotation_quaternion(), weight))

	if give > 0.0:
		var forearm := skeleton.get_bone_global_pose(mid).basis.orthonormalized()
		var local := (forearm.inverse() * turn).get_rotation_quaternion()
		var rest := skeleton.get_bone_rest(tip).basis.get_rotation_quaternion()
		var delta := rest.inverse() * local
		var roll := wrapf(2.0 * atan2(delta.y, delta.w), -PI, PI)
		_set_global_rotation(skeleton, mid, forearm * Basis(Vector3.UP, roll * FOREARM_ROLL))

	_set_global_rotation(skeleton, tip, turn)


## Turns `bone` so the direction `from` (skeleton space) becomes `to`.
func _aim(skeleton: Skeleton3D, bone: int, from: Vector3, to: Vector3) -> void:
	if from.length() < 0.00001 or to.length() < 0.00001:
		return

	var arc := Quaternion(from.normalized(), to.normalized())
	var global := skeleton.get_bone_global_pose(bone)
	_set_global_rotation(skeleton, bone, Basis(arc) * global.basis.orthonormalized())


func _set_global_rotation(skeleton: Skeleton3D, bone: int, basis: Basis) -> void:
	var parent := skeleton.get_bone_parent(bone)
	var parent_basis := skeleton.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis.IDENTITY
	skeleton.set_bone_pose_rotation(bone, (parent_basis.inverse() * basis.orthonormalized()).get_rotation_quaternion())


func _curl(skeleton: Skeleton3D, side: int) -> void:
	var suffix := "l" if side == 0 else "r"
	var amount := clampf(curls[side], 0.0, 1.0)

	for finger in FINGERS:
		for joint in ["01", "02", "03"]:
			var bone := StringName("%s_%s_%s" % [finger, joint, suffix])

			if not _fingers.has(bone):
				continue

			var index := _bone(skeleton, bone)
			var poses: Array = _fingers[bone]
			skeleton.set_bone_pose_rotation(index, (poses[0] as Quaternion).slerp(poses[1], amount))


func _bone(skeleton: Skeleton3D, bone: StringName) -> int:
	if not _index.has(bone):
		_index[bone] = skeleton.find_bone(bone)

	return _index[bone]
