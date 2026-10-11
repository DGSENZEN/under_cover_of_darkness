extends Node3D
## A kit's pieces in the district's gusting wind (Gusts.gd), filmed: frames a
## tenth of a second apart, for a clip of the trees moving. In a window:
##   Godot --path . --resolution 960x540 res://tests/tree_clip.tscn -- --kit=trees_kit --out=/tmp/trees_clip
## frame_000.png ... (tools/eclipse/clip.py makes them a GIF).

const FRAMES := 60
const GAP := 3.0

var out := "/tmp/trees_clip/"
var kit := "trees_kit"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=").trim_suffix("/") + "/"
		elif arg.begins_with("--kit="):
			kit = arg.trim_prefix("--kit=")

	DirAccess.make_dir_recursive_absolute(out)
	var loader := KitLoader.new()
	add_child(loader)
	var meshes := KitLoader.meshes(kit)
	var x := 0.0

	for name in ["tree_ash", "palm_canary", "tree_laurel", "tree_willow", "ahuehuete_split", "tree_ash_young"]:
		if not meshes.has(name):
			continue

		var box: AABB = (meshes[name] as Mesh).get_aabb()
		var piece := MeshInstance3D.new()
		piece.mesh = loader._dressed(kit, name, meshes[name])
		add_child(piece)
		piece.position = Vector3(x - box.position.x, 0, 0)
		x += box.size.x + GAP

	var ground := Ground.build(Rect2(-20, -30, x + 40, 70), [], [], 3, {"tile": &"ground_flags", "level": -0.003})
	add_child(ground)
	var gusts := Gusts.new()
	gusts.gust = 8.0
	add_child(gusts)
	var environment := Environment.new()
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	environment.sky = sky
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	add_child(sun)
	sun.rotation = Vector3(deg_to_rad(-40), deg_to_rad(-30), 0)
	var eye := Camera3D.new()
	eye.fov = 62.0
	add_child(eye)
	eye.make_current()
	eye.global_transform = Transform3D(Basis(), Vector3(x * 0.5 - 3.0, 4.0, 30.0)).looking_at(Vector3(x * 0.5 - 3.0, 5.0, 0), Vector3.UP)
	for i in 20:
		await get_tree().process_frame

	for k in FRAMES:
		var start := Time.get_ticks_msec()

		while Time.get_ticks_msec() - start < 100:
			await get_tree().process_frame

		RenderingServer.force_draw()
		get_viewport().get_texture().get_image().save_png(out + "frame_%03d.png" % k)

	print("clip: %d frames in %s" % [FRAMES, out])
	get_tree().quit()
