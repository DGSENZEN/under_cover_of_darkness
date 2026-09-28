extends RefCounted
## What a guard has in his hands, and what he picks up (GuardFighter decides
## when; this does it, and the rig shows it: GuardRig.activity):
##   his weapon  knocked off his feet a man may lose his grip on it (never the
##               brute: `grip_loss`); it clatters away and he goes back for it,
##               or for any blade lying near that he can use, unless you stand
##               over it. Without one he fights with fists and boots, and with
##               whatever he can throw.
##   throwing    a crate, a stool, a stone: picked up (a stoop, open to
##               anything), drawn back overhead (your warning), and thrown at
##               a man he cannot reach. It hurts (Thrown.gd), and a raised
##               guard knocks it aside.
##   the bell    a pull on its rope (AlarmBell.gd).
##   a torch     gone out on its wall (Torch.gd): he reaches up to it with his
##               tinder and lights it again (relight).
##   a lantern   searching somewhere dark with the garrison roused, he lights
##               one and holds it up, hanging from his fist by its bail
##               (Hanging.gd); it lights you (and a body in a corner) as any
##               light does. Into a fight he drops it, still burning.
##   his rounds  a man set to walk them with a light (Guard.rounds_light)
##               carries it lit (GuardHabits keeps it so): a lantern held out
##               before him in his sword hand, hanging and swinging from his
##               fist, his blade in its scabbard; or a torch held up in the
##               other, his sword hand free for his blade. Into a fight he
##               drops it as he would the lantern (a torch lies where it
##               falls, still burning).
##   his blade   drawn when he needs it and put by when he does not: GuardRig
##               shows it, from what is in his hands here.
##   evidence    your arrow in a wall, pulled out and taken (GuardLife).

const WeaponScript := preload("res://scripts/Combat/Weapon.gd")
const Lights := preload("res://scripts/Visual/Lights/Lights.gd")
const HumanoidScript := preload("res://scripts/Visual/Humanoid.gd")
const HangingScript := preload("res://scripts/Visual/Hanging.gd")
const ThrownScript := preload("res://scripts/Combat/Thrown.gd")
const Dangers := preload("res://scripts/AISystem/Dangers.gd")
const LightProbe := preload("res://scripts/StimuliSystem/LightProbe.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")

## A stoop to pick something up off the floor: this long, and open to
## anything while it lasts. Then this long to straighten.
const STOOP := 0.55
const RISE := 0.35
## Within this (flat) of the thing, he can reach it.
const REACH := 1.25
## A pull on the bell rope: this long, the bell rung this far into it.
const RING_TIME := 1.6
const RING_AT := 0.55
## Lighting a torch again: this long at it, lit this far into it.
const RELIGHT_TIME := 2.2
const RELIGHT_AT := 1.5
## How hard he throws (m/s), and the most he spends in the air (s).
const THROW_SPEED := 12.0
const THROW_FLIGHT_MAX := 1.3
## A lantern: how bright, how far it reaches; dropped, how long it burns on.
const LANTERN_ENERGY := 1.5
const LANTERN_RANGE := 6.5
const DROPPED_LIGHT_TIME := 25.0
## A torch on his rounds: brighter and wilder than a lantern.
const TORCH_ENERGY := 2.1
const TORCH_RANGE := 7.5
## A torch's flame this far up its stick from his fist; a lantern's flame
## this far below his fist, hanging by its bail.
const TORCH_UP := 0.36
const LANTERN_HANG := 0.22

var guard: CharacterBody3D
## His blade is in his hand (or his crossbow).
var armed := true
## What he carries: "sword", "rapier", "maul" or "crossbow".
var kind: StringName = &"sword"
## Something picked up to throw, and his lantern (lit), if any.
var held: RigidBody3D = null
var lantern: Node3D = null
## His light carried on his rounds: "lantern", "torch", or "" (none, or the
## lantern lit to search by).
var light_kind: StringName = &""

var _stoop := 0.0
var _rise := 0.0
var _item: Node3D = null
## What the thing he stoops for is to him: "weapon", "throwable", "evidence".
var _item_kind: StringName = &""
var _ringing := 0.0
## A torch he is lighting again, how long he has left at it, and whether it
## is lit yet.
var _relight: Node3D = null
var _relighting := 0.0
var _relit := false
var _bell: Node3D = null
var _bell_where := Vector3.ZERO
var _rung := false
var _held_layer := 1
var _held_mask := 1
## What holds his light on his hand (a BoneAttachment3D), gone with it.
var _light_holder: Node = null
## What he threw -> how long until it can strike him again: it leaves his
## hand through him, and once clear of him it is a thing like any other.
var _thrown := {}


