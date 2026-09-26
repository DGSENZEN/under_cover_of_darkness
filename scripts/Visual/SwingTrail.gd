extends MeshInstance3D
## A fading ribbon behind a moving blade, the smear a sword leaves in the air.
##
## The owner calls `push(base, tip)` every frame while the blade cuts, with
## both points in this node's own space (set `top_level` for world space).
## Old samples fade and drop off on their own once pushing stops.

const Layers := preload("res://scripts/Visual/Layers.gd")
const SHADER := preload("res://scripts/Visual/trail.gdshader")
## The viewmodel's depth squeeze, as its materials have it (ViewArms.Z_CLIP).
const ON_TOP_Z_CLIP := 0.05

## Seconds a sample lives before it has faded out.
@export var lifetime := 0.13
## The light's colour; alpha is how bright it is at its brightest (it is
## added to what is behind it: see trail.gdshader).
@export var color := Color(0.88, 0.92, 1.0, 0.5)
## Smoothing: extra points between samples, along a Catmull-Rom curve.
@export var subdivisions := 3
## How far from the hilt the ribbon becomes visible: 0 hilt, 1 tip.
@export_range(0.0, 1.0, 0.05) var base_fade := 0.0

var _base: Array[Vector3] = []
var _tip: Array[Vector3] = []
var _age: Array[float] = []
var _mesh := ImmediateMesh.new()
var _material: ShaderMaterial


## `on_top`: drawn over the world like the hands (for the viewmodel).
func setup(render_layers: int, on_top := false) -> void:
	layers = render_layers
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	mesh = _mesh

	_material = ShaderMaterial.new()
	_material.shader = SHADER

	# Squeezed in front of the world like the hands, so a hand still covers
	# the smear behind it.
	if on_top:
		_material.set_shader_parameter("z_clip", ON_TOP_Z_CLIP)
		_material.render_priority = 11

	material_override = _material


func _ready() -> void:
	if _material == null:
		setup(Layers.FX)

	# The ribbon is rebuilt around its points; never cull it on a stale box.
	custom_aabb = AABB(Vector3(-500, -500, -500), Vector3(1000, 1000, 1000))


func push(base: Vector3, tip: Vector3) -> void:
	_base.append(base)
	_tip.append(tip)
	_age.append(0.0)


## Forget everything at once (a weapon was put away mid-swing).
func clear() -> void:
	_base.clear()
	_tip.clear()
	_age.clear()
	_mesh.clear_surfaces()


func sample_count() -> int:
	return _age.size()


func _process(delta: float) -> void:
	for i in range(_age.size()):
		_age[i] += delta

	while not _age.is_empty() and _age[0] >= lifetime:
		_base.pop_front()
		_tip.pop_front()
		_age.pop_front()

	_rebuild()


func _rebuild() -> void:
	_mesh.clear_surfaces()
	var count := _age.size()

	if count < 2:
		return

	_material.set_shader_parameter("tint", Color(color.r, color.g, color.b, 1.0))
	_material.set_shader_parameter("strength", color.a)
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)

	for i in range(count - 1):
		var steps := subdivisions + 1 if i < count - 2 else subdivisions + 2

		for s in range(steps):
			var u := float(s) / float(subdivisions + 1)
			var base := _catmull(_base, i, u)
			var tip := _catmull(_tip, i, u)
			var age := clampf(lerpf(_age[i], _age[i + 1], u) / maxf(lifetime, 0.001), 0.0, 1.0)

			# Across the ribbon, from where it starts (toward the hilt) to the
			# edge's path; along it, by age. The shader draws the light.
			_mesh.surface_set_uv(Vector2(age, 0.0))
			_mesh.surface_add_vertex(base.lerp(tip, base_fade))
			_mesh.surface_set_uv(Vector2(age, 1.0))
			_mesh.surface_add_vertex(tip)

	_mesh.surface_end()


## Catmull-Rom between points i and i + 1, with the ends clamped.
func _catmull(points: Array[Vector3], i: int, u: float) -> Vector3:
	var last := points.size() - 1
	var p0: Vector3 = points[maxi(i - 1, 0)]
	var p1: Vector3 = points[i]
	var p2: Vector3 = points[mini(i + 1, last)]
	var p3: Vector3 = points[mini(i + 2, last)]
	var u2 := u * u
	var u3 := u2 * u
	return 0.5 * (
		2.0 * p1
		+ (p2 - p0) * u
		+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * u2
		+ (3.0 * p1 - p0 - 3.0 * p2 + p3) * u3
	)
