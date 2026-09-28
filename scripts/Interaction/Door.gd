class_name Door
extends AnimatableBody3D
## A hinged door. This body IS the hinge: place it at the door's edge and give
## it a CollisionShape3D and a mesh offset sideways, so the panel hangs off
## the hinge. It has to be the body itself that rotates: an AnimatableBody3D
## only follows its own transform, never a moving parent's.
##
## Frob toggles it. It swings away from whoever frobs it, stops when it would
## push into a body, and can be locked with a key id the inventory must hold.
##
## It remembers who last opened it: a door that stood shut, opened by someone
## who is not one of the guards and left open, is something a guard on his
## rounds notices (GuardLife.gd), and shuts again.

const SoundBus := preload("res://scripts/StimuliSystem/SoundBus.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")

signal opened
signal closed
signal rattled

## How deep the doorway NavBaker bakes as a region of its own is (m).
const DOORWAY_DEPTH := 0.6

## Each key's navigation layer (2 to 32, handed out as keys turn up; layer 1
## is everyone's). Locked, a door's doorway is on its key's layer only: off
## the navmesh of anyone without the key (Guard: his keys' layers).
static var _key_layers := {}

@export var open_db := 42.0
@export var rattle_db := 52.0

@export var open_degrees := 100.0
@export var open_time := 0.9
## When on, the door swings away from the player each time. Off swings one way.
@export var swing_away_from_frobber := true
@export var locked := false:
	set(value):
		locked = value
		var region: Variant = get_meta(&"nav_region") if has_meta(&"nav_region") else null

		if region is NavigationRegion3D and is_instance_valid(region):
			(region as NavigationRegion3D).navigation_layers = nav_layers()
@export var key_id: StringName = &""
@export var door_name := "door"

var is_open := false
## It stood shut when the level began.
var was_shut := true
var _target_angle := 0.0
var _closed_yaw := 0.0
var _shape: CollisionShape3D
var _opened_by: WeakRef = null


func _ready() -> void:
	_closed_yaw = rotation.y
	sync_to_physics = true
	was_shut = not is_open

	# A closed door must not cut the navmesh at its doorway.
	add_to_group(&"nav_ignore")
	add_to_group(&"doors")

	for child in get_children():
		if child is CollisionShape3D:
			_shape = child
			break


func get_prompt(player: Node) -> String:
	if locked:
		if can_unlock(player):
			return "Unlock the " + door_name

		if can_pick(player):
			return "Pick the lock"

		return "Locked"

	return ("Close " if is_open else "Open ") + door_name


## No key, but a lockpick (PlayerFrob.can_pick): it can be picked.
static func can_pick(player: Node) -> bool:
	var hands: Variant = player.get("frob") if player != null else null
	return hands != null and hands.has_method("can_pick") and hands.can_pick()


## The layer `id`'s key opens (see _key_layers).
static func key_layer(id: StringName) -> int:
	if not _key_layers.has(id):
		_key_layers[id] = 1 << (1 + _key_layers.size() % 31)

	return _key_layers[id]


## Its doorway's navigation layers: everyone's, or locked, its key's only.
func nav_layers() -> int:
	return key_layer(key_id) if locked else 1


## Does this frobber carry the key?
func can_unlock(player: Node) -> bool:
	if key_id == &"" or player == null:
		return false

	var inventory: Variant = player.get("inventory")
	return inventory != null and inventory.has_key(key_id)


func frob(player: Node) -> void:
	if locked:
		if key_id != &"" and player.get("inventory") != null and player.inventory.has_key(key_id):
			locked = false
		else:
			rattled.emit()
			SoundBus.emit_sound(global_position + Vector3.UP, rattle_db, player, &"door")
			Sfx.play(self, &"door_rattle", global_position + Vector3.UP, Sfx.loudness(rattle_db))
			return

	SoundBus.emit_sound(global_position + Vector3.UP, open_db, player, &"door")

	if not is_open:
		Sfx.play(self, &"door_open", global_position + Vector3.UP, Sfx.loudness(open_db))

	if is_open:
		_target_angle = 0.0
		is_open = false
		return

	var sign := 1.0

	if swing_away_from_frobber:
		# Local -Z is the door's front WHEN CLOSED. Taken from the closed pose,
		# not the current one: a door stopped halfway must still pick the side
		# away from the player, not swing back through its frame at them.
		var to_player: Vector3 = player.global_position - global_position
		var front := -(_closed_global_basis() * Vector3.BACK)
		sign = -1.0 if to_player.dot(front) > 0.0 else 1.0

	_target_angle = deg_to_rad(open_degrees) * sign
	is_open = true
	_opened_by = weakref(player) if player != null else null

	# Opened again: whoever notices it this time, notices it afresh.
	if has_meta(&"noticed"):
		remove_meta(&"noticed")


