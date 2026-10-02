extends Node3D
## Exclusive guard habit location: floor origin and local -Z facing.
## Kinds: seat, lean, rail, table, chop, fire, work, pile. Weak ownership
## expires when the holder leaves, dies, is knocked out, or changes spots.
## Pile spots use metadata other to identify their paired destination.

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


## Returns the nearest free matching spot in horizontal reach, or null.
## Accepts the caller’s own spot; rejects height differences above 2.5 m.
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


## Stores a weak owner reference and returns true if free_for(man); otherwise false.
func claim(man: Node) -> bool:
	if not free_for(man):
		return false

	_holder = weakref(man)
	return true


## Clears ownership only when man currently holds the spot.
func release(man: Node) -> void:
	if _holder != null and _holder.get_ref() == man:
		_holder = null
