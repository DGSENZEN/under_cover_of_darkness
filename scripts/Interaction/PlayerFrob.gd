extends Node3D
## Gameplay-aim frob ray, target highlight, dispatch, carrying, and belt-tool use.
## Targets implement frob(player); get_prompt(player) is optional. Carrying
## marks bodies in_hand and blocks traversal. Keys turn through HandSlot jobs;
## lockpicking requires a lockpick, continued aim, and near-still locomotion.
## See docs/systems/interaction.md for target, carry, and inventory contracts.

const SoundBus := preload("res://scripts/StimuliSystem/SoundBus.gd")
const GuardBodyScript := preload("res://scripts/AISystem/GuardBody.gd")
const Fx := preload("res://scripts/Visual/Fx.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")
const TimeFx := preload("res://scripts/Visual/TimeFx.gd")
const ThrownToolScript := preload("res://scripts/Combat/ThrownTool.gd")

## The tools thrown from your hand (ThrownTool.kind).
const THROWN_TOOLS := [&"flashbomb", &"waterflask"]
## Picking a lock: this long at it (s), a click every PICK_CLICK (s) heard this
## loud (SoundBus, dB); moving faster than PICK_STILL (m/s) undoes it.
const PICK_TIME := 3.2
const PICK_CLICK := 0.4
const PICK_DB := 28.0
const PICK_STILL := 0.8

signal frobbed(target: Node)
signal picked_up(body: RigidBody3D)
signal released(body: RigidBody3D, thrown: bool)

@export var frob_distance := 2.2
## Layer 1 is the world, layer 3 (value 4) is bodies on the floor.
@export_flags_3d_physics var frob_mask := 5

@export_group("Blackjack")
@export var blackjack_reach := 1.9
## The swing lands this long after the click.
@export var blackjack_windup := 0.18
@export var blackjack_cooldown := 0.7

@export_group("Tools")
## A tool leaves your hand this long after the click; none again for this long.
@export var tool_windup := 0.16
@export var tool_cooldown := 0.7

@export_group("Carry")
@export var max_carry_mass := 30.0
@export var hold_distance := 1.1
@export var hold_drop := 0.2
@export var carry_stiffness := 14.0
@export var carry_max_speed := 9.0
@export var throw_speed := 11.0
## Set down if the object stays farther than this from the hold point for
## carry_break_time: it has snagged on something. A fast turn does not count.
@export var carry_break_distance := 2.0
@export var carry_break_time := 0.25

var player: CharacterBody3D
var camera: Camera3D
var target: Node = null
var held: RigidBody3D = null

## A body over the shoulder. Too heavy to hold out in front, so it is carried
## out of sight and slows you down.
var shouldered: RigidBody3D = null
var _shouldered_layer := 0
var _shouldered_mask := 0

var _swing_windup := -1.0
var _swing_cooldown := 0.0
## A tool on its way out of your hand: seconds to its release (-1: none), which,
## and what it looks like.
var _tool_windup := -1.0
var _tool_kind: StringName = &""
var _tool_mesh: Mesh = null
## The lock being picked (null: none), how far along (s), and the next click.
var _picking: Node = null
var _pick_t := 0.0
var _pick_click := 0.0

## Where the frob ray met the target: a lock, for the key to go to.
var _target_point := Vector3.ZERO
## A key is being turned. Nothing else happens until it has.
var _unlocking := false

## Things in flight or falling that will make a noise when they hit
## something. body -> the velocity it had last frame.
var _falling := {}
var _game_time := 0.0

@export_group("Impact noise")
## Setting something down places it on a surface this far below your hands.
## Further down than that, letting go is dropping it.
@export var set_down_reach := 1.3
## Slower than this at the moment of impact: silent. A careful set-down is.
@export var impact_min_speed := 2.2
@export var impact_db_base := 36.0
@export var impact_db_per_speed := 3.5
@export var impact_db_max := 68.0

