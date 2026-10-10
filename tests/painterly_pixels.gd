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

	# At each texel's centre (bilinear filtering blends between them, as the
	# PS2 did, so only there is a texel itself). The centre falls up to a
	# pixel off the read grid, so the best of the 3 x 3 pixels round it,
	# within a few percent's blend (half a pixel each way is 3% of a
	# neighbour per axis, 0.05 at most in linear light, where the filter
	# blends); a palette mapping or stroke moves it far more.
	var step := VIEW / CELLS

	for cy in CELLS:
		for cx in CELLS:
			var want: Color = atlas.get_image().get_pixel(cx, cy)
			var best := INF

			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					var got: Color = plain.get_pixel(cx * step + step / 2 + dx, cy * step + step / 2 + dy).srgb_to_linear()
					var lin := want.srgb_to_linear()
					best = minf(best, maxf(maxf(absf(got.r - lin.r), absf(got.g - lin.g)), absf(got.b - lin.b)))

			if best > 0.06:
				off += 1

	_check("X1 paint_mix 0 draws the painted atlas as it is", off == 0, "%d of %d texel centres off" % [off, CELLS * CELLS])

	# X7 PS2-style smooth filtering: between two texels the colour blends
	var edge: Color = plain.get_pixel(step - 1, step / 2)
	var left: Color = atlas.get_image().get_pixel(0, 0)
	var right: Color = atlas.get_image().get_pixel(1, 0)
	_check("X7 the atlas is filtered smoothly (PS2): between texels the colours blend",
		not _near(edge, left) and not _near(edge, right), "edge %s between %s and %s" % [edge, left, right])

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

	# X4 painted light: a white sphere under one light falls into a few
	#    bands with it on, a smooth ramp of shades with it off
	var smooth_levels := await _sphere_levels(0.0)
	var banded_levels := await _sphere_levels(1.0)
	_check("X4 painted light bands the shading (3 bands: a handful of shades, against a smooth ramp)",
		banded_levels <= 6 and smooth_levels >= 20, "painted %d shades, plain %d" % [banded_levels, smooth_levels])

	# X5 the light ramp: with a ramp from red (no light) to green (full),
	#    the sphere's shadow side reads red and its lit side green
	var ramp_image := Image.create(64, 1, false, Image.FORMAT_RGB8)

	for i in 64:
		ramp_image.set_pixel(i, 0, Color(1, 0, 0) if i < 32 else Color(0, 1, 0))

	var ramped := await _sphere({"painted_light": 1.0, "ramp_amount": 1.0,
		"light_ramp": ImageTexture.create_from_image(ramp_image)}, true)
	var reds := 0
	var greens := 0
	var drawn := 0

	for y in ramped.get_height():
		for x in ramped.get_width():
			var c := ramped.get_pixel(x, y)

			if c.r + c.g + c.b > 0.02:
				drawn += 1
				reds += int(c.r > c.g * 2.0)
				greens += int(c.g > c.r * 2.0)

	_check("X5 the light ramp colours the light: red where none falls, green where it is full",
		drawn > 400 and reds > drawn * 0.15 and greens > drawn * 0.15, "%d drawn: %d red, %d green" % [drawn, reds, greens])

	# X6 painted ambient: with no light at all, the sphere's top takes the sky
	#    colour and its underside the ground's
	var hemi := await _sphere({"ambient_amount": 1.0, "ambient_sky": Color(0, 0, 1), "ambient_ground": Color(1, 0.5, 0)}, false)
	var top := _band_colour(hemi, 0.0, 0.3)
	var bottom := _band_colour(hemi, 0.7, 1.0)
	_check("X6 painted ambient: sky from above, ground's bounce from below",
		top.b > top.r and bottom.r > bottom.b, "top %s bottom %s" % [top, bottom])

	# Vertex paint (the vertex-paint plan, Task 6): a quad whose corners
	# carry colours, drawn unshaded over the checker with a pure green under
	# layer, strokes and palette off unless named.
	var green := Image.create(4, 4, false, Image.FORMAT_RGB8)
	green.fill(Color(0, 1, 0))
	var under := ImageTexture.create_from_image(green)
	var neutral := func(_x: float) -> Color: return Color(0.0, 0.0, 0.5, 1.0)

	# X8 vertex_paint 0: whatever the colours, today's image
	var odd := await _painted_quad(atlas, under, func(_x: float) -> Color: return Color(1, 1, 0, 0.3),
		{"vertex_paint": 0.0, "stroke_strength": 0.12})
	var drift := 0.0

	for y in VIEW:
		for x in VIEW:
			var a := odd.get_pixel(x, y)
			var b := plain.get_pixel(x, y)
			drift = maxf(drift, maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b))))

	_check("X8 vertex_paint 0 reproduces today's image", drift <= 1.0 / 255.0 + 1e-4, "largest difference %.4f" % drift)

	# X9 G = 1: the under layer everywhere
	var worn := await _painted_quad(atlas, under, func(_x: float) -> Color: return Color(0, 1, 0.5, 1),
		{"vertex_paint": 1.0, "stroke_strength": 0.0})
	_check("X9 G = 1 shows the under layer", _share(worn, _is_green) > 0.9, "%.2f green" % _share(worn, _is_green))

	# X10 G rising left to right: the edge where it wears through is ragged,
	#     not a straight line (the brush breaks it)
	var ramp := await _painted_quad(atlas, under, func(x: float) -> Color: return Color(0, (x + 1.0) / 2.0, 0.5, 1),
		{"vertex_paint": 1.0, "stroke_strength": 0.0})
	var edges := []

	for y in VIEW:
		for x in VIEW:
			if _is_green(ramp.get_pixel(x, y)):
				edges.append(x)
				break

	var spread: int = (edges.max() - edges.min()) if edges.size() == VIEW else -1
	_check("X10 the wear-through's edge is ragged", spread > 3, "edge column spread %d px over %d rows" % [spread, edges.size()])

	# X11 R: grime darkens
	var clean := await _painted_quad(atlas, under, neutral, {"vertex_paint": 1.0, "stroke_strength": 0.0})
	var grimy := await _painted_quad(atlas, under, func(_x: float) -> Color: return Color(1, 0, 0.5, 1),
		{"vertex_paint": 1.0, "stroke_strength": 0.0})
	var darker := _mean_value(clean) - _mean_value(grimy)
	_check("X11 R grime darkens", darker > 0.1, "mean value drops %.3f" % darker)

	# X12 A: baked light pulls the lit sphere toward the ramp's shadow end
	#     (red: no light, green: full, as X5)
	var open_reds := _reds(await _sphere({"painted_light": 1.0, "ramp_amount": 1.0, "vertex_paint": 1.0,
		"light_ramp": ImageTexture.create_from_image(ramp_image)}, true, Color(0, 0, 0.5, 1.0)))
	var shut_reds := _reds(await _sphere({"painted_light": 1.0, "ramp_amount": 1.0, "vertex_paint": 1.0,
		"light_ramp": ImageTexture.create_from_image(ramp_image)}, true, Color(0, 0, 0.5, 0.3)))
	_check("X12 A baked light takes light away: more of the sphere reads unlit", shut_reds > open_reds + 200,
		"red pixels open %d, occluded %d" % [open_reds, shut_reds])

	# Hex-tiling (Task 7): a 20 m plane of a 1 m noise tile, seen from above
	# at 16 px a tile, then along it at a grazing angle
	var noise := _noise_tile()
	var plain_top := await _tiled_plane(noise, {"tiled": 0.0, "hex_tiling": 0.0}, false)
	var hex_top := await _tiled_plane(noise, {"tiled": 1.0, "hex_tiling": 1.0}, false)
	var plain_repeat := _shift_correlation(plain_top, PLANE_TILE_PX)
	var hex_repeat := _shift_correlation(hex_top, PLANE_TILE_PX)
	_check("X13 plain tiling repeats at its period", plain_repeat > 0.9, "correlation one tile along %.3f" % plain_repeat)
	_check("X14 hex-tiling breaks the repeat", hex_repeat < 0.5, "correlation one tile along %.3f" % hex_repeat)
	var plain_far := _rough_edges(await _tiled_plane(noise, {"tiled": 0.0, "hex_tiling": 0.0}, true))
	var hex_far := _rough_edges(await _tiled_plane(noise, {"tiled": 1.0, "hex_tiling": 1.0}, true))
	_check("X15 no seams at a distance: hex-tiling's sharpest steps no worse than plain tiling's",
		plain_far > 0.0 and hex_far <= plain_far * 1.5, "99th-percentile neighbour step: hex %.4f, plain %.4f" % [hex_far, plain_far])

	# X17 hex-tiled relief turns with its colour: in every hexagon the
	#     relief leans the way the colour runs (a tile whose red rises along u,
	#     its normals leaning +u). Plain tiling must agree too (it fixes the
	#     conventions); a normal turned the wrong way leans 2a off.
	var plain_agree := await _relief_follows_colour({"tiled": 1.0, "hex_tiling": 0.0})
	var hex_agree := await _relief_follows_colour({"tiled": 1.0, "hex_tiling": 1.0})
	_check("X17 hex-tiled relief leans the way its colour runs", plain_agree > 0.9 and hex_agree > 0.8,
		"pixels agreeing within 25 degrees: plain %.2f, hex %.2f" % [plain_agree, hex_agree])

	# X18 where a lamp's light has died, it adds nothing: the ground there is
	#     as dark as with no lamp at all (Godot runs a light over whole screen
	#     tiles; a floor added there showed as blocky bands round each lamp)
	var lit_ground := await _lamp_ground(true)
	var unlit_ground := await _lamp_ground(false)
	var px_per_m := lit_ground.get_width() / LAMP_VIEW_M
	var centre := lit_ground.get_width() / 2
	var far_lit := lit_ground.get_pixel(centre + int(9.0 * px_per_m), centre).get_luminance()
	var far_unlit := unlit_ground.get_pixel(centre + int(9.0 * px_per_m), centre).get_luminance()
	_check("X18 past a lamp's reach the ground is as dark as with no lamp", absf(far_lit - far_unlit) < 2.0 / 255.0,
		"9 m out: with the lamp %.4f, without %.4f" % [far_lit, far_unlit])

	# X19 a lamp's light falls off smoothly: no hard step as you walk away
	var steepest := 0.0
	var profile := []

	for k in range(2, 30):
		var a := lit_ground.get_pixel(centre + int(k * 0.25 * px_per_m), centre).get_luminance()
		var b := lit_ground.get_pixel(centre + int((k + 1) * 0.25 * px_per_m), centre).get_luminance()
		steepest = maxf(steepest, absf(a - b))
		profile.append("%.2f" % a)

	_check("X19 a lamp's light falls off smoothly (no step over 0.06 in a quarter metre)", steepest < 0.06,
		"steepest %.3f, profile %s" % [steepest, profile.slice(0, 16)])

	# X20 baked light dims the highlight too (an occluded corner keeps no shine)
	var shine := {"painted_light": 0.0, "ramp_amount": 0.0, "ambient_amount": 0.0, "rim_amount": 0.0,
		"macro_amount": 0.0, "specular": 1.0, "roughness": 0.15, "vertex_paint": 1.0}
	var bright_open := _brightest(await _sphere(shine, true, Color(0, 0, 0.5, 1.0)))
	var bright_shut := _brightest(await _sphere(shine, true, Color(0, 0, 0.5, 0.0)))
	_check("X20 baked light dims the highlight as well as the light", bright_shut < bright_open * 0.5,
		"brightest open %.3f, occluded %.3f" % [bright_open, bright_shut])

	# X16 the macro layer: one quad drawn at two places half a macro scale
	#     apart differs with it on, and is the same with it off
	var flat := {"vertex_paint": 0.0, "stroke_strength": 0.0}
	var here := await _painted_quad(atlas, under, neutral, flat.merged({"macro_amount": 1.0}))
	var there := await _painted_quad(atlas, under, neutral, flat.merged({"macro_amount": 1.0}), Vector3(11.5, 0, 0))
	var here_off := await _painted_quad(atlas, under, neutral, flat.merged({"macro_amount": 0.0}))
	var there_off := await _painted_quad(atlas, under, neutral, flat.merged({"macro_amount": 0.0}), Vector3(11.5, 0, 0))
	var apart := absf(_mean_value(here) - _mean_value(there))
	var apart_off := absf(_mean_value(here_off) - _mean_value(there_off))
	_check("X16 one quad at two places differs through the macro layer, and not without it",
		apart > 2.0 / 255.0 and apart_off <= 1.0 / 255.0, "mean value apart: on %.4f, off %.4f" % [apart, apart_off])

	print("\n==== RESULTS ====")
	for r in results:
		print(r)

	get_tree().quit()