func _init(p_guard: CharacterBody3D, carried: StringName) -> void:
	guard = p_guard
	kind = carried


## Every physics frame.
func update(delta: float) -> void:
	if _stoop > 0.0:
		_stoop -= delta

		if _stoop <= 0.0:
			_take()
			_rise = RISE
	elif _rise > 0.0:
		_rise -= delta

	if _ringing > 0.0:
		_ringing -= delta

		if not _rung and RING_TIME - _ringing >= RING_AT:
			_rung = true

			if _bell != null and is_instance_valid(_bell):
				_bell.ring(guard, _bell_where)

		if _ringing <= 0.0:
			_bell = null

	if _relighting > 0.0:
		_relighting -= delta

		if _relight != null and is_instance_valid(_relight):
			# Facing it as he works.
			var to: Vector3 = (_relight.flame_position() if _relight.has_method("flame_position") else _relight.global_position) - guard.global_position
			guard.rotation.y = lerp_angle(guard.rotation.y, atan2(-to.x, -to.z), 1.0 - exp(-8.0 * delta))

			if not _relit and RELIGHT_TIME - _relighting >= RELIGHT_AT:
				_relit = true
				_relight.relight(guard)

		if _relighting <= 0.0:
			_relight = null

	if not _thrown.is_empty():
		_clear_thrown(delta)


## Stooping, straightening, at the bell rope or lighting a torch: he can do
## nothing else.
func busy() -> bool:
	return _stoop > 0.0 or _rise > 0.0 or _ringing > 0.0 or _relighting > 0.0


## Anything in his hands to show (GuardRig): "pickup", "ring", "hold" (a thing
## to throw), "carry_lantern" or "carry_torch" (his light on his rounds), or
## "".
func activity() -> StringName:
	if _stoop > 0.0 or _rise > 0.0:
		return &"pickup"

	if _ringing > 0.0:
		return &"ring"

	if _relighting > 0.0:
		return &"relight"

	if held != null:
		return &"hold"

	if lantern != null and light_kind != &"" and int(guard.state) != 4:
		return &"carry_lantern" if light_kind == &"lantern" else &"carry_torch"

	return &""


## 0..1 through the stoop and back up (for the rig).
func pickup_progress() -> float:
	if _stoop > 0.0:
		return (1.0 - _stoop / STOOP) * 0.62

	if _rise > 0.0:
		return 0.62 + (1.0 - _rise / RISE) * 0.38

	return 0.0


## 0..1 through a pull on the rope.
func ring_progress() -> float:
	return clampf(1.0 - _ringing / RING_TIME, 0.0, 1.0)


## The torch he is lighting again (for the rig: his hand goes up to it), and
## how far through it he is (0..1).
func relighting() -> Node3D:
	return _relight if _relighting > 0.0 and _relight != null and is_instance_valid(_relight) else null


func relight_progress() -> float:
	return clampf(1.0 - _relighting / RELIGHT_TIME, 0.0, 1.0)


# ---------------------------------------------------------------------------
# Picking things up
# ---------------------------------------------------------------------------

## Stoops for `item` (a "weapon", a "throwable", or "evidence"): it is his,
## once he has straightened, if it is still within reach.
func stoop_for(item: Node3D, what: StringName) -> void:
	if busy() or item == null or not is_instance_valid(item):
		return

	_item = item
	_item_kind = what
	_stoop = STOOP
	Dangers.claim(item, guard)
	guard.velocity.x = 0.0
	guard.velocity.z = 0.0


## What he is stooping for ("weapon", "throwable", "evidence"), or "".
func stooping_for() -> StringName:
	return _item_kind if _stoop > 0.0 and _item != null else &""


## Struck, knocked about: whatever he was stooping for or pulling at, he
## leaves (the bell, if it had not rung yet, stays silent).
func interrupt() -> void:
	if _item != null and is_instance_valid(_item):
		Dangers.unclaim(_item, guard)

	_item = null
	_stoop = 0.0
	_rise = 0.0

	if not _rung:
		_ringing = 0.0
		_bell = null

	stop_relighting()