var _highlighted: Node = null
var _highlight_material := StandardMaterial3D.new()
var _held_gravity_scale := 1.0
var _carry_strain := 0.0
## Where what you hold was when you took it: moved from there (into a guard's
## hand), it is no longer yours.
var _held_parent: Node = null


func _ready() -> void:
	player = get_parent() as CharacterBody3D
	camera = player.get_node("Neck/Camera3D")

	_highlight_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_highlight_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_highlight_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_highlight_material.albedo_color = Color(0.9, 0.75, 0.35, 0.18)

	_ensure_action("frob", KEY_E)
	_ensure_action("inventory", KEY_TAB)
	_ensure_action("throw", -1, MOUSE_BUTTON_LEFT)
	_ensure_action("belt_next", -1, MOUSE_BUTTON_WHEEL_DOWN)
	_ensure_action("belt_prev", -1, MOUSE_BUTTON_WHEEL_UP)


## Something is in your hands (tracked apart from `held`, which reads as
## null once what it points at has been freed).
var _holding := false


func is_carrying() -> bool:
	return held != null or shouldered != null


func is_shouldering() -> bool:
	return shouldered != null


func _physics_process(delta: float) -> void:
	_game_time += delta
	_update_falling()

	if player.is_dead:
		_set_target(null)
		_swing_windup = -1.0
		return

	# What you held is gone (it burst in your hands): the hands are free.
	if _holding and not is_instance_valid(held):
		_holding = false
		held = null
		released.emit(null, false)

	if held != null:
		_update_carry(delta)
		_set_target(null)
	elif shouldered != null:
		_set_target(null)
	else:
		_set_target(_find_target())

	_swing_cooldown = maxf(_swing_cooldown - delta, 0.0)

	if _swing_windup >= 0.0:
		_swing_windup -= delta

		if _swing_windup < 0.0:
			_blackjack_lands()

	if _tool_windup >= 0.0:
		_tool_windup -= delta

		if _tool_windup < 0.0:
			_release_tool()

	if _picking != null:
		_update_picking(delta)

	if Input.is_action_just_pressed("frob") and not _unlocking:
		_on_frob()

	# Holding Tab: raise the purse and key ring to see what you carry.
	var hands: Node = player.hand

	if hands != null and hands.has_method("set_checking"):
		var free := held == null and shouldered == null and _hands_free()
		hands.set_checking(Input.is_action_pressed("inventory") and free)

	# The click that recaptured the mouse is not also an attack.
	var mouse_free: bool = not player.is_mouse_input_swallowed()

	# One button, read by what your hands are doing: throw what you hold,
	# otherwise use what is in your hand.
	if mouse_free and Input.is_action_just_pressed("throw"):
		# Falling onto a guard: the click belongs to the drop attack.
		var dropping: bool = player.combat != null and player.combat.drop_target() != null

		if held != null:
			_throw()
			# The press went on the throw: it is not also a sword stroke.
			player.spend_attack_press()
		elif shouldered == null and _hands_free() and not dropping:
			_use_item()

	if mouse_free and Input.is_action_just_pressed("belt_next"):
		player.inventory.select_next(1)

	if mouse_free and Input.is_action_just_pressed("belt_prev"):
		player.inventory.select_next(-1)


## On the ground and not mid-move. Hanging, climbing and vaulting all need
## both hands.
func _hands_free() -> bool:
	return player.movement_state == player.MoveState.LOCOMOTION


## Not in the middle of a blow, a stagger or a dodge: taking something up now
## would cut it short (combat stands down while you carry).
func _combat_idle() -> bool:
	return player.combat == null or player.combat.phase == player.combat.Phase.IDLE


# Finding and highlighting

func _find_target() -> Node:
	var space := get_world_3d().direct_space_state
	var eye := _eye()
	var from := eye.origin
	var to := from - eye.basis.z * frob_distance
	var query := PhysicsRayQueryParameters3D.create(from, to, frob_mask, [player.get_rid()])
	query.collide_with_areas = true
	query.collide_with_bodies = true

	var hit := space.intersect_ray(query)

	if hit.is_empty():
		return null

	_target_point = hit["position"]
	var collider: Node = hit.get("collider")
	var owner := _frobbable_owner(collider)

	if owner != null:
		return owner

	# Anything physical can at least be picked up or declared too heavy.
	if collider is RigidBody3D:
		return collider

	return null


