extends Node3D
## The effects as drawn (the effects plan, Ruling 2: GPU particles are
## judged by what they draw), at night, in a window:
##   Godot --path . --resolution 960x540 res://tests/vfx_test.tscn

const RetroScript := preload("res://scripts/Visual/Retro.gd")
const Layers := preload("res://scripts/Visual/Layers.gd")

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
	await _petals()
	await _against_a_wall()
	await _breath()
	await _swell()

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


## V5 petals fall, tumble and settle: after six seconds marigold lies on
## the ground under their emitter (seen from above in a low sun: a petal
## lying flat is a sliver from eye height).
func _petals() -> void:
	var floor_field := Vfx.heightfield(self)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-60), deg_to_rad(20), 0)
	add_child(sun)
	var kept := eye.global_transform
	eye.global_transform = Transform3D(Basis(), Vector3(0, 5.0, 2.5)).looking_at(Vector3.ZERO, Vector3.UP)
	var drift: Node3D = Vfx.system("petals")
	add_child(drift)
	Vfx.place(drift, Vector3.ZERO)
	Vfx.emit(drift, true)
	await _seconds(6.0)
	var image := get_viewport().get_texture().get_image()
	image.save_png(OS.get_cache_dir() + "/vfx_test_petals.png")
	var marigold := 0
	var p := _pixel(Vector3(-2.2, 0.0, -2.2), image)
	var q := _pixel(Vector3(2.2, 0.0, 2.2), image)

	for y in range(int(p.y), int(q.y)):
		for x in range(int(p.x), int(q.x)):
			var c := image.get_pixel(x, y)

			if c.r > 0.45 and c.r > c.g + 0.12 and c.g > c.b + 0.05:
				marigold += 1

	_check("V5 petals settle on the ground under their emitter", marigold >= 40, "%d marigold pixels on the ground" % marigold)
	drift.free()
	floor_field.free()
	sun.free()
	eye.global_transform = kept


## V5b petals blown against a wall slide down it: once they have had time
## to fall, none hangs on its face above the ground (a collision laid them
## to rest wherever it came).
func _against_a_wall() -> void:
	var floor_field := Vfx.heightfield(self)
	var sun := DirectionalLight3D.new()
	# (Lighting the wall's face toward the camera.)
	sun.rotation = Vector3(deg_to_rad(-40), deg_to_rad(-90), 0)
	add_child(sun)
	var wall := MeshInstance3D.new()
	var block := BoxMesh.new()
	block.size = Vector3(0.4, 4, 8)
	wall.mesh = block
	wall.position = Vector3(1.8, 2, 0)
	add_child(wall)
	var stop := GPUParticlesCollisionBox3D.new()
	stop.size = block.size
	stop.position = wall.position
	stop.cull_mask = Layers.FX
	add_child(stop)
	var gust := Vfx.wind_attractor()
	add_child(gust)
	Vfx.steer(gust, Vector3(6, 0, 0), Vector3.ZERO)
	var drift: Node3D = Vfx.system("petals")
	add_child(drift)
	Vfx.place(drift, Vector3.ZERO)
	Vfx.emit(drift, true)
	var kept := eye.global_transform
	eye.global_transform = Transform3D(Basis(), Vector3(-1.5, 1.4, 4.5)).looking_at(Vector3(1.6, 1.2, 0), Vector3.UP)
	# (Blown at it a while, then stopped, and given time to finish falling:
	# what is still on the wall's face hangs there.)
	await _seconds(5.0)
	Vfx.emit(drift, false)
	await _seconds(4.0)
	var image := get_viewport().get_texture().get_image()
	image.save_png(OS.get_cache_dir() + "/vfx_test_wall.png")
	var hung := 0
	var p := _pixel(Vector3(1.55, 3.0, -2.0), image)
	var q := _pixel(Vector3(1.55, 0.4, 2.0), image)

	for y in range(int(minf(p.y, q.y)), int(maxf(p.y, q.y))):
		for x in range(int(minf(p.x, q.x)), int(maxf(p.x, q.x))):
			var c := image.get_pixel(x, y)

			if c.r > 0.3 and c.r > c.g + 0.08 and c.g > c.b:
				hung += 1

	_check("V5b petals blown at a wall slide down it, none hangs on it", hung == 0, "%d marigold pixels on the wall's face" % hung)
	eye.global_transform = kept
	drift.free()
	gust.free()
	stop.free()
	wall.free()
	sun.free()
	floor_field.free()


