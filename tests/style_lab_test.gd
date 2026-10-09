extends Node3D
## The style lab (the Eclipse city's style lab, Task 6): three blends side by
## side, glass that stays glass, night and day, the user's overpaint first,
## and a lab that still opens when its pieces are not built. Headless.

const LAB := preload("res://maps/style_lab.tscn")
const MIXES := {&"painted_led": 0.25, &"even": 0.5, &"shader_led": 0.85}

var results: Array[String] = []


func _ready() -> void:
	await _run()

	print("\n==== RESULTS ====")
	for r in results:
		print(r)

	get_tree().quit()


func _run() -> void:
	var lab: Node3D = LAB.instantiate()
	add_child(lab)
	await _frames(3)

	# L1 three stations, each a kiosk and three bays
	var shape := []

	for preset in lab.STATIONS:
		var station: Node = lab.get_node_or_null(String(preset))
		shape.append([preset, station != null and station.get_node_or_null("kiosk") != null,
			station.find_children("bay_*", "", false, false).size() if station else 0])

	_check("L1 three stations, each a kiosk and three bays",
		lab.STATIONS.size() == 3 and shape.all(func(s): return s[1] and s[2] == 3), "%s" % [shape])

	# L2 every painted surface in station k draws in its preset's blend
	var wrong := []
	var glass := []

	for preset in lab.STATIONS:
		for mesh in lab.get_node(String(preset)).find_children("*", "MeshInstance3D", true, false):
			for i in mesh.mesh.get_surface_count():
				var slot: String = mesh.mesh.surface_get_material(i).resource_name if mesh.mesh.surface_get_material(i) else ""
				var drawn: Material = mesh.get_surface_override_material(i)

				if slot == "glass":
					glass.append(drawn)
				elif not (drawn is ShaderMaterial and is_equal_approx(drawn.get_shader_parameter("paint_mix"), MIXES[preset])):
					wrong.append("%s/%s.%d" % [preset, mesh.name, i])

	_check("L2 every painted surface in a station draws in its preset's blend", wrong.is_empty(),
		"%d wrong, e.g. %s" % [wrong.size(), wrong.slice(0, 3)])

	# L3 glass stays glass
	var opaque := glass.filter(func(m): return not (m is StandardMaterial3D
		and m.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA and m.albedo_color.a <= 0.5))
	_check("L3 every glass surface is translucent glass, not the painterly shader",
		glass.size() > 0 and opaque.is_empty(), "%d glass, %d not" % [glass.size(), opaque.size()])

	# L4 day and night
	lab.set_day(true)
	var day_env: Environment = lab.world.environment
	var sun_on: bool = lab.sun.visible and is_equal_approx(lab.sun.light_energy, 1.0) and not lab.moon.visible
	lab.set_day(false)
	_check("L4 day brings a sky and the sun at 1.0; night takes them away",
		day_env.background_mode == Environment.BG_SKY and day_env.sky != null and sun_on
		and lab.world.environment.background_mode != Environment.BG_SKY and lab.moon.visible and not lab.sun.visible,
		"day bg %d sun %s" % [day_env.background_mode, sun_on])

	# L5 the user's overpaint first, else the painted base
	var base: Texture2D = lab.atlas_for(&"kiosk")
	DirAccess.make_dir_recursive_absolute("user://lab_atlas")
	var mine := Image.create(8, 8, false, Image.FORMAT_RGB8)
	mine.fill(Color(1, 0, 1))
	mine.save_png("user://lab_atlas/kiosk.png")
	var default_dir: String = lab.atlas_dir
	lab.atlas_dir = "user://lab_atlas/"
	var theirs: Texture2D = lab.atlas_for(&"kiosk")
	lab.atlas_dir = default_dir
	_check("L5 the painted base without an overpaint; the user's kiosk.png when there is one",
		base != null and base.get_width() == 512 and theirs != null and theirs.get_width() == 8,
		"base %s theirs %s" % [base.get_size() if base else null, theirs.get_size() if theirs else null])
	lab.queue_free()
	await _frames(2)

	# L6 a lab whose pieces are not built still opens, and says what is missing
	DirAccess.make_dir_recursive_absolute("user://lab_empty")
	var bare: Node3D = LAB.instantiate()
	bare.lab_dir = "user://lab_empty/"
	add_child(bare)
	await _frames(3)
	var said: PackedStringArray = bare.missing
	_check("L6 without its pieces the lab opens and names the two missing",
		is_instance_valid(bare) and said.size() == 2 and said[0].ends_with("kiosk.glb") and said[1].ends_with("arcade_bay.glb"),
		"%s" % [said])
	bare.queue_free()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