const PLANE_M := 20.0
const PLANE_TILE_PX := 16


## A 64 px tile of soft seeded blobs.
func _noise_tile() -> Texture2D:
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	var small := Image.create(16, 16, false, Image.FORMAT_RGB8)

	for y in 16:
		for x in 16:
			var v := rng.randf()
			small.set_pixel(x, y, Color(v, 1.0 - v, rng.randf()))

	small.resize(64, 64, Image.INTERPOLATE_CUBIC)
	small.generate_mipmaps()
	return ImageTexture.create_from_image(small)


## A PLANE_M square plane of `tile`, one tile a metre (UV in metres), drawn
## unshaded from straight above at PLANE_TILE_PX a tile, or from a grazing
## eye looking along it.
func _tiled_plane(tile: Texture2D, settings: Dictionary, grazing: bool) -> Image:
	var px := int(PLANE_M) * PLANE_TILE_PX
	var view := SubViewport.new()
	view.size = Vector2i(px, px) if not grazing else Vector2i(320, 180)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	var camera := Camera3D.new()

	if grazing:
		camera.position = Vector3(0, 1.7, PLANE_M / 2)
		camera.rotation = Vector3(-0.12, 0, 0)
	else:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = PLANE_M
		camera.position = Vector3(0, 10, 0)
		camera.rotation = Vector3(-PI / 2, 0, 0)

	view.add_child(camera)
	var material: ShaderMaterial = Painterly.material(tile, &"even")
	material.shader = UNSHADED
	material.set_shader_parameter("paint_mix", 0.0)
	material.set_shader_parameter("stroke_strength", 0.0)

	for key in settings:
		material.set_shader_parameter(key, settings[key])

	var plane := PlaneMesh.new()
	plane.size = Vector2(PLANE_M, PLANE_M)
	var arrays := plane.get_mesh_arrays()
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]

	for i in uvs.size():
		uvs[i] *= PLANE_M

	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var ground := MeshInstance3D.new()
	ground.mesh = mesh
	ground.material_override = material
	view.add_child(ground)

	for i in 5:
		await RenderingServer.frame_post_draw

	var image := view.get_texture().get_image()
	view.queue_free()
	return image


