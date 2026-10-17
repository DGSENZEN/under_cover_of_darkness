extends Node3D
## The new standard's materials (the Metro Underground, Task 5): the bespoke
## preset, and neon signs that flicker by a seeded pattern on game time, so
## two runs light the same.

const Painterly := preload("res://scripts/Visual/Painterly.gd")

var results: Array[String] = []


func _ready() -> void:
	await _frames(2)
	await _run()

	print("\n==== RESULTS ====")
	for r in results:
		print(r)

	get_tree().quit()


func _run() -> void:
	# N1 the bespoke preset: the painted atlas carries the colour, no palette pull
	_check("N1 the bespoke preset exists and leaves the atlas's colour alone (paint_mix 0)",
		Painterly.PRESETS.has(&"bespoke") and Painterly.PRESETS[&"bespoke"]["paint_mix"] == 0.0,
		"%s" % [Painterly.PRESETS.get(&"bespoke")])

	# N2 a neon tube's material: unshaded, glowing in its colour
	var tube: ShaderMaterial = Neon.material(Color.HOT_PINK)
	var code: String = tube.shader.code if tube != null and tube.shader != null else ""
	_check("N2 a neon tube is unshaded and glows in its colour",
		tube != null and code.contains("unshaded") and float(tube.get_shader_parameter("energy")) > 1.0
		and tube.get_shader_parameter("colour") == Color.HOT_PINK,
		"energy %s colour %s" % [tube.get_shader_parameter("energy") if tube else null, tube.get_shader_parameter("colour") if tube else null])

	# N3 the flicker is the pattern's, set by the seed alone
	var a := _sign(7)
	var b := _sign(7)
	var c := _sign(8)
	var same := true
	var differs := false

	for i in 101:
		var t := i * 0.1
		same = same and is_equal_approx(a.energy_at(t), b.energy_at(t))
		differs = differs or not is_equal_approx(a.energy_at(t), c.energy_at(t))

	_check("N3 two signs with one pattern and seed flicker alike; another seed differs", same and differs,
		"same %s differs %s" % [same, differs])

	# N4 in the scene its light follows the pattern on game time, never below zero,
	#    and its tube casts no shadow
	add_child(a)
	var seen := {}
	var lowest := INF

	for i in 180:
		await get_tree().physics_frame
		var energy: float = a.light.light_energy
		seen[snappedf(energy, 0.001)] = true
		lowest = minf(lowest, energy)

	var shadowless: bool = a.tube != null and a.tube.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_check("N4 a sign's light flickers over three seconds of game time, never negative, its tube casting no shadow",
		seen.size() >= 2 and lowest >= 0.0 and shadowless, "levels %d lowest %.3f shadowless %s" % [seen.size(), lowest, shadowless])
	b.free()
	c.free()


func _sign(seed_value: int) -> NeonSign:
	var sign := NeonSign.new()
	sign.colour = Color.HOT_PINK
	sign.pattern = "mmmmmaammmmzmmmmmamm"
	sign.seed = seed_value
	var mesh := MeshInstance3D.new()
	mesh.mesh = CylinderMesh.new()
	sign.add_child(mesh)
	return sign


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
