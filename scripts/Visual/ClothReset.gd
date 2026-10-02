extends SkeletonModifier3D
## Restarts spring-bone cloth after pose jumps and keeps its floor beneath limp hips.
## Runs inside the skeleton update after physics and immediately before Cloth; restart() also covers recovery.

## Further than this (metres) in one frame is being put somewhere, not
## moving (a sprint moves him 0.15). Getting up and being laid down restart
## the cloth themselves (restart()): their pops are about 2 m, on either
## side of any threshold near that.
const JUMP := 1.0
## Frames a jump restarts the cloth for: the cloth can feel a jump a frame
## after his skeleton reports it (the transform reaches it late), so a
## single restart can land a frame early.
const RESTARTS := 3

## The cloth it restarts.
var cloth: Node
## His ragdoll: while it has him limp, the cloth's floor is kept under him.
var ragdoll: Node

## What the floor is found on (the world, not his own bodies).
const FLOOR_MASK := 1

var _last := Vector3.INF
var _owed := 0
## Where his hips were when the floor was last found, and where it was put:
## lying still, the floor under him is where it was.
var _floor_from := Vector3.INF
var _floor_put := Vector3.INF


func _process_modification() -> void:
	var skeleton := get_skeleton()

	if cloth == null or skeleton == null:
		return

	var at := skeleton.global_position

	if _last != Vector3.INF and at.distance_to(_last) > JUMP:
		_owed = RESTARTS

	_last = at

	if _owed > 0:
		_owed -= 1
		cloth.reset()

	_keep_floor(skeleton)


## The cloth's floor at the floor under his hips while he lies limp (his
## hips as physics has them: this runs after the ragdoll); parked below
## otherwise.
func _keep_floor(skeleton: Skeleton3D) -> void:
	var ground := cloth.get_node_or_null("Floor") as Node3D

	if ground == null:
		return

	var hips := skeleton.find_bone(&"pelvis")

	if ragdoll == null or not ragdoll.is_limp() or hips < 0 or not skeleton.is_inside_tree():
		ground.global_position = cloth.PARKED
		_floor_from = Vector3.INF
		return

	var at := skeleton.global_transform * skeleton.get_bone_global_pose(hips).origin

	if _floor_from != Vector3.INF and at.distance_to(_floor_from) < 0.01 and ground.global_position.distance_to(_floor_put) < 0.001:
		return

	var ray := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.3, at + Vector3.DOWN * 2.0, FLOOR_MASK)
	var hit := skeleton.get_world_3d().direct_space_state.intersect_ray(ray)
	ground.global_position = (hit.position + Vector3.UP * 0.01) if not hit.is_empty() else cloth.PARKED
	_floor_from = at
	_floor_put = ground.global_position


## Requests cloth restarts over the following skeleton updates to cover delayed transform propagation.
func restart() -> void:
	_owed = RESTARTS
