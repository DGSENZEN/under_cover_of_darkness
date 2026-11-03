extends RefCounted
## How a revenant looks on its model, whoever is driving it: its flesh, the light in its sockets, and the lake it brings with it.

const FLESH := preload("res://scripts/Monsters/revenant_flesh.gdshader")
const HALO := preload("res://scripts/Monsters/revenant_halo.gdshader")
const POOL := preload("res://scripts/Monsters/revenant_pool.gdshader")
const BRUSH := preload("res://textures/painted/eclipse/brush.png")
const SEEP := Color("#7FD36A")
const HALO_SIZE := 0.36
const POOL_SIZE := 3.2
const FACE_LIGHT := 0.14
const FACE_LIGHT_REACH := 0.5
const FACE_LIGHT_AT := Vector3(0.0, -0.02, 0.12)


## Dresses a model made by tools/monsters/build_revenant.py. Returns its mesh.
static func dress(model: Node3D) -> MeshInstance3D:
	var mesh: MeshInstance3D = model.find_children("*", "MeshInstance3D", true, false)[0]
	var bones: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	var look := ShaderMaterial.new()
	look.shader = FLESH
	look.set_shader_parameter(&"stroke_sheet", BRUSH)
	look.set_shader_parameter(&"wet", 0.0)
	# (As the ánimas' flesh is: enough fill that its shapes hold in the dark, a neutral one, so the seep is the only colour.)
	look.set_shader_parameter(&"fill", 0.52)
	look.set_shader_parameter(&"rim", 0.2)
	look.set_shader_parameter(&"fill_sky", Color(0.38, 0.42, 0.4))
	look.set_shader_parameter(&"fill_ground", Color(0.36, 0.33, 0.28))
	look.set_shader_parameter(&"rim_colour", Color(0.42, 0.55, 0.38))
	mesh.material_override = look

	for bone in [&"eye_l", &"eye_r"]:
		var socket := BoneAttachment3D.new()
		socket.name = String(bone).capitalize().replace(" ", "")
		bones.add_child(socket)
		socket.bone_name = bone
		var quad := MeshInstance3D.new()
		quad.name = "Halo"
		var shape := QuadMesh.new()
		shape.size = Vector2(HALO_SIZE, HALO_SIZE)
		quad.mesh = shape
		var halo := ShaderMaterial.new()
		halo.shader = HALO
		halo.set_shader_parameter(&"colour", SEEP)
		quad.material_override = halo
		quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		quad.set_instance_shader_parameter(&"phase", 0.0 if bone == &"eye_l" else 2.1)
		socket.add_child(quad)

	var lit_by := BoneAttachment3D.new()
	lit_by.name = "FaceLight"
	bones.add_child(lit_by)
	lit_by.bone_name = &"eye_l"
	var light := OmniLight3D.new()
	light.light_color = SEEP
	light.light_energy = FACE_LIGHT
	light.omni_range = FACE_LIGHT_REACH
	light.shadow_enabled = false
	light.position = FACE_LIGHT_AT
	lit_by.add_child(light)
	var pool := MeshInstance3D.new()
	pool.name = "Pool"
	var disc := QuadMesh.new()
	disc.size = Vector2(POOL_SIZE, POOL_SIZE)
	disc.orientation = PlaneMesh.FACE_Y
	pool.mesh = disc
	var water := ShaderMaterial.new()
	water.shader = POOL
	water.set_shader_parameter(&"seep", SEEP)
	water.set_shader_parameter(&"stroke_sheet", BRUSH)
	pool.material_override = water
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pool.position.y = 0.012
	model.add_child(pool)
	return mesh
