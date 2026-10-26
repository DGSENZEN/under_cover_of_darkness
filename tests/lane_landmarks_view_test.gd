extends Node3D
## The candle lane's landmarks as the player sees them from the Pasaje (docs/superpowers/plans/2026-10-25-lane-landmarks.md,
## Task 1): the real map, the player camera's field of view, the eye 1.65 m over the floor. Each check is judged on the
## mouth view, its regions projected from points in the lane's frame. Windowed, in the game's time:
##   Godot --path . --fixed-fps 60 --resolution 1152x648 res://tests/lane_landmarks_view_test.tscn
## The views are saved to docs/superpowers/refs/underground/landmarks/ (review media, not committed).
const MAP := preload("res://maps/metro.tscn")
const OUT := "res://docs/superpowers/refs/underground/landmarks/"
## The views in the plan's frame: [where the eye is, what it looks at, the file's name]. The mouth view is the judged one.
const VIEWS := [
	[Vector3(-5.0, -9.35, 75.45), Vector3(29.6, -9.5, 75.45), "2_at_the_mouth"],
	[Vector3(-9.0, -9.35, 71.0), Vector3(8.0, -9.5, 75.45), "1_from_the_pasaje"],
	[Vector3(2.0, -9.35, 75.45), Vector3(29.6, -9.5, 75.45), "3_a_few_metres_in"],
]
## The close views, in the lane's own frame: [eye, looks at, name].
const CLOSE := [
	[Vector3(-4.0, 1.65, 1.4), Vector3(0.0, 2.2, -1.0), "4_her_stall_close"],
	[Vector3(2.0, 1.65, 1.2), Vector3(6.2, 2.0, 4.5), "5_his_arch_close"],
]
## The lane's frame: its walls, its height.
const NORTH := -2.35
const SOUTH := 4.55
const RED_BAND := Vector2(350.0, 10.0)

var results: Array[String] = []
var failures := 0
var eye: Camera3D
var lane: Node3D


func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var map: Node3D = MAP.instantiate()
	add_child(map)
	await _seconds(0.5)
	var fov: float = get_viewport().get_camera_3d().fov
	map.player.global_position = map.spawn_point() + Vector3(0.0, 1.05, 0.0)
	lane = map.get_node("candle_lane")
	eye = Camera3D.new()
	eye.fov = fov
	add_child(eye)
	eye.make_current()
	await _seconds(4.0)

	# The mouth, twice half a second apart (the crowd hidden for those shots: what moves is judged without it).
	_look(VIEWS[0][0], VIEWS[0][1], false)
	# (-- --no-garland: the check's own baseline, the garland hidden.)
	if OS.get_cmdline_user_args().has("--no-garland") and lane.get("landmarks") != null and lane.landmarks.has("garland"):
		lane.landmarks["garland"].visible = false
	var crowd: Node3D = lane.get("crowd_of_shades")
	if crowd != null:
		crowd.visible = false
	await _seconds(0.5)
	var a := _shot(VIEWS[0][2])
	await _seconds(0.5)
	var b := _shot("")
	if crowd != null:
		crowd.visible = true
	_judge(a, b)

	for view in VIEWS.slice(1):
		_look(view[0], view[1], false)
		await _seconds(0.5)
		_shot(view[2])
	for view in CLOSE:
		_look(view[0], view[1], true)
		await _seconds(0.5)
		_shot(view[2])

	print("\n==== RESULTS ====")
	for r in results:
		print(r)
	get_tree().quit(1 if failures > 0 else 0)