const LAMP_VIEW_M := 20.0
const LAMP_RANGE := 8.0
const LAMP_HEIGHT := 3.0


## A white ground seen from straight above in the shader-led look (painted
## light and ramp; no ambient, rim, macro or strokes), lit by one lamp
## LAMP_HEIGHT over its middle, LAMP_RANGE its range, nothing else.
func _lamp_ground(lamp_on: bool) -> Image:
	var view := SubViewport.new()
	view.size = Vector2i(320, 320)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	world.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color.BLACK
	view.add_child(world)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = LAMP_VIEW_M
	camera.position = Vector3(0, 10, 0)
	camera.rotation = Vector3(-PI / 2, 0, 0)
	view.add_child(camera)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, LAMP_HEIGHT, 0)
	lamp.omni_range = LAMP_RANGE
	lamp.light_energy = 1.6
	lamp.visible = lamp_on
	view.add_child(lamp)
	var white := Image.create(4, 4, false, Image.FORMAT_RGB8)
	white.fill(Color.WHITE)
	var material: ShaderMaterial = Painterly.material(ImageTexture.create_from_image(white), &"shader_led")

	for key in {"paint_mix": 0.0, "stroke_strength": 0.0, "terminator_break": 0.0, "specular": 0.0,
			"ambient_amount": 0.0, "rim_amount": 0.0, "macro_amount": 0.0}:
		material.set_shader_parameter(key, 0.0)

	var plane := MeshInstance3D.new()
	plane.mesh = PlaneMesh.new()
	(plane.mesh as PlaneMesh).size = Vector2(LAMP_VIEW_M, LAMP_VIEW_M)
	plane.material_override = material
	view.add_child(plane)

	for i in 5:
		await RenderingServer.frame_post_draw

	var image := view.get_texture().get_image()
	view.queue_free()
	return image


