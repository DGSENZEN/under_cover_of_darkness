extends Node3D
## The trees in the wind (the scenes plan, Task 2): a tree's crown moves in a
## strong wind while its foot stays put, a calm stirs it far less, and the
## district's gusts (Gusts.gd) breathe within their bounds. In a window (a
## headless run draws nothing):
##   Godot --path . --resolution 960x540 res://tests/sway_test.tscn

const Materials := preload("res://scripts/Visual/Materials.gd")

var results: Array[String] = []
var eye: Camera3D


func _ready() -> void:
	await _run()

	print("\n==== RESULTS ====")
	for r in results:
		print(r)

	get_tree().quit()


func _run() -> void:
	_gusts()
	var loader := KitLoader.new()
	add_child(loader)
	var tree := MeshInstance3D.new()
	tree.mesh = loader._dressed("trees_kit", "tree_ash", KitLoader.meshes("trees_kit")["tree_ash"])
	add_child(tree)
	var sun := DirectionalLight3D.new()
	add_child(sun)
	sun.rotation = Vector3(deg_to_rad(-50), deg_to_rad(-35), 0)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.8, 0.85, 0.9)
	add_child(environment)
	eye = Camera3D.new()
	add_child(eye)
	eye.make_current()
	eye.global_transform = Transform3D(Basis(), Vector3(0, 4.5, 16)).looking_at(Vector3(0, 4.5, 0), Vector3.UP)

	# The limbs alone (every leaf cut out), so the bark's own sway is measured,
	# not the leaves' flutter.
	for slot in KitLoader.CARDS:
		KitLoader.card_material(slot).set_shader_parameter(&"alpha_scissor", 2.0)

	Materials.blow(Vector3(9.0, 0.0, 0.0))
	var windy := await _moved()
	Materials.blow(Vector3.ZERO)
	var calm := await _moved()

	_check("S1 in a strong wind its limbs move", windy["crown"] > 0.01, "%s" % [windy])
	_check("S2 its foot stays put", windy["foot"] < 0.005, "%s" % [windy])
	_check("S3 a calm stirs them far less", calm["crown"] < windy["crown"] * 0.5, "calm %s, windy %s" % [calm, windy])

	for slot in KitLoader.CARDS:
		KitLoader.card_material(slot).set_shader_parameter(&"alpha_scissor", 0.5)


## The share of pixels that changed between two frames 0.4 s apart: round the
## crown (5-9 m up) and round the foot (0-1 m).
func _moved() -> Dictionary:
	await _drawn(30)
	var a := get_viewport().get_texture().get_image()
	var start := Time.get_ticks_msec()

	while Time.get_ticks_msec() - start < 400:
		await _drawn(1)

	var b := get_viewport().get_texture().get_image()
	return {"crown": _changed(a, b, Vector3(-3.5, 9.0, 0), Vector3(3.5, 5.0, 0)),
		"foot": _changed(a, b, Vector3(-0.6, 1.0, 0), Vector3(0.6, 0.05, 0))}


## Where a point falls in a captured image (the viewport's own size is the
## project's window, not the window the run was given).
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

	return snappedf(float(changed) / maxi(total, 1), 0.001)


func _gusts() -> void:
	var gusts := Gusts.new()
	var speeds: Array[float] = []
	var widest := 0.0

	for k in 1200:
		var w := gusts.at(k * 0.25)
		speeds.append(w.length())
		widest = maxf(widest, rad_to_deg(absf(Vector2(w.x, w.z).angle_to(Vector2(gusts.prevailing.x, gusts.prevailing.z)))))

	gusts.free()
	var lo: float = speeds.min()
	var hi: float = speeds.max()
	_check("G1 the wind never stops nor storms", lo > 1.0 and hi < 9.5, "%.2f..%.2f m/s" % [lo, hi])
	_check("G2 it gusts", hi - lo > 3.5, "%.2f..%.2f m/s" % [lo, hi])
	_check("G3 its way swings no more than 20 degrees", widest <= 20.5, "%.1f degrees" % widest)


func _drawn(n: int) -> void:
	for i in n:
		RenderingServer.force_draw()
		await RenderingServer.frame_post_draw


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
