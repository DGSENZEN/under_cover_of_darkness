class_name GuardStation
extends Marker3D
## A place where a guard at his ease does something with himself (GuardRota):
## where he stands (this node's position) and which way he faces (its -Z),
## and what he does there (`kind`):
##   sit      sits on the bench or log in front of him; talks seated when a
##            friend at his ease is near.
##   eat      stands here and eats and drinks now and then (between bites,
##            a word with a friend near).
##   sleep    lies on a bedroll here; asleep he sees nothing and hears little.
##   rummage  goes through the chest (`chest`): lid up, a look inside, lid down.
##   carry    carries crates (group "cargo") from here to `drop_to`, and back
##            the other way once there are none left here.
##   chop     chops wood at the block in front of him.
##   lean     leans on the rail in front of him (a lookout sweeps his ground
##            from it).
## One man at a time holds a station (claim, release).

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


func chest_node() -> Node3D:
	return get_node_or_null(chest) as Node3D if not chest.is_empty() else null


func drop_node() -> Node3D:
	return get_node_or_null(drop_to) as Node3D if not drop_to.is_empty() else null


## Taken by `guard`, if nobody else has it. True if it is his.
func claim(guard: Node) -> bool:
	if holder != null and is_instance_valid(holder) and holder != guard and holder.get("_knocked_out") != true:
		return false

	holder = guard
	return true


func release(guard: Node) -> void:
	if holder == guard:
		holder = null
