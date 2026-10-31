extends Node3D
## One of the Company's engine's flywheels and what it drives (maps/metro_station_machinery.gd; the kit's linkage in
## tools/eclipse/station_engine.py). This node stands at the wheel's centre, its X across the wheel's face, its Y out
## along the wheel's axle, its Z down; its children: `flywheel` (turned about Y, its crank's pin at (throw, out, 0)),
## `conrod` (from the pin, its own Y toward the crosshead's pin, `conrod` long) and `crosshead` (its pin straight over
## the wheel's centre, `out` from the wheel's face, riding up and down its slide bars). On game time, uninterpolated.

@export var turns := 0.25
@export var start := 0.0
@export var throw := 0.32
@export var conrod := 0.95
@export var out := 0.27

var _time := 0.0


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	for part in get_children():
		part.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_turn()


func _process(delta: float) -> void:
	_time += delta
	_turn()


## The crosshead's pin's height over the wheel's centre at crank angle `t` (rising first from across the face).
func head_height(t: float) -> float:
	return throw * sin(t) + sqrt(conrod * conrod - pow(throw * cos(t), 2.0))


func _turn() -> void:
	var t := start + TAU * turns * _time
	var wheel := get_node_or_null("flywheel") as Node3D
	var rod := get_node_or_null("conrod") as Node3D
	var head := get_node_or_null("crosshead") as Node3D
	if wheel == null or rod == null or head == null:
		return
	wheel.transform = Transform3D(Basis(Vector3.UP, t), Vector3.ZERO)
	var pin := Vector3(throw * cos(t), out, -throw * sin(t))
	var top := Vector3(0.0, out, -head_height(t))
	# (The crosshead upright, its pin along the axle; the conrod from pin to pin, its eyes along the axle too.)
	head.transform = Transform3D(Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP), top)
	var along := (top - pin).normalized()
	var axle := Vector3.UP
	rod.transform = Transform3D(Basis(along.cross(axle), along, axle), pin)