## The share of pixels where the relief leans the way the colour runs, on
## a 10 m plane seen from above: the colour's direction from an unlit draw
## (red rising along u), the relief's from four lit draws (from +x, -x, +z,
## -z: their differences give the lean's x and z).
func _relief_follows_colour(settings: Dictionary) -> float:
	var ramp := Image.create(64, 64, false, Image.FORMAT_RGB8)

	for y in 64:
		for x in 64:
			ramp.set_pixel(x, y, Color(x / 63.0, 0.0, 0.0))

	ramp.generate_mipmaps()
	var lean := Image.create(8, 8, false, Image.FORMAT_RGB8)
	lean.fill(Color(0.85, 0.5, 0.85))
	lean.generate_mipmaps()
	var colour := ImageTexture.create_from_image(ramp)
	var relief := ImageTexture.create_from_image(lean)
	var flat := await _seen_plane(colour, relief, settings, -1.0)
	var lit := []

	for yaw in [PI / 2, -PI / 2, 0.0, PI]:          # lit from +x, -x, +z, -z
		lit.append(await _seen_plane(colour, relief, settings, yaw))

	var agree := 0
	var counted := 0

	for y in range(2, flat.get_height() - 2):
		for x in range(2, flat.get_width() - 2):
			var gx := flat.get_pixel(x + 1, y).r - flat.get_pixel(x - 1, y).r
			var gz := flat.get_pixel(x, y + 1).r - flat.get_pixel(x, y - 1).r

			# Only where the ramp runs smoothly (not across its wrap).
			if Vector2(gx, gz).length() < 0.004 or Vector2(gx, gz).length() > 0.08:
				continue

			var nx: float = lit[0].get_pixel(x, y).r - lit[1].get_pixel(x, y).r
			var nz: float = lit[2].get_pixel(x, y).r - lit[3].get_pixel(x, y).r

			if Vector2(nx, nz).length() < 0.02:
				continue

			counted += 1
			agree += int(absf(angle_difference(Vector2(gx, gz).angle(), Vector2(nx, nz).angle())) < deg_to_rad(25.0))

	return float(agree) / maxi(counted, 1)