## Walks up from what the ray hit to the node that answers frob().
func _frobbable_owner(node: Node) -> Node:
	var current := node

	while current != null:
		if current.has_method("frob"):
			return current

		current = current.get_parent()

	return null


func _set_target(new_target: Node) -> void:
	if new_target == target:
		return

	if _highlighted != null and is_instance_valid(_highlighted):
		_apply_highlight(_highlighted, false)

	target = new_target
	_highlighted = target

	if target != null:
		_apply_highlight(target, true)


func _apply_highlight(node: Node, on: bool) -> void:
	# Not a flame (a torch's: a glow over its quad would show as a box).
	if node is GeometryInstance3D and not node.has_meta(&"no_highlight"):
		(node as GeometryInstance3D).material_overlay = _highlight_material if on else null

	for child in node.get_children():
		# Do not restyle other frobbables nested inside this one, like loot in a chest.
		if child.has_method("frob"):
			continue

		_apply_highlight(child, on)


## Returns current HUD prompt, or an empty String when no prompt applies.
func current_prompt() -> String:
	if held != null:
		return "Set down"

	if shouldered != null:
		return "Put the body down"

	if target == null:
		return ""

	if target.has_method("get_prompt"):
		return String(target.get_prompt(player))

	if target is RigidBody3D:
		var body := target as RigidBody3D
		return "Pick up" if body.mass <= max_carry_mass else "Too heavy"

	return "Use"


## Returns Array of [action: StringName, label: String] HUD rows.
## An empty action denotes status text; an empty array means no available rows.
func current_actions() -> Array:
	if _unlocking:
		return []

	# At a lock with the pick: what you are doing, not a key to press.
	if _picking != null:
		return [[&"", "Picking the lock"]]

	if held != null:
		return [[&"frob", "Set down"], [&"throw", "Throw"]]

	if shouldered != null:
		return [[&"frob", "Put the body down"]]

	var prompt := current_prompt()

	if prompt == "":
		return []

	if prompt == "Too heavy" or prompt == "Locked":
		return [[&"", prompt]]

	return [[&"frob", prompt]]


# Frob dispatch

func _on_frob() -> void:
	if held != null:
		_release(false)
		return

	if shouldered != null:
		put_down_body()
		return

	if target == null:
		return

	if target is RigidBody3D and _can_carry(target as RigidBody3D):
		if _hands_free() and _combat_idle():
			_pick_up(target as RigidBody3D)
			frobbed.emit(target)

		return

	if not target.has_method("frob"):
		# A plain object too heavy to lift: give it a shove instead.
		if target is RigidBody3D:
			var forward := -_eye().basis.z
			(target as RigidBody3D).apply_central_impulse(forward * 40.0)

		return

	# Locked, and you have the key: the key goes to the lock and turns, and
	# only then does it open.
	if target.get("locked") == true and target.has_method("can_unlock") and target.can_unlock(player):
		_turn_key_in(target)
		return

	# Locked, no key, a lockpick on your belt: you set to work on it (unless
	# it is a lock no pick opens).
	if target.get("locked") == true and target.get("pickable") != false and can_pick():
		if _picking != target:
			_pick_lock(target)

		return

	var pickup := _pickup_visual(target)
	target.frob(player)
	frobbed.emit(target)

	# Taken from the world: the hands take it.
	if not pickup.is_empty() and target.get("taken") == true and player.hand != null:
		player.hand.receive(pickup["kind"], pickup["mesh"], pickup["from"])


