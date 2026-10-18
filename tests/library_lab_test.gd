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

	# L13 the five sections: a case each, painted, the low cases either side of the runner, the ladder on its rail;
	#     hunting flanking his corner, necromancy beside the cage
	var s_wrong := []

	for part in ["chronology", "necromancy", "alchemy", "metaphysics", "hunting"]:
		if not lab.sections.has(part):
			s_wrong.append(part)
	for mesh: MeshInstance3D in lab.shelves:
		for i in mesh.mesh.get_surface_count():
			var m: Material = mesh.get_surface_override_material(i)
			var slot: Material = mesh.mesh.surface_get_material(i)
			var s_glass: bool = slot != null and slot.resource_name == "glass"
			var s_glazed: bool = m is StandardMaterial3D and (m as StandardMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
			var s_painted: bool = m is ShaderMaterial and m.get_shader_parameter("atlas") != null
			if (s_glass and not s_glazed) or (not s_glass and not s_painted):
				s_wrong.append("%s/%d" % [mesh.name, i])
	var s_kinds: Array = lab.shelves.map(func(n): return String(n.get_meta("kind")))
	var s_near_desk := INF
	var s_near_cage := INF

	if s_wrong.is_empty():
		s_near_desk = _apart(lab.sections["hunting"], lab.corner["desk"])
		s_near_cage = _apart(lab.sections["necromancy"], lab.corner["quarantine_cage"])
	_check("L13 the five sections stand, painted, with the low cases and the ladder; hunting by his desk, necromancy by the cage",
		s_wrong.is_empty() and s_kinds.count("shelf_middle") == 2 and "ladder" in s_kinds and "ladder_rail" in s_kinds
		and s_near_desk < 2.5 and s_near_cage < 2.0,
		"wrong %s kinds %s hunting %.2f m from the desk, necromancy %.2f m from the cage" % [s_wrong, s_kinds, s_near_desk, s_near_cage])

	# L14 the aisles: down either side of the low cases the player walks to the back of the shop, and a body's width
	#     swept along each line meets nothing
	var s_walks := []
	var s_clear := []
	var s_space := lab.get_world_3d().direct_space_state

	for x in [-lab.AISLE_X, lab.AISLE_X]:
		var s_walk: Dictionary = await _walk(Vector3(x, 1.05, -0.5), 0.0, func(q): return q.z < -4.5, 600)
		s_walks.append(s_walk["ok"] and s_walk["stall"] < 20)
		var s_box := BoxShape3D.new()
		s_box.size = Vector3(1.0, 1.9, 0.1)
		var s_q := PhysicsShapeQueryParameters3D.new()
		s_q.shape = s_box
		s_q.transform = Transform3D(Basis(), Vector3(x, 1.06, -0.5))
		s_q.motion = Vector3(0.0, 0.0, -4.0)
		s_q.exclude = [lab.player.get_rid()]
		s_clear.append(s_space.cast_motion(s_q)[0] >= 1.0)
	_check("L14 the aisles: the player walks either side of the low cases to the back; a body's width down each meets nothing",
		s_walks == [true, true] and s_clear == [true, true], "walks %s clear %s" % [s_walks, s_clear])

	# L15 the corner still shows: from the corridor, nothing stands between the eye and his lamp
	lab.player.global_position = lab.SPAWN
	lab.player.rotation.y = 0.0
	await _frames(10)
	var s_eye: Camera3D = get_viewport().get_camera_3d()
	var s_ray := PhysicsRayQueryParameters3D.create(s_eye.global_position, lab.lamp_bulb())
	s_ray.exclude = [lab.player.get_rid()]
	var s_hit := s_space.intersect_ray(s_ray)
	_check("L15 from the corridor his lamp shows over the low cases, nothing between", s_hit.is_empty(),
		"hit %s" % [s_hit.get("collider")])

	# L16 the shelves full and varied: hundreds of books in a handful of draws, every board holding some, none in an
	#     upright or a neighbour, each just above its board, never three alike in a row
	var b_layout: Array = lab.book_layout
	var b_held := {}
	var b_wrong := []
	var b_by_spot := {}

	for b in b_layout:
		b_held[b["spot"]] = true
		var spot: Dictionary = lab.book_spots[b["spot"]]
		var box: AABB = b["box"]
		if box.position.x < spot["x0"] - 0.0001 or box.end.x > spot["x1"] + 0.0001:
			b_wrong.append("upright %s" % b["spot"])
		for run: Vector2 in spot["keep"]:
			if box.end.x > run.x and box.position.x < run.y:
				b_wrong.append("in a study's run %s" % b["spot"])
		var lift: float = box.position.y - spot["top"]
		if lift < 0.001 or lift > 0.004:
			b_wrong.append("lift %.4f" % lift)
		b_by_spot.get_or_add(b["spot"], []).append(b)
	for spot_books: Array in b_by_spot.values():
		spot_books.sort_custom(func(p, q): return p["box"].position.x < q["box"].position.x)
		for i in spot_books.size():
			if i > 0 and spot_books[i]["box"].position.x < spot_books[i - 1]["box"].end.x - 0.0001:
				b_wrong.append("overlap")
			if i > 1 and spot_books[i]["look"] == spot_books[i - 1]["look"] and spot_books[i]["look"] == spot_books[i - 2]["look"]:
				b_wrong.append("three alike")
	_check("L16 the shelves full and varied: 400+ books in 20 draws or fewer, every board stocked, none touching or in a study's room, each set on its board",
		b_layout.size() >= 400 and lab.book_draws.size() <= 20 and b_held.size() == lab.book_spots.size() and b_wrong.is_empty(),
		"books %d draws %d boards %d/%d wrong %s" % [b_layout.size(), lab.book_draws.size(), b_held.size(), lab.book_spots.size(),
		b_wrong.slice(0, 5)])

	# L17 a live book opens as the player comes near and looks at it, and shuts as they go
	var b_novel: Node3D = lab.live_books.filter(func(x): return x.kind == LiveBook.Kind.NOVEL)[0]
	var b_at: Vector3 = b_novel.global_position
	var b_opens := [0, 0]
	b_novel.opened.connect(func(_b): b_opens[0] += 1)
	b_novel.closed.connect(func(_b): b_opens[1] += 1)
	var b_near := Vector3(b_at.x - 1.0, 1.05, b_at.z)
	var b_open_by := -1

	for i in 90:
		lab.player.global_position = b_near
		lab.player.rotation.y = -PI / 2.0
		await get_tree().process_frame
		if b_open_by < 0 and b_novel.open >= 0.95:
			b_open_by = i
	var b_far := Vector3(b_at.x - 3.0, 1.05, b_at.z)
	var b_shut_by := -1

	for i in 120:
		lab.player.global_position = b_far
		await get_tree().process_frame
		if b_shut_by < 0 and b_novel.open <= 0.05:
			b_shut_by = i
	_check("L17 a live book opens within 1.2 s as the player comes near it, and shuts within 1.5 s as they go",
		b_open_by >= 0 and b_open_by <= 72 and b_shut_by >= 0 and b_shut_by <= 90 and b_opens == [1, 1],
		"open by frame %d shut by frame %d signals %s" % [b_open_by, b_shut_by, b_opens])

	# L18 not through shelves: near a book on a shelf but on the far side of its case's side, it stays shut
	var b_study: Node3D = lab.live_books.filter(func(x): return x.kind == LiveBook.Kind.STUDY and x.section == &"necromancy")[0]
	# (Standing on the floor, its eye near the book's height, so near enough that only the case's side keeps it shut.)
	var b_side: Vector3 = b_study.global_position + Vector3(0.05, 0.0, 1.15)
	b_side.y = 1.05
	var b_eye := 0.0

	for i in 120:
		lab.player.global_position = b_side
		lab.player.rotation.y = 0.0
		await get_tree().process_frame
		b_eye = get_viewport().get_camera_3d().global_position.distance_to(b_study.global_position)
	# (And the same book, from in front of its case as near, does open.)
	var b_front: Vector3 = b_study.global_position + Vector3(1.15, 0.0, -0.05)
	b_front.y = 1.05
	var b_shut_side: float = b_study.open

	for i in 90:
		lab.player.global_position = b_front
		await get_tree().process_frame
	_check("L18 a live book behind its case's side stays shut for someone near (%.2f m) but unable to see it; seen from in front it opens" % b_eye,
		b_shut_side < 0.01 and b_eye < LiveBook.OPEN_NEAR and b_study.open > 0.95,
		"open behind the side %.2f (eye %.2f m), in front %.2f" % [b_shut_side, b_eye, b_study.open])
	lab.player.global_position = lab.SPAWN

	# L19 the kinds: novels, spellbooks, and a study in every section
	var b_novels: int = lab.live_books.filter(func(x): return x.kind == LiveBook.Kind.NOVEL).size()
	var b_spells: int = lab.live_books.filter(func(x): return x.kind == LiveBook.Kind.SPELL).size()
	var b_studied := {}
	var b_hidden := []
	var b_space: PhysicsDirectSpaceState3D = lab.get_world_3d().direct_space_state
	for x in lab.live_books:
		if x.kind == LiveBook.Kind.STUDY:
			b_studied[x.section] = true
			# (Each in sight of someone standing before its case: nothing, the ladder neither, in the way.)
			var case: Node3D = lab.sections[String(x.section)]
			var front: Vector3 = x._middle() + case.global_basis.z * 1.2 + Vector3.UP * 0.2
			if not b_space.intersect_ray(PhysicsRayQueryParameters3D.create(front, x._middle())).is_empty():
				b_hidden.append(x.section)
	_check("L19 the live books: three novels or more, two spellbooks or more, a study in each of the five sections, each in sight from before its case",
		b_novels >= 3 and b_spells >= 2 and b_studied.size() == 5 and b_hidden.is_empty(),
		"novels %d spells %d studied %s hidden %s" % [b_novels, b_spells, b_studied.keys(), b_hidden])

	# L21 the form light spares them: F2 on and off leaves the live books, the lamp and the chained book as they were,
	#     the lamp lit again
	var b_watched: Array = [lab.corner["lamp"], lab.corner["chained_book_cover"]]
	for x in lab.live_books:
		b_watched += x.parts
	var b_before := b_watched.map(func(m): return [m.material_override] + range(m.mesh.get_surface_count()).map(func(i): return m.get_surface_override_material(i)))
	lab.set_form(true)
	lab.set_form(false)
	var b_after := b_watched.map(func(m): return [m.material_override] + range(m.mesh.get_surface_count()).map(func(i): return m.get_surface_override_material(i)))
	_check("L21 F2 on and off leaves the live books, the lamp and the chained book as they were, the lamp lit",
		b_before == b_after and lab.lamp_light.visible, "same %s lamp lit %s" % [b_before == b_after, lab.lamp_light.visible])

	# L20 the frame time: the shop no slower than the underground bay, measured the same way in this run
	lab.player.global_position = Vector3(0.0, 1.05, -3.0)
	var b_ours: float = await _median_frame(300)
	lab.queue_free()
	await _frames(10)
	var b_under: Node3D = (load("res://maps/underground_lab.tscn") as PackedScene).instantiate()
	add_child(b_under)
	await _frames(60)
	var b_theirs: float = await _median_frame(300)
	b_under.queue_free()
	_check("L20 the shop's frames take no longer than 1.1 times the underground bay's", b_ours <= 1.1 * b_theirs,
		"shop %.2f ms, underground bay %.2f ms" % [b_ours / 1000.0, b_theirs / 1000.0])


## The median time between process frames over `n` frames (microseconds).
func _median_frame(n: int) -> float:
	var times := []
	var was := Time.get_ticks_usec()

	for i in n:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		times.append(now - was)
		was = now
	times.sort()
	return float(times[n / 2])


## How far apart two pieces stand on the floor (m, between their boxes; 0 if they overlap).
func _apart(a: MeshInstance3D, b: MeshInstance3D) -> float:
	var p: AABB = a.global_transform * a.get_aabb()
	var q: AABB = b.global_transform * b.get_aabb()
	var dx := maxf(0.0, maxf(p.position.x - q.end.x, q.position.x - p.end.x))
	var dz := maxf(0.0, maxf(p.position.z - q.end.z, q.position.z - p.end.z))
	return Vector2(dx, dz).length()


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
