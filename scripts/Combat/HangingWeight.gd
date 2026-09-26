extends Node3D
## A heavy load hung from a beam by one rope: a cage of stones, a crate of
## iron. Cut the rope (a blade, an arrow, a blast) and it drops. Whoever is
## under it when it comes down is crushed; guards under it die.
##
##   var weight := HangingWeight.new()
##   weight.drop = 4.0            # metres of rope, beam to load
##   add_child(weight); weight.global_position = beam_point

const StrikeableScript := preload("res://scripts/Combat/Strikeable.gd")
const Fx := preload("res://scripts/Visual/Fx.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")
const SoundBus := preload("res://scripts/StimuliSystem/SoundBus.gd")

signal released
signal crushed(victim: Node3D)

## Metres of rope between the beam (this node) and the top of the load.
@export var drop := 3.0
@export var load_size := Vector3(1.1, 0.9, 1.1)
@export var load_mass := 200.0
@export var crush_damage := 400.0

var body: RigidBody3D
var rope: StaticBody3D
var cut := false
var _crushed := {}


func _ready() -> void:
	# An archer who sees you under it knows what the rope is for.
	add_to_group(&"hanging_weights")
	# The rope: a thin cord, and a slightly fatter box for blades and arrows.
	rope = StrikeableScript.new()
	rope.name = "Rope"
	var cord := MeshInstance3D.new()
	var cord_mesh := BoxMesh.new()
	cord_mesh.size = Vector3(0.04, drop, 0.04)
	var hemp := StandardMaterial3D.new()
	hemp.albedo_color = Color(0.6, 0.5, 0.32)
	cord_mesh.material = hemp
	cord.mesh = cord_mesh
	rope.add_child(cord)
	var cord_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.16, drop, 0.16)
	cord_shape.shape = box
	rope.add_child(cord_shape)
	rope.position = Vector3(0.0, -drop * 0.5, 0.0)
	rope.set_meta(&"surface", "carpet")
	add_child(rope)
	rope.struck.connect(_on_rope_struck)

	# The load, hung still until the rope goes.
	body = RigidBody3D.new()
	body.name = "Load"
	body.mass = load_mass
	body.freeze = true
	body.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	body.continuous_cd = true
	var shape := CollisionShape3D.new()
	var load_box := BoxShape3D.new()
	load_box.size = load_size
	shape.shape = load_box
	body.add_child(shape)
	var crate := MeshInstance3D.new()
	var crate_mesh := BoxMesh.new()
	crate_mesh.size = load_size
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.28, 0.27, 0.28)
	iron.metallic = 0.5
	iron.roughness = 0.6
	crate_mesh.material = iron
	crate.mesh = crate_mesh
	body.add_child(crate)
	body.position = Vector3(0.0, -drop - load_size.y * 0.5, 0.0)
	add_child(body)
	reset_physics_interpolation.call_deferred()


func _on_rope_struck(kind: StringName, point: Vector3) -> void:
	if kind in [&"quick", &"power", &"arrow", &"blast"]:
		release(point)


func release(at := Vector3.ZERO) -> void:
	if cut:
		return

	cut = true
	Sfx.play(self, &"rope_snap", at if at != Vector3.ZERO else rope.global_position)
	rope.queue_free()

	# It comes down through a man, not onto his head to rest there.
	for player in get_tree().get_nodes_in_group(&"player"):
		if player is PhysicsBody3D:
			body.add_collision_exception_with(player)

	body.freeze = false
	body.sleeping = false
	released.emit()


func _physics_process(_delta: float) -> void:
	if not cut or body == null or not is_instance_valid(body):
		return

	# Coming down hard: whoever is under it.
	if body.linear_velocity.y > -3.0:
		return

	# The space it will fall through before the next check, and a little.
	var ahead: float = -body.linear_velocity.y / float(Engine.physics_ticks_per_second) + 0.3
	var sphere := BoxShape3D.new()
	sphere.size = load_size + Vector3(0.2, ahead * 2.0, 0.2)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, body.global_position - Vector3.UP * ahead)
	query.collision_mask = 2 | 1
	query.exclude = [body.get_rid()]

	for hit in body.get_world_3d().direct_space_state.intersect_shape(query, 8):
		var victim: Object = hit.get("collider")

		if victim == null or _crushed.has(victim) or not (victim is CharacterBody3D):
			continue

		_crushed[victim] = true

		if victim.has_method("take_hit"):
			victim.take_hit(crush_damage, null, &"crush", (victim as Node3D).global_position + Vector3.UP * 1.6, Vector3.DOWN)
		elif victim.has_method("take_damage"):
			victim.take_damage(60.0, null)

		Fx.dust(self, (victim as Node3D).global_position, Vector3.UP, 1.6, "stone")
		Sfx.play(self, &"thud", body.global_position, 3.0, 0.6)
		SoundBus.emit_sound(body.global_position, 70.0, body, &"impact")
		crushed.emit(victim as Node3D)