## Within reach of `item` (flat, and not far above or below his feet).
func can_reach(item: Node3D) -> bool:
	if item == null or not is_instance_valid(item):
		return false

	var off := item.global_position - guard.global_position
	return Vector2(off.x, off.z).length() <= REACH and off.y > -0.6 and off.y < 1.6


func _take() -> void:
	var item := _item
	_item = null

	if item == null or not is_instance_valid(item) or item.is_queued_for_deletion():
		return

	if not can_reach(item) or not _still_there(item):
		# Kicked away from under his hand, or taken up by someone else.
		Dangers.unclaim(item, guard)
		return

	Sfx.play(guard, &"grab", item.global_position, -3.0)

	match _item_kind:
		&"weapon":
			_rearm(item)
		&"throwable":
			_hold(item as RigidBody3D)
		_:
			item.queue_free()


## What he stooped for is still lying there to take: not in your hands, and
## (to throw) still a thing to throw, (a weapon) not in another man's.
func _still_there(item: Node3D) -> bool:
	if item.is_in_group(&"in_hand"):
		return false

	match _item_kind:
		&"throwable":
			return item is RigidBody3D and Dangers.throwable(item as RigidBody3D, guard)
		&"weapon":
			return not (item is RigidBody3D and (item as RigidBody3D).freeze)

	return true


## The weapons he can fight with: his own kind, and what is near enough to it.
func usable() -> Array:
	match kind:
		&"crossbow":
			return [&"crossbow"]
		&"maul":
			return [&"maul", &"sword", &"rapier"]

	return [&"sword", &"rapier"]


func _rearm(item: Node3D) -> void:
	var taken: StringName = item.get_meta(&"weapon_kind", kind)
	item.queue_free()
	armed = true

	if guard._rig != null and guard._rig.has_method("take_weapon"):
		guard._rig.take_weapon(taken)

	Sfx.play(guard, &"blade_draw", guard.eye_position() - Vector3.UP * 0.5, -2.0)
	guard.say(&"rearmed", 0.7)


func _hold(item: RigidBody3D) -> void:
	if item == null:
		return

	held = item
	_held_layer = item.collision_layer
	_held_mask = item.collision_mask
	item.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	item.freeze = true
	item.collision_layer = 0
	item.collision_mask = 0
	var hand: Node3D = guard._rig.throwing_hand() if guard._rig != null and guard._rig.has_method("throwing_hand") else guard
	item.reparent(hand, false)
	item.transform = Transform3D(Basis.IDENTITY, Vector3(0.0, 0.12, 0.05))
	item.reset_physics_interpolation()


## Lets go of whatever he holds to throw, where he stands.
func drop_held() -> void:
	var item := held
	held = null

	if item == null or not is_instance_valid(item):
		return

	item.reparent(guard.get_parent(), true)
	item.collision_layer = _held_layer
	item.collision_mask = _held_mask
	item.freeze = false
	Dangers.unclaim(item, guard)


## Throws what he holds at `aim` (where he wants it to meet `target`, or to
## land). Let go over his shoulder, flat and fast if the way is clear, lobbed
## higher if not (onto a roof, over a wall). True if there was anything.
func throw_held(aim: Vector3, target: Node3D = null) -> bool:
	var item := held
	held = null

	if item == null or not is_instance_valid(item):
		return false

	item.reparent(guard.get_parent(), true)
	var from: Vector3 = guard.eye_position() - guard.global_basis.z * 0.35 + Vector3.UP * 0.1
	item.global_position = from
	item.collision_layer = _held_layer
	item.collision_mask = _held_mask
	item.freeze = false
	item.add_collision_exception_with(guard)
	_thrown[item] = 0.5
	Dangers.unclaim(item, guard)
	var gravity := float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)) * item.gravity_scale
	var gap := aim - from
	var flight := clampf(Vector2(gap.x, gap.z).length() / THROW_SPEED, 0.2, THROW_FLIGHT_MAX)
	var velocity := gap / flight + Vector3.UP * 0.5 * gravity * flight

	for attempt in 3:
		if _arc_clear(from, velocity, gravity, flight, [item, target]):
			break

		flight *= 1.35
		velocity = gap / flight + Vector3.UP * 0.5 * gravity * flight

	var damage := clampf(item.mass * 2.6 + 6.0, 8.0, 26.0)
	ThrownScript.launch(item, guard, velocity, damage)
	Sfx.play(guard, &"whoosh", from, 0.0, 0.8)
	return true


