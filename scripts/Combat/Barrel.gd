extends RigidBody3D
## A barrel of lamp oil and black powder. An arrow, a heavy blow, fire, or
## another barrel going up next to it lights the fuse; a moment later it
## bursts and throws everyone near it off their feet. Quick cuts and kicks
## only knock it about, so it can be rolled into place first, or picked up
## and thrown.
##
## Guards caught in it are hurt by how close they stood (a wall between them
## and it takes most of the blast) and flung like a kick; you are too. Every
## guard in earshot hears it, and none of them knows who did it.

const Fx := preload("res://scripts/Visual/Fx.gd")
const RagdollScript := preload("res://scripts/Visual/Ragdoll.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")
const SoundBus := preload("res://scripts/StimuliSystem/SoundBus.gd")
const Layers := preload("res://scripts/Visual/Layers.gd")

signal exploded(at: Vector3)

@export var fuse := 0.7
@export var radius := 4.0
## At the heart of it; nothing at the edge.
@export var damage := 130.0
## How hard it throws what it catches, in m/s at the heart.
@export var push := 10.0
@export var noise_db := 88.0

var lit := false
var _fuse_left := 0.0
var _spark_timer := 0.0
var _gone := false


func _ready() -> void:
	add_to_group(&"explosives")
	mass = 9.0
	contact_monitor = true
	max_contacts_reported = 2

	if get_child_count() == 0:
		var shape := CollisionShape3D.new()
		var cylinder := CylinderShape3D.new()
		cylinder.radius = 0.28
		cylinder.height = 0.78
		shape.shape = cylinder
		add_child(shape)

		var body := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.28
		mesh.bottom_radius = 0.28
		mesh.height = 0.78
		mesh.radial_segments = 12
		var wood := StandardMaterial3D.new()
		wood.albedo_color = Color(0.42, 0.16, 0.1)
		wood.roughness = 0.8
		mesh.material = wood
		body.mesh = mesh
		add_child(body)

		# Iron hoops, and a skull daubed on it so nobody mistakes it.
		for y in [-0.26, 0.26]:
			var hoop := MeshInstance3D.new()
			var ring := CylinderMesh.new()
			ring.top_radius = 0.29
			ring.bottom_radius = 0.29
			ring.height = 0.05
			ring.radial_segments = 12
			var iron := StandardMaterial3D.new()
			iron.albedo_color = Color(0.2, 0.2, 0.22)
			iron.metallic = 0.6
			ring.material = iron
			hoop.mesh = ring
			hoop.position.y = y
			add_child(hoop)

		var mark := MeshInstance3D.new()
		var plate := BoxMesh.new()
		plate.size = Vector3(0.2, 0.2, 0.01)
		var paint := StandardMaterial3D.new()
		paint.albedo_color = Color(0.9, 0.85, 0.6)
		plate.material = paint
		mark.mesh = plate
		mark.position = Vector3(0.0, 0.0, 0.285)
		add_child(mark)


## Hit by something that is not a person: a blade, an arrow, a boot.
func strike(kind: StringName, _point: Vector3, _direction := Vector3.ZERO) -> void:
	if kind in [&"power", &"arrow", &"blast", &"fire"]:
		light()


## Starts the fuse. A shorter one when set off by another blast.
func light(seconds := -1.0) -> void:
	if lit or _gone:
		return

	lit = true
	_fuse_left = fuse if seconds < 0.0 else seconds
	Sfx.play(self, &"ignite", global_position + Vector3.UP * 0.4, -2.0, 1.4)


## What a blast is to whoever it hits: through any guard.
func attack_info() -> Dictionary:
	return {"type": &"blast", "unblockable": true}


func _physics_process(delta: float) -> void:
	if not lit or _gone:
		return

	_fuse_left -= delta
	_spark_timer -= delta

	# The fuse fizzes.
	if _spark_timer <= 0.0:
		_spark_timer = 0.07
		Fx.sparks(self, global_position + global_basis.y * 0.42, Vector3.UP, 0.35, false)

	if _fuse_left <= 0.0:
		explode()


