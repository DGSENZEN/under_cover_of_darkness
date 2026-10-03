extends Node3D
## Damage rider for a guard-thrown RigidBody3D. launch() attaches the rider and
## sets the body velocity; each victim can be hit once. The rider frees itself
## after 4 s or after 0.3 s once speed falls below HARMLESS_SPEED.

const Sfx := preload("res://scripts/Audio/Sfx.gd")
const SoundBus := preload("res://scripts/StimuliSystem/SoundBus.gd")

## Slower than this, it is only something rolling about.
const HARMLESS_SPEED := 3.0
## It looks for whoever it meets this far out from its middle.
const REACH := 0.35

var thrower: Node3D = null
var damage := 12.0
var _body: RigidBody3D
var _life := 0.0
var _heading := Vector3.FORWARD
var _hit := {}


## Attaches a damage rider to item and sets its world linear/random angular velocity.
## Returns the rider Node3D; by is the excluded thrower and hit_damage is base damage.
static func launch(item: RigidBody3D, by: Node3D, velocity: Vector3, hit_damage: float) -> Node3D:
	var rider: Node3D = (load("res://scripts/Combat/Thrown.gd") as GDScript).new()
	rider.name = "Thrown"
	rider.thrower = by
	rider.damage = hit_damage
	item.add_child(rider)
	item.linear_velocity = velocity
	item.angular_velocity = Vector3(randf_range(-6.0, 6.0), randf_range(-3.0, 3.0), randf_range(-6.0, 6.0))
	return rider


func _ready() -> void:
	_body = get_parent() as RigidBody3D

	if _body != null and _body.linear_velocity.length() > 0.5:
		_heading = _body.linear_velocity.normalized()


## What it is to a raised guard: a missile from the way it came, cheap to stop;
## and a blow, not a cut.
func attack_info() -> Dictionary:
	return {"type": &"thrown", "ranged": true, "blunt": true, "guard_damage": 7.0, "from_direction": -_heading}


func _physics_process(delta: float) -> void:
	if _body == null or not is_instance_valid(_body):
		queue_free()
		return

	_life += delta
	var velocity := _body.linear_velocity

	if velocity.length() > 0.5:
		_heading = velocity.normalized()

	if _life > 4.0 or (_life > 0.3 and velocity.length() < HARMLESS_SPEED):
		queue_free()
		return

	if not is_instance_valid(thrower):
		thrower = null

	var sphere := SphereShape3D.new()
	sphere.radius = _half_size() + REACH
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, _body.global_position)
	query.collision_mask = 1 | 2
	var exclude: Array[RID] = [_body.get_rid()]

	if thrower is CollisionObject3D:
		exclude.append((thrower as CollisionObject3D).get_rid())

	query.exclude = exclude

	for hit in _body.get_world_3d().direct_space_state.intersect_shape(query, 4):
		var who: Object = hit.get("collider")

		if who == null or _hit.has(who) or who == thrower:
			continue

		if who.has_method("take_hit"):
			# One of his own, in the way.
			_hit[who] = true
			who.take_hit(damage * 0.8, thrower, &"thrown", _body.global_position, _heading)
			_bounce()
		elif who.has_method("take_damage"):
			_hit[who] = true
			who.take_damage(damage, self)
			Sfx.play(_body, &"thud", _body.global_position, 0.0, 1.0 if _body.mass >= 3.0 else 1.25)

			# Something heavy knocks you back a step.
			if who.has_method("shove") and _body.mass >= 3.0:
				who.shove(Vector3(_heading.x, 0.0, _heading.z).normalized() * clampf(_body.mass * 0.4, 1.5, 4.0), 0.18)

			_bounce()


## Off whoever it met: it drops away, spent.
func _bounce() -> void:
	_body.linear_velocity = -_heading * 1.2 + Vector3.UP * 1.0
	SoundBus.emit_sound(_body.global_position, 50.0, _body, &"impact")


func _half_size() -> float:
	for child in _body.get_children():
		var holder := child as CollisionShape3D

		if holder == null or holder.shape == null:
			continue

		if holder.shape is BoxShape3D:
			return (holder.shape as BoxShape3D).size.length() * 0.35

		if holder.shape is SphereShape3D:
			return (holder.shape as SphereShape3D).radius

		if holder.shape is CylinderShape3D:
			return maxf((holder.shape as CylinderShape3D).radius, (holder.shape as CylinderShape3D).height * 0.5)

	return 0.2
