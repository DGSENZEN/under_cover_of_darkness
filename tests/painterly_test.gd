extends Node3D
## The painterly look's materials (the Eclipse city's style lab, Task 2):
## presets, uniforms, and the Retro autoload leaving them alone. Headless, so
## settings only; the pixels are tests/painterly_pixels.tscn, run in a window.

const Painterly := preload("res://scripts/Visual/Painterly.gd")

var results: Array[String] = []


func _ready() -> void:
	await _frames(2)
	_run()

	print("\n==== RESULTS ====")
	for r in results:
		print(r)

	get_tree().quit()


func _run() -> void:
	# P1 the even blend
	var even: ShaderMaterial = Painterly.material(Painterly.BRUSH, &"even")
	_check("P1 the even preset: paint_mix 0.25, stroke_strength 0.24 (the softer brush, after the user's reference, at three times)",
		even is ShaderMaterial and is_equal_approx(even.get_shader_parameter("paint_mix"), 0.25)
		and is_equal_approx(even.get_shader_parameter("stroke_strength"), 0.24),
		"%s" % [even])

	# P2 every preset's values reach its material
	var wrong: Array[String] = []

	for preset in Painterly.PRESETS:
		var material: ShaderMaterial = Painterly.material(Painterly.BRUSH, preset)

		for key in Painterly.PRESETS[preset]:
			if not is_equal_approx(material.get_shader_parameter(key), Painterly.PRESETS[preset][key]):
				wrong.append("%s.%s" % [preset, key])

		if material.get_shader_parameter("palette") != Painterly.ZOCALO or material.get_shader_parameter("brush") != Painterly.BRUSH:
			wrong.append("%s textures" % preset)

	_check("P2 every preset's values reach its material, with the Zócalo palette and the brush",
		wrong.is_empty() and Painterly.PRESETS.size() == 3, "wrong %s" % [wrong])

	# P3 the Retro sweep leaves a painterly material alone
	var box := MeshInstance3D.new()
	box.mesh = BoxMesh.new()
	var material: ShaderMaterial = Painterly.material(Painterly.BRUSH, &"even")
	box.material_override = material
	add_child(box)
	var retro: Node = get_node_or_null("/root/Retro")

	if retro != null:
		retro.retro_geometry(box)

	_check("P3 the Retro autoload's sweep leaves the painterly material as it is",
		retro != null and box.material_override == material and material.shader == Painterly.SHADER,
		"retro %s" % [retro != null])


	# P4 a painted normal map reaches the material, at full depth; without
	#    one the shader's flat default stands
	var normals := ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGB8))
	var bumped: ShaderMaterial = Painterly.material(Painterly.BRUSH, &"even", Painterly.ZOCALO, normals)
	var smooth: ShaderMaterial = Painterly.material(Painterly.BRUSH, &"even")
	_check("P4 a painted normal map reaches the material at depth 1; none leaves the flat default",
		bumped.get_shader_parameter("normal_atlas") == normals and is_equal_approx(bumped.get_shader_parameter("normal_depth"), 1.0)
		and smooth.get_shader_parameter("normal_atlas") == null,
		"bumped %s smooth %s" % [bumped.get_shader_parameter("normal_atlas"), smooth.get_shader_parameter("normal_atlas")])


	# P5 the strokes are colour only: no brush-stroke normals (the user, Oct 9
	#    2026: they made everything gritty)
	var names := Painterly.SHADER.get_shader_uniform_list().map(func(u): return u["name"])
	var keys := Painterly.PRESETS.values().map(func(p): return p.keys())
	_check("P5 the shader's strokes bend no normals: no stroke_relief, in the shader or a preset",
		not "stroke_relief" in names and keys.all(func(k): return not "stroke_relief" in k), "uniforms %s" % [names])


	# P6 the shader-led look is variant D (the user's choice, Oct 9 2026):
	#    painted light through the ramp, painted ambient and rim
	var d: Dictionary = Painterly.PRESETS[&"shader_led"]
	_check("P6 shader-led is variant D: painted light, the ramp, ambient 0.15, rim 0.25",
		d.get("painted_light") == 1.0 and d.get("ramp_amount") == 1.0 and d.get("ambient_amount") == 0.15
		and d.get("rim_amount") == 0.25, "%s" % [d])


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
