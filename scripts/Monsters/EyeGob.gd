extends Node3D
## What a turned eye spits: a gob of its own curse, wet meat with an eye in it, looking at you the
## whole way. Slow enough to step out of. It hurts, and it puts the evil eye on you, or opens another.
## A wall or the Ward stops it. Whip it, and it goes back the way you hit it, and hurts what it
## meets, and never you. It outlives the eye that spat it.

const Sfx := preload("res://scripts/Audio/Sfx.gd")
const Fx := preload("res://scripts/Visual/Fx.gd")
const WardScript := preload("res://scripts/Magic/Ward.gd")
const EyeBody := preload("res://scripts/Monsters/EyeBody.gd")
const MODEL := preload("res://assets/monsters/eye_gob.glb")

const SPEED := 9.0
const DAMAGE := 8.0
## How near the line down your middle it finds you (m), and what it finds when whipped back.
const REACH := 0.5
const BAT_SPEED := 14.0
const BAT_HURT := 40.0
const BAT_MEET := 0.95
const EXPOSES := 2.0
const LASTS := 4.0
## On you: what it does if you carry no curse yet.
const CURSE_TIME := 8.0
## How it looks: its size on the unit model, and a low sick light to find it by in the dark.
const SIZE := 0.17
const GLOW := Color(1.0, 0.3, 0.08)
const GLOW_ENERGY := 0.7
const GLOW_RANGE := 2.2
const DRIP_EVERY := 0.07
## How it wobbles as it flies.
const WOBBLE := 0.1
const WOBBLE_RATE := 17.0
## The whip finds it this far off (Revolver.try_whip), and it counts as something to hit.
var whip_reach := 3.2
var health := 1.0
var asleep := false
var velocity := Vector3.ZERO
## If it kills you, how you die (PlayerDeath.gd).
var kills_as: StringName = &"eyes"

var _by: Node3D
var _batted := false
var _life := 0.0
var _drip_in := 0.0
var _meat: Node3D

static var _look: ShaderMaterial


static func spat_at(context: Node, from: Vector3, at: Vector3, by: Node3D) -> Node3D:
	var gob: Node3D = (load("res://scripts/Monsters/EyeGob.gd") as GDScript).new()
	context.add_child(gob)
	gob.global_position = from
	gob._launch(at, by)
	return gob


func is_batted() -> bool:
	return _batted


## Where a blow aims at it (Revolver._update_whip): itself, there being no more of it.
func eye_position() -> Vector3:
	return global_position


func _launch(at: Vector3, by: Node3D) -> void:
	add_to_group(&"eye_gobs")
	_by = by
	velocity = (at - global_position).normalized() * SPEED
	_build_look()
	reset_physics_interpolation()
	Sfx.play(self, &"flesh", global_position, -3.0, 0.8)


## Struck: the whip or the boot sends it back along the blow.
func take_hit(_damage: float, attacker: Node3D, hit_kind: StringName, _point: Vector3, direction: Vector3) -> StringName:
	if hit_kind == &"power" or hit_kind == &"kick" or hit_kind == &"blast":
		_batted = true
		_by = attacker
		velocity = direction.normalized() * BAT_SPEED
		_life = 0.0
		Sfx.play(self, &"thud", global_position, -3.0, 1.4)
		return &"weak"

	return &"none"


func _physics_process(delta: float) -> void:
	_life += delta

	if _life >= LASTS:
		queue_free()
		return

	if velocity.length() > 0.01:
		look_at(global_position + velocity, Vector3.UP if absf(velocity.normalized().y) < 0.99 else Vector3.RIGHT)

	var wobble := sin(_life * WOBBLE_RATE) * WOBBLE
	_meat.scale = Vector3(1.0 + wobble, 1.0 - wobble, 1.0 + wobble * 0.5)
	_drip_in -= delta

	if _drip_in <= 0.0 and velocity.length() > 0.01:
		_drip_in = DRIP_EVERY
		Fx.drip(self, global_position, 0.09)

	var from := global_position
	var to := from + velocity * delta

	if not _batted:
		var warded := WardScript.stopped_by(from, to, _by if is_instance_valid(_by) else null)

		if not warded.is_empty():
			WardScript.turned_aside(self, warded["at"], velocity.normalized(), warded["ward"])
			queue_free()
			return

	# (You stand on the walls' layer. It meets you by reach, below.)
	var you_not: Array[RID] = []

	for you in get_tree().get_nodes_in_group(&"player"):
		you_not.append((you as CollisionObject3D).get_rid())

	var wall := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1, you_not))

	if not wall.is_empty():
		_burst(wall["position"], wall["normal"])
		return

	if _batted:
		if _meets_a_monster():
			return
	elif _meets_you():
		return

	global_position = to


func _meets_you() -> bool:
	for you in get_tree().get_nodes_in_group(&"player"):
		var at: Vector3 = (you as Node3D).global_position
		var nearest := Vector3(at.x, clampf(global_position.y, at.y - 0.5, at.y + 0.5), at.z)

		if global_position.distance_to(nearest) > REACH or you.get("is_dead") == true:
			continue

		if you.get("combat") != null and you.combat.is_dodging():
			return false

		you.take_damage(DAMAGE, self)
		_curse(you)
		var juice = you.get("juice")

		if juice != null:
			juice.add_trauma(0.14)

		_burst(global_position, -velocity.normalized())
		return true

	return false


func _curse(you: Node) -> void:
	var bearer: Node = you.get("statuses")

	if bearer == null or bearer.has(&"cleansed"):
		return

	if bearer.has(&"evil_eye"):
		if you.get("curse") != null:
			you.curse.deepen()
	else:
		bearer.apply(&"evil_eye", CURSE_TIME)


func _meets_a_monster() -> bool:
	for other in get_tree().get_nodes_in_group(&"monsters"):
		if not other.dead and not other.asleep and other.global_position.distance_to(global_position) <= BAT_MEET:
			other.round_hint = &"lead"
			other.take_hit(BAT_HURT, _by if is_instance_valid(_by) else null, &"kick", other.global_position, velocity.normalized())

			if is_instance_valid(other) and not other.dead:
				other.statuses.apply(&"exposed", EXPOSES)
				other.exposed_now.emit()

			_burst(global_position, -velocity.normalized())
			return true

	return false


func _burst(at: Vector3, normal: Vector3) -> void:
	Fx.blood(self, at, normal, 1.6)
	Sfx.play(self, &"flesh_heavy", at, -4.0, 1.25)
	queue_free()


func _build_look() -> void:
	if _look == null:
		_look = EyeBody._painted_look(EyeBody.FleshShader, 1.0)

	var made: Node3D = MODEL.instantiate()
	made.scale = Vector3.ONE * SIZE
	add_child(made)

	for part in made.find_children("*", "MeshInstance3D", true, false):
		part.set_surface_override_material(0, _look)
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_meat = made.find_child("Meat", true, false)
	var glow := OmniLight3D.new()
	glow.light_color = GLOW
	glow.light_energy = GLOW_ENERGY
	glow.omni_range = GLOW_RANGE
	glow.shadow_enabled = false
	add_child(glow)