func _turn_key_in(lock: Node) -> void:
	var hands: Node = player.hand
	var key_mesh: Mesh = null

	for entry in player.inventory.belt:
		if entry["id"] == lock.get("key_id"):
			key_mesh = entry.get("mesh")

	if hands == null or not hands.has_method("turn_key"):
		lock.frob(player)
		frobbed.emit(lock)
		return

	_unlocking = true
	var point := _target_point
	hands.turn_key(key_mesh, point, func() -> void:
		_unlocking = false

		# Turned with you gone from the door (or down): it stays locked.
		if is_instance_valid(lock) and not player.is_dead and _eye().origin.distance_to(point) <= frob_distance + 0.3:
			SoundBus.emit_sound(point, 30.0, player, &"unlock")
			Sfx.play(player, &"unlock", point)
			lock.frob(player)
			frobbed.emit(lock))


## What a pickup looks like and where it lay, before it is freed.
func _pickup_visual(node: Node) -> Dictionary:
	if node.get("taken") == null or not (node is Node3D):
		return {}

	var kind := "tool"

	if node.get("value") != null:
		kind = "loot"
	elif node.get("key_id") != null:
		kind = "key"

	var mesh: Mesh = null

	for child in node.get_children():
		if child is MeshInstance3D:
			mesh = (child as MeshInstance3D).mesh
			break

	return { "kind": kind, "mesh": mesh, "from": (node as Node3D).global_transform }


func _can_carry(body: RigidBody3D) -> bool:
	if body.has_method("can_carry"):
		return body.can_carry()

	return body.mass <= max_carry_mass


# Carrying

func _pick_up(body: RigidBody3D) -> void:
	Sfx.play_flat(player, &"pickup", -2.0)
	_carry_strain = 0.0
	held = body
	_holding = true
	_held_parent = body.get_parent()
	_held_gravity_scale = body.gravity_scale
	body.gravity_scale = 0.0
	body.add_to_group(&"in_hand")
	body.add_collision_exception_with(player)
	player.add_collision_exception_with(body)
	picked_up.emit(body)


func _hold_point() -> Vector3:
	var eye := _eye()
	var basis := eye.basis
	var point := eye.origin - basis.z * hold_distance - Vector3.UP * hold_drop

	# Looking steeply down would bring it back into your own body, where it
	# fits only thanks to the collision exception, and bursts out on release.
	var axis := player.global_position
	var flat := Vector3(point.x - axis.x, 0.0, point.z - axis.z)
	var forward := -player.global_transform.basis.z
	var clear := 0.8

	if flat.length() < clear:
		var direction := flat.normalized() if flat.length() > 0.05 else forward
		point.x = axis.x + direction.x * clear
		point.z = axis.z + direction.z * clear

	return point


func _update_carry(delta: float) -> void:
	if not is_instance_valid(held):
		held = null
		# Whatever was holding the hand item out of sight, it is gone.
		released.emit(null, false)
		return

	# Taken out of your hands (a guard lifted it): let go of it as it is.
	if held.freeze or held.get_parent() != _held_parent:
		_release(false, false)
		return

	var to_hold := _hold_point() - held.global_position

	if to_hold.length() > carry_break_distance:
		_carry_strain += delta

		if _carry_strain >= carry_break_time:
			_release(false)
			return
	else:
		_carry_strain = 0.0

	var wanted := to_hold * carry_stiffness

	if wanted.length() > carry_max_speed:
		wanted = wanted.normalized() * carry_max_speed

	held.linear_velocity = wanted
	held.angular_velocity *= 0.85


## Lets go of what you hold: thrown, or set down (`place`: onto whatever is
## under it; not, when it has been taken from you).
func _release(thrown: bool, place := true) -> void:
	var body := held
	held = null
	_holding = false
	_held_parent = null

	if not is_instance_valid(body):
		released.emit(null, thrown)
		return

	body.gravity_scale = _held_gravity_scale
	body.remove_collision_exception_with(player)
	player.remove_collision_exception_with(body)
	body.remove_from_group(&"in_hand")

	if not thrown and place:
		body.linear_velocity = player.velocity

		# Set down means set down: onto whatever is under your hands, quietly.
		# With nothing within reach below, you have let go over a drop, and it
		# will be heard where it lands.
		if not _place_on_surface(body):
			_arm_impact_noise(body)

	released.emit(body, thrown)