## A 10 m plane at 32 px a metre seen from straight above (image x is world
## x, image y world z), its colour `colour` and relief `relief` a metre a
## tile: lit by one sun at 57 degrees turned `yaw`, or unshaded when `yaw`
## is -1.
func _seen_plane(colour: Texture2D, relief: Texture2D, settings: Dictionary, yaw: float) -> Image:
	var size := 10.0
	var view := SubViewport.new()
	view.size = Vector2i(320, 320)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	world.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	view.add_child(world)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = size
	camera.position = Vector3(0, 10, 0)
	camera.rotation = Vector3(-PI / 2, 0, 0)
	view.add_child(camera)
	var white := Image.create(4, 4, false, Image.FORMAT_RGB8)
	white.fill(Color.WHITE)
	var material: ShaderMaterial = Painterly.material(colour if yaw == -1.0 else ImageTexture.create_from_image(white),
		&"even", Painterly.ZOCALO, relief)

	if yaw == -1.0:
		material.shader = UNSHADED
	else:
		var sun := DirectionalLight3D.new()
		sun.rotation = Vector3(-1.0, yaw, 0)
		view.add_child(sun)

	for key in {"paint_mix": 0.0, "stroke_strength": 0.0, "terminator_break": 0.0, "specular": 0.0}:
		material.set_shader_parameter(key, 0.0)

	for key in settings:
		material.set_shader_parameter(key, settings[key])

	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	var arrays := plane.get_mesh_arrays()
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]

	for i in uvs.size():
		uvs[i] *= size

	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var ground := MeshInstance3D.new()
	ground.mesh = mesh
	ground.material_override = material
	view.add_child(ground)

	for i in 5:
		await RenderingServer.frame_post_draw

	var image := view.get_texture().get_image()
	view.queue_free()
	return image


