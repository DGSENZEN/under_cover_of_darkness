extends Node3D
## Light running through a book's paper: narrow ink-like filaments and four
## glints travel along the actual page surface, in the page's moving frame.

const MeshVfx := preload("res://scripts/Visual/MeshVfx.gd")
const Layers := preload("res://scripts/Visual/Layers.gd")

var wisps: MeshInstance3D
var sparks: MultiMeshInstance3D
var _wisp_look: ShaderMaterial
var _spark_look: ShaderMaterial
var _seed := 0.0
var surface_size := Vector2(0.22, 0.3)


func build(colour: Color, phase: float) -> void:
	_seed = phase * 1.618
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	visible = false
	_wisp_look = MeshVfx.look(colour.lerp(Color.WHITE, 0.65), colour, colour.darkened(0.75), 2.1, 0.25, 0.7, _seed)
	_wisp_look.set_shader_parameter("churn", 0.0005)
	_wisp_look.set_shader_parameter("tail_eat", 0.32)
	_wisp_look.set_shader_parameter("core_reach", 0.25)
	var threads := SurfaceTool.new()
	threads.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 3:
		var path := PackedVector3Array()
		var phase_at := _seed + k * TAU / 3.0
		for j in 17:
			var t := float(j) / 16.0
			var x := lerpf(-0.46, 0.46, t) * surface_size.x
			var z := (sin(phase_at + t * 4.0) * 0.13 + (k - 1) * 0.22) * surface_size.y
			path.append(Vector3(x, 0.003 + sin(t * PI) * 0.003, z))
		threads.append_from(MeshVfx.tendril(path, 0.0025, 8), 0, Transform3D.IDENTITY)
	var mesh := threads.commit()
	mesh.surface_set_material(0, _wisp_look)
	wisps = MeshInstance3D.new()
	wisps.name = "page_filaments"
	wisps.mesh = mesh
	wisps.layers = Layers.FX
	wisps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(wisps)

	_spark_look = MeshVfx.look(colour.lerp(Color.WHITE, 0.8), colour, colour.darkened(0.5), 3.2, 0.05, 0.0, _seed)
	_spark_look.set_shader_parameter("churn", 0.0)
	_spark_look.set_shader_parameter("tail_eat", 0.0)
	var crystal := _crystal()
	crystal.surface_set_material(0, _spark_look)
	var pool := MultiMesh.new()
	pool.transform_format = MultiMesh.TRANSFORM_3D
	pool.mesh = crystal
	pool.instance_count = 4
	sparks = MultiMeshInstance3D.new()
	sparks.name = "page_glints"
	sparks.multimesh = pool
	sparks.layers = Layers.FX
	sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sparks.custom_aabb = AABB(Vector3(-0.3, 0.0, -0.3), Vector3(0.6, 1.0, 0.6))
	add_child(sparks)


func set_state(amount: float, clearance: float, time: float) -> void:
	if wisps == null:
		return
	var height := maxf(0.0, minf(clearance - 0.005, 0.018))
	visible = amount > 0.001 and height > 0.002
	if not visible:
		return
	wisps.scale.y = 1.0
	_wisp_look.set_shader_parameter("erosion", lerpf(0.95, 0.22, amount))
	_wisp_look.set_shader_parameter("opacity", amount * 0.85)
	_wisp_look.set_shader_parameter("energy", 2.1 + sin(time * 2.1 + _seed) * 0.25)
	_wisp_look.set_shader_parameter("sway", Vector3(0.0, sin(time * 1.3 + _seed) * 0.001, 0.0))
	_spark_look.set_shader_parameter("opacity", amount)
	for i in 4:
		var age := fposmod(time * (0.28 + i * 0.017) + _seed * 0.13 + i * 0.251, 1.0)
		var turn := _seed + i * 2.4 + age * 3.5
		var at := Vector3(lerpf(-0.45, 0.45, age) * surface_size.x, 0.004 + height * sin(age * PI), sin(turn) * surface_size.y * 0.35)
		var size := maxf(0.0001, sin(age * PI) * 0.0035 * amount)
		var spin := Basis(Vector3.UP, turn).rotated(Vector3.FORWARD, age * 3.0)
		sparks.multimesh.set_instance_transform(i, Transform3D(spin.scaled(Vector3(size, size * 1.7, size)), at))


func _crystal() -> ArrayMesh:
	var shape := SurfaceTool.new()
	shape.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring := [Vector3.RIGHT, Vector3.FORWARD, Vector3.LEFT, Vector3.BACK]
	for i in 4:
		for face in [[Vector3.UP, ring[i], ring[(i + 1) % 4]], [Vector3.DOWN, ring[(i + 1) % 4], ring[i]]]:
			for j in 3:
				shape.set_uv(Vector2(float(j) / 2.0, 0.3))
				shape.add_vertex(face[j])
	shape.generate_normals()
	return shape.commit()
