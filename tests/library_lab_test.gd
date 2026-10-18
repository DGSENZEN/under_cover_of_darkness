extends Node3D
## The librarian's shop's look-dev bay (maps/library_lab.tscn; docs/superpowers/plans/2026-10-17-librarian-shop-part-1.md):
## his vaulted room off a strip of the Metro corridor, painted in the bespoke blend; the player walks in through
## its arch. Headless:
##   Godot --headless --fixed-fps 60 --path . res://tests/library_lab_test.tscn

const LAB := preload("res://maps/library_lab.tscn")
const ROOM := ["room_vault", "room_back", "room_front", "room_floor", "room_rug"]

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

	# L2 the way in: from the corridor the player walks straight in through the arch to the back of the room
	var walk: Dictionary = await _walk(lab.SPAWN, 0.0, func(p): return p.z < -4.0, 600)
	_check("L2 the player walks from the corridor through the arch to the back of the shop without snagging",
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
