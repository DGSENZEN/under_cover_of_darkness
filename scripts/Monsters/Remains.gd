extends RigidBody3D
## What is left of a monster: it drops, bounces and lies there a while, and
## leaves a stain where it first lands. For show: nothing hits it, and a save
## does not keep it.

const Fx := preload("res://scripts/Visual/Fx.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")

const LASTS := 8.0
const STAIN := 0.9
## It lands spent: flattened, and darker.
const SPENT_HEIGHT := 0.62
const SPENT_DARK := Color(0.0, 0.0, 0.0, 0.45)

var _left := LASTS
var _landed := false


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
	add_to_group(&"remains")
	collision_layer = 0
	collision_mask = 1
	mass = 2.0
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
	Fx.stain(self, global_position - Vector3(0.0, 0.3, 0.0), Vector3.UP, STAIN)
	Fx.blood(self, global_position, Vector3.UP, 0.6)
	Sfx.play(self, &"flesh", global_position, -2.0, 0.85)
	var spent := StandardMaterial3D.new()
	spent.albedo_color = SPENT_DARK
	spent.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	for piece in find_children("*", "MeshInstance3D", true, false):
		(piece as MeshInstance3D).material_overlay = spent
		(piece as MeshInstance3D).scale.y *= SPENT_HEIGHT


func _physics_process(delta: float) -> void:
	_left -= delta

	if _left <= 0.0:
		queue_free()
