extends SceneTree
## Rendered investigation: a collision-derived occluder seals the crane treadwheel in the user recording.
## Run with Godot --path . --script tools/diagnostics/crane_occlusion_audit.gd.
var cam: Camera3D
func _initialize() -> void:
	_run.call_deferred()
func _frames() -> void:
	for i in 120: await process_frame
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
func _run() -> void:
	root.use_occlusion_culling = true
	root.size = Vector2i(960,540)
	root.get_node('Retro').enabled = false
	var stage := Node3D.new(); root.add_child(stage)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.02,0.02,0.02)
	stage.add_child(env)
	var scene := load('res://assets/level/city_harbour/shipyard.glb') as PackedScene
	var src := scene.instantiate(); stage.add_child(src)
	var original := src.find_child('crane_jib_001', true, false) as MeshInstance3D
	if original == null:
		for node in src.find_children('*','MeshInstance3D',true,false): print(node.name)
		quit(1); return
	var m := MeshInstance3D.new(); m.mesh = original.mesh; stage.add_child(m)
	src.queue_free()
	
	var white := StandardMaterial3D.new(); white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material_override = white
	var target := MeshInstance3D.new(); var box := BoxMesh.new(); box.size = Vector3(0.4,0.4,0.4); target.mesh = box
	var red := StandardMaterial3D.new(); red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; red.albedo_color = Color(1,0,0)
	target.material_override = red; stage.add_child(target); target.position = Vector3(2,2.5,0.9)
	var loader := load('res://scripts/Level/LevelLoader.gd')
	var level = loader.Level.new(); level.root = stage
	# The existing manifest's whole wheel collider, placed in the crane's local frame.
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string('res://assets/level/city_harbour/city_harbour.json'))
	var collider: Dictionary
	for c in manifest['colliders']:
		if c['sector'] == 'shipyard' and c['size'] == [1.1,4.0,4.0]:
			collider = c.duplicate(true); break
	collider['centre'] = [-1.3,2.2,0.0]
	collider['basis'] = [[1.0,0.0,0.0],[0.0,1.0,0.0],[0.0,0.0,1.0]]
	loader._occluders(level,[collider])
	var holder := stage.get_node('Occluders') as Node3D; holder.visible = false
	cam = Camera3D.new(); stage.add_child(cam); cam.position = Vector3(-5,2.5,0.9); cam.look_at(Vector3(-1.3,2.5,0.9)); cam.current = true
	await _frames()
	var before := root.get_texture().get_image(); before.save_png('/tmp/crane-open.png')
	holder.visible = true
	await _frames()
	var after := root.get_texture().get_image(); after.save_png('/tmp/crane-occluded.png')
	print('CRANE baseline=',before.get_pixel(480,270),' collision occluder=',after.get_pixel(480,270))
	print('Reproduced false occlusion: ',before.get_pixel(480,270).r > 0.9 and after.get_pixel(480,270).r < 0.1)
	quit()
