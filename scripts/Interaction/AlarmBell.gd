extends StaticBody3D
## Frobbable/guard-operated alarm with cooldown and timed tolls.
## ring() broadcasts the supplied destination, raises the player garrison
## alarm, and emits rung; player frob uses the bell position as destination.

const SoundBus := preload("res://scripts/StimuliSystem/SoundBus.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")
const Comms := preload("res://scripts/AISystem/Comms.gd")
const GarrisonScript := preload("res://scripts/AISystem/Garrison.gd")

signal rung(by: Node)

## Carries across a whole keep (every 7 dB doubles the reach).
@export var ring_db := 96.0
## Seconds before it can be rung again.
@export var cooldown := 45.0
## How many times it tolls, and how far apart.
@export var tolls := 5
@export var toll_gap := 0.75

var _since_rung := 999.0
var _tolls_left := 0
var _toll_timer := 0.0
var _swing := 0.0
var _bell: Node3D


static func build(parent: Node, position: Vector3, yaw := 0.0) -> StaticBody3D:
	var bell: StaticBody3D = (load("res://scripts/Interaction/AlarmBell.gd") as GDScript).new()
	bell.name = "AlarmBell"
	parent.add_child(bell)
	bell.global_position = position
	bell.rotation.y = yaw
	bell.reset_physics_interpolation()
	return bell


func _ready() -> void:
	add_to_group(&"alarm_bells")
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.3, 0.2, 0.12)
	wood.roughness = 0.9
	var bronze := StandardMaterial3D.new()
	bronze.albedo_color = Color(0.55, 0.4, 0.18)
	bronze.metallic = 0.7
	bronze.roughness = 0.45

	# Two posts and a beam across them.
	for x in [-0.45, 0.45]:
		var post := MeshInstance3D.new()
		var post_mesh := BoxMesh.new()
		post_mesh.size = Vector3(0.14, 2.5, 0.14)
		post_mesh.material = wood
		post.mesh = post_mesh
		post.position = Vector3(x, 1.25, 0.0)
		add_child(post)

	var beam := MeshInstance3D.new()
	var beam_mesh := BoxMesh.new()
	beam_mesh.size = Vector3(1.1, 0.14, 0.16)
	beam_mesh.material = wood
	beam.mesh = beam_mesh
	beam.position = Vector3(0.0, 2.45, 0.0)
	add_child(beam)

	# The bell, hung from the beam at its crown, and its rope.
	_bell = Node3D.new()
	_bell.name = "Bell"
	_bell.position = Vector3(0.0, 2.38, 0.0)
	add_child(_bell)
	var cup := MeshInstance3D.new()
	var cup_mesh := CylinderMesh.new()
	cup_mesh.top_radius = 0.12
	cup_mesh.bottom_radius = 0.24
	cup_mesh.height = 0.36
	cup_mesh.material = bronze
	cup.mesh = cup_mesh
	cup.position = Vector3(0.0, -0.2, 0.0)
	_bell.add_child(cup)
	var rope := MeshInstance3D.new()
	var rope_mesh := BoxMesh.new()
	rope_mesh.size = Vector3(0.025, 1.3, 0.025)
	var hemp := StandardMaterial3D.new()
	hemp.albedo_color = Color(0.6, 0.5, 0.32)
	rope_mesh.material = hemp
	rope.mesh = rope_mesh
	rope.position = Vector3(0.0, -1.0, 0.0)
	_bell.add_child(rope)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.1, 2.5, 0.3)
	shape.shape = box
	shape.position = Vector3(0.0, 1.25, 0.0)
	add_child(shape)
	set_meta(&"surface", "wood")


func get_prompt(_player: Node) -> String:
	return "Ring the alarm bell" if can_ring() else ""


## You ring it: they come to the bell, knowing nothing more.
func frob(player: Node) -> void:
	ring(player, global_position)


## Returns whether cooldown has elapsed.
func can_ring() -> bool:
	return _since_rung >= cooldown


## Returns the world standing point 0.55 m along the bell’s +Z.
func rope_point() -> Vector3:
	return global_position + global_basis.z * 0.55


## Broadcasts an alarm message targeting world where, raises the player’s garrison alarm,
## starts tolling/cooldown, and emits rung(by). No-op during cooldown.
func ring(by: Node, where: Vector3) -> void:
	if not can_ring():
		return

	_since_rung = 0.0
	_tolls_left = tolls
	_toll_timer = 0.0
	var message := {"what": &"alarm", "where": where, "time": Comms.now(), "id": -get_instance_id(), "from": weakref(by)}
	SoundBus.emit_message(global_position + Vector3.UP * 2.2, ring_db, self, &"call", message)
	var enemy := get_tree().get_first_node_in_group(&"player") as Node3D

	if enemy != null:
		GarrisonScript.of(enemy).raise_alarm(1.0)

	rung.emit(by)


func is_tolling() -> bool:
	return _tolls_left > 0


func _physics_process(delta: float) -> void:
	_since_rung += delta

	if _tolls_left > 0:
		_toll_timer -= delta

		if _toll_timer <= 0.0:
			_toll_timer = toll_gap
			_tolls_left -= 1
			_swing = 1.0
			var at := _bell.global_position + Vector3.DOWN * 0.25
			Sfx.play(self, &"clang", at, 6.0, 0.5)
			Sfx.play(self, &"ting", at, 2.0, 0.45)

	_swing = move_toward(_swing, 0.0, delta * 0.9)

	if _bell != null:
		_bell.rotation.x = sin(_since_rung * 7.0) * 0.45 * _swing
