extends Node3D
## The librarian's shop's look-dev bay (maps/library_lab.tscn; docs/superpowers/plans/2026-10-17-librarian-shop-part-1.md):
## his vaulted room off a strip of the Metro corridor, painted in the bespoke blend; the player walks in through
## its arch. Headless:
##   Godot --headless --fixed-fps 60 --path . res://tests/library_lab_test.tscn

const LAB := preload("res://maps/library_lab.tscn")
const ROOM := ["room_vault", "room_back", "room_front", "room_floor", "room_rug"]
const DEALER := ["desk", "desk_chair", "lamp", "ledger", "magnifier", "gloves", "repair_kit", "coat_hook"]

var results: Array[String] = []
var lab: Node3D


func _ready() -> void:
	await _run()

	print("\n==== RESULTS ====")
	for r in results:
		print(r)

	get_tree().quit()


func _run() -> void:
	lab = LAB.instantiate()
	add_child(lab)
	await _frames(5)

	# L1 the shell: the room's five pieces, each in the bespoke blend with its atlas
	var painted := []
	var wrong := []

	for part in ROOM:
		var mesh: MeshInstance3D = lab.room.get(part)
		if mesh == null:
			wrong.append(part)
			continue
		var all_painted := true
		for i in mesh.mesh.get_surface_count():
			var m: Material = mesh.get_surface_override_material(i)
			all_painted = all_painted and m is ShaderMaterial and is_equal_approx(m.get_shader_parameter("paint_mix"), 0.0) \
				and m.get_shader_parameter("atlas") != null
		(painted if all_painted else wrong).append(part)
	_check("L1 the shop's room stands, its five pieces painted in the bespoke blend", wrong.is_empty() and lab.missing.is_empty(),
		"painted %s wrong %s missing %s" % [painted, wrong, lab.missing])

	# L2 the way in: from the corridor the player walks straight in through the arch, deep into the room (his
	#     corner fills the back of its middle; the aisles to the back are L14's)
	var walk: Dictionary = await _walk(lab.SPAWN, 0.0, func(p): return p.z < -3.0, 600)
	_check("L2 the player walks from the corridor through the arch deep into the shop without snagging",
		walk["ok"] and walk["stall"] < 20, str(walk))

	# L3 the first look: from where they stand in the corridor, the back wall's middle (where his corner stands)
	#    is in the middle of the view
	lab.player.global_position = lab.SPAWN
	lab.player.rotation.y = 0.0
	await _frames(10)
	var eye: Camera3D = get_viewport().get_camera_3d()
	var back := Vector3(0.0, 1.5, -lab.DEPTH)
	var off := rad_to_deg((back - eye.global_position).normalized().angle_to(-eye.global_transform.basis.z))
	_check("L3 from the corridor the back of the shop, where his corner stands, is in the middle of the view",
		eye.is_position_in_frustum(back) and off < 8.0, "%.1f degrees off the view's middle" % off)

	# L4 the form light: F2 greys every piece of the room, and off gives each back exactly what it had
	var before := {}

	for part in ROOM:
		var mesh: MeshInstance3D = lab.room[part]
		before[part] = [mesh.material_override] + range(mesh.mesh.get_surface_count()).map(func(i): return mesh.get_surface_override_material(i))
	lab.set_form(true)
	var greyed: bool = ROOM.all(func(p): return lab.room[p].material_override == lab.form_material)
	lab.set_form(false)
	var restored := true

	for part in ROOM:
		var mesh: MeshInstance3D = lab.room[part]
		var now := [mesh.material_override] + range(mesh.mesh.get_surface_count()).map(func(i): return mesh.get_surface_override_material(i))
		restored = restored and now == before[part]
	_check("L4 F2 greys the room under the form light, and off restores every material", greyed and restored,
		"greyed %s restored %s" % [greyed, restored])

	# L5 his corner, the dealer: the desk and its things, painted (or glazed), the desk's front toward the shopfront
	var c_wrong := []

	for part in DEALER:
		var mesh: MeshInstance3D = lab.corner.get(part)
		if mesh == null:
			c_wrong.append(part)
			continue
		for i in mesh.mesh.get_surface_count():
			var m: Material = mesh.get_surface_override_material(i)
			var c_glazed: bool = m is StandardMaterial3D and (m as StandardMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
			var c_painted: bool = m is ShaderMaterial and m.get_shader_parameter("atlas") != null
			if not (c_glazed or c_painted):
				c_wrong.append("%s/%d" % [part, i])
	var c_space := lab.get_world_3d().direct_space_state
	var c_ray := PhysicsRayQueryParameters3D.create(Vector3(0.0, 0.5, -1.0), Vector3(0.0, 0.5, -6.0))
	var c_hit := c_space.intersect_ray(c_ray)
	var c_front_z: float = lab.CORNER_AT.z + 0.36
	var c_facing: bool = not c_hit.is_empty() and c_hit.collider.get_parent() == lab.corner.get("desk") \
		and absf(c_hit.position.z - c_front_z) < 0.06
	_check("L5 his corner: the dealer's desk and its things stand painted, the desk's front to the shopfront",
		c_wrong.is_empty() and lab.missing.is_empty() and c_facing,
		"wrong %s missing %s front hit %s" % [c_wrong, lab.missing, c_hit.get("position")])

	# L6 his lamp lit: a warm light at the bulb in its shade, casting shadows
	var c_light: OmniLight3D = lab.lamp_light
	var c_bulb: Vector3 = lab.lamp_bulb()
	_check("L6 his lamp lights the desk: a warm, shadowed light at the bulb in its green shade",
		c_light != null and c_light.global_position.distance_to(c_bulb) < 0.01 and c_light.light_color.r > c_light.light_color.b
		and c_light.shadow_enabled and c_light.light_energy > 0.5,
		"light at %s bulb %s colour %s" % [c_light.global_position if c_light else null, c_bulb, c_light.light_color if c_light else null])

	# L7 the walk to his desk: from the corridor the player comes up to its front without snagging, never into it
	var c_desk: MeshInstance3D = lab.corner["desk"]
	var c_box: AABB = c_desk.global_transform * c_desk.get_aabb()
	var c_walk: Dictionary = await _walk(lab.SPAWN, 0.0, func(q): return q.z < c_front_z + 0.9, 600)
	var c_end: Vector3 = c_walk["end"]
	_check("L7 the player walks up to his desk's front without snagging, and never into it",
		c_walk["ok"] and c_walk["stall"] < 20 and not c_box.has_point(c_end), str(c_walk))


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])


func _walk(start: Vector3, yaw: float, done: Callable, frames: int) -> Dictionary:
	var player: CharacterBody3D = lab.player
	player.global_position = start
	player.rotation.y = yaw
	player.velocity = Vector3.ZERO
	await _frames(10)
	Input.action_press("move_forward")
	var stall := 0
	var still := 0
	var last := player.global_position
	var arrived := false

	for i in frames:
		await get_tree().physics_frame
		still = still + 1 if player.global_position.distance_to(last) < 0.005 else 0
		stall = maxi(stall, still)
		last = player.global_position

		if done.call(player.global_position):
			arrived = true
			break

	Input.action_release("move_forward")
	await _frames(10)
	return {"ok": arrived, "end": player.global_position, "stall": stall}


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
