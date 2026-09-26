extends StaticBody3D
## An arrow. It flies itself under gravity, casting a ray along each step of
## its path, so even a fast arrow never passes through a thin wall.
##
##   a guard   it hurts him; above the shoulders, far more
##   the world it sticks, makes a noise there (a distraction, as in Thief),
##             and can be picked up again
##
## In flight it collides with nothing. Stuck, it sits on layer 3 like a body:
## the frob ray finds it, the player's feet do not.

const SoundBus := preload("res://scripts/StimuliSystem/SoundBus.gd")
const RagdollScript := preload("res://scripts/Visual/Ragdoll.gd")
const WeaponScript := preload("res://scripts/Combat/Weapon.gd")
const Fx := preload("res://scripts/Visual/Fx.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")

signal struck(target: Object, damage: float, headshot: bool)

@export var gravity := 9.8
@export var stick_db := 40.0
@export var lifetime := 10.0

var velocity := Vector3.ZERO
var damage := 40.0
var headshot_multiplier := 2.5
var shooter: Node3D = null
var stuck := false
var taken := false

var _life := 0.0
## Which way it was flying when it hit.
var _heading := Vector3.FORWARD
var _visual: MeshInstance3D
## Seconds since it stuck, while the shaft still quivers; -1 when still.
var _quiver := -1.0
var _quiver_axis := Vector3.RIGHT


func _ready() -> void:
	collision_layer = 0
	collision_mask = 0

	var visual := MeshInstance3D.new()
	visual.name = "MeshInstance3D"
	visual.mesh = WeaponScript.arrow_mesh()
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)
	_visual = visual
	# The shaft's quiver is animated every frame: drawn as set, riding the
	# arrow's own interpolated transform.
	visual.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.12, 0.12, 0.7)
	shape.shape = box
	add_child(shape)


func launch(from: Vector3, launch_velocity: Vector3, hit_damage: float, by: Node3D, head_multiplier: float) -> void:
	global_position = from
	velocity = launch_velocity
	damage = hit_damage
	shooter = by
	headshot_multiplier = head_multiplier
	_face_travel()
	# Drawn from here, not flown in from wherever it was made.
	reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	if stuck:
		return

	_life += delta

	if _life > lifetime:
		queue_free()
		return

	var next_velocity := velocity + Vector3.DOWN * gravity * delta
	var travel := (velocity + next_velocity) * 0.5 * delta
	var from := global_position
	var to := from + travel

	var exclude: Array[RID] = []

	# Whoever loosed it may be gone (dead, or the level moved on) while it
	# flies.
	if not is_instance_valid(shooter):
		shooter = null

	if shooter is CollisionObject3D:
		exclude.append((shooter as CollisionObject3D).get_rid())

	# Bodies too: a man lying on the floor.
	var query := PhysicsRayQueryParameters3D.create(from, to, 1 | 2 | 4, exclude)
	query.collide_with_areas = false
	# Loosed from right against a wall, it starts inside it: that still hits.
	query.hit_from_inside = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)

	if not hit.is_empty():
		_hit(hit, travel.normalized())
		return

	global_position = to
	velocity = next_velocity
	_face_travel()
	# A faint line behind it, so a shot can be followed. The arrow is drawn up
	# to a tick behind where physics has it; the line starts behind that.
	var tick := 1.0 / float(maxi(Engine.physics_ticks_per_second, 1))
	Fx.streak(self, global_position - velocity * tick, velocity)


