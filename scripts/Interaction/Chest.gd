class_name Chest
extends Node3D
## A chest or cabinet with a lid. This node sits at the lid's hinge line; the
## child AnimatableBody3D named Lid holds the lid's shape and mesh, and the
## body of the chest is any static child. Loot and keys placed inside are
## ordinary frobbables that the closed lid simply hides from the ray.

const Sfx := preload("res://scripts/Audio/Sfx.gd")

signal opened
signal closed
signal rattled

@export var open_degrees := -110.0
@export var open_time := 0.6
@export var locked := false
@export var key_id: StringName = &""
## Off: no lockpick opens it, only its key (a level's `pick` false).
@export var pickable := true
@export var container_name := "chest"

var is_open := false
var _target_angle := 0.0
var _lid: AnimatableBody3D


func _ready() -> void:
	_lid = get_node_or_null("Lid") as AnimatableBody3D


func get_prompt(player: Node) -> String:
	if locked:
		if can_unlock(player):
			return "Unlock the " + container_name

		if pickable and can_pick(player):
			return "Pick the lock"

		return "Locked"

	return ("Close " if is_open else "Open ") + container_name


## No key, but a lockpick (PlayerFrob.can_pick): it can be picked.
static func can_pick(player: Node) -> bool:
	var hands: Variant = player.get("frob") if player != null else null
	return hands != null and hands.has_method("can_pick") and hands.can_pick()


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
			Sfx.play(self, &"door_rattle", global_position, -6.0, 1.3)
			return

	is_open = not is_open

	if is_open:
		Sfx.play(self, &"chest_open", global_position)
	_target_angle = deg_to_rad(open_degrees) if is_open else 0.0


func _physics_process(delta: float) -> void:
	# The lid may be added after this node is ready (Props builds it that way).
	if _lid == null:
		_lid = get_node_or_null("Lid") as AnimatableBody3D

		if _lid == null:
			return

	var current := _lid.rotation.x

	if is_equal_approx(current, _target_angle):
		return

	var speed := absf(deg_to_rad(open_degrees)) / maxf(open_time, 0.05)
	var next := move_toward(current, _target_angle, speed * delta)
	_lid.rotation.x = next

	# Compare the value just set, not the lid's: a synced AnimatableBody3D
	# reads back last frame's physics transform until physics catches up.
	if is_equal_approx(next, _target_angle):
		if is_open:
			opened.emit()
		else:
			closed.emit()
			Sfx.play(self, &"chest_close", global_position)
