class_name Chest
extends Node3D
## Lockable lid container. This node sits at the lid hinge; child Lid is an
## AnimatableBody3D. Static children form the chest. The closed lid occludes
## ordinary frobbables inside; missing Lid leaves animation pending.

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
## The precious things that lay in it when the level was made (their names;
## LevelGameplay.fill_chests): taken, the chest is robbed.
var held_specials: Array[String] = []
var _held: Array[WeakRef] = []
## Who last opened or shut it (a guard shutting what you left open).
var _opened_by: WeakRef = null
var _target_angle := 0.0
var _lid: AnimatableBody3D
## load_state's: set the lid at its target on the next tick.
var _snap := false


func _ready() -> void:
	# (The guards look over every chest for one left open: GuardLife.)
	add_to_group(&"chests")
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


## Unlocks with a matching inventory key or emits rattled and returns.
## Otherwise toggles requested open state and target lid angle; completion signals come later.
func frob(player: Node) -> void:
	if locked:
		if key_id != &"" and player.get("inventory") != null and player.inventory.has_key(key_id):
			locked = false
		else:
			rattled.emit()
			Sfx.play(self, &"door_rattle", global_position, -6.0, 1.3)
			return

	is_open = not is_open
	_opened_by = weakref(player) if player != null else null

	if is_open:
		Sfx.play(self, &"chest_open", global_position)
	_target_angle = deg_to_rad(open_degrees) if is_open else 0.0


func opened_by() -> Node:
	return _opened_by.get_ref() as Node if _opened_by != null else null


## Open, and not by one of the guards: someone has been in it.
func left_open() -> bool:
	if not is_open:
		return false

	var who := opened_by()
	return who == null or not who.is_in_group(&"guards")


## `loot` (something precious) lies in it.
func hold_special(loot: Node) -> void:
	held_specials.append(String(loot.name))
	_held.append(weakref(loot))


## Something precious that lay in it is gone: taken, or never made again
## (the district come back to remembers it taken).
func robbed() -> bool:
	for ref in _held:
		var loot: Object = ref.get_ref()

		if loot == null or (loot as Node).is_queued_for_deletion() or loot.get("taken") == true:
			return true

	return false


## What was done to it, for the district's memory: open or shut, locked or not.
func save_state() -> Dictionary:
	return {"open": is_open, "locked": locked}


## Puts it as it was left (save_state), its lid set on the next physics tick
## (where a body that moves with the physics takes its turn): no sound.
func load_state(state: Dictionary) -> void:
	locked = bool(state.get("locked", locked))
	is_open = bool(state.get("open", false))
	_target_angle = deg_to_rad(open_degrees) if is_open else 0.0
	_snap = true


func _physics_process(delta: float) -> void:
	# The lid may be added after this node is ready (Props builds it that way).
	if _lid == null:
		_lid = get_node_or_null("Lid") as AnimatableBody3D

		if _lid == null:
			return

	if _snap:
		_snap = false
		_lid.rotation.x = _target_angle
		_lid.reset_physics_interpolation()
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