## Lowers a released body onto the surface under it, if that is close.
func _place_on_surface(body: RigidBody3D) -> bool:
	var half := _half_height(body)
	var from := body.global_position
	var exclude: Array[RID] = [player.get_rid(), body.get_rid()]
	var query := PhysicsRayQueryParameters3D.create(from, from - Vector3.UP * set_down_reach, 1, exclude)
	query.collide_with_areas = false

	var hit := get_world_3d().direct_space_state.intersect_ray(query)

	if hit.is_empty():
		return false

	var floor_normal: Vector3 = hit["normal"]

	if floor_normal.y < 0.7:
		return false

	var floor_point: Vector3 = hit["position"]
	var upright := Basis(Vector3.UP, body.global_rotation.y)
	var down := from.y - (floor_point.y + half + 0.01)

	# All of it let down there, not just its middle: a table's edge or a man
	# in the way, and it is dropped instead.
	if not _fits_down(body, Transform3D(upright, from), down):
		return false

	body.global_position = Vector3(from.x, floor_point.y + half + 0.01, from.z)
	body.global_rotation = Vector3(0.0, body.global_rotation.y, 0.0)
	body.reset_physics_interpolation()
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	Sfx.play(player, &"thud_wood", body.global_position, -9.0, 1.2)
	return true


## Whether `body`'s own shapes, stood at `at`, go `down` (m) without meeting
## anything: the world, a man, a body, another thing lying there.
func _fits_down(body: RigidBody3D, at: Transform3D, down: float) -> bool:
	var space := get_world_3d().direct_space_state

	for child in body.get_children():
		var holder := child as CollisionShape3D

		if holder == null or holder.shape == null or holder.disabled:
			continue

		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = holder.shape
		query.transform = at * holder.transform
		query.motion = Vector3.DOWN * down
		query.collision_mask = 1 | 2 | GuardBodyScript.LAYER
		query.exclude = [player.get_rid(), body.get_rid()]

		if space.cast_motion(query)[0] < 1.0:
			return false

	return true


## Approximate half-height from the first supported direct-child shape;
## ignores child transforms and returns 0.25 m without a supported shape.
func _half_height(body: RigidBody3D) -> float:
	for child in body.get_children():
		if not (child is CollisionShape3D) or (child as CollisionShape3D).shape == null:
			continue

		var shape: Shape3D = (child as CollisionShape3D).shape

		if shape is BoxShape3D:
			return (shape as BoxShape3D).size.y * 0.5
		if shape is SphereShape3D:
			return (shape as SphereShape3D).radius
		if shape is CapsuleShape3D:
			return (shape as CapsuleShape3D).height * 0.5
		if shape is CylinderShape3D:
			return (shape as CylinderShape3D).height * 0.5

	return 0.25


func _throw() -> void:
	var body := held
	var direction := -_eye().basis.z
	_release(true)

	if body == null:
		return

	# Heavier things fly slower. Anything up to 4 kg gets the full speed.
	var factor := clampf(4.0 / maxf(body.mass, 0.1), 0.4, 1.0)
	body.linear_velocity = direction * throw_speed * factor + player.velocity
	Sfx.play_flat(player, &"whoosh_light", -4.0, 0.85)

	# The body goes into the throw, the head with it; a heavy thing takes a
	# grunt to send.
	if player.get("juice") != null:
		player.juice.on_throw(clampf(body.mass / 4.0, 0.4, 1.5))

	if body.mass >= 6.0 and randf() < 0.6:
		Sfx.play_flat(player, &"effort", -5.0)
	_arm_impact_noise(body)


## The classic distraction: whatever you throw or drop makes its noise where
## it lands, not where you stand.
##
## Impacts are found by watching the velocity: a hit is a sudden change of
## it. That reads the speed from BEFORE the hit, which a contact signal
## cannot do, because by the time it fires the collision has already taken
## the speed away.
func _arm_impact_noise(body: RigidBody3D) -> void:
	_falling[body] = {
		"velocity": body.linear_velocity,
		"armed_at": _game_time,
	}


