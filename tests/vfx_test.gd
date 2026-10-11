extends Node3D
## The effects as drawn (the effects plan, Ruling 2: GPU particles are
## judged by what they draw), at night, in a window:
##   Godot --path . --resolution 960x540 res://tests/vfx_test.tscn

const RetroScript := preload("res://scripts/Visual/Retro.gd")

var results: Array[String] = []
var eye: Camera3D


func _ready() -> void:
	var world := WorldEnvironment.new()
	world.environment = RetroScript.night_environment()
	add_child(world)
	add_child(Ground.build(Rect2(-20, -20, 40, 40), [], [], 3, {"tile": &"ground_flags", "level": 0.0}))
	eye = Camera3D.new()
	add_child(eye)
	eye.make_current()
	eye.global_transform = Transform3D(Basis(), Vector3(0, 1.6, 6)).looking_at(Vector3(0, 1.0, 0), Vector3.UP)
	await _brazier()
	await _copal()
	await _mist()
	await _shafts()

	print("\n==== RESULTS ====")
	for r in results:
		print(r)

	get_tree().quit()


## V1 a brazier's fire moves round its top; the ground a metre and a half aside is still.
func _brazier() -> void:
	var fire: Node3D = Vfx.system("brazier")
	add_child(fire)
	fire.position = Vector3(0, 0.9, 0)
	Vfx.emit(fire, true)
	await _seconds(1.5)
	var a := get_viewport().get_texture().get_image()
	await _seconds(0.3)
	var b := get_viewport().get_texture().get_image()
	var top := _changed(a, b, Vector3(-0.4, 1.8, 0), Vector3(0.4, 0.95, 0))
	var aside := _changed(a, b, Vector3(1.4, 0.4, 0), Vector3(2.0, 0.05, 0))
	_check("V1 a brazier's fire moves round its top, the ground aside still", top > 0.05 and aside < 0.01,
		"top %.3f, aside %.3f" % [top, aside])

	# V1b its flames narrow to their tips (the sheet's bed fills its frame:
	# drawn edge to edge the flames stood in a box)
	var foot := 0.0
	var tips := 0.0

	for k in 8:
		await _seconds(0.15)
		var shot := get_viewport().get_texture().get_image()
		var rows := []
		var high := int(_pixel(Vector3(0, 2.2, 0), shot).y)
		var low := int(_pixel(Vector3(0, 0.9, 0), shot).y)

		for row in range(high, low):
			var wide := _fire_width(shot, row)

			if wide > 0.0:
				rows.append(wide)

		if rows.size() >= 4:
			tips += rows[int(rows.size() * 0.25)]
			foot += rows[int(rows.size() * 0.8)]

	_check("V1b the brazier's flames narrow to their tips", foot > 0.0 and tips < foot * 0.7,
		"%.0f px wide at the foot, %.0f px near the tips" % [foot / 8.0, tips / 8.0])
	fire.free()


## V2 copal shows pale against the night under a lamp: the patch over its
## source brighter than the same patch before it smoked.
func _copal() -> void:
	var lamp := OmniLight3D.new()
	lamp.light_color = Color("#e8d8a8")
	lamp.omni_range = 14.0
	lamp.light_energy = 1.6
	lamp.position = Vector3(1.5, 5.0, 1.0)
	add_child(lamp)
	var smoke: Node3D = Vfx.system("copal")
	add_child(smoke)
	await _seconds(0.5)
	var before := _luminance(get_viewport().get_texture().get_image(), Vector3(-0.4, 2.4, 0), Vector3(0.4, 1.0, 0))
	Vfx.emit(smoke, true)
	await _seconds(4.0)
	var after := _luminance(get_viewport().get_texture().get_image(), Vector3(-0.4, 2.4, 0), Vector3(0.4, 1.0, 0))
	_check("V2 copal shows pale against the night under a lamp", after > before + 0.03,
		"before %.3f, smoking %.3f" % [before, after])
	smoke.free()
	lamp.free()


