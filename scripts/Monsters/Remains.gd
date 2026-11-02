extends RigidBody3D
## What is left of a monster: it drops, bounces and lies there a while, and
## leaves a stain where it first lands. For show: nothing hits it, and a save
## does not keep it.

const Fx := preload("res://scripts/Visual/Fx.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")

const LASTS := 8.0
const STAIN := 0.9
const CHUNK_LASTS := 6.0
const CHUNK_STAIN := 0.22

var _left := LASTS
var is_chunk := false
var _landed := false


## A chunk thrown off: a wet lump of `flesh`, or a shard of the stone. Small and
## soon gone.
static func chunk(context: Node, at: Vector3, push: Vector3, stone: bool, flesh: Material) -> RigidBody3D:
	var body: RigidBody3D = (load("res://scripts/Monsters/Remains.gd") as GDScript).new()
	var size := 0.05 + absf(fmod(at.x * 37.0 + at.z * 53.0, 0.05))
	var shape := CollisionShape3D.new()
	var ball := SphereShape3D.new()
	ball.radius = size
	shape.shape = ball
	body.add_child(shape)
	var mesh := MeshInstance3D.new()

	if stone:
		var box := BoxMesh.new()
		box.size = Vector3(size * 2.2, size * 1.5, size * 1.8)
		var look := StandardMaterial3D.new()
		look.albedo_color = Color(0.3, 0.09, 0.07)
		look.roughness = 0.95
		box.material = look
		mesh.mesh = box
	else:
		var lump := SphereMesh.new()
		lump.radius = size
		lump.height = size * 1.6
		lump.radial_segments = 8
		lump.rings = 4
		lump.material = flesh
		mesh.mesh = lump
		mesh.set_instance_shader_parameter(&"hurt", 0.4)

	body.add_child(mesh)
	body.is_chunk = true
	body._left = CHUNK_LASTS
	context.add_child(body)
	body.global_position = at
	body.reset_physics_interpolation()
	body.linear_velocity = push
	body.angular_velocity = Vector3(push.z, push.x, push.y) * 2.0
	return body


## `look` is taken over as its body; thrown along `push`.
static func drop(context: Node, look: Node3D, at: Vector3, push: Vector3, radius: float) -> RigidBody3D:
	var body: RigidBody3D = (load("res://scripts/Monsters/Remains.gd") as GDScript).new()
	var shape := CollisionShape3D.new()
	var ball := SphereShape3D.new()
	ball.radius = radius
	shape.shape = ball
	body.add_child(shape)
	look.reparent(body, false)
	look.transform = Transform3D.IDENTITY
	context.add_child(body)
	body.global_position = at
	body.reset_physics_interpolation()
	body.linear_velocity = push
	body.angular_velocity = Vector3(push.z, 3.0, -push.x) * 0.8
	return body


func _ready() -> void:
	add_to_group(&"gibs" if is_chunk else &"remains")
	collision_layer = 0
	collision_mask = 1
	mass = 0.3 if is_chunk else 2.0
	var bouncy := PhysicsMaterial.new()
	bouncy.bounce = 0.45
	bouncy.friction = 0.9
	physics_material_override = bouncy
	contact_monitor = true
	max_contacts_reported = 1
	body_entered.connect(_on_body_entered)


func _on_body_entered(_body: Node) -> void:
	if _landed:
		return

	_landed = true
	if is_chunk:
		Fx.stain(self, global_position - Vector3(0.0, 0.04, 0.0), Vector3.UP, CHUNK_STAIN)
		return

	Fx.stain(self, global_position - Vector3(0.0, 0.3, 0.0), Vector3.UP, STAIN)
	Fx.blood(self, global_position, Vector3.UP, 0.6)
	Sfx.play(self, &"flesh", global_position, -2.0, 0.85)


func _physics_process(delta: float) -> void:
	_left -= delta

	if _left <= 0.0:
		queue_free()
