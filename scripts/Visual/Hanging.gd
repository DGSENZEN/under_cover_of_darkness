extends Node3D
## Hand-held pendulum anchor: children hang beneath the grip, stay upright, and swing with hand movement.
## Updates from Skeleton3D.skeleton_updated so its world transform follows the final hand pose.
## Humanoid.attach() supplies the grip; children use negative local Y below it.

## How far below the bail its weight hangs (m): the pendulum's length.
@export var length := 0.22
## How quickly a swing dies away (per second).
@export var damping := 3.5
## The most it swings from straight down (rad), and the fastest (rad/s).
@export var max_swing := 0.6
@export var max_spin := 8.0

var _skeleton: Skeleton3D
var _tilt := Vector2.ZERO
var _spin := Vector2.ZERO
var _last := Vector3.INF
var _last_velocity := Vector3.ZERO


func _enter_tree() -> void:
	# Placed where the hand is when it is drawn, not smoothed between ticks.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var above := get_parent()

	while above != null and not (above is Skeleton3D):
		above = above.get_parent()

	_skeleton = above as Skeleton3D
	_last = Vector3.INF

	if _skeleton != null and not _skeleton.skeleton_updated.is_connected(_hang):
		_skeleton.skeleton_updated.connect(_hang)


func _exit_tree() -> void:
	if _skeleton != null and is_instance_valid(_skeleton) and _skeleton.skeleton_updated.is_connected(_hang):
		_skeleton.skeleton_updated.disconnect(_hang)

	_skeleton = null


## Under where it is held now, swung by how the hand has moved.
func _hang() -> void:
	var holder := get_parent() as Node3D

	if holder == null or _skeleton == null:
		return

	var pivot := holder.global_position
	var delta := get_process_delta_time()

	if _last != Vector3.INF and delta > 0.0:
		var velocity := (pivot - _last) / delta
		var push := (velocity - _last_velocity) / delta
		_last_velocity = velocity
		# Pulled back under the bail, swung the other way by the hand's push.
		var pull := -_tilt * (9.8 / length) - Vector2(push.x, push.z) / length - _spin * damping
		_spin = (_spin + pull * delta).limit_length(max_spin)
		_tilt = (_tilt + _spin * delta).limit_length(max_swing)
	else:
		_last_velocity = Vector3.ZERO

	_last = pivot
	# Upright but for the swing, and turned the way the man faces.
	var up := Vector3(-_tilt.x, 1.0, -_tilt.y).normalized()
	var back := _skeleton.global_basis.z
	back = (back - up * back.dot(up)).normalized()

	if not back.is_finite() or back.length_squared() < 0.5:
		back = Vector3.BACK

	global_transform = Transform3D(Basis(up.cross(back).normalized(), up, back), pivot)
