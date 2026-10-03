extends StaticBody3D
## Bloodless practice target with optional frontal guard and damage tally.
## It reports hit/blocked results, briefly breaks guard on power hits or kicks,
## and never loses health or dies.

const Fx := preload("res://scripts/Visual/Fx.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")
const Layers := preload("res://scripts/Visual/Layers.gd")

## result: "hit" or "blocked"; kind as a blow's (quick, power, backstab...).
signal struck(result: StringName, kind: StringName, damage: float)
signal guard_broken

@export var guards := false

var _body: Node3D
var _shield: Node3D
var _tilt := Vector3.ZERO
var _tilt_v := Vector3.ZERO
var _broken := 0.0
## Damage taken since the last pause: shown by the arena as a total.
var tally := 0.0
var _since_hit := 0.0


func _ready() -> void:
	# On the guards' layer, so blades and arrows treat it as someone.
	collision_layer = 2
	collision_mask = 0
	set_meta(&"hit_sound", &"thud")
	set_meta(&"bloodless", true)

	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.5
	shape.shape = capsule
	shape.position.y = 1.1
	add_child(shape)

	var post := MeshInstance3D.new()
	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = 0.05
	post_mesh.bottom_radius = 0.07
	post_mesh.height = 1.0
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.3, 0.21, 0.13)
	post_mesh.material = wood
	post.mesh = post_mesh
	post.position.y = 0.5
	add_child(post)

	_body = Node3D.new()
	_body.position = Vector3(0.0, 0.7, 0.0)
	add_child(_body)
	var straw := StandardMaterial3D.new()
	straw.albedo_color = Color(0.72, 0.6, 0.32)
	straw.roughness = 1.0
	var torso := MeshInstance3D.new()
	var torso_mesh := CapsuleMesh.new()
	torso_mesh.radius = 0.28
	torso_mesh.height = 1.0
	torso_mesh.material = straw
	torso.mesh = torso_mesh
	torso.position.y = 0.5
	torso.layers = Layers.ACTORS
	_body.add_child(torso)
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.17
	head_mesh.height = 0.34
	head_mesh.material = straw
	head.mesh = head_mesh
	head.position.y = 1.16
	head.layers = Layers.ACTORS
	_body.add_child(head)
	# A painted face: where it is looking.
	var face := MeshInstance3D.new()
	var face_mesh := BoxMesh.new()
	face_mesh.size = Vector3(0.18, 0.05, 0.04)
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.2, 0.1, 0.08)
	face_mesh.material = paint
	face.mesh = face_mesh
	face.position = Vector3(0.0, 1.18, -0.16)
	_body.add_child(face)

	if guards:
		_shield = Node3D.new()
		_shield.position = Vector3(-0.1, 0.62, -0.34)
		_body.add_child(_shield)
		var board := MeshInstance3D.new()
		var board_mesh := BoxMesh.new()
		board_mesh.size = Vector3(0.62, 0.78, 0.06)
		var oak := StandardMaterial3D.new()
		oak.albedo_color = Color(0.4, 0.28, 0.16)
		board_mesh.material = oak
		board.mesh = board_mesh
		_shield.add_child(board)
		var boss := MeshInstance3D.new()
		var boss_mesh := SphereMesh.new()
		boss_mesh.radius = 0.09
		boss_mesh.height = 0.1
		var iron := StandardMaterial3D.new()
		iron.albedo_color = Color(0.4, 0.4, 0.42)
		iron.metallic = 0.7
		boss_mesh.material = iron
		boss.mesh = boss_mesh
		boss.position.z = -0.05
		_shield.add_child(boss)


## Reports blocked for frontal quick/thrown hits while guarded; otherwise adds damage
## to tally and returns hit. Power hits break guard; attacker may be null.
func take_hit(damage: float, attacker: Node3D, kind: StringName, point: Vector3, direction: Vector3) -> StringName:
	_since_hit = 0.0

	if guards and _broken <= 0.0 and attacker != null and not is_behind(attacker):
		if kind == &"quick" or kind == &"thrown":
			Fx.sparks(self, point, -direction, 0.7, false)
			_rock(direction, 0.3)
			struck.emit(&"blocked", kind, 0.0)
			return &"blocked"

		if kind == &"power":
			_break_guard()

	tally += damage
	_rock(direction, clampf(damage / 40.0, 0.4, 1.6))
	Fx.dust(self, point, -direction, 0.7, "grass")
	struck.emit(&"hit", kind, damage)
	return &"hit"


## Rocks the dummy, breaks optional guard, and emits a zero-damage kick hit.
func kick(push: Vector3, _attacker: Node3D) -> void:
	_rock(push.normalized(), 1.8)

	if guards:
		_break_guard()

	struck.emit(&"hit", &"kick", 0.0)


## Unwatched from behind: a straw man is always unaware.
func is_unaware() -> bool:
	return true


func is_behind(attacker: Node3D) -> bool:
	var to := attacker.global_position - global_position
	to.y = 0.0
	return to.length() > 0.01 and (-global_basis.z).dot(to.normalized()) < -0.2


func _break_guard() -> void:
	if _broken > 0.0:
		return

	_broken = 2.0
	Sfx.play(self, &"guard_break", global_position + Vector3.UP * 1.2)
	guard_broken.emit()


func _rock(direction: Vector3, strength: float) -> void:
	var local := global_basis.inverse() * direction
	local.y = 0.0
	_tilt_v += local.normalized() * 3.5 * strength if local.length() > 0.01 else Vector3.ZERO


func _physics_process(delta: float) -> void:
	_broken = maxf(_broken - delta, 0.0)
	_since_hit += delta

	if _since_hit > 2.5:
		tally = 0.0

	_tilt_v += (-_tilt * 90.0 - _tilt_v * 7.0) * delta
	_tilt += _tilt_v * delta
	_tilt = _tilt.limit_length(0.7)
	var angle := _tilt.length()
	_body.basis = Basis(Vector3.UP.cross(_tilt / angle).normalized(), angle) if angle > 0.001 else Basis.IDENTITY

	if _shield != null:
		# Knocked aside while broken.
		var down := 1.0 if _broken > 0.0 else 0.0
		_shield.position = _shield.position.lerp(Vector3(-0.1 - 0.35 * down, 0.62 - 0.35 * down, -0.34 + 0.2 * down), 1.0 - exp(-12.0 * delta))
		_shield.rotation.z = lerpf(_shield.rotation.z, 1.1 * down, 1.0 - exp(-12.0 * delta))