## Tracks a body’s prior velocity so later impacts emit noise at the landing point.
func arm_impact_noise(body: RigidBody3D) -> void:
	_arm_impact_noise(body)


func _update_falling() -> void:
	if _falling.is_empty():
		return

	var now := _game_time

	for body in _falling.keys():
		if not is_instance_valid(body):
			_falling.erase(body)
			continue

		var entry: Dictionary = _falling[body]
		var before: Vector3 = entry["velocity"]
		var after: Vector3 = body.linear_velocity
		entry["velocity"] = after

		# Picked up again, or come to rest: nothing more to hear.
		if body == held or body.freeze or now - float(entry["armed_at"]) > 6.0:
			_falling.erase(body)
			continue

		if body.sleeping and before.length() < 0.1:
			_falling.erase(body)
			continue

		var jolt := (before - after).length()

		if jolt < impact_min_speed:
			continue

		var speed := before.length()
		_strike_guard_with(body, before)
		var db := clampf(impact_db_base + speed * impact_db_per_speed + body.mass * 0.5, 0.0, impact_db_max)
		SoundBus.emit_sound(body.global_position, db, body, &"impact")
		# Heavy things thud; small things clatter.
		Sfx.play(body, &"thud_wood" if body.mass >= 3.0 else &"clank", body.global_position, Sfx.loudness(db), 1.0 if body.mass >= 3.0 else 1.25)

		# One noise per landing; a bounce after it is too small to count.
		_falling.erase(body)


## Thrown or kicked into a man: it knocks him about, by its weight and
## speed. His raised guard can take it.
func _strike_guard_with(body: RigidBody3D, velocity: Vector3) -> void:
	var speed := velocity.length()

	if speed < 4.0:
		return

	var sphere := SphereShape3D.new()
	sphere.radius = _half_height(body) + 0.35
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, body.global_position)
	query.collision_mask = 2
	query.exclude = [player.get_rid(), body.get_rid()]

	for hit in get_world_3d().direct_space_state.intersect_shape(query, 4):
		var guard: Object = hit.get("collider")

		if guard != null and guard.has_method("take_hit"):
			var damage := clampf(body.mass * speed * 0.45, 3.0, 28.0)
			guard.take_hit(damage, player, &"thrown", body.global_position, velocity.normalized())
			return


## Releases hand-held and shouldered bodies; no-op if neither is carried.
func drop_held() -> void:
	if held != null:
		_release(false)

	if shouldered != null:
		put_down_body()


# Bodies over the shoulder

## Carries a valid body only when hands are empty, locomotion permits it, and combat is idle.
## Freezes/hides the body, disables its collision layers/mask, and emits picked_up.
## An already carried body or unavailable hands cause a no-op.
func shoulder(body: RigidBody3D) -> void:
	if held != null or shouldered != null or not _hands_free() or not _combat_idle():
		return

	shouldered = body
	Sfx.play_flat(player, &"cloth", 2.0, 0.8)

	if body.has_method("finish_fall"):
		body.finish_fall()
	_shouldered_layer = body.collision_layer
	_shouldered_mask = body.collision_mask
	body.freeze = true
	body.visible = false
	# Both, or it is still an invisible obstacle where it lay: other bodies
	# collide with anything whose mask includes their layer.
	body.collision_layer = 0
	body.collision_mask = 0
	_set_target(null)
	picked_up.emit(body)


