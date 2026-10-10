extends Node3D
## The style lab (the Eclipse city's style lab, Task 6): three blends side by
## side, glass that stays glass, night and day, the user's overpaint first,
## and a lab that still opens when its pieces are not built. Headless.

const LAB := preload("res://maps/style_lab.tscn")
const MIXES := {&"painted_led": 0.1, &"even": 0.25, &"shader_led": 0.45}

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
		base != null and base.get_width() == _atlas_px(&"kiosk") and theirs != null and theirs.get_width() == 8,
		"base %s theirs %s" % [base.get_size() if base else null, theirs.get_size() if theirs else null])
	# L7 the stair is walked: the player goes down to the landing and back up
	#    to the street (it wedged on the old one, 1.7 m in)
	var player: CharacterBody3D = lab.player
	var kiosk: Node3D = lab.get_node("even/kiosk")
	var top: Vector3 = kiosk.global_position + Vector3(0, 1.05, 1.0)
	player.global_position = top
	player.rotation.y = 0.0
	player.velocity = Vector3.ZERO
	await _frames(10)
	Input.action_press("move_forward")
	var lowest := player.global_position.y

	for i in 360:
		await get_tree().physics_frame
		lowest = minf(lowest, player.global_position.y)

		if player.global_position.z < kiosk.global_position.z - 6.6:
			break

	Input.action_release("move_forward")
	var landed: bool = player.global_position.z < kiosk.global_position.z - 6.6 and player.is_on_floor()
	var down_at := player.global_position
	player.rotation.y = PI
	await _frames(5)
	Input.action_press("move_forward")

	for i in 480:
		await get_tree().physics_frame

		if player.global_position.z > kiosk.global_position.z + 0.5:
			break

	Input.action_release("move_forward")
	var back: bool = player.global_position.z > kiosk.global_position.z + 0.5 and player.global_position.y > 0.9
	_check("L7 the player walks down the kiosk's stair to its landing and back up to the street",
		landed and back and lowest < -1.8, "down at %s (lowest %.2f), back at %s" % [down_at, lowest, player.global_position])
	# L8 no hole in the passage under the street: from its landing every ray
	#    going on into it or down meets a face turned toward it (a face wound
	#    backwards is culled and lets the sky through; the old end wall did)
	var escaped := _escapes(kiosk.global_position + Vector3(0, -1.6, -7.0), 6.0)
	_check("L8 the passage under the street is closed: every ray on into it or down meets a front face",
		escaped.is_empty(), "%d rays escape, e.g. %s" % [escaped.size(), escaped.slice(0, 3)])
	# L9 the arcade's building is closed from behind: rays from behind the row
	#    to points across its back meet a face turned toward them
	var row: Node3D = lab.get_node("even/bay_1")
	var holes := []
	var space := get_world_3d().direct_space_state

	# The row runs from 4.5 m left of the middle bay to 9 m right of it.
	for gx in range(-4, 9):
		for gy in range(1, 9):
			var target: Vector3 = row.global_position + Vector3(gx, gy, -4.0)
			var from: Vector3 = row.global_position + Vector3(gx * 0.5, 4.0, -12.0)
			var query := PhysicsRayQueryParameters3D.create(from, target + (target - from).normalized() * 1.0)
			query.hit_back_faces = true
			var hit := space.intersect_ray(query)

			if hit.is_empty() or (hit["normal"] as Vector3).dot(target - from) > 0.0:
				holes.append(Vector2(gx, gy))

	_check("L9 the arcade's building is closed from behind", holes.is_empty(),
		"%d of 104 rays through: %s" % [holes.size(), holes])
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


## Rays from `at` heading on down the passage (Godot -z) or downward that
## meet nothing within `reach`, or meet a face from behind: their directions.
func _escapes(at: Vector3, reach: float) -> Array:
	var space := get_world_3d().direct_space_state
	var out := []

	for i in 400:
		# A spiral of directions over the sphere, kept to those going on or down.
		var y := 1.0 - 2.0 * (i + 0.5) / 400.0
		var r := sqrt(maxf(0.0, 1.0 - y * y))
		var t := PI * (3.0 - sqrt(5.0)) * i
		var dir := Vector3(cos(t) * r, y, sin(t) * r)

		if dir.z > -0.2 and dir.y > -0.2:
			continue

		var query := PhysicsRayQueryParameters3D.create(at, at + dir * reach)
		query.hit_back_faces = true
		var hit := space.intersect_ray(query)

		if hit.is_empty() or (hit["normal"] as Vector3).dot(dir) > 0.0:
			out.append(dir.snapped(Vector3.ONE * 0.01))

	return out


## A piece's atlas size, as its build wrote it.
func _atlas_px(piece: StringName) -> int:
	var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/eclipse/source/%s_regions.json" % piece))
	return int(meta["atlas_px"]) if meta is Dictionary else -1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
