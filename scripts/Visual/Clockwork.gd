extends Node3D
## A turning part of the Company's engine (maps/metro_station_machinery.gd): its one child (a gear, the governor) spun
## about this node's own Y, `turns` a second, on game time from `start`. Moved every frame, so uninterpolated: physics
## interpolation would draw it a tick behind (the Metro's M20).

@export var turns := 0.1
@export var start := 0.0

var _time := 0.0


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	for part in get_children():
		part.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_turn()


func _process(delta: float) -> void:
	_time += delta
	_turn()


func _turn() -> void:
	if get_child_count() > 0:
		(get_child(0) as Node3D).basis = Basis(Vector3.UP, start + TAU * turns * _time)
