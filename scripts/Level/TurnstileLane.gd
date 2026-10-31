extends Area3D
## A turnstile's lane (the Zócalo station's banks, maps/metro_station_dressing.gd): whoever walks through it turns its
## arms a third, the way they walk. Nothing stops anyone; the arms are not solid. They turn between physics ticks, so
## they are drawn uninterpolated (the M20 rule).

## How long a third's turn takes (s).
const TURN_TIME := 0.45

## The arms' pivot, on their hub; the axis they turn about (the set's frame); the way through the lane (unit, either
## way turns them).
var arms: Node3D
var axis := Vector3.RIGHT
var walk := Vector3.RIGHT
## How far they have turned (radians) and how far they are going.
var angle := 0.0
var _target := 0.0


func _ready() -> void:
	monitorable = false
	body_entered.connect(_on_body_entered)
	if arms != null:
		arms.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


## Turns the arms a third for someone coming through from `from` (a crowd's shade calls this as it passes).
func pass_through(from: Vector3) -> void:
	var way := signf((global_position - from).dot(walk))
	_target += (way if way != 0.0 else 1.0) * TAU / 3.0


func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		pass_through(body.global_position)


func _process(delta: float) -> void:
	if arms == null or is_equal_approx(angle, _target):
		return
	angle = move_toward(angle, _target, TAU / 3.0 / TURN_TIME * delta)
	arms.basis = Basis(axis, angle)