## Clears shoulder ownership and tries nearby free floor placements. If none fits,
## uses a fallback point in front; restores visibility/collision, lays down or
## unfreezes the body, emits landing noise and released. Invalid bodies stop early.
func put_down_body() -> void:
	var body := shouldered
	shouldered = null

	if not is_instance_valid(body):
		return

	# In front of you, across your path, wherever there is room: turned or
	# shifted if a wall, a table or you are in the way.
	var forward := -player.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()

	var feet_y: float = player.global_position.y - 1.0
	var exclude: Array[RID] = [body.get_rid()]
	var space := get_world_3d().direct_space_state
	var rest := Transform3D.IDENTITY
	var found := false

	for direction in [forward, forward.rotated(Vector3.UP, 0.8), forward.rotated(Vector3.UP, -0.8), -forward]:
		var center: Vector3 = player.global_position + direction * 1.0
		center.y = feet_y + GuardBodyScript.RADIUS + 0.03
		rest = GuardBodyScript.find_rest_transform(space, center, player.rotation.y + PI * 0.5, exclude)

		if rest.origin.distance_to(center) < 1.0 and _body_fits(space, rest, exclude):
			found = true
			break

	if not found:
		var center := player.global_position + forward * 1.0
		center.y = feet_y + GuardBodyScript.RADIUS + 0.03
		rest = Transform3D(Basis(Vector3.UP, player.rotation.y + PI * 0.5), center)

	var spot := rest.origin
	body.global_transform = rest
	body.collision_layer = _shouldered_layer
	body.collision_mask = _shouldered_mask
	body.visible = true

	# A man with a body of his own is let fall and lies as he lands; the old
	# stand-in body is simply set down.
	if not (body.has_method("lay_down") and body.lay_down(rest)):
		body.freeze = false
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO

	# Only now, the man (under the body) put where he lies too: drawn there
	# from the first frame, not slid in from where he was taken up.
	body.reset_physics_interpolation()

	# Setting a body down is not silent.
	SoundBus.emit_sound(spot, 36.0, player, &"body")
	Sfx.play(player, &"body_fall", spot, Sfx.loudness(36.0), 1.1)
	released.emit(body, false)


func _body_fits(space: PhysicsDirectSpaceState3D, rest: Transform3D, exclude: Array[RID]) -> bool:
	var capsule := CapsuleShape3D.new()
	capsule.radius = GuardBodyScript.RADIUS
	capsule.height = GuardBodyScript.LENGTH

	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.collision_mask = 1 | 2 | GuardBodyScript.LAYER
	query.exclude = exclude
	query.transform = Transform3D(rest.basis * Basis(Vector3.RIGHT, PI * 0.5), rest.origin)
	return space.intersect_shape(query, 1).is_empty()


# The blackjack

func _use_item() -> void:
	if _swing_cooldown > 0.0 or _swing_windup >= 0.0 or not _hands_free():
		return

	var item: Dictionary = player.inventory.selected_item()

	if not item.is_empty() and item["id"] in THROWN_TOOLS:
		_throw_tool(item)
		return

	if item.is_empty() or item["id"] != &"blackjack":
		return

	_swing_windup = blackjack_windup
	_swing_cooldown = blackjack_cooldown
	player.spend_attack_press()
	Sfx.play_flat(player, &"whoosh_light", -5.0, 0.8)

	if player.hand != null and player.hand.has_method("play_swing"):
		player.hand.play_swing()


## A tool from your hand (a flash bomb, a water flask): drawn back and thrown,
## leaving your hand a moment into the throw (_release_tool).
func _throw_tool(item: Dictionary) -> void:
	_tool_kind = item["id"]
	_tool_mesh = item.get("mesh")
	_tool_windup = tool_windup
	_swing_cooldown = tool_cooldown
	player.spend_attack_press()
	Sfx.play_flat(player, &"whoosh_light", -8.0, 1.15)

	if player.hand != null and player.hand.has_method("play_throw"):
		player.hand.play_throw()


## Out of your hand along your aim, and one fewer on your belt.
func _release_tool() -> void:
	if _tool_kind == &"" or player.inventory.count_of(_tool_kind) <= 0:
		return

	var eye := _eye()
	var tool: Node3D = ThrownToolScript.new()
	tool.kind = _tool_kind
	player.get_parent().add_child(tool)
	# From in front of your face, a little to the right (the throwing hand).
	tool.launch(eye.origin - eye.basis.z * 0.35 + eye.basis.x * 0.15 - eye.basis.y * 0.05, -eye.basis.z, _tool_mesh, player)
	player.inventory.take_one(_tool_kind)
	_tool_kind = &""


