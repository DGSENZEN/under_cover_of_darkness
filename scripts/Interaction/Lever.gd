extends StaticBody3D
## A lever on a post. Pull it (frob) and it throws, and whatever it works
## happens: the arena's gates, a trap. It springs back after a moment.
##
##   Lever.build(parent, position, yaw, "Release the brute", func(): ...)

const Sfx := preload("res://scripts/Audio/Sfx.gd")

signal pulled

## What the frob prompt says.
@export var verb := "Pull"
## Seconds before it can be pulled again.
@export var cooldown := 1.0

var _handle: Node3D
var _throw := 0.0
var _wait := 0.0


static func build(parent: Node, position: Vector3, yaw: float, title: String, action: Callable) -> StaticBody3D:
	var lever: StaticBody3D = (load("res://scripts/Interaction/Lever.gd") as GDScript).new()
	lever.verb = title
	parent.add_child(lever)
	lever.global_position = position
	lever.rotation.y = yaw
	lever.pulled.connect(action)

	var sign := Label3D.new()
	sign.text = title
	sign.font_size = 26
	sign.pixel_size = 0.006
	sign.outline_size = 6
	sign.modulate = Color(0.95, 0.88, 0.72)
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.shaded = false
	sign.position = Vector3(0.0, 1.55, 0.0)
	lever.add_child(sign)
	return lever


func _ready() -> void:
	var post := MeshInstance3D.new()
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(0.22, 1.0, 0.22)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.3, 0.2, 0.12)
	post_mesh.material = wood
	post.mesh = post_mesh
	post.position.y = 0.5
	add_child(post)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.4, 1.3, 0.4)
	shape.shape = box
	shape.position.y = 0.65
	add_child(shape)

	_handle = Node3D.new()
	_handle.position = Vector3(0.0, 0.95, 0.0)
	add_child(_handle)
	var bar := MeshInstance3D.new()
	var bar_mesh := BoxMesh.new()
	bar_mesh.size = Vector3(0.05, 0.5, 0.05)
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.25, 0.25, 0.27)
	iron.metallic = 0.6
	bar_mesh.material = iron
	bar.mesh = bar_mesh
	bar.position.y = 0.25
	_handle.add_child(bar)
	var knob := MeshInstance3D.new()
	var knob_mesh := SphereMesh.new()
	knob_mesh.radius = 0.06
	knob_mesh.height = 0.12
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.6, 0.12, 0.08)
	knob_mesh.material = red
	knob.mesh = knob_mesh
	knob.position.y = 0.5
	_handle.add_child(knob)
	_handle.rotation.x = -0.6


func get_prompt(_player: Node) -> String:
	return verb if _wait <= 0.0 else ""


func frob(_player: Node) -> void:
	if _wait > 0.0:
		return

	_wait = cooldown
	_throw = 1.0
	Sfx.play(self, &"unlock", global_position + Vector3.UP, 0.0, 0.7)
	Sfx.play(self, &"door_rattle", global_position + Vector3.UP, -6.0, 0.8)
	pulled.emit()


func _process(delta: float) -> void:
	_wait = maxf(_wait - delta, 0.0)
	_throw = move_toward(_throw, 0.0, delta / maxf(cooldown, 0.01))
	# Thrown over in the first quarter, then back slowly.
	var over := smoothstep(1.0, 0.75, _throw) if _throw > 0.75 else _throw / 0.75
	_handle.rotation.x = lerpf(-0.6, 0.6, over)
