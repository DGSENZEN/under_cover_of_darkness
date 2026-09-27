extends Node3D
## A place a guard at his ease goes to and does something at (GuardHabits):
## where he stands (this node, on the floor) and which way he faces (its -Z),
## and what for (kind):
##   seat   sits down: the seat is behind him (SEAT_BACK), at knee height.
##   lean   leans back against a wall: the wall is behind him.
##   rail   leans on a rail, a parapet or a barrel head in front of him.
##   table  takes something off the table in front of him, and eats it.
##   chop   splits wood on the block in front of him.
##   fire   crouches at the fire in front of him and tends it.
##   work   kneels at a job in front of him (a cart wheel, a barrel).
##   pile   crates stacked there (the "stock" group): carried to the other
##          pile it is paired with (meta "other"), and set down there.
## One man at a time: claimed while he is about it (claim), free again when
## he is done or can no longer be (released, knocked out, gone). Levels place
## them with build(); the furnishings (Furnishings.gd) bring their own.

const KINDS := [&"seat", &"lean", &"rail", &"table", &"chop", &"fire", &"work", &"pile"]
## Sitting: the middle of the seat is this far behind where his feet go.
const SEAT_BACK := 0.32

@export var kind: StringName = &"seat"

var _holder: WeakRef = null


## A spot of `kind` at `at` (on the floor), facing `yaw` (he faces -Z turned
## by it).
static func build(parent: Node, spot_kind: StringName, at: Vector3, yaw: float) -> Node3D:
	var spot: Node3D = (load("res://scripts/Interaction/IdleSpot.gd") as GDScript).new()
	spot.kind = spot_kind
	spot.name = "Spot_%s" % spot_kind
	parent.add_child(spot)
	spot.global_position = at
	spot.rotation.y = yaw
	return spot


## The free spot of `spot_kind` nearest `from` (flat), within `reach` and not
## far above or below it, for `man` (his own counts as free).
static func nearest(tree: SceneTree, spot_kind: StringName, from: Vector3, reach: float, man: Node) -> Node3D:
	var best: Node3D = null
	var best_distance := reach

	for spot in tree.get_nodes_in_group(&"idle_spots"):
		if spot.get("kind") != spot_kind or not spot.free_for(man):
			continue

		var at: Vector3 = (spot as Node3D).global_position

		if absf(at.y - from.y) > 2.5:
			continue

		var distance := Vector2(at.x - from.x, at.z - from.z).length()

		if distance < best_distance:
			best_distance = distance
			best = spot

	return best


func _ready() -> void:
	add_to_group(&"idle_spots")


## The way he faces there (flat).
func facing() -> Vector3:
	var forward := -global_basis.z
	forward.y = 0.0
	return forward.normalized() if forward.length() > 0.001 else Vector3.FORWARD


## Who has it: a man still about it, or null.
func holder() -> Node3D:
	if _holder == null:
		return null

	var man := _holder.get_ref() as Node3D

	if man == null or not man.is_inside_tree() or man.get("_knocked_out") == true or man.get("is_dead") == true:
		_holder = null
		return null

	var habits: RefCounted = man.get("_habits")

	if habits != null and habits.get("spot") != self:
		_holder = null
		return null

	return man


func free_for(man: Node) -> bool:
	var held := holder()
	return held == null or held == man


func claim(man: Node) -> bool:
	if not free_for(man):
		return false

	_holder = weakref(man)
	return true


func release(man: Node) -> void:
	if _holder != null and _holder.get_ref() == man:
		_holder = null