## How alike the image is to itself moved `shift` px along x (Pearson's r
## of the luminance, over the middle of the image).
func _shift_correlation(image: Image, shift: int) -> float:
	var a := PackedFloat32Array()
	var b := PackedFloat32Array()
	var w := image.get_width()

	for y in range(w / 8, w - w / 8, 2):
		for x in range(w / 8, w - w / 8 - shift, 2):
			a.append(image.get_pixel(x, y).get_luminance())
			b.append(image.get_pixel(x + shift, y).get_luminance())

	var ma := 0.0
	var mb := 0.0

	for i in a.size():
		ma += a[i]
		mb += b[i]

	ma /= a.size()
	mb /= b.size()
	var sab := 0.0
	var saa := 0.0
	var sbb := 0.0

	for i in a.size():
		sab += (a[i] - ma) * (b[i] - mb)
		saa += (a[i] - ma) * (a[i] - ma)
		sbb += (b[i] - mb) * (b[i] - mb)

	return sab / sqrt(maxf(saa * sbb, 1e-12))


## The 99th-percentile step between neighbouring pixels across the plane's
## far stretch, just under the horizon (mip seams show as lines of sharp
## steps).
func _rough_edges(image: Image) -> float:
	var steps := []

	for y in range(int(image.get_height() * 0.45), int(image.get_height() * 0.75)):
		for x in range(1, image.get_width()):
			steps.append(absf(image.get_pixel(x, y).get_luminance() - image.get_pixel(x - 1, y).get_luminance()))

	steps.sort()
	return steps[int(steps.size() * 0.99)]


## The quad of _draw with vertex colours: `colour_at` gives each corner's
## colour from its x (-1 to 1); unshaded, its under layer `under`.
func _painted_quad(atlas: Texture2D, under: Texture2D, colour_at: Callable, settings: Dictionary,
		at := Vector3.ZERO) -> Image:
	var view := SubViewport.new()
	view.size = Vector2i(VIEW, VIEW)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.0
	camera.position = at
	view.add_child(camera)
	var material: ShaderMaterial = Painterly.material(atlas, &"even", Painterly.ZOCALO, null, under)
	material.shader = UNSHADED
	material.set_shader_parameter("paint_mix", 0.0)

	for key in settings:
		material.set_shader_parameter(key, settings[key])

	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	var arrays := quad.get_mesh_arrays()
	var colours := PackedColorArray()

	for v: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
		colours.append(colour_at.call(v.x))

	arrays[Mesh.ARRAY_COLOR] = colours
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var shape := MeshInstance3D.new()
	shape.mesh = mesh
	shape.position = at + Vector3(0, 0, -1)
	shape.material_override = material
	view.add_child(shape)

	for i in 5:
		await RenderingServer.frame_post_draw

	var image := view.get_texture().get_image()
	view.queue_free()
	return image


func _brightest(image: Image) -> float:
	var best := 0.0

	for y in image.get_height():
		for x in image.get_width():
			best = maxf(best, image.get_pixel(x, y).get_luminance())

	return best


func _is_green(c: Color) -> bool:
	return c.g > 0.85 and c.r < 0.15 and c.b < 0.15


func _share(image: Image, test: Callable) -> float:
	var n := 0

	for y in image.get_height():
		for x in image.get_width():
			n += int(test.call(image.get_pixel(x, y)))

	return float(n) / (image.get_width() * image.get_height())


func _mean_value(image: Image) -> float:
	var sum := 0.0

	for y in image.get_height():
		for x in image.get_width():
			sum += image.get_pixel(x, y).get_luminance()

	return sum / (image.get_width() * image.get_height())


func _reds(image: Image) -> int:
	var n := 0

	for y in image.get_height():
		for x in image.get_width():
			var c := image.get_pixel(x, y)
			n += int(c.r + c.g + c.b > 0.02 and c.r > c.g * 2.0)

	return n


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


