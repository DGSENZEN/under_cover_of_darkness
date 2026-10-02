extends SceneTree
## Compare an actual ship deck from below before and after LevelLoader dresses it.
## Run with Godot --path . --script tools/diagnostics/backface_audit.gd.
const Loader := preload('res://scripts/Level/LevelLoader.gd')
func _initialize() -> void:
	_run.call_deferred()
func _frames() -> void:
	for i in 60: await process_frame
	await RenderingServer.frame_post_draw
func _run() -> void:
	root.use_occlusion_culling = false
	root.size = Vector2i(960,540)
	root.get_node('Retro').enabled = false
	var stage := Node3D.new(); root.add_child(stage)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.02,0.02,0.02)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE; env.environment.ambient_light_energy = 1
	stage.add_child(env)
	var src := (load('res://assets/level/city_harbour/ships.glb') as PackedScene).instantiate()
	var original := src.find_child('carrack_hull_001',true,false) as MeshInstance3D
	var m := MeshInstance3D.new(); var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, original.mesh.surface_get_arrays(2))
	var imported := original.mesh.surface_get_material(2).duplicate() as StandardMaterial3D
	imported.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	imported.albedo_color = Color.WHITE; imported.albedo_texture = null
	imported.vertex_color_use_as_albedo = false
	mesh.surface_set_material(0,imported); m.mesh = mesh; stage.add_child(m); src.free()
	var cam := Camera3D.new(); stage.add_child(cam); cam.position = Vector3(0,0.5,0)
	cam.look_at(Vector3(0,3,0), Vector3.FORWARD); cam.current = true
	await _frames()
	var before := root.get_texture().get_image(); before.save_png('/tmp/deck-imported.png')
	Loader._dress(m)
	var runtime := m.get_surface_override_material(0) as BaseMaterial3D
	await _frames()
	var after := root.get_texture().get_image(); after.save_png('/tmp/deck-runtime.png')
	print('DECK imported cull=',imported.cull_mode,' runtime cull=',runtime.cull_mode,' center imported=',before.get_pixel(480,270),' runtime=',after.get_pixel(480,270))
	print('Reproduced lost reverse side: ',before.get_pixel(480,270).r > 0.9 and after.get_pixel(480,270).r < 0.1)
	quit()