func explode() -> void:
	if _gone:
		return

	_gone = true
	var at := global_position + Vector3.UP * 0.2
	Fx.flash(self, at, Color(1.0, 0.62, 0.28), 9.0, 10.0, 0.3)
	Fx.sparks(self, at, Vector3.UP, 4.0)
	Fx.dust(self, at, Vector3.UP, 2.8, "stone")
	Sfx.play(self, &"explosion", at, 0.0, randf_range(0.92, 1.05))
	SoundBus.emit_sound(at, noise_db, self, &"explosion")
	_scorch(at)

	var sphere := SphereShape3D.new()
	sphere.radius = radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, at)
	query.collision_mask = 1 | 2 | 4
	query.exclude = [get_rid()]
	var space := get_world_3d().direct_space_state
	var done := {}

	for hit in space.intersect_shape(query, 32):
		var thing: Object = hit.get("collider")
		var limb: Node = null

		if not is_instance_valid(thing):
			continue

		# A limb: its man (down but alive, or dead), once.
		if thing is PhysicalBone3D:
			limb = RagdollScript.of(thing)
			var owner_now := RagdollScript.owner_of(thing)

			if owner_now != null:
				thing = owner_now

		if thing == null or done.has(thing) or not (thing is Node3D):
			continue

		done[thing] = true
		var node := thing as Node3D
		var centre := node.global_position + Vector3.UP * (0.9 if thing is CharacterBody3D else 0.0)

		# A long thin thing (a rope) is as near as its nearest part.
		if thing is StaticBody3D:
			centre = _nearest_point(node, at)
		var offset := centre - at
		var k := 1.0 - clampf(offset.length() / radius, 0.0, 1.0)

		if k <= 0.0:
			continue

		# Behind a wall, most of it passes over.
		if not (thing is StaticBody3D):
			var exclude: Array[RID] = [get_rid()]

			if thing is CollisionObject3D:
				exclude.append((thing as CollisionObject3D).get_rid())

			var ray := PhysicsRayQueryParameters3D.create(at, centre, 1, exclude)

			if not space.intersect_ray(ray).is_empty():
				k *= 0.35

		var away := Vector3(offset.x, 0.0, offset.z)
		away = away.normalized() if away.length() > 0.05 else Vector3.FORWARD

		if thing.has_method("light"):
			thing.light(randf_range(0.12, 0.3))
		elif thing.has_method("kick") and thing.has_method("take_hit"):
			# A guard: burnt and thrown off his feet. Nobody to blame.
			var result: StringName = thing.take_hit(damage * k, null, &"blast", centre, away)

			if result != &"killed" and result != &"none" and is_instance_valid(thing):
				if thing.has_method("knock_down") and k > 0.25:
					thing.knock_down(away * push * k * 0.8 + Vector3.UP * 3.0 * k, null, centre)
				else:
					thing.kick(away * push * k, null)
		elif limb != null:
			# A dead man: flung.
			limb.shove((away + Vector3.UP * 0.8) * push * 0.7 * k)
		elif thing.has_method("take_damage"):
			thing.take_damage(damage * 0.45 * k, self)

			if thing.has_method("shove"):
				thing.shove(away * push * 0.8 * k, 0.35)

			if thing.get("juice") != null:
				thing.juice.add_trauma(0.9 * k)
		elif thing is RigidBody3D and not (thing as RigidBody3D).freeze:
			(thing as RigidBody3D).apply_central_impulse((away + Vector3.UP * 0.6) * 40.0 * k)
		elif thing.has_method("strike"):
			thing.strike(&"blast", centre, away)

	# Even at the edge of the room it is felt.
	var viewer := get_tree().get_first_node_in_group(&"player") as Node3D

	if viewer != null and viewer.get("juice") != null:
		var far := viewer.global_position.distance_to(at)
		viewer.juice.add_trauma(clampf(0.5 - far / 30.0, 0.0, 0.5))

	exploded.emit(at)
	queue_free()


## The point of `body`'s box shapes nearest to `at`.
static func _nearest_point(body: Node3D, at: Vector3) -> Vector3:
	var best := body.global_position
	var best_gap := INF

	for child in body.get_children():
		var holder := child as CollisionShape3D

		if holder == null or not (holder.shape is BoxShape3D):
			continue

		var half := (holder.shape as BoxShape3D).size * 0.5
		var local := holder.global_transform.affine_inverse() * at
		var clamped := Vector3(clampf(local.x, -half.x, half.x), clampf(local.y, -half.y, half.y), clampf(local.z, -half.z, half.z))
		var point := holder.global_transform * clamped

		if point.distance_to(at) < best_gap:
			best_gap = point.distance_to(at)
			best = point

	return best


func _scorch(at: Vector3) -> void:
	var ray := PhysicsRayQueryParameters3D.create(at, at - Vector3.UP * 1.5, 1, [get_rid()])
	var ground := get_world_3d().direct_space_state.intersect_ray(ray)

	if not ground.is_empty():
		Fx.stain(self, ground["position"], ground["normal"], 2.4, "scorch")