## The distinct greys on a lit white sphere, drawn with the lit painterly
## shader (paint_mix 0, no strokes) at this much painted light.
func _sphere_levels(painted: float) -> int:
	var view := SubViewport.new()
	view.size = Vector2i(96, 96)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color.BLACK
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	world.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	view.add_child(world)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 0, 3)
	view.add_child(camera)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.4, 0.6, 0)
	view.add_child(sun)
	var white := Image.create(4, 4, false, Image.FORMAT_RGB8)
	white.fill(Color.WHITE)
	var material: ShaderMaterial = Painterly.material(ImageTexture.create_from_image(white), &"shader_led")
	material.set_shader_parameter("paint_mix", 0.0)
	material.set_shader_parameter("stroke_strength", 0.0)
	material.set_shader_parameter("terminator_break", 0.0)
	material.set_shader_parameter("band_softness", 0.0)
	material.set_shader_parameter("light_bands", 3.0)
	material.set_shader_parameter("painted_light", painted)
	material.set_shader_parameter("specular", 0.0)   # the highlight is meant to stay smooth
	# The bands alone: no ramp, ambient or rim (the shader-led preset has them).
	material.set_shader_parameter("ramp_amount", 0.0)
	material.set_shader_parameter("ambient_amount", 0.0)
	material.set_shader_parameter("rim_amount", 0.0)
	var ball := MeshInstance3D.new()
	ball.mesh = SphereMesh.new()
	ball.material_override = material
	view.add_child(ball)

	for i in 5:
		await RenderingServer.frame_post_draw

	var image := view.get_texture().get_image()
	view.queue_free()
	var seen := {}

	for y in image.get_height():
		for x in image.get_width():
			var c := image.get_pixel(x, y)

			if c.r > 0.02:
				seen[snappedf(c.r, 1.0 / 255.0)] = true

	return seen.size()


## The mean colour of the drawn pixels (not black) in a band of rows, from
## `from` to `to` of the way down the sphere's own height.
func _band_colour(image: Image, from: float, to: float) -> Color:
	var rows := []

	for y in image.get_height():
		for x in image.get_width():
			var c := image.get_pixel(x, y)

			if c.r + c.g + c.b > 0.02:
				rows.append(y)
				break

	var first: int = rows.min() if not rows.is_empty() else 0
	var last: int = rows.max() if not rows.is_empty() else 0
	var sum := Color(0, 0, 0)
	var n := 0

	for y in range(first + int((last - first) * from), first + int((last - first) * to) + 1):
		for x in image.get_width():
			var c := image.get_pixel(x, y)

			if c.r + c.g + c.b > 0.02:
				sum += c
				n += 1

	return sum / maxf(n, 1)


## A white sphere drawn with the lit painterly shader set by `settings`
## (paint_mix and strokes off), under one light or none; the image.
func _sphere(settings: Dictionary, lit: bool, paint: Variant = null) -> Image:
	var view := SubViewport.new()
	view.size = Vector2i(96, 96)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	world.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color.BLACK
	view.add_child(world)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 0, 3)
	camera.fov = 24.0
	view.add_child(camera)

	if lit:
		var sun := DirectionalLight3D.new()
		sun.rotation = Vector3(-0.4, 0.6, 0)
		view.add_child(sun)

	var white := Image.create(4, 4, false, Image.FORMAT_RGB8)
	white.fill(Color.WHITE)
	var material: ShaderMaterial = Painterly.material(ImageTexture.create_from_image(white), &"shader_led")

	for key in {"paint_mix": 0.0, "stroke_strength": 0.0, "terminator_break": 0.0, "specular": 0.0}:
		material.set_shader_parameter(key, 0.0)

	for key in settings:
		material.set_shader_parameter(key, settings[key])

	var ball := MeshInstance3D.new()
	ball.mesh = SphereMesh.new()

	if paint != null:
		var arrays := (ball.mesh as SphereMesh).get_mesh_arrays()
		var colours := PackedColorArray()
		colours.resize((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
		colours.fill(paint)
		arrays[Mesh.ARRAY_COLOR] = colours
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		ball.mesh = mesh

	ball.material_override = material
	view.add_child(ball)

	for i in 5:
		await RenderingServer.frame_post_draw

	var image := view.get_texture().get_image()
	view.queue_free()
	return image


func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) <= TOLERANCE and absf(a.g - b.g) <= TOLERANCE and absf(a.b - b.b) <= TOLERANCE


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