## V6 the god's inhale draws smoke toward its mouth: copal beside an
## attractor at the inhale's pull leans toward it, its smoke's middle on
## the attractor's side.
func _breath() -> void:
	var lamp := OmniLight3D.new()
	lamp.light_color = Color("#e8d8a8")
	lamp.omni_range = 14.0
	lamp.light_energy = 1.6
	lamp.position = Vector3(0, 5.0, 2.0)
	add_child(lamp)
	var mouth := GPUParticlesAttractorSphere3D.new()
	mouth.radius = Occult.REACH
	mouth.cull_mask = Layers.BREATHED
	mouth.position = Vector3(3.0, 2.5, 0)
	mouth.strength = Occult.pull(1.0)
	add_child(mouth)
	var smoke: Node3D = Vfx.system("copal")
	add_child(smoke)
	Vfx.place(smoke, Vector3.ZERO)
	Vfx.emit(smoke, true)
	await _seconds(5.0)
	var image := get_viewport().get_texture().get_image()
	var p := _pixel(Vector3(-3.0, 4.0, 0), image)
	var q := _pixel(Vector3(3.0, 1.2, 0), image)
	var weight := 0.0
	var across := 0.0

	for y in range(int(p.y), int(q.y), 2):
		for x in range(int(p.x), int(q.x), 2):
			var lum := image.get_pixel(x, y).get_luminance()

			if lum > 0.12:
				weight += lum
				across += lum * x

	var middle := across / maxf(weight, 1e-6)
	var source := _pixel(Vector3.ZERO, image).x
	_check("V6 the god's inhale draws smoke toward its mouth", weight > 0.0 and middle > source + 8.0,
		"smoke's middle %.0f px, its source %.0f px (the mouth to the right)" % [middle, source])
	smoke.free()
	mouth.free()
	lamp.free()


## V7 a swell stays whole: a box (each face its own normals, its corners
## split, as the god's are) swollen in the god's material, seen corner-on
## against a red wall, shows no red down its near edge (pushed along their
## normals the faces parted there into a slit).
func _swell() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-30), deg_to_rad(10), 0)
	add_child(sun)
	var centre := Vector3(0, 3.0, 0)
	var wall := MeshInstance3D.new()
	var slab := QuadMesh.new()
	slab.size = Vector2(60, 60)
	var red := StandardMaterial3D.new()
	red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	red.albedo_color = Color(1, 0, 0)
	slab.material = red
	wall.mesh = slab
	wall.position = centre + Vector3(-8, 0, -8)
	wall.rotation.y = deg_to_rad(45)
	add_child(wall)
	var box := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = Vector3.ONE
	box.mesh = shape
	box.position = centre
	var look: ShaderMaterial = KitLoader.material("bound_god").duplicate()
	look.set_shader_parameter(&"swell", 0.3)
	look.set_shader_parameter(&"swell_centre", centre)
	look.set_shader_parameter(&"swell_radius", Occult.CHEST_REACH)
	box.material_override = look
	add_child(box)
	var kept := eye.global_transform
	eye.global_transform = Transform3D(Basis(), centre + Vector3(2.2, 0.0, 2.2)).looking_at(centre, Vector3.UP)
	await _seconds(0.5)
	var image := get_viewport().get_texture().get_image()
	# The near vertical edge (x 0.5, z 0.5), its middle stretch.
	var top := _pixel(centre + Vector3(0.5, 0.3, 0.5), image)
	var foot := _pixel(centre + Vector3(0.5, -0.3, 0.5), image)
	var through := 0

	for y in range(int(top.y), int(foot.y)):
		for x in range(int(top.x) - 10, int(top.x) + 11):
			var c := image.get_pixel(x, y)

			if c.r > 0.8 and c.g < 0.2 and c.b < 0.2:
				through += 1

	_check("V7 a swell stays whole, no slits at split corners", through == 0, "%d red pixels down the near edge" % through)
	eye.global_transform = kept
	box.free()
	wall.free()
	sun.free()


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
