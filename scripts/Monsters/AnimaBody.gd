extends Node3D
## What a ravenous ánima looks like. For now, stand-in shapes, plainly unfinished,
## until each form's model is made and approved (the plan's Tasks 10 to 12).

const Fx := preload("res://scripts/Visual/Fx.gd")

var form: StringName = &"hands"
## How much it has drunk, shown, 0..1.
var fed_shown := 0.0

var _look: StandardMaterial3D
var _pieces: Array[MeshInstance3D] = []
var _clock := 0.0


func _ready() -> void:
	_look = StandardMaterial3D.new()
	_look.albedo_color = Color(0.13, 0.12, 0.1)
	_look.emission_enabled = true
	_look.emission = Color(0.38, 0.5, 0.08)
	_look.emission_energy_multiplier = 0.25

	match form:
		&"hands":
			for x in [-0.14, 0.14]:
				_piece(Vector3(0.1, 0.1, 0.34), Vector3(x, 0.0, 0.0))
		&"face":
			_piece(Vector3(0.34, 0.42, 0.26), Vector3.ZERO)
			for x in [-0.34, 0.34]:
				_piece(Vector3(0.1, 0.1, 0.6), Vector3(x, -0.1, -0.3))
		_:
			_piece(Vector3(0.5, 0.42, 0.56), Vector3(0.0, 0.15, 0.2))
			_piece(Vector3(0.26, 0.3, 0.26), Vector3(0.0, 0.4, -0.1))
			for x in [-0.42, 0.42]:
				_piece(Vector3(0.12, 0.12, 0.9), Vector3(x, 0.0, -0.45))


func _piece(size: Vector3, at: Vector3) -> void:
	var piece := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = _look
	piece.mesh = box
	piece.position = at
	add_child(piece)
	_pieces.append(piece)


## Each tick: what it is doing, whom at, how it moves, how much it has drunk (0..1).
func tick(delta: float, doing: StringName, you: Node3D, moving: Vector3, fed: float, exposed: bool, smoked: bool) -> void:
	_clock += delta
	fed_shown = fed
	var flat := Vector3(moving.x, 0.0, moving.z)

	if you != null:
		var way := you.global_position - global_position
		way.y = 0.0

		if flat.length() < 0.2 and way.length() > 0.01:
			flat = way

	if flat.length() > 0.01:
		var wanted := Basis.looking_at(flat.normalized(), Vector3.UP)
		global_basis = global_basis.orthonormalized().slerp(wanted, 1.0 - exp(-10.0 * delta))

	# A tell you can read: it draws itself up, shaking.
	position.y = 0.16 + sin(_clock * 40.0) * 0.015 if doing == &"tell" else 0.0
	_look.emission_energy_multiplier = 0.25 + fed * 1.6 + (0.8 if exposed else 0.0)
	_look.emission = Color(1.0, 0.5, 0.1) if smoked else Color(0.38, 0.5, 0.08)


func struck(point: Vector3, direction: Vector3, result: StringName) -> void:
	Fx.blood(self, point, -direction.normalized(), 0.2 if result == &"resisted" else 0.7)


func burst(_context: Node, _at: Vector3, _push: Vector3) -> void:
	visible = false
