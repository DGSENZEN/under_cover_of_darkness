extends SkeletonModifier3D
## Small changes laid over the animation after it plays: the head turned
## where the eyes look, the hips turned the way the feet go while the chest
## stays on the enemy, a leg raised and driven out for a kick (the library
## has none), and his expression (a bowed head, hunched shoulders, the chest
## breathing, his weight shifting, a limp). Every turn is about the man's own axes (his right, his
## up), whatever way his bones happen to point.
##
## Humanoid.gd makes one for every person; set the values each frame.

## Radians, positive to his left, followed smoothly.
var head_yaw := 0.0
## The way his feet go, radians from straight ahead, positive to his left.
## The hips turn toward it and the spine turns back, so he keeps his face.
var hips_yaw := 0.0
## 0 standing, 1 the knee up in front of him.
var knee := 0.0
## 0 the knee up, 1 the leg driven out straight.
var extend := 0.0
## Leaning back at the waist, radians.
var lean := 0.0
## Laid over those by his expression (Expression.gd), all followed smoothly
## but breath and limp:
##   head_pitch   radians, positive bowed.
##   chest_yaw    radians, positive to his left (the chest after the eyes).
##   chest_lean   radians, positive hunched forward.
##   shoulders    -1 dropped .. 1 hunched up.
##   breath       0 out .. 1 in: the chest lifts, the shoulders with it.
##   hip_shift    -1 .. 1: his weight on one leg or the other.
##   limp         0..1, with limp_phase (0..1 through his step): a dip on
##                the bad leg.
var head_pitch := 0.0
var chest_yaw := 0.0
var chest_lean := 0.0
var shoulders := 0.0
var breath := 0.0
var hip_shift := 0.0
var limp := 0.0
var limp_phase := 0.0

## The person this belongs to (Humanoid.gd): his axes are the ones turned about.
var man: Node3D

var _head := 0.0
var _hips := 0.0
var _pitch := 0.0
var _chest_yaw := 0.0
var _chest_lean := 0.0
var _shoulders := 0.0
var _shift := 0.0
var _bones := {}


func _process_modification() -> void:
	var skeleton := get_skeleton()

	if skeleton == null:
		return

	var delta := get_process_delta_time()
	_head = lerp_angle(_head, head_yaw, 1.0 - exp(-8.0 * delta))
	_hips = lerp_angle(_hips, hips_yaw, 1.0 - exp(-10.0 * delta))
	var follow := 1.0 - exp(-8.0 * delta)
	_pitch = lerpf(_pitch, head_pitch, follow)
	_chest_yaw = lerpf(_chest_yaw, chest_yaw, follow)
	_chest_lean = lerpf(_chest_lean, chest_lean, follow)
	_shoulders = lerpf(_shoulders, shoulders, follow)
	_shift = lerpf(_shift, hip_shift, follow)

	if man == null:
		return

	# His own axes, in the skeleton's space.
	var into := (skeleton.global_basis.inverse() * man.global_basis).orthonormalized()
	var up := (into * Vector3.UP).normalized()
	var right := (into * Vector3.RIGHT).normalized()
	var ahead := (into * Vector3.FORWARD).normalized()

	if absf(_hips) > 0.001:
		_turn(skeleton, &"pelvis", up, _hips)
		_turn(skeleton, &"spine_01", up, -_hips * 0.55)
		_turn(skeleton, &"spine_02", up, -_hips * 0.45)

	if absf(_head) > 0.001:
		_turn(skeleton, &"neck_01", up, _head * 0.35)
		_turn(skeleton, &"Head", up, _head * 0.65)

	# His expression, over the animation (not while a leg is up to kick).
	if knee <= 0.001:
		var dip := 0.06 * clampf(limp, 0.0, 1.0) * maxf(sin(TAU * limp_phase), 0.0)

		if absf(_shift) > 0.001 or dip > 0.0001:
			_turn(skeleton, &"pelvis", ahead, 0.05 * _shift + dip)
			_turn(skeleton, &"spine_01", ahead, -0.04 * _shift - dip * 0.6)

		if absf(_chest_yaw) > 0.001:
			_turn(skeleton, &"spine_02", up, _chest_yaw * 0.45)
			_turn(skeleton, &"spine_03", up, _chest_yaw * 0.55)

		var bend := -_chest_lean + 0.035 * clampf(breath, 0.0, 1.0)

		if absf(bend) > 0.0001:
			_turn(skeleton, &"spine_02", right, bend * 0.5)
			_turn(skeleton, &"spine_03", right, bend * 0.5)

		var shrug := 0.18 * clampf(_shoulders, -1.0, 1.0) + 0.03 * clampf(breath, 0.0, 1.0)

		if absf(shrug) > 0.0001:
			_turn(skeleton, &"clavicle_l", ahead, shrug)
			_turn(skeleton, &"clavicle_r", ahead, -shrug)

		if absf(_pitch) > 0.001:
			_turn(skeleton, &"neck_01", right, -_pitch * 0.35)
			_turn(skeleton, &"Head", right, -_pitch * 0.65)

	if knee > 0.001:
		var k := clampf(knee, 0.0, 1.0)
		var e := clampf(extend, 0.0, 1.0)
		_turn(skeleton, &"spine_01", right, (0.12 + 0.1 * e) * k)
		_turn(skeleton, &"thigh_r", right, lerpf(1.5, 1.3, e) * k)
		_turn(skeleton, &"calf_r", right, -lerpf(1.95, 0.12, e) * k)
		_turn(skeleton, &"foot_r", right, lerpf(0.2, 0.5, e) * k)
		# The standing leg gives a little.
		_turn(skeleton, &"thigh_l", right, 0.2 * k)
		_turn(skeleton, &"calf_l", right, -0.3 * k)
	elif absf(lean) > 0.001:
		_turn(skeleton, &"spine_01", right, lean)


## Turns `bone` (and so all below it) by `angle` about `axis` (skeleton
## space) through its own joint.
func _turn(skeleton: Skeleton3D, bone: StringName, axis: Vector3, angle: float) -> void:
	var index: int = _bones.get(bone, -2)

	if index == -2:
		index = skeleton.find_bone(bone)
		_bones[bone] = index

	if index < 0:
		return

	var parent := skeleton.get_bone_parent(index)
	var parent_basis := skeleton.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
	var turned := Basis(axis, angle) * skeleton.get_bone_global_pose(index).basis
	var local := (parent_basis.inverse() * turned).orthonormalized()
	skeleton.set_bone_pose_rotation(index, local.get_rotation_quaternion())
