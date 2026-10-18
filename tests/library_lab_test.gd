extends Node3D
## The librarian's shop's look-dev bay (maps/library_lab.tscn; docs/superpowers/plans/2026-10-17-librarian-shop-part-1.md):
## his vaulted room off a strip of the Metro corridor, painted in the bespoke blend; the player walks in through
## its arch. Headless:
##   Godot --headless --fixed-fps 60 --path . res://tests/library_lab_test.tscn

const LAB := preload("res://maps/library_lab.tscn")
const ROOM := ["room_vault", "room_back", "room_front", "room_floor", "room_rug"]
const DEALER := ["desk", "desk_chair", "lamp", "ledger", "magnifier", "gloves", "repair_kit", "coat_hook"]
const RITE := ["rituale", "stole", "crucifix", "aspergillum", "salt_tin", "oil_phial", "reliquary", "benedict_medal"]
const HUNT := ["hunt_rack", "stakes", "sword_cane", "revolver", "rounds", "crossbow", "bandolier", "chains", "trap_jaws"]

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

	# L8 the rite on his desk: the eight things of his office placed and painted; the reliquary's panes and the
	#     phial glazed
	var r_wrong := []

	for part in RITE:
		var mesh: MeshInstance3D = lab.corner.get(part)
		if mesh == null:
			r_wrong.append(part)
			continue
		for i in mesh.mesh.get_surface_count():
			var m: Material = mesh.get_surface_override_material(i)
			var slot: Material = mesh.mesh.surface_get_material(i)
			var want_glass: bool = slot != null and slot.resource_name == "glass"
			var r_glazed: bool = m is StandardMaterial3D and (m as StandardMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
			var r_painted: bool = m is ShaderMaterial and m.get_shader_parameter("atlas") != null
			if (want_glass and not r_glazed) or (not want_glass and not r_painted):
				r_wrong.append("%s/%d" % [part, i])
	var r_glass := ["reliquary", "oil_phial"].all(func(n): return lab.corner.has(n) and range(lab.corner[n].mesh.get_surface_count()).any(
		func(i): return lab.corner[n].mesh.surface_get_material(i) != null and lab.corner[n].mesh.surface_get_material(i).resource_name == "glass"))
	_check("L8 the rite on his desk: the Rituale, stole, crucifix, aspergillum, salt, oil, reliquary and medal, painted; glass glazed",
		r_wrong.is_empty() and r_glass, "wrong %s glass %s" % [r_wrong, r_glass])

	# L9 the hunt: his rack and his working tools on the back wall behind the desk, painted (the phials glazed)
	var h_wrong := []
	var h_desk: AABB = lab.corner["desk"].global_transform * lab.corner["desk"].get_aabb()

	for part in HUNT:
		var mesh: MeshInstance3D = lab.corner.get(part)
		if mesh == null:
			h_wrong.append(part)
			continue
		var h_box: AABB = mesh.global_transform * mesh.get_aabb()
		# Behind the desk, against the wall: between the desk's back and the back wall.
		if h_box.position.z < -lab.DEPTH - 0.001 or h_box.end.z > h_desk.position.z:
			h_wrong.append("%s at %s" % [part, h_box])
		for i in mesh.mesh.get_surface_count():
			var m: Material = mesh.get_surface_override_material(i)
			var slot: Material = mesh.mesh.surface_get_material(i)
			var want_glass: bool = slot != null and slot.resource_name == "glass"
			var h_glazed: bool = m is StandardMaterial3D and (m as StandardMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
			var h_painted: bool = m is ShaderMaterial and m.get_shader_parameter("atlas") != null
			if (want_glass and not h_glazed) or (not want_glass and not h_painted):
				h_wrong.append("%s/%d" % [part, i])
	_check("L9 the hunt: his rack and tools hang on the back wall behind the desk, painted, the phials glazed",
		h_wrong.is_empty(), "wrong %s" % [h_wrong])

	# L10 the chained book strains: its nailed cover lifts against the chain in jerks, then drops shut
	var w_book: Node3D = lab.chained
	var w_peak := 0.0
	var w_shut_by := -1
	var w_gap := 0.0
	w_book.strain_now()

	for i in 180:
		await get_tree().process_frame
		# The chain held to the staple as the cover pulls at it: they never come apart.
		w_gap = maxf(w_gap, w_book.staple_gap())
		if i < 60:
			w_peak = maxf(w_peak, w_book.angle)
		elif w_shut_by < 0 and w_book.angle < 0.5:
			w_shut_by = i
	var w_lifted: bool = w_book.cover.global_transform.origin.distance_to(w_book.cover_rest.origin) < 0.001 and w_shut_by >= 0
	_check("L10 the chained book strains: its cover lifts over 6 degrees within a second against its chain, shut again within three",
		w_peak > 6.0 and w_lifted and w_gap < 0.01, "peak %.1f shut by frame %d chain gap %.3f m" % [w_peak, w_shut_by, w_gap])

	# L11 the quarantine stirs: over 40 s every book in the cage twitches at least once, never in step
	var w_q: Node3D = lab.quarantine
	var w_before: Array = w_q.jolts.duplicate()

	for i in 2400:
		await get_tree().process_frame
	var w_each := true

	for k in w_q.books.size():
		w_each = w_each and w_q.jolts[k] > w_before[k]
	_check("L11 the quarantine stirs: every caged book twitches within 40 s, never two in step more than twice",
		w_q.books.size() == 7 and w_each and w_q.together <= 2, "books %d jolts %s together %d" % [w_q.books.size(), w_q.jolts,
		w_q.together])

	# L12 his ward: the chalk circle round the desk on the floor, its open side to the customers closed by salt; F3
	#     hides them with the other decals
	var w_desk: AABB = lab.corner["desk"].global_transform * lab.corner["desk"].get_aabb()
	var w_circle: Decal = lab.find_child("decal_ward_circle", true, false)
	var w_salt: Decal = lab.find_child("decal_salt_line", true, false)
	var w_round := false
	var w_closes := false

	if w_circle != null and w_salt != null:
		var half: Vector3 = w_circle.size / 2.0
		var c: Vector3 = w_circle.global_position
		w_round = c.x - half.x < w_desk.position.x and w_desk.end.x < c.x + half.x and c.z - half.z < w_desk.position.z \
			and w_desk.end.z < c.z + half.z and absf(c.y) < 0.3
		# The salt across the circle's front (toward the shopfront), where its ring is left open.
		w_closes = w_salt.global_position.z > w_desk.end.z and absf(w_salt.global_position.x - c.x) < 0.1
	lab.set_decals(false)
	var w_hidden: bool = w_circle != null and not w_circle.visible and not w_salt.visible
	lab.set_decals(true)
	_check("L12 his ward: a chalk circle round his desk, closed by salt toward the customers; F3 hides it",
		w_round and w_closes and w_hidden, "round %s closes %s hidden %s" % [w_round, w_closes, w_hidden])


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