## What he threw strikes him again (throw it back at him) once it has flown
## clear of him.
func _clear_thrown(delta: float) -> void:
	for item in _thrown.keys():
		if not is_instance_valid(item):
			_thrown.erase(item)
			continue

		_thrown[item] -= delta

		if _thrown[item] > 0.0:
			continue

		# Still at his feet: not out of him yet.
		var off: Vector3 = (item as Node3D).global_position - guard.global_position

		if Vector2(off.x, off.z).length() < 0.9 and absf(off.y) < 2.0:
			continue

		_thrown.erase(item)
		(item as PhysicsBody3D).remove_collision_exception_with(guard)


## Whether a throw from `from` at `velocity` (under `gravity`) goes through
## `flight` seconds (all but its very end, where it meets its mark) without
## striking the world. `skip`: things it may pass through (itself, its mark).
func _arc_clear(from: Vector3, velocity: Vector3, gravity: float, flight: float, skip: Array) -> bool:
	var exclude: Array[RID] = [guard.get_rid()]

	for thing in skip:
		if thing is CollisionObject3D and is_instance_valid(thing):
			exclude.append((thing as CollisionObject3D).get_rid())

	var space := guard.get_world_3d().direct_space_state
	var last := from
	var steps := 8

	for i in range(1, steps + 1):
		var t := flight * 0.92 * float(i) / float(steps)
		var at := from + velocity * t + Vector3.DOWN * 0.5 * gravity * t * t
		var ray := PhysicsRayQueryParameters3D.create(last, at, 1, exclude)

		if not space.intersect_ray(ray).is_empty():
			return false

		last = at

	return true


# ---------------------------------------------------------------------------
# His weapon
# ---------------------------------------------------------------------------

## His grip goes (thrown off his feet): the weapon clatters away along
## `push`. Returns it, lying in the world. Put by (in its scabbard), it stays
## on him, unless `even_put_by` (thrown down to beg).
func lose_weapon(push := Vector3.ZERO, even_put_by := false) -> RigidBody3D:
	if not armed or guard._rig == null:
		return null

	drop_held()
	var dropped: RigidBody3D = guard._rig.drop_weapon(even_put_by)

	if dropped == null:
		return null

	mark_dropped(dropped, kind)
	dropped.linear_velocity += Vector3(push.x, 0.0, push.z) * 0.35
	armed = false
	return dropped


## A weapon lying where it fell, of `weapon_kind`: someone may pick it up.
static func mark_dropped(dropped: RigidBody3D, weapon_kind: StringName) -> void:
	if dropped == null:
		return

	dropped.add_to_group(&"dropped_weapons")
	dropped.set_meta(&"weapon_kind", weapon_kind)


# ---------------------------------------------------------------------------
# The bell
# ---------------------------------------------------------------------------

## A pull on `bell`'s rope, calling everyone to `where`.
## Lighting a torch again, left off (struck, or into a fight): not lit yet,
## it stays out for whoever notices it next.
func stop_relighting() -> void:
	if _relighting <= 0.0:
		return

	if not _relit and _relight != null and is_instance_valid(_relight) and _relight.has_meta(&"noticed"):
		_relight.remove_meta(&"noticed")

	_relighting = 0.0
	_relight = null


## Lights `light` (a torch gone out) again: at it RELIGHT_TIME, lit
## RELIGHT_AT into it.
func relight(light: Node3D) -> void:
	if light == null or not is_instance_valid(light):
		return

	# Hands full: not lit, so it stays out for whoever notices it next.
	if busy():
		if light.has_meta(&"noticed"):
			light.remove_meta(&"noticed")
		return

	_relight = light
	_relighting = RELIGHT_TIME
	_relit = false
	guard.velocity.x = 0.0
	guard.velocity.z = 0.0


func ring_bell(bell: Node3D, where: Vector3) -> void:
	if busy() or bell == null:
		return

	_bell = bell
	_bell_where = where
	_ringing = RING_TIME
	_rung = false
	guard.velocity.x = 0.0
	guard.velocity.z = 0.0


# ---------------------------------------------------------------------------
# The lantern
# ---------------------------------------------------------------------------

func light_lantern() -> void:
	if lantern != null or guard._rig == null or guard._rig.get("man") == null:
		return

	lantern = _hang_lantern(&"hand_l", 0.08)
	Sfx.play(guard, &"ignite", guard.eye_position() - Vector3.UP * 0.4, -6.0, 1.3)
	LightProbe.invalidate()


