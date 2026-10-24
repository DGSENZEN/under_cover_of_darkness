class_name Moths
extends Node3D
## Moths drawn to a light (the Underground's bulbs): each circles it on its
## own loop, rising and dipping, wings beating, on game time with a seeded
## start, so two runs of a scene fly alike. `around` is the light they
## circle; without one they circle this node.

@export var count := 3
## How far out they circle (m), how fast (turns a second), how high they rise and dip (m).
@export var reach := 0.28
@export var speed := 0.35
@export var bob := 0.12
@export var seed := 0
@export var colour := Color(0.82, 0.76, 0.62)

var around: Node3D
var _time := 0.0
var _phases: Array[Vector3] = []


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var look := StandardMaterial3D.new()
	look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	look.albedo_color = colour
	look.cull_mode = BaseMaterial3D.CULL_DISABLED

	for i in count:
		var moth := MeshInstance3D.new()
		moth.name = "moth_%d" % i
		moth.mesh = _wings()
		moth.material_override = look
		moth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(moth)
		# Where on its loop it starts, how fast its loop turns, how its wings beat.
		_phases.append(Vector3(rng.randf() * TAU, rng.randf_range(0.8, 1.3), rng.randf_range(18.0, 26.0)))

	_place()


func _process(delta: float) -> void:
	_time += delta
	_place()


func _place() -> void:
	var centre := around.global_position if around != null else global_position

	for i in get_child_count():
		var p: Vector3 = _phases[i]
		var a := p.x + TAU * speed * p.y * _time
		var out := reach * (0.7 + 0.3 * sin(a * 1.7 + p.x))
		var moth: Node3D = get_child(i)
		moth.global_position = centre + Vector3(cos(a) * out, bob * sin(a * 2.3 + p.x * 2.0), sin(a) * out)
		# Facing along its flight, wings beating.
		moth.global_basis = Basis(Vector3.UP, -a).scaled(Vector3(1.0, 1.0, 0.3 + 0.7 * absf(sin(_time * p.z))))


## Two wings in a shallow V, 5 cm across.
func _wings() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)

	for side in [-1.0, 1.0]:
		surface.add_vertex(Vector3(0, 0, -0.01))
		surface.add_vertex(Vector3(0.025 * side, 0.008, -0.012))
		surface.add_vertex(Vector3(0.02 * side, 0.006, 0.014))
		surface.add_vertex(Vector3(0, 0, -0.01))
		surface.add_vertex(Vector3(0.02 * side, 0.006, 0.014))
		surface.add_vertex(Vector3(0, 0, 0.01))

	return surface.commit()