## Returns whether player.inventory contains at least one lockpick.
func can_pick() -> bool:
	return player.inventory.count_of(&"lockpick") > 0


## Picking `lock`: the lockpick to hand, then at it until it gives
## (_update_picking).
func _pick_lock(lock: Node) -> void:
	_picking = lock
	_pick_t = 0.0
	_pick_click = 0.0
	player.inventory.select_by_id(&"lockpick")


## Advances clicks/progress while the target is locked, aimed at, and the player stays still.
## Cancellation clears picking; completion unlocks and emits frobbed without opening the lock.
func _update_picking(delta: float) -> void:
	var lock := _picking

	if not is_instance_valid(lock) or lock.get("locked") != true or target != lock or Vector2(player.velocity.x, player.velocity.z).length() > PICK_STILL or not _hands_free():
		_picking = null
		return

	_pick_t += delta
	_pick_click -= delta

	if _pick_click <= 0.0:
		_pick_click = PICK_CLICK * randf_range(0.7, 1.3)
		Sfx.play(player, &"keys", _target_point, -12.0, randf_range(1.6, 2.1))
		SoundBus.emit_sound(_target_point, PICK_DB, player, &"pick")

	if _pick_t < PICK_TIME:
		return

	_picking = null
	lock.set("locked", false)
	SoundBus.emit_sound(_target_point, 30.0, player, &"unlock")
	Sfx.play(player, &"unlock", _target_point)
	frobbed.emit(lock)


## Returns whether a lockpick target is active.
func picking() -> bool:
	return _picking != null


## Returns active lockpick progress clamped to 0..1, or 0 when inactive.
func pick_progress() -> float:
	return clampf(_pick_t / PICK_TIME, 0.0, 1.0) if _picking != null else 0.0


func _blackjack_lands() -> void:
	var eye := _eye()
	var from := eye.origin
	var to := from - eye.basis.z * blackjack_reach

	# Guards stand on layer 2. The world on layer 1 can be in the way.
	var query := PhysicsRayQueryParameters3D.create(from, to, 3, [player.get_rid()])
	query.collide_with_areas = false

	var hit := get_world_3d().direct_space_state.intersect_ray(query)

	if hit.is_empty():
		return

	var struck: Object = hit.get("collider")

	if struck != null and struck.has_method("knock_out"):
		if struck.knock_out(player):
			# A dull, heavy stop: the club finds the back of his head.
			TimeFx.hitstop(get_tree(), 0.06, 0.06)
			player.juice.add_trauma(0.22)
			player.juice.punch(0.4, 0.0)
		else:
			TimeFx.hitstop(get_tree(), 0.04, 0.08)
			player.juice.add_trauma(0.3)
	else:
		# Wood on stone: a small noise for a wasted swing.
		var point: Vector3 = hit["position"]
		SoundBus.emit_sound(point, 40.0, player, &"knock")
		Sfx.play(player, &"thud", point, -8.0, 1.4)
		Fx.dust(player, point, hit.get("normal", Vector3.UP), 0.4)


# Helpers

## Where you look from: the head, leaning included, without the camera's
## bob, shake and smoothing, which are only for show.
func _eye() -> Transform3D:
	if player.has_method("aim_transform"):
		return player.aim_transform()

	return camera.global_transform

## Registers a missing runtime input action with key or mouse button fallback.
func _ensure_action(action: StringName, key: Key, mouse_button := -1) -> void:
	if InputMap.has_action(action):
		return

	InputMap.add_action(action)

	if key != -1 and key != KEY_NONE:
		var key_event := InputEventKey.new()
		key_event.physical_keycode = key
		InputMap.action_add_event(action, key_event)

	if mouse_button != -1:
		var mouse_event := InputEventMouseButton.new()
		mouse_event.button_index = mouse_button
		InputMap.action_add_event(action, mouse_event)
