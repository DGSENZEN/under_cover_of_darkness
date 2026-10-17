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
## Where each hand's closed pose comes from, as FIST_FROM (the Prosecutor's
## own arms have their own Fist: ViewArms).
var fist_from: Array = FIST_FROM
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
## Where the foot was put (world space), at the last solve of a kick.
var solved_foot := Vector3.ZERO
## Shoulder to wrist (m, his space): the elbow and wrist joints are pushed
## out along the bones to make the arms this long. 0 keeps the model's own.
## (The first-person arms are given a real arm's length: ViewArms.)
var arm_length := 0.0
## Per hand: held on the world (a climb), its target is brought in along the
## line from the eye until the arm reaches it bent: drawn about the eye, it
## shows in the same place, and the arm takes the body's weight instead of
## stretching to the hold (HandSlot sets this).
var pull_to_eye: Array[bool] = [false, false]
## The eye, in his space (ViewArms.EYE).
var eye := Vector3(0.0, 1.62, 0.1)
## The eye in the skeleton's space, this solve (it and the goals must share one).
var _eye_in_skeleton := Vector3.ZERO
## Both held hands are brought in by the same share of their eye lines, so a
## single depth (the arms share their materials) puts both back where they
## hold: -1 when not both are held.
var _shared_t := -1.0
## How bent a held arm stays: this share of its full length.
const HELD_REACH := 0.93

## Per hand, from the last solve: how far its shoulder came forward to reach
## (metres, his space), and whether the arm ran out of length (straight).
var shoulder_slides: Array[float] = [0.0, 0.0]
var straight: Array[bool] = [false, false]
## Per hand, the arm's length (shoulder to wrist) the last solve used.
var solved_lengths: Array[float] = [0.0, 0.0]

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
		var source: Array = fist_from[side]

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

	if arm_length > 0.0:
		_lengthen_arms(skeleton)

	# His space to the skeleton's.
	var into := skeleton.global_transform.affine_inverse() * man.global_transform
	_eye_in_skeleton = into * eye
	_shared_t = _shared_trim(skeleton, into)

	for side in range(2):
		if weights[side] > 0.001:
			_reach(skeleton, side, into)

		if weights[side] > 0.001 or not curl_only_reaching:
			_curl(skeleton, side)

	if foot_weight > 0.001:
		var knee := into.basis * KNEE_HINT
		_solve(skeleton, LEG[0], LEG[1], LEG[2], into * foot_target, foot_weight, knee, 0.0)
		var foot := _bone(skeleton, LEG[2])

		if foot >= 0:
			solved_foot = skeleton.global_transform * skeleton.get_bone_global_pose(foot).origin


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
	var arm := 0 if root_name == ARMS[0][1] else (1 if root_name == ARMS[1][1] else -1)

	if arm >= 0:
		shoulder_slides[arm] = 0.0

	if arm >= 0 and pull_to_eye[arm]:
		if _shared_t > 0.0:
			goal = _eye_in_skeleton + (goal - _eye_in_skeleton) * _shared_t
		else:
			goal = _toward_eye(skeleton.get_bone_global_pose(root).origin, goal, (a + b) * HELD_REACH)

	if base >= 0 and give > 0.0:
		var shoulder := skeleton.get_bone_global_pose(root).origin
		var short := shoulder.distance_to(goal) - (a + b) * REACH

		if short > 0.0:
			var slide := (goal - shoulder).normalized() * minf(short, give) * weight
			if arm >= 0:
				shoulder_slides[arm] = minf(short, give) * weight
			var parent_basis := skeleton.get_bone_global_pose(base).basis
			skeleton.set_bone_pose_position(root, skeleton.get_bone_pose_position(root) + parent_basis.inverse() * slide)

	var s := skeleton.get_bone_global_pose(root).origin
	var e := skeleton.get_bone_global_pose(mid).origin
	var w := skeleton.get_bone_global_pose(tip).origin
	var to := goal - s
	var d := clampf(to.length(), absf(a - b) + 0.01, (a + b) * 0.999)

	if arm >= 0:
		straight[arm] = to.length() >= (a + b) * 0.999
		solved_lengths[arm] = a + b
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


## With both hands held: the share of the eye line (0..1) that brings both
## within reach, the smaller of the two. -1 otherwise.
func _shared_trim(skeleton: Skeleton3D, into: Transform3D) -> float:
	if not (pull_to_eye[0] and pull_to_eye[1] and weights[0] > 0.001 and weights[1] > 0.001):
		return -1.0

	var shared := 1.0

	for side in range(2):
		var bones: Array = ARMS[side]
		var root := _bone(skeleton, bones[1])
		var mid := _bone(skeleton, bones[2])
		var tip := _bone(skeleton, bones[3])

		if root < 0 or mid < 0 or tip < 0:
			return -1.0

		var shoulder := skeleton.get_bone_global_pose(root).origin
		var a := shoulder.distance_to(skeleton.get_bone_global_pose(mid).origin)
		var b := skeleton.get_bone_global_pose(mid).origin.distance_to(skeleton.get_bone_global_pose(tip).origin)
		var goal: Vector3 = skeleton.get_bone_global_pose(tip).origin.lerp((into * targets[side]).origin, weights[side])
		var trimmed := _toward_eye(shoulder, goal, (a + b) * HELD_REACH)
		var line := goal - _eye_in_skeleton

		if line.length() > 0.0001:
			shared = minf(shared, (trimmed - _eye_in_skeleton).length() / line.length())

	return shared


## The point on the line from the eye to `goal`, as far out as it goes, no
## further than `length` from `shoulder`: `goal` itself if already in reach.
func _toward_eye(shoulder: Vector3, goal: Vector3, length: float) -> Vector3:
	if shoulder.distance_to(goal) <= length:
		return goal

	var from := _eye_in_skeleton
	var d := goal - from
	var o := from - shoulder
	var qa := d.dot(d)
	var qb := 2.0 * d.dot(o)
	var qc := o.dot(o) - length * length
	var disc := qb * qb - 4.0 * qa * qc

	if qa < 0.000001:
		return goal

	# The eye line never comes within reach: its point nearest the shoulder,
	# still drawn where the hold is, the arm as near it as it gets.
	if disc < 0.0:
		return from + d * clampf(-qb / (2.0 * qa), 0.0, 1.0)

	var t := (-qb + sqrt(disc)) / (2.0 * qa)
	return from + d * clampf(t, 0.0, 1.0) if t > 0.0 else goal


## The elbow and wrist joints moved out along their bones (their rest offsets,
## scaled) so shoulder to wrist is arm_length: longer, not thicker.
func _lengthen_arms(skeleton: Skeleton3D) -> void:
	for side in range(2):
		var mid := _bone(skeleton, ARMS[side][2])
		var tip := _bone(skeleton, ARMS[side][3])

		if mid < 0 or tip < 0:
			continue

		var upper := skeleton.get_bone_rest(mid).origin
		var fore := skeleton.get_bone_rest(tip).origin
		var own := upper.length() + fore.length()

		if own < 0.0001:
			continue

		var stretch := arm_length / own
		skeleton.set_bone_pose_position(mid, upper * stretch)
		skeleton.set_bone_pose_position(tip, fore * stretch)


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