func _judge(a: Image, b: Image) -> void:
	# LV1 her garland crosses the corridor: warm (marigold, reddened under her neon and the chapel's haze) in most of
	# the span's columns.
	# (Its columns span the walk where the garland crosses, x 1.4-2.1, from her stall's front, where it ties on, to the
	# south wall: a box running nearer the eye would be wider on screen than the lane there.)
	var span := _region(Vector3(1.4, 2.6, 0.0), Vector3(2.1, 3.6, SOUTH))
	var bins := 10
	var hit := []
	hit.resize(bins)
	hit.fill(false)
	_each(a, span, func(x: int, _y: int, c: Color):
		if _hue_in(c.h * 360.0, Vector2(0.0, 45.0)) and c.s > 0.5 and c.v > 0.25:
			hit[clampi(int(float(x - span.position.x) / maxf(span.size.x, 1.0) * bins), 0, bins - 1)] = true)
	var spanned: int = hit.count(true)
	var hidden := OS.get_cmdline_user_args().has("--no-garland")
	_check("LV1 her garland crosses the corridor over her stall%s" % (" (garland hidden)" if hidden else ""), spanned >= 8,
		"%d of %d columns warm" % [spanned, bins])

	# LV2 a red pool at his arch, none at the chapel's end.
	var at_arch := _share(a, _region(Vector3(4.7, 0.0, SOUTH - 1.5), Vector3(7.7, 3.2, SOUTH)), _red)
	# (The chapel's end below 2.2 m: higher, the garland's flags hang across it on screen.)
	var at_chapel := _share(a, _region(Vector3(14.0, 0.0, NORTH), Vector3(16.8, 2.2, SOUTH)), _red)
	# (The chapel's end has a scatter of warm candle and neon hues in the band, ~3 %: no pool. His arch's is a pool.)
	_check("LV2 a red pool at his arch, twice the chapel end's scatter", at_arch >= 0.04 and at_arch >= 2.0 * at_chapel,
		"arch %.3f, chapel %.3f" % [at_arch, at_chapel])

	# LV3 something moves out of his arch onto the walk.
	var floor_box := _region(Vector3(6.0, 0.0, 0.5), Vector3(16.0, 0.3, 3.0))
	var moved := 0
	var seen := 0
	for y in range(floor_box.position.y, floor_box.end.y, 2):
		for x in range(floor_box.position.x, floor_box.end.x, 2):
			var c := a.get_pixel(x, y)
			var d := b.get_pixel(x, y)
			seen += 1
			# (A page is pale paper: what flickers on the floor, candle and neon light, is not.)
			var paper := (c.v > 0.55 and c.s < 0.3) or (d.v > 0.55 and d.s < 0.3)
			if paper and absf(c.r - d.r) + absf(c.g - d.g) + absf(c.b - d.b) > 0.15:
				moved += 1
	var share_moved := float(moved) / maxf(seen, 1.0)
	_check("LV3 something moves out of his arch onto the walk", share_moved >= 0.005, "%.4f of the floor changed" % share_moved)

	# LV4 the station sign no longer leads; LV5 the niche quieter than her stall.
	var stall_lum := _luminance(a, _region(Vector3(-1.5, 0.5, NORTH), Vector3(1.5, 2.8, 0.0)))
	var sign_node: Node3D = lane.get("mouth_sign")
	# (Its face toward the mouth alone: the box round it is mostly the dark vault.)
	var sign_box := _lane_box(sign_node) if sign_node != null else AABB()
	var sign_lum := _luminance(a, _region(sign_box.position, Vector3(sign_box.position.x, sign_box.end.y, sign_box.end.z))) \
		if sign_node != null else INF
	_check("LV4 the blank station sign is dimmer than her stall", sign_lum < stall_lum,
		"sign %.3f, her stall %.3f" % [sign_lum, stall_lum])
	var niche: Node3D = lane.find_child("niche", true, false)
	var niche_lum := _luminance(a, _box_region(niche)) if niche != null else INF
	# (By a margin her stall leads by, not a hair: today they are near level, 0.82.)
	_check("LV5 the shrine niche is quieter than her stall", niche_lum <= 0.6 * stall_lum,
		"niche %.3f, her stall %.3f" % [niche_lum, stall_lum])

	# LV6 a warm cloud over her pitch, against the bare vault.
	var haze := _region(Vector3(-1.5, 3.0, -2.0), Vector3(1.5, 3.9, 0.5))
	var bare := _region(Vector3(-7.5, 3.0, -2.0), Vector3(-4.5, 3.9, 0.5))
	var haze_colour := _mean(a, haze)
	var warm := _hue_in(haze_colour.h * 360.0, Vector2(20.0, 50.0))
	var lum := haze_colour.get_luminance()
	var bare_lum := _mean(a, bare).get_luminance()
	_check("LV6 a warm cloud over her pitch, brighter than the bare vault", warm and lum >= 1.5 * bare_lum,
		"hue %.0f°, %.3f against %.3f" % [haze_colour.h * 360.0, lum, bare_lum])


