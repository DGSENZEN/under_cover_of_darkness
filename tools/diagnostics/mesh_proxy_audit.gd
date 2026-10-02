extends SceneTree
## Isolated rendered probe of a known collision/mesh mismatch.
## Run one process per piece: Godot --max-fps 60 --disable-vsync --path .
## --script tools/diagnostics/mesh_proxy_audit.gd -- nave_vault
## The fixture records the audited recipe's local collider and exported mesh.
const Loader := preload("res://scripts/Level/LevelLoader.gd")
const CASES := "res://tools/diagnostics/mesh_proxy_cases.json"

func _initialize() -> void:
	_run.call_deferred()

func _vec(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))

func _frames() -> void:
	# Occlusion updates asynchronously. Wait for real rendered frames, without
	# forcing draws or reusing the viewport across different cases.
	for i in 90:
		await process_frame
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var piece := args[0] if not args.is_empty() else "nave_vault"
	var entry: Dictionary
	for candidate in JSON.parse_string(FileAccess.get_file_as_string(CASES)):
		if candidate["piece"] == piece:
			entry = candidate
			break
	if entry.is_empty():
		push_error("No mesh proxy fixture for %s" % piece)
		quit(2)
		return
	root.use_occlusion_culling = true
	root.size = Vector2i(640, 360)
	root.get_node("Retro").enabled = false
	var output := "/tmp/mesh-proxy-audit/" + piece
	DirAccess.make_dir_recursive_absolute(output)
	var stage := Node3D.new()
	root.add_child(stage)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.02, 0.02, 0.02)
	stage.add_child(env)
	var src := (load(entry["file"]) as PackedScene).instantiate()
	var original := src.find_child(entry["node"], true, false) as MeshInstance3D
	if original == null:
		push_error("Missing audited mesh %s" % entry["node"])
		src.free()
		quit(2)
		return
	var draw := MeshInstance3D.new()
	draw.mesh = original.mesh
	stage.add_child(draw)
	src.free()
	var white := StandardMaterial3D.new()
	white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw.material_override = white
	var c: Array = entry["collider"]
	var rot := Vector3(deg_to_rad(float(c[8])), deg_to_rad(float(c[7])), deg_to_rad(float(c[9])))
	var at := Transform3D(Basis.from_euler(rot), _vec(c.slice(0, 3)))
	var p := _vec(entry["point"])
	var axis := Vector3.ZERO
	axis[int(entry["axis"])] = 1
	var reach := float(c[3 + int(entry["axis"])]) / 2.0 + 3.0
	var marker := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3.ONE * 0.04
	marker.mesh = box
	var red := StandardMaterial3D.new()
	red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	red.albedo_color = Color(1, 0, 0)
	marker.material_override = red
	stage.add_child(marker)
	marker.position = at * (p - axis * reach)
	var cam := Camera3D.new()
	stage.add_child(cam)
	cam.fov = 25
	cam.far = reach * 4
	cam.position = at * (p + axis * reach)
	cam.look_at(at * p, at.basis * Vector3.FORWARD if int(entry["axis"]) == 1 else at.basis * Vector3.UP)
	cam.current = true
	var level := Loader.Level.new()
	level.root = stage
	var basis := [[at.basis.x.x, at.basis.y.x, at.basis.z.x], [at.basis.x.y, at.basis.y.y, at.basis.z.y], [at.basis.x.z, at.basis.y.z, at.basis.z.z]]
	Loader._occluders(level, [{"centre": c.slice(0, 3), "basis": basis, "size": c.slice(3, 6), "surface": c[6]}])
	var holder := stage.get_node("Occluders") as Node3D
	holder.visible = false
	await _frames()
	var baseline := root.get_texture().get_image()
	baseline.save_png(output + "/open.png")
	holder.visible = true
	await _frames()
	var culled := root.get_texture().get_image()
	culled.save_png(output + "/proxy.png")
	var a := baseline.get_pixel(320, 180)
	var b := culled.get_pixel(320, 180)
	var reproduced := a.r > 0.9 and a.g < 0.1 and b.r < 0.1
	print(piece, " baseline ", a, " proxy ", b, " REPRODUCED ", reproduced)
	print("Captures: ", output)
	quit()
