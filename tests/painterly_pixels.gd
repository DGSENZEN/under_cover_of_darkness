extends Node3D
## The painterly shader's pixels (the Eclipse city's style lab, Task 2), in a
## window (headless runs draw nothing):
##   Godot --path . --resolution 640x360 res://tests/painterly_pixels.tscn
## A quad filling a 64 x 64 view, drawn unshaded, read back after 5 frames.

const Painterly := preload("res://scripts/Visual/Painterly.gd")
const UNSHADED := preload("res://scripts/Visual/painterly_unshaded.gdshader")

const VIEW := 64
const CELLS := 4
const TOLERANCE := 2.0 / 255.0
## The test atlas: a 4 x 4 checker of colours the palette does not hold.
const CHECKER := [Color8(200, 30, 40), Color8(30, 160, 210), Color8(240, 230, 60), Color8(90, 20, 140)]

var results: Array[String] = []


func _ready() -> void:
	var atlas := _checker()
	var plain := await _draw(atlas, 0.0, 0.12)
	var mapped := await _draw(atlas, 1.0, 0.0)

	# X1 paint_mix 0: the atlas, texel for texel
	var off := 0

	for y in VIEW:
		for x in VIEW:
			var want: Color = atlas.get_image().get_pixel(x * CELLS / VIEW, y * CELLS / VIEW)

			if not _near(plain.get_pixel(x, y), want):
				off += 1

	_check("X1 paint_mix 0 draws the painted atlas as it is", off == 0, "%d of %d pixels off" % [off, VIEW * VIEW])

	# X2 paint_mix 1, no strokes: only the palette's colours
	var palette := Painterly.ZOCALO.get_image()
	var outside := 0

	for y in VIEW:
		for x in VIEW:
			var found := false

			for i in palette.get_width():
				if _near(mapped.get_pixel(x, y), palette.get_pixel(i, 0)):
					found = true
					break

			if not found:
				outside += 1

	_check("X2 paint_mix 1 maps every pixel onto the Zócalo palette", outside == 0, "%d pixels outside" % outside)

	# X3 both shaders compiled and drew (the run's log has no SHADER ERROR)
	_check("X3 both painterly shaders draw", plain.get_pixel(32, 32).a > 0.0 and not plain.is_invisible()
		and mapped.get_pixel(32, 32) != Color(0, 0, 0, 1) and Painterly.SHADER.get_mode() == Shader.MODE_SPATIAL,
		"centre %s / %s" % [plain.get_pixel(32, 32), mapped.get_pixel(32, 32)])

	print("\n==== RESULTS ====")
	for r in results:
		print(r)

	get_tree().quit()


func _checker() -> ImageTexture:
	var image := Image.create(CELLS, CELLS, false, Image.FORMAT_RGB8)

	for y in CELLS:
		for x in CELLS:
			image.set_pixel(x, y, CHECKER[(x + y * 3) % CHECKER.size()])

	return ImageTexture.create_from_image(image)


## The quad drawn with the unshaded painterly shader at these settings.
func _draw(atlas: Texture2D, paint_mix: float, stroke_strength: float) -> Image:
	var view := SubViewport.new()
	view.size = Vector2i(VIEW, VIEW)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.0
	view.add_child(camera)

	var material: ShaderMaterial = Painterly.material(atlas, &"even")
	material.shader = UNSHADED
	material.set_shader_parameter("paint_mix", paint_mix)
	material.set_shader_parameter("stroke_strength", stroke_strength)

	var quad := MeshInstance3D.new()
	quad.mesh = QuadMesh.new()
	(quad.mesh as QuadMesh).size = Vector2(2, 2)
	quad.position = Vector3(0, 0, -1)
	quad.material_override = material
	view.add_child(quad)

	for i in 5:
		await RenderingServer.frame_post_draw

	var image := view.get_texture().get_image()
	view.queue_free()
	return image


func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) <= TOLERANCE and absf(a.g - b.g) <= TOLERANCE and absf(a.b - b.b) <= TOLERANCE


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