func _red(c: Color) -> bool:
	return _hue_in(c.h * 360.0, RED_BAND) and c.s > 0.45 and c.v > 0.3


func _hue_in(hue: float, band: Vector2) -> bool:
	return hue >= band.x and hue <= band.y if band.x <= band.y else hue >= band.x or hue <= band.y


## The screen rectangle a box in the lane's frame covers (its corners projected), clipped to the image. (Run at the
## project's base size, 1152x648: under canvas_items stretch a larger window's shot and the camera's projection differ.)
func _region(lo: Vector3, hi: Vector3) -> Rect2i:
	var size := Vector2(get_viewport().get_texture().get_size())
	var rect := Rect2()
	var first := true
	for i in 8:
		var p := Vector3(hi.x if i & 1 else lo.x, hi.y if i & 2 else lo.y, hi.z if i & 4 else lo.z)
		var g := lane.to_global(p)
		if eye.is_position_behind(g):
			continue
		var s := eye.unproject_position(g)
		rect = Rect2(s, Vector2.ZERO) if first else rect.expand(s)
		first = false
	return Rect2i(rect.intersection(Rect2(Vector2.ZERO, size)))


## The screen rectangle a node's drawn box covers.
func _box_region(node: Node3D) -> Rect2i:
	var box := _lane_box(node)
	return _region(box.position, box.end)


## A node's drawn box, in the lane's frame.
func _lane_box(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mesh in [node] + node.find_children("*", "VisualInstance3D", true, false):
		if not mesh is VisualInstance3D:
			continue
		var b: AABB = lane.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


## (Plain loops: a lambda's counters are copies, and would come back unchanged.)
func _each(image: Image, rect: Rect2i, visit: Callable) -> void:
	for y in range(rect.position.y, rect.end.y, 2):
		for x in range(rect.position.x, rect.end.x, 2):
			visit.call(x, y, image.get_pixel(x, y))


func _share(image: Image, rect: Rect2i, matches: Callable) -> float:
	var n := 0
	var hits := 0
	for y in range(rect.position.y, rect.end.y, 2):
		for x in range(rect.position.x, rect.end.x, 2):
			n += 1
			if matches.call(image.get_pixel(x, y)):
				hits += 1
	return float(hits) / maxf(n, 1.0)


func _mean(image: Image, rect: Rect2i) -> Color:
	var sum := Vector3.ZERO
	var n := 0
	for y in range(rect.position.y, rect.end.y, 2):
		for x in range(rect.position.x, rect.end.x, 2):
			var c := image.get_pixel(x, y)
			sum += Vector3(c.r, c.g, c.b)
			n += 1
	sum /= maxf(n, 1.0)
	return Color(sum.x, sum.y, sum.z)


func _luminance(image: Image, rect: Rect2i) -> float:
	return _mean(image, rect).get_luminance() if rect.has_area() else INF


## The eye at `from` looking at `target` (the plan's frame, or the lane's when `in_lane`).
func _look(from: Vector3, target: Vector3, in_lane: bool) -> void:
	var f := lane.to_global(from) if in_lane else from
	var t := lane.to_global(target) if in_lane else target
	eye.global_transform = Transform3D(Basis.IDENTITY, f).looking_at(t, Vector3.UP)


func _shot(file_name: String) -> Image:
	RenderingServer.force_draw(false)
	var image := get_viewport().get_texture().get_image()
	if file_name != "":
		image.save_png(ProjectSettings.globalize_path(OUT + file_name + ".png"))
	return image


## `s` seconds of the game's time (60 frames a second under --fixed-fps 60).
func _seconds(s: float) -> void:
	for i in maxi(int(s * 60.0), 1):
		await get_tree().process_frame


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		failures += 1
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", label, detail])