func _hit(hit: Dictionary, direction: Vector3) -> void:
	var collider: Object = hit.get("collider")
	var point: Vector3 = hit["position"]

	if not is_instance_valid(collider):
		collider = null

	# A limb: its man's, if he is down but alive. In a dead man it goes in,
	# stays, and goes where he goes.
	if collider is PhysicalBone3D:
		var limb := collider as PhysicalBone3D
		var owner_now := RagdollScript.owner_of(limb)

		if owner_now != null and owner_now.has_method("take_hit"):
			collider = owner_now
		else:
			limb.linear_velocity += direction * 1.5
			Fx.blood(self, point, direction, 0.35)
			Sfx.play(self, &"arrow_flesh", point, -3.0)
			stuck = true
			global_position = point - direction * 0.12
			collision_layer = 0
			_stick_in.call_deferred(limb)
			struck.emit(owner_now, 0.0, false)
			return

	# You: through your guard or not, by what you do with it (PlayerCombat).
	if collider != null and collider.has_method("take_damage") and not collider.has_method("take_hit"):
		_heading = direction
		collider.take_damage(damage, self)
		struck.emit(collider, damage, false)
		queue_free()
		return

	if collider != null and collider.has_method("take_hit"):
		var target := collider as Node3D
		var eye: float = target.get("eye_height") if target.get("eye_height") != null else 1.65
		var headshot := point.y - target.global_position.y >= eye - 0.25
		var dealt := damage * (headshot_multiplier if headshot else 1.0)
		# Into him: the arrow's own sound (the guard voices nothing for it).
		Sfx.play(self, &"arrow_flesh", point, 0.0 if headshot else -1.5, 0.95 if headshot else 1.0)
		collider.take_hit(dealt, shooter, &"arrow", point, direction)
		struck.emit(collider, dealt, headshot)
		queue_free()
		return

	# A rope: cut through, and the arrow goes on its way (gone).
	if collider is StaticBody3D and collider.has_method("strike"):
		collider.strike(&"arrow", point, direction)
		queue_free()
		return

	if collider is RigidBody3D:
		(collider as RigidBody3D).apply_impulse(direction * velocity.length() * 0.05, point - (collider as RigidBody3D).global_position)

		# A powder barrel, say.
		if collider.has_method("strike"):
			collider.strike(&"arrow", point, direction)

	# Into the world: half its length in, and it stays, quivering.
	stuck = true
	global_position = point - direction * 0.15
	collision_layer = 4
	SoundBus.emit_sound(point, stick_db, self, &"arrow")

	var normal: Vector3 = hit.get("normal", -direction)
	var surface := "stone"

	if collider is Node and (collider as Node).has_meta(&"surface"):
		surface = String((collider as Node).get_meta(&"surface"))
	elif collider is RigidBody3D or (collider != null and collider.has_method("frob")):
		surface = "wood"

	Fx.dust(self, point, normal, 0.55, surface)
	Sfx.play(self, &"arrow_thunk", point)

	# In something that moves (a crate, a door), it goes with it.
	if collider is RigidBody3D or collider is AnimatableBody3D:
		_stick_in.call_deferred(collider)
	var side := direction.cross(Vector3.UP)
	_quiver_axis = side.normalized() if side.length() > 0.01 else Vector3.RIGHT
	_quiver = 0.0
	struck.emit(collider, 0.0, false)


## What it is, to a raised guard: a missile from over there, cheap to stop.
func attack_info() -> Dictionary:
	return {"type": &"arrow", "ranged": true, "guard_damage": 6.0, "from_direction": -_heading}


func _stick_in(body: Node) -> void:
	if not is_instance_valid(body) or not is_inside_tree():
		return

	reparent(body, true)
	reset_physics_interpolation()


## Stuck: the shaft shivers about where it went in, and settles. (In flight
## it moves on physics ticks, and physics interpolation draws it smoothly.)
func _process(delta: float) -> void:
	if _visual == null or not stuck or _quiver < 0.0:
		return

	_quiver += delta

	if _quiver > 0.9:
		_quiver = -1.0
		_visual.transform = Transform3D.IDENTITY
		return

	var angle := sin(_quiver * 48.0) * 0.07 * exp(-_quiver * 6.5)
	var axis: Vector3 = global_basis.inverse() * _quiver_axis
	var turn := Basis(axis.normalized(), angle)
	# It pivots at the surface, 0.15 m along its length from its middle.
	var pivot := Vector3(0.0, 0.0, -0.15)
	_visual.transform = Transform3D(turn, pivot - turn * pivot)


func _face_travel() -> void:
	if velocity.length_squared() > 0.001:
		var forward := velocity.normalized()
		var up := Vector3.UP if absf(forward.dot(Vector3.UP)) < 0.98 else Vector3.FORWARD
		global_basis = Basis.looking_at(forward, up)


# Picking it back up --------------------------------------------------------

func get_prompt(_player: Node) -> String:
	return "Take arrow" if stuck else ""


func frob(player: Node) -> void:
	if not stuck or taken:
		return

	taken = true
	player.inventory.add_belt_item(&"arrows", "arrows", WeaponScript.arrow_mesh(), 1)
	queue_free()
