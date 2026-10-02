class_name GuardStation
extends Marker3D
## Exclusive station used by GuardRota. World position is the standing point;
## local -Z is facing. Kind selects sit/eat/sleep/rummage/carry/chop/lean or pray.
## Optional chest/drop_to paths supply work targets. Claims store the holder Node directly.

@export var kind: StringName = &"sit"
## Rummage: the chest (a Chest.gd hinge).
@export var chest: NodePath
## Carry: where the crates go (a Node3D).
@export var drop_to: NodePath

## The man at it now.
var holder: Node = null


func _ready() -> void:
	add_to_group(&"guard_stations")


## Which way a man at it faces.
func facing() -> Vector3:
	var ahead := -global_basis.z
	ahead.y = 0.0
	return ahead.normalized() if ahead.length() > 0.01 else Vector3.FORWARD


## Resolves chest as Node3D; null for an empty/missing/incompatible path.
func chest_node() -> Node3D:
	return get_node_or_null(chest) as Node3D if not chest.is_empty() else null


## Resolves drop_to as Node3D; null for an empty/missing/incompatible path.
func drop_node() -> Node3D:
	return get_node_or_null(drop_to) as Node3D if not drop_to.is_empty() else null


## Returns true if free, holder invalid/incapacitated, or already held by this guard;
## otherwise false. Stores guard directly in holder.
func claim(guard: Node) -> bool:
	if holder != null and is_instance_valid(holder) and holder != guard and holder.get("_knocked_out") != true:
		return false

	holder = guard
	return true


## Clears holder only if it equals this guard.
func release(guard: Node) -> void:
	if holder == guard:
		holder = null
