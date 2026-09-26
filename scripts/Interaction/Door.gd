class_name Door
extends AnimatableBody3D
## A hinged door. This body IS the hinge: place it at the door's edge and give
## it a CollisionShape3D and a mesh offset sideways, so the panel hangs off
## the hinge. It has to be the body itself that rotates: an AnimatableBody3D
## only follows its own transform, never a moving parent's.
##
## Frob toggles it. It swings away from whoever frobs it, stops when it would
## push into a body, and can be locked with a key id the inventory must hold.

const SoundBus := preload("res://scripts/StimuliSystem/SoundBus.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")

signal opened
signal closed
signal rattled

@export var open_db := 42.0
@export var rattle_db := 52.0

@export var open_degrees := 100.0
@export var open_time := 0.9
## When on, the door swings away from the player each time. Off swings one way.
@export var swing_away_from_frobber := true
@export var locked := false
@export var key_id: StringName = &""
@export var door_name := "door"

var is_open := false
var _target_angle := 0.0
var _closed_yaw := 0.0
var _shape: CollisionShape3D


func _ready() -> void:
	_closed_yaw = rotation.y
	sync_to_physics = true

	# A closed door must not cut the navmesh at its doorway.
	add_to_group(&"nav_ignore")

	for child in get_children():
		if child is CollisionShape3D:
			_shape = child
			break


func get_prompt(player: Node) -> String:
	if locked:
		if can_unlock(player):
			return "Unlock the " + door_name

		return "Locked"

	return ("Close " if is_open else "Open ") + door_name


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


## Would the panel push into a PERSON at this angle? Crates, keys and bodies
## are simply pushed aside: a key on the floor must not jam a door. Only
## bodies on the side the door swings TOWARD count; whoever just opened it is
## standing against the other face. Static walls are not checked: a door that
## swings into a wall is a level bug, not a runtime one.
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

		if not (collider is CharacterBody3D):
			continue

		# The panel lies along local +X with its front toward -Z. Turning the
		# positive way sweeps it toward -Z, the negative way toward +Z.
		var side: float = (to_local * (collider as Node3D).global_position).z

		if (direction > 0.0 and side < 0.0) or (direction < 0.0 and side > 0.0):
			return true

	return false
