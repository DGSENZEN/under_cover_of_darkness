extends "res://scripts/AISystem/Guard.gd"
## The NPC showcase's intruder: a guard's body with the guard's mind switched
## off (Guard.puppet). He wears the archer's hooded outfit dyed near-black and
## carries a sword (Intruder.tscn sets all of it: values an inherited scene
## instances with would undo any set in _init). The guards take him for the
## one they are after: he is the "player" group's only member in the showcase.
##
## He answers to the guards as the player does: how easy he is to see
## (get_exposure, get_sight_points), where to aim at him (get_aim_point), his
## fighting (combat: IntruderCombat, the read-outs PlayerCombat gives them),
## and a blow of theirs meeting him (take_damage, through his guard).
##
## Plot armour: until the director lifts it (fall), nothing takes him under
## ARMOUR_FLOOR of his health.

const IntruderCombatScript := preload("res://scripts/Showcase/IntruderCombat.gd")
const IntruderBrainScript := preload("res://scripts/Showcase/IntruderBrain.gd")

## The least of his health he keeps while armoured. (Over the 35% at which a
## squad would think him all but done and do nothing but press him:
## Squad's "press" plan.)
const ARMOUR_FLOOR := 0.4
## How lit he is, as the player's light gem would read it, is taken at this
## height; crouched, his exposure is this much of it (the player's); moving,
## it grows by up to this much (the player's motion_exposure) at this speed.
const LIGHT_HEIGHT := 1.0
const CROUCH_EXPOSURE := 0.85
const MOTION_EXPOSURE := 0.35
const WALK_SPEED := 1.6
## His head, chest and shins, standing (m above his feet); crouched, these
## times as high.
const SIGHT_HEIGHTS := [1.6, 1.0, 0.3]
const CROUCH_HEIGHT := 0.62
## Where a thrower or an archer aims: his chest.
const AIM_HEIGHT := 1.2

var combat: Node
var is_dead := false
var armoured := true
## The director's hand on how easily he is seen (Act II only: the sneak).
var exposure_scale := 1.0
var crouched := false
## What moves him when neither a blow nor a dodge does (IntruderBrain.drive).
var brain: RefCounted = null


func _ready() -> void:
	super()
	combat = IntruderCombatScript.new(self)
	add_child(combat)
	brain = IntruderBrainScript.new(self, combat)


func _physics_process(delta: float) -> void:
	if combat != null and not _knocked_out:
		combat.tick(delta)

	super(delta)

	# Nor can bleeding take him under it.
	if armoured and not _knocked_out:
		health = maxf(health, ARMOUR_FLOOR * max_health)


func _puppet_drive(delta: float) -> void:
	if brain != null:
		brain.react(delta)

	if combat != null and combat.move(delta):
		return

	if brain != null:
		brain.drive(delta)
	else:
		_stop(delta)


## How lit he is, 0..1 (LightProbe, as the gem would read it).
func get_light_level() -> float:
	return clampf(LightProbe.light_at(self, global_position + Vector3.UP * LIGHT_HEIGHT, [get_rid()]), 0.0, 1.0)


## How easy he is to see, 0..1: light, crouch and motion, as the player's.
func get_exposure() -> float:
	var speed := Vector3(velocity.x, 0.0, velocity.z).length()
	var moving := clampf(speed / WALK_SPEED, 0.0, 1.3)
	var stance := CROUCH_EXPOSURE if crouched else 1.0
	return clampf(get_light_level() * stance * (1.0 + MOTION_EXPOSURE * moving) * exposure_scale, 0.0, 1.0)


## Head, chest and shins: what a guard's sight rays look for.
func get_sight_points() -> Array:
	var scale := CROUCH_HEIGHT if crouched else 1.0
	var points := []

	for height in SIGHT_HEIGHTS:
		points.append(global_position + Vector3.UP * float(height) * scale)

	return points


func get_aim_point() -> Vector3:
	return global_position + Vector3.UP * AIM_HEIGHT * (CROUCH_HEIGHT if crouched else 1.0)


## A guard's blow (GuardFighter._strike), a thrown thing: through his guard
## first, then onto him as any blow lands on a guard (take_hit), so he
## flinches, bleeds and falls as they do.
func take_damage(amount: float, from: Node) -> void:
	if is_dead or _knocked_out or amount <= 0.0:
		return

	if not is_instance_valid(from):
		from = null

	amount = combat.filter_incoming(amount, from)

	if amount <= 0.0:
		return

	var info: Dictionary = from.attack_info() if from != null and from.has_method("attack_info") else {}
	var kind: StringName = &"power" if bool(info.get("heavy", false)) else &"quick"
	var direction := -global_basis.z

	if from is Node3D:
		var away := global_position - (from as Node3D).global_position
		away.y = 0.0

		if away.length() > 0.01:
			direction = away.normalized()

	take_hit(amount, from as Node3D, kind, global_position + Vector3.UP * AIM_HEIGHT, direction)


## Every blow that lands on him (a guard's through take_damage, an arrow or a
## thrown thing straight here): never under his floor while armoured.
func take_hit(damage: float, attacker: Node3D, kind: StringName, point: Vector3, direction: Vector3) -> StringName:
	if armoured:
		damage = minf(damage, maxf(health - ARMOUR_FLOOR * max_health, 0.0))

		# Nothing left to take: he feels it all the same.
		if damage <= 0.0:
			if _rig != null:
				_rig.react_hit(direction, 0.6)

			return &"hit"

	return super(damage, attacker, kind, point, direction)


## For the rig: crossing, swimming and the rest as a guard's; else sneaking.
func activity() -> StringName:
	var own: StringName = super()

	if own != &"" or brain == null:
		return own

	return brain.activity()


## A blow of theirs is coming: his brain decides what to do about it.
func warn_attack(from: Node3D) -> void:
	if brain != null and brain.has_method("on_warned"):
		brain.on_warned(from)


## The director lifts his plot armour: the next blows can kill him.
func fall() -> void:
	armoured = false


func die(attacker: Node3D) -> void:
	is_dead = true
	super(attacker)