## Whoever opened it last, if they are still about.
func opened_by() -> Node:
	return _opened_by.get_ref() as Node if _opened_by != null else null


## Open when it should be shut, and not by one of the guards: someone has
## been through.
func left_open() -> bool:
	if not is_open or not was_shut:
		return false

	var who := opened_by()
	return who == null or not who.is_in_group(&"guards") and who.get("_knocked_out") == null


## The middle of the panel, wherever it has swung to.
func panel_centre() -> Vector3:
	return _shape.global_position if _shape != null else global_position + Vector3.UP


## Which way the doorway faces (the shut panel's front), flat.
func facing() -> Vector3:
	var front := -(_closed_global_basis() * Vector3.BACK)
	front.y = 0.0
	return front.normalized() if front.length() > 0.01 else Vector3.FORWARD


## The middle of the doorway, at the floor: where the panel stands when shut.
func doorway() -> Vector3:
	if _shape == null:
		return global_position

	var parent := get_parent_node_3d()
	var parent_xform := parent.global_transform if parent != null else Transform3D.IDENTITY
	var shut := parent_xform * Transform3D(Basis(Vector3.UP, _closed_yaw), position)
	var middle := shut * _shape.position
	return Vector3(middle.x, global_position.y, middle.z)


## The doorway seen from above, in the world: the shut panel, a little wider
## (into its frame), DOORWAY_DEPTH through.
func footprint() -> PackedVector3Array:
	var middle := doorway()
	var front := facing()
	var width := _shape.shape.get_debug_mesh().get_aabb().size.x if _shape != null and _shape.shape != null else 1.0
	var along := Vector3(-front.z, 0.0, front.x) * (width * 0.5 + 0.2)
	var through := front * DOORWAY_DEPTH * 0.5
	return PackedVector3Array([middle - along - through, middle + along - through, middle + along + through, middle - along + through])


func _physics_process(delta: float) -> void:
	var current := wrapf(rotation.y - _closed_yaw, -PI, PI)

	if is_equal_approx(current, _target_angle):
		return

	var speed := deg_to_rad(open_degrees) / maxf(open_time, 0.05)
	var next := move_toward(current, _target_angle, speed * delta)

	if _would_hit_body(next, signf(next - current)):
		return

	rotation.y = _closed_yaw + next

	if is_equal_approx(next, _target_angle):
		if is_open:
			opened.emit()
		else:
			closed.emit()
			# Home in its frame: the thud and the latch.
			Sfx.play(self, &"door_close", global_position + Vector3.UP, Sfx.loudness(open_db))


## The door's basis in world space when closed.
func _closed_global_basis() -> Basis:
	var parent := get_parent_node_3d()
	var parent_basis := parent.global_transform.basis if parent != null else Basis.IDENTITY
	return parent_basis * Basis(Vector3.UP, _closed_yaw)


## Would the panel push into a PERSON at this angle, or a man lying down (a
## body, the limbs of one gone limp), or what you hold in your hands? Crates
## and keys on the floor are simply pushed aside: a key on the floor must not
## jam a door. Only what is on the side the door swings TOWARD counts;
## whoever just opened it is standing against the other face. Static walls
## are not checked: a door that swings into a wall is a level bug, not a
## runtime one.
func _would_hit_body(angle: float, direction: float) -> bool:
	if _shape == null or _shape.shape == null:
		return false

	# Built in the parent's space, so a door under a rotated parent is tested
	# where it really is.
	var parent := get_parent_node_3d()
	var parent_xform := parent.global_transform if parent != null else Transform3D.IDENTITY
	var hinge := parent_xform * Transform3D(Basis(Vector3.UP, _closed_yaw + angle), position)

	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _shape.shape
	query.transform = hinge * _shape.transform
	query.exclude = [get_rid()]
	query.collision_mask = 0xFFFFFFFF
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var space := get_world_3d().direct_space_state
	var to_local := global_transform.affine_inverse()

	for hit in space.intersect_shape(query, 8):
		var collider: Object = hit.get("collider")

		if not _stops_door(collider):
			continue

		# The panel lies along local +X with its front toward -Z. Turning the
		# positive way sweeps it toward -Z, the negative way toward +Z.
		var side: float = (to_local * (collider as Node3D).global_position).z

		if (direction > 0.0 and side < 0.0) or (direction < 0.0 and side > 0.0):
			return true

	return false


## A man standing or lying, or something in your hands: not to be shoved
## through the frame.
static func _stops_door(thing: Object) -> bool:
	if thing is CharacterBody3D:
		return true

	if not (thing is Node):
		return false

	var node := thing as Node
	return node.is_in_group(&"bodies") or node.is_in_group(&"in_hand") or node.has_meta(&"ragdoll")