## His light for his rounds (`kind` "lantern" or "torch"), lit and carried:
## the lantern held out in his sword hand (his blade at his belt), the torch
## held up in the other.
func carry_light(kind: StringName) -> void:
	if lantern != null or guard._rig == null or guard._rig.get("man") == null:
		return

	if kind == &"torch":
		lantern = _torch()
		# Its stick through his fist, the flame at its head, over his hand.
		_light_holder = guard._rig.man.attach(&"hand_l", lantern, HumanoidScript.FIST_L * Transform3D(Basis.IDENTITY, Vector3(0.0, TORCH_UP, 0.0)))
	else:
		# His blade in its scabbard while his hand holds the light (GuardRig).
		lantern = _hang_lantern(&"hand_r", 0.06)

	light_kind = kind
	Sfx.play(guard, &"ignite", guard.eye_position() - Vector3.UP * 0.4, -8.0, 1.2)
	LightProbe.invalidate()


## A torch (Lights.carried_torch): a stick with a head of pitch-soaked rag,
## the flame on it (the flame is the node: the stick hangs down from it).
func _torch() -> Node3D:
	var flame: Node3D = Lights.carried_torch()
	flame.overrides = {"energy": TORCH_ENERGY, "light_range": TORCH_RANGE}
	return flame


## A lantern (Lights.carried_lantern) hanging by its bail from his fist on
## `bone` (Hanging.gd), wavering by `flicker`. The flame is returned (what
## hangs is its node, the lantern round it).
func _hang_lantern(bone: StringName, flicker: float) -> Node3D:
	var flame: Node3D = Lights.carried_lantern()
	flame.overrides = {"energy": LANTERN_ENERGY, "light_range": LANTERN_RANGE, "flicker": flicker}
	var grip := Node3D.new()
	grip.name = "Bail"
	_light_holder = guard._rig.man.attach(bone, grip, HumanoidScript.FIST_R if bone == &"hand_r" else HumanoidScript.FIST_L)
	var hanging: Node3D = HangingScript.new()
	hanging.length = LANTERN_HANG
	grip.add_child(hanging)
	hanging.add_child(flame)
	# Its bail's grip in his fist, the lantern below it.
	flame.position = -flame.socket(&"grip")
	return flame


## Out: back on his belt.
func douse() -> void:
	if lantern == null:
		return

	if is_instance_valid(lantern):
		lantern.queue_free()

	lantern = null
	_light_gone()
	LightProbe.invalidate()


## His hand free of the light (his blade back in it, if he wants it:
## GuardRig), and nothing left on his hand to hold one.
func _light_gone() -> void:
	light_kind = &""

	if _light_holder != null and is_instance_valid(_light_holder):
		_light_holder.queue_free()

	_light_holder = null


## Let fall where he stands, still burning a while (into a fight). A torch
## lies where it falls, its flame at one end.
func drop_lantern() -> void:
	var flame := lantern
	var torch := light_kind == &"torch"
	lantern = null
	_light_gone()

	if flame == null or not is_instance_valid(flame) or not guard.is_inside_tree():
		return

	var at := flame.global_position
	var body := RigidBody3D.new()
	body.name = "DroppedLantern"
	body.mass = 1.0
	body.collision_layer = 0
	body.collision_mask = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.62, 0.07, 0.07) if torch else Vector3(0.14, 0.2, 0.14)
	shape.shape = box
	body.add_child(shape)
	guard.get_parent().add_child(body)
	body.global_position = at
	flame.reparent(body, false)
	# The torch along the body, its stick one way from the flame; the lantern
	# in its cage.
	flame.transform = Transform3D(Basis(Vector3.BACK, -PI * 0.5), Vector3(0.34, 0.0, 0.0)) if torch else Transform3D.IDENTITY
	body.linear_velocity = guard.velocity * 0.4 + Vector3(randf_range(-0.8, 0.8), 1.2, randf_range(-0.8, 0.8))
	body.add_to_group(&"dropped_lights")
	body.reset_physics_interpolation()
	Sfx.play(body, &"clank", at, -6.0, 1.2)
	# It burns on a while, gutters, and is gone.
	var tween := body.create_tween()
	tween.tween_interval(DROPPED_LIGHT_TIME)
	tween.tween_property(flame, "energy", 0.0, 3.0)
	tween.tween_callback(body.queue_free)
	LightProbe.invalidate()
