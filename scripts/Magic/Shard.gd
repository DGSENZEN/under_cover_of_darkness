extends StaticBody3D
## Shard (Obsidian, a hand spell): a splinter of black glass loosed from the
## circle, flying straight and very fast. Swept by a ray each tick, as an
## arrow is (Arrow.gd), with no drop. Into a man it cuts (a "shard"): it
## bleeds, and if it kills, it can take off the limb it struck. On the world
## it bursts into glass dust and is gone. Quiet beside the gun.

const SoundBus := preload("res://scripts/StimuliSystem/SoundBus.gd")
const RagdollScript := preload("res://scripts/Visual/Ragdoll.gd")
const Fx := preload("res://scripts/Visual/Fx.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")
const WardScript := preload("res://scripts/Magic/Ward.gd")
const MagicFx := preload("res://scripts/Visual/MagicFx.gd")

signal struck(target: Object, damage: float)

const SPEED := 70.0
const DAMAGE := 40.0
const LIFETIME := 3.0
## Its hiss as it goes, and the crack where it lands.
const HISS_DB := 36.0
## How fast it spins about its length (radians a second).
const SPIN := 14.0
## Struck this close to a limb's bone, a killing shard takes that limb.
const LIMB_REACH := 0.16

var velocity := Vector3.ZERO
var damage := DAMAGE
var shooter: Node3D = null

var _life := 0.0
## How far it has turned about its length (radians).
var spin := 0.0
var _visual: MeshInstance3D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	add_to_group(&"shards")
	# A long splinter of black glass, its point along the flight (-Z).
	_visual = MeshInstance3D.new()
	_visual.name = "MeshInstance3D"
	_visual.mesh = MagicFx.splinter_mesh(0.03, 0.2, 0.012)
	_visual.material_override = MagicFx.glass_look()
	_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_visual)
	_turn()


## Its length along the flight (-Z), turned `spin` about it.
func _turn() -> void:
	_visual.transform = Transform3D(Basis(Vector3.FORWARD, spin) * Basis(Vector3.RIGHT, -PI * 0.5), Vector3.ZERO)


func launch(from: Vector3, launch_velocity: Vector3, hit_damage: float, by: Node3D) -> void:
	global_position = from
	velocity = launch_velocity
	damage = hit_damage
	shooter = by
	_face_travel()
	reset_physics_interpolation()
	SoundBus.emit_sound(from, HISS_DB, by, &"shard")
	Sfx.play(self, &"whoosh_light", from, -6.0, 1.6)


func _physics_process(delta: float) -> void:
	_life += delta

	if _life > LIFETIME:
		queue_free()
		return

	if not is_instance_valid(shooter):
		shooter = null

	var from := global_position
	var to := from + velocity * delta
	var exclude: Array[RID] = []

	if shooter is CollisionObject3D:
		exclude.append((shooter as CollisionObject3D).get_rid())

	# A ward in the way (not its owner's own): turned aside into its smoke.
	var warded := WardScript.stopped_by(from, to, shooter)

	if not warded.is_empty():
		WardScript.turned_aside(self, warded["at"], velocity.normalized(), warded["ward"])
		queue_free()
		return

	var query := PhysicsRayQueryParameters3D.create(from, to, 1 | 2 | 4, exclude)
	query.hit_from_inside = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)

	if not hit.is_empty():
		_hit(hit, velocity.normalized())
		return

	global_position = to
	_face_travel()
	spin = wrapf(spin + SPIN * delta, -1000.0, 1000.0)
	_turn()
	Fx.streak(self, global_position - velocity * delta, velocity, 0.06)


func _hit(hit: Dictionary, direction: Vector3) -> void:
	var collider: Object = hit.get("collider")
	var point: Vector3 = hit["position"]

	if collider is PhysicalBone3D:
		var owner_now := RagdollScript.owner_of(collider)

		if owner_now != null and owner_now.has_method("take_hit"):
			collider = owner_now

	if collider != null and collider.has_method("take_damage") and not collider.has_method("take_hit"):
		collider.take_damage(damage, self)
		struck.emit(collider, damage)
		queue_free()
		return

	if collider != null and collider.has_method("take_hit"):
		var target := collider as Node3D
		var health_before: float = float(target.get("health")) if target.get("health") != null else damage

		# Killing him, it takes the limb it went into.
		if damage >= health_before and target.get("sever_hint") != null:
			var limb := limb_at(target, point, direction)

			if limb != &"":
				target.set("sever_hint", [limb] as Array[StringName])

		Sfx.play(self, &"arrow_flesh", point, -2.0, 1.3)
		collider.take_hit(damage, shooter, &"shard", point, direction)

		if is_instance_valid(target) and target.get("sever_hint") != null:
			target.set("sever_hint", [] as Array[StringName])

		struck.emit(collider, damage)
		queue_free()
		return

	if collider is RigidBody3D:
		var body := collider as RigidBody3D
		body.apply_impulse(direction * 3.0, point - body.global_position)

	# On the world: it shatters into black glass, and is gone.
	var normal: Vector3 = hit.get("normal", -direction)
	Fx.dust(self, point, normal, 0.5, "stone")
	MagicFx.shatter(self, point, normal)
	SoundBus.emit_sound(point, HISS_DB, shooter, &"shard")
	struck.emit(collider, 0.0)
	queue_free()


## The limb of `target` a shard went into, struck at `point` (on his body's
## outline) going `direction`: the head above the neck, else the arm or leg
## bone its line passes nearest, within LIMB_REACH; &"" for the body.
static func limb_at(target: Node3D, point: Vector3, direction: Vector3) -> StringName:
	var rig := target.get_node_or_null("Rig")
	var man: Node3D = rig.get("man") as Node3D if rig != null else null

	if man == null or not man.has_method("bone_global"):
		return &""

	if point.y >= man.bone_global(&"neck_01").origin.y - 0.08:
		return &"neck_01"

	# Its line on through him.
	var through := point + direction.normalized() * 0.8
	var best: StringName = &""
	var nearest := LIMB_REACH
	var segments := [
		[&"upperarm", &"lowerarm"], [&"lowerarm", &"hand"],
		[&"thigh", &"calf"], [&"calf", &"foot"],
	]

	for side in ["_l", "_r"]:
		for segment in segments:
			var a: Vector3 = man.bone_global(StringName(String(segment[0]) + side)).origin
			var b: Vector3 = man.bone_global(StringName(String(segment[1]) + side)).origin
			var closest := Geometry3D.get_closest_points_between_segments(point, through, a, b)
			var gap: float = (closest[0] as Vector3).distance_to(closest[1])

			if gap < nearest:
				nearest = gap
				best = StringName(String(segment[0]) + side)

	return best


func _face_travel() -> void:
	if velocity.length() > 0.01:
		look_at(global_position + velocity, Vector3.UP if absf(velocity.normalized().y) < 0.99 else Vector3.RIGHT)
