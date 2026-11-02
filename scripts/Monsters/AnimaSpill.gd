extends Node3D
## What comes out of an ánima when glass goes through it. It has no blood to speak of: its low fire
## spills from the wound, with a little ash, and is gone. Rides on what it came out of.

const FireShader := preload("res://scripts/Monsters/anima_fire.gdshader")
const FIRE_SHEET := "res://assets/vfx/fire.png"

const LASTS := 0.6
const FLAMES := 3
const FLAME_SIZE := Vector2(0.26, 0.5)
const ASH := 14
const ASH_PALE := Color(0.2, 0.205, 0.22)
const ASH_DARK := Color(0.05, 0.05, 0.055)
const SPARK := Color("#A8C840")

var _flames: Array[MeshInstance3D] = []
var _sizes: Array[float] = []
var _t := 0.0


static func at(context: Node, point: Vector3, out: Vector3) -> Node3D:
	var spill: Node3D = (load("res://scripts/Monsters/AnimaSpill.gd") as GDScript).new()
	context.add_child(spill)
	spill.global_position = point
	spill._start(out)
	return spill


func _start(out: Vector3) -> void:
	add_to_group(&"anima_spill")
	var quad := QuadMesh.new()
	var look := ShaderMaterial.new()
	look.shader = FireShader
	look.set_shader_parameter(&"sheet", load(FIRE_SHEET))
	look.set_shader_parameter(&"noise", MeshVfx.noise())
	quad.material = look

	for i in FLAMES:
		var flame := MeshInstance3D.new()
		flame.mesh = quad
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flame.position = Vector3(randf_range(-0.07, 0.07), randf_range(-0.04, 0.04), randf_range(-0.07, 0.07))
		add_child(flame)
		_flames.append(flame)
		_sizes.append(randf_range(FLAME_SIZE.x, FLAME_SIZE.y))

	var ash := CPUParticles3D.new()
	ash.amount = ASH
	ash.lifetime = LASTS
	ash.one_shot = true
	ash.explosiveness = 0.85
	ash.local_coords = false
	var bit := SurfaceTool.new()
	bit.begin(Mesh.PRIMITIVE_TRIANGLES)

	for corner in [Vector3(-0.012, -0.02, 0.0), Vector3(0.016, -0.008, 0.0), Vector3(0.002, 0.022, 0.0)]:
		bit.add_vertex(corner)

	ash.mesh = bit.commit()
	ash.direction = out + Vector3.UP * 0.6
	ash.spread = 40.0
	ash.gravity = Vector3(0.0, -2.2, 0.0)
	ash.initial_velocity_min = 0.6
	ash.initial_velocity_max = 2.0
	ash.angle_max = 360.0
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.25, 0.8, 1.0])
	ramp.colors = PackedColorArray([SPARK, ASH_PALE, ASH_DARK, Color(ASH_DARK, 0.0)])
	ash.color_ramp = ramp
	var flat := StandardMaterial3D.new()
	flat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flat.vertex_color_use_as_albedo = true
	flat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	flat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ash.material_override = flat
	ash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ash.emitting = true
	add_child(ash)


func _physics_process(delta: float) -> void:
	_t += delta
	var up := smoothstep(0.0, 0.08, _t) * (1.0 - smoothstep(LASTS * 0.5, LASTS, _t))

	for i in _flames.size():
		var size := maxf(_sizes[i] * up, 0.001)
		_flames[i].basis = Basis.from_scale(Vector3(size * 1.1, size * 1.6, 1.0))

	if _t >= LASTS + 0.1:
		queue_free()
