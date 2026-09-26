extends SkeletonModifier3D
## Small changes laid over the animation after it plays: the head turned
## where the eyes look, the hips turned the way the feet go while the chest
## stays on the enemy, and a leg raised and driven out for a kick (the
## library has none). Every turn is about the man's own axes (his right, his
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

## The person this belongs to (Humanoid.gd): his axes are the ones turned about.
var man: Node3D

var _head := 0.0
var _hips := 0.0
var _bones := {}


func _process_modification() -> void:
	var skeleton := get_skeleton()

	if skeleton == null:
		return

	var delta := get_process_delta_time()
	_head = lerp_angle(_head, head_yaw, 1.0 - exp(-8.0 * delta))
	_hips = lerp_angle(_hips, hips_yaw, 1.0 - exp(-10.0 * delta))

	if man == null:
		return

	# His own axes, in the skeleton's space.
	var into := (skeleton.global_basis.inverse() * man.global_basis).orthonormalized()
	var up := (into * Vector3.UP).normalized()
	var right := (into * Vector3.RIGHT).normalized()

	if absf(_hips) > 0.001:
		_turn(skeleton, &"pelvis", up, _hips)
		_turn(skeleton, &"spine_01", up, -_hips * 0.55)
		_turn(skeleton, &"spine_02", up, -_hips * 0.45)

	if absf(_head) > 0.001:
		_turn(skeleton, &"neck_01", up, _head * 0.35)
		_turn(skeleton, &"Head", up, _head * 0.65)

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
