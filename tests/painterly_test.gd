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
	_check("P1 the even preset: paint_mix 0.5, stroke_strength 0.12",
		even is ShaderMaterial and is_equal_approx(even.get_shader_parameter("paint_mix"), 0.5)
		and is_equal_approx(even.get_shader_parameter("stroke_strength"), 0.12),
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


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
