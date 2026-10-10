extends Node3D
## A kit's painted pieces in a row on the setts, by day, in the game's look
## (the street and canal kit's plan, Task 5), in a window (headless runs draw
## nothing):
##   Godot --path . --resolution 1600x900 res://tests/kit_stills.tscn -- --kit=street_kit --out=/tmp/kit
## <kit>_row.png along the row, <kit>_<piece>.png close to each.

const FRAMES := 12
## Space between the pieces along the row (m).
const GAP := 2.0

var out := "/tmp/kit/"
var kit := "street_kit"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=").trim_suffix("/") + "/"
		elif arg.begins_with("--kit="):
			kit = arg.trim_prefix("--kit=")

	DirAccess.make_dir_recursive_absolute(out)
	_lights()
	var meshes := KitLoader.meshes(kit)
	var x := 0.0
	var spots := {}
	var inlays := []

	for name in meshes:
		var mesh: Mesh = meshes[name]
		var box := mesh.get_aabb()
		var piece := MeshInstance3D.new()
		piece.name = name
		piece.mesh = mesh
		piece.material_override = KitLoader.material(kit)
		add_child(piece)
		piece.position = Vector3(x - box.position.x, 0, 0)
		spots[name] = piece.position + box.get_center()
		x += box.size.x + GAP

		# Pieces let into the ground (their tops at the setts') are set in it,
		# as the dresser lays them; the curve's ring is no rectangle, so the
		# ground lies a hair under it instead.
		if box.end.y < 0.01 and not String(name).ends_with("curve"):
			var r := Rect2(piece.position.x + box.position.x, box.position.z, box.size.x, box.size.z)
			inlays.append(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]))

	var ground := Ground.build(Rect2(-4, -8, x + 8, 16), [], [], 3, {"tile": &"ground_setts", "level": -0.003,
		"inlays": inlays})
	add_child(ground)
	var eye := Camera3D.new()
	eye.fov = 50.0
	add_child(eye)
	eye.make_current()
	eye.global_transform = Transform3D(Basis(), Vector3(x * 0.5, 6.0, 9.0)).looking_at(Vector3(x * 0.5, 0, -1), Vector3.UP)
	await _frames(FRAMES)
	_save(kit + "_row.png")

	for name in spots:
		var at: Vector3 = spots[name]
		var size: float = maxf((meshes[name] as Mesh).get_aabb().get_longest_axis_size(), 1.0)
		eye.global_transform = Transform3D(Basis(), at + Vector3(size * 0.55, size * 0.6 + 0.4, size * 0.9)) \
			.looking_at(at, Vector3.UP)
		await _frames(FRAMES)
		_save("%s_%s.png" % [kit, name])

	get_tree().quit()


func _lights() -> void:
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
	sun.rotation = Vector3(deg_to_rad(-50), deg_to_rad(-35), 0)


func _save(file: String) -> void:
	get_viewport().get_texture().get_image().save_png(out + file)
	print("still: ", out + file)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