## V3 the seeped mist reads green round its booth: greener there than a
## metre past the mist.
func _mist() -> void:
	var seeped: Node3D = Vfx.system("mist")
	add_child(seeped)
	Vfx.place(seeped, Vector3.ZERO)
	Vfx.emit(seeped, true)
	await _seconds(2.5)
	var image := get_viewport().get_texture().get_image()
	var round_booth := _greenness(image, Vector3(-1.0, 0.9, 0), Vector3(1.0, 0.1, 0))
	var beyond := _greenness(image, Vector3(3.0, 0.9, 0), Vector3(4.0, 0.1, 0))
	_check("V3 the seeped mist reads green round its booth", round_booth > beyond + 0.02,
		"round the booth %.3f, beyond %.3f" % [round_booth, beyond])
	seeped.free()


## V4 a lamp lights the night air under it (its shaft in the fog): brighter
## there than between two lamps.
func _shafts() -> void:
	var kit := KitLoader.build({"pieces": [], "colliders": [], "lights": [
		{"at": [-5.0, 5.0, 0.0], "colour": "#e8d8a8", "range": 12.0}, {"at": [5.0, 5.0, 0.0], "colour": "#e8d8a8", "range": 12.0}]})
	add_child(kit)
	kit.set_day(false)
	# A wall far behind, past the lamps' reach (the night's fog draws over
	# geometry, not the sky).
	var wall := MeshInstance3D.new()
	var slab := BoxMesh.new()
	slab.size = Vector3(60, 20, 1)
	wall.mesh = slab
	wall.position = Vector3(0, 10, -16)
	add_child(wall)
	await _seconds(2.0)
	var image := get_viewport().get_texture().get_image()
	var under := _luminance(image, Vector3(4.5, 4.0, 0), Vector3(5.5, 2.5, 0))
	var between := _luminance(image, Vector3(-0.5, 4.0, 0), Vector3(0.5, 2.5, 0))
	_check("V4 a lamp lights the night air under it", under > between + 0.02, "under %.3f, between %.3f" % [under, between])
	kit.free()
	wall.free()


func _greenness(image: Image, top_left: Vector3, bottom_right: Vector3) -> float:
	var p := _pixel(top_left, image)
	var q := _pixel(bottom_right, image)
	var sum := 0.0
	var total := 0

	for y in range(int(p.y), int(q.y), 2):
		for x in range(int(p.x), int(q.x), 2):
			var c := image.get_pixel(x, y)
			sum += c.g - (c.r + c.b) / 2.0
			total += 1

	return sum / maxi(total, 1)


func _pixel(at: Vector3, image: Image) -> Vector2:
	return eye.unproject_position(at) * float(image.get_width()) / get_viewport().get_visible_rect().size.x


func _changed(a: Image, b: Image, top_left: Vector3, bottom_right: Vector3) -> float:
	var p := _pixel(top_left, a)
	var q := _pixel(bottom_right, a)
	var changed := 0
	var total := 0

	for y in range(int(p.y), int(q.y), 2):
		for x in range(int(p.x), int(q.x), 2):
			total += 1
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)

			if absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b) > 0.06:
				changed += 1

	return float(changed) / maxi(total, 1)


## How wide (px) the fire draws on an image row: its outermost
## flame-coloured pixels within 70 cm of its middle.
func _fire_width(image: Image, row: int) -> float:
	var left := int(_pixel(Vector3(-0.7, 1.2, 0), image).x)
	var right := int(_pixel(Vector3(0.7, 1.2, 0), image).x)
	var first := -1
	var last := -1

	for x in range(left, right):
		var c := image.get_pixel(x, row)

		if c.r > 0.55 and c.r > c.b + 0.3:
			first = x if first < 0 else first
			last = x

	return 0.0 if first < 0 else float(last - first + 1)


func _luminance(image: Image, top_left: Vector3, bottom_right: Vector3) -> float:
	var p := _pixel(top_left, image)
	var q := _pixel(bottom_right, image)
	var sum := 0.0
	var total := 0

	for y in range(int(p.y), int(q.y), 2):
		for x in range(int(p.x), int(q.x), 2):
			sum += image.get_pixel(x, y).get_luminance()
			total += 1

	return sum / maxi(total, 1)


func _seconds(s: float) -> void:
	var start := Time.get_ticks_msec()

	while Time.get_ticks_msec() - start < s * 1000.0:
		await get_tree().process_frame

	RenderingServer.force_draw()


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
