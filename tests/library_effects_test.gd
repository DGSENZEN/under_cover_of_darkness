extends Node3D
## Library Part 2 behaviour. Run headless with --fixed-fps 60.

const LAB := preload("res://maps/library_lab.tscn")

var results: Array[String] = []
var failures := 0
var lab: Node3D


func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	await _run()
	print("\n==== RESULTS ====")
	for result in results:
		print(result)
	get_tree().quit(1 if failures > 0 else 0)


func _run() -> void:
	lab = LAB.instantiate()
	add_child(lab)
	await _frames(5)
	var effects: Node3D = lab.get("effects")
	_check("E1 every live book has one level-owned effects controller", effects != null,
		"effects node present %s" % (effects != null))
	if effects == null:
		return
	var projections: Array = effects.get("projections")
	_check("E2 twelve distinct controllers belong to this lab", projections.size() == lab.live_books.size()
		and projections.size() == 12 and projections.all(func(p): return effects.is_ancestor_of(p)), str(projections.size()))
	await _lighting(effects)
	await _radiance(effects)
	await _chronology(effects)
	await _necromancy(effects)
	await _alchemy(effects)

	# Drive a real novel through partial openings, without a full-open signal.
	var book: LiveBook = lab.live_books[7]
	var projection: Node3D = projections[7]
	var watcher := Node3D.new()
	add_child(watcher)
	book.watcher = watcher
	book.set_process(false)
	book.open = 0.0
	book.wanted = false
	watcher.global_position = book._middle() + Vector3.UP * 0.15
	for i in 18:
		book._process(1.0 / 60.0)
		await _frames(1)
	var partial: float = projection.get("presence")
	_check("E3 a partly open book has a partly present effect", partial > 0.1 and partial < 0.9,
		"open %.3f presence %.3f" % [book.open, partial])
	watcher.global_position = book._middle() + Vector3.UP * 4.0
	for i in 60:
		book._process(1.0 / 60.0)
		await _frames(1)
	_check("E4 leaving mid-opening removes the effect completely", book.open == 0.0
		and is_zero_approx(float(projection.get("presence"))) and not projection.visible,
		"open %.3f presence %s visible %s" % [book.open, projection.get("presence"), projection.visible])
	var count := effects.find_children("*", "", true, false).size()
	for cycle in 20:
		watcher.global_position = book._middle() + Vector3.UP * 0.15
		book._process(0.2)
		await _frames(1)
		watcher.global_position = book._middle() + Vector3.UP * 4.0
		book._process(1.0)
		await _frames(1)
	_check("E5 twenty opening reversals allocate no additional nodes", effects.find_children("*", "", true, false).size() == count,
		"before %d after %d" % [count, effects.find_children("*", "", true, false).size()])

	# Both the rotated studies and sloped lecterns anchor to the stationary page block.
	var wrong := []
	for i in lab.live_books.size():
		var b: LiveBook = lab.live_books[i]
		var p: Node3D = projections[i]
		var page: MeshInstance3D
		for part: MeshInstance3D in b.parts:
			if part.get_meta("book_part", "") == "live_block_right":
				page = part
		if page == null:
			wrong.append("page anchor %d missing" % i)
			continue
		var bounds := page.get_aabb()
		var top := Vector3(bounds.get_center().x, bounds.end.y, bounds.get_center().z)
		var anchor: Vector3 = p.call("origin_world")
		if anchor.distance_to(page.to_global(top)) > 0.002 or not p.global_basis.is_equal_approx(page.global_basis.orthonormalized()):
			wrong.append("anchor/up %d" % i)
		if b.kind == LiveBook.Kind.STUDY:
			var height: float = p.get("clear_height")
			var ray := PhysicsRayQueryParameters3D.create(anchor + Vector3.UP * 0.004,
				anchor + Vector3.UP * height)
			if height <= 0.0 or not lab.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
				wrong.append("headroom %d height %.3f" % [i, height])
	_check("E6 studies and sloped lecterns anchor in their actual page frame, clear of the next board", wrong.is_empty(), str(wrong))

	effects.call("set_enabled", false)
	await _frames(2)
	var hidden := projections.all(func(p): return not p.visible and is_zero_approx(float(p.get("presence"))))
	_check("E7 disabling effects clears presence without losing controllers", hidden, "all hidden")
	effects.call("set_enabled", true)
	book.set_process(true)
	watcher.queue_free()
	book.watcher = null

	# Controllers must not own a camera. Camera fallback also works after replacement.
	lab.player.queue_free()
	await _frames(2)
	var camera := Camera3D.new()
	add_child(camera)
	camera.make_current()
	book.watcher = camera
	camera.global_position = book._middle() + Vector3.UP * 0.15
	await _frames(55)
	var opened: bool = projection.get("presence") > 0.95
	camera.queue_free()
	await _frames(2)
	var replacement := Camera3D.new()
	add_child(replacement)
	replacement.make_current()
	replacement.global_position = book._middle() + Vector3.UP * 4.0
	await _frames(65)
	_check("E8 replacement camera opens then closes books safely", opened and projection.get("presence") == 0.0,
		"opened %s final presence %s" % [opened, projection.get("presence")])
	replacement.queue_free()
	await _frames(3)
	_check("E9 no camera leaves closed controllers inactive", projection.get("presence") == 0.0, "presence %s" % projection.get("presence"))

	var old_effects: WeakRef = weakref(effects)
	lab.queue_free()
	await _frames(3)
	lab = LAB.instantiate()
	add_child(lab)
	await _frames(4)
	_check("E10 a replacement lab owns fresh controllers and frees the old effects", old_effects.get_ref() == null
		and lab.get("effects") != null and lab.get("effects") != effects, "old effects freed %s" % (old_effects.get_ref() == null))
	lab.queue_free()
	await _frames(3)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


## Chronology's projection (Task 3's first family): over an opened chronology book, an astrolabe's three rings
## turning each on its own axis, two clock hands sweeping at their own rates, sand falling upward from the pages
## into the rings, a ghost page that ages and un-ages; all within the room above the pages.
func _chronology(effects: Node3D) -> void:
	var projections: Array = effects.get("projections")
	var study_at: int = lab.live_books.find(lab.live_books.filter(func(b): return b.kind == LiveBook.Kind.STUDY and b.section == &"chronology")[0])
	var other_at: int = lab.live_books.find(lab.live_books.filter(func(b): return b.kind == LiveBook.Kind.STUDY and b.section == &"metaphysics")[0])
	var projection: Node3D = projections[study_at]
	var family: Node3D = projection.get("family")
	var parts_ok: bool = family != null and family.get("kind") == &"chronology" and family.rings.size() == 3 \
		and family.hands.size() == 2 and family.grains is MultiMeshInstance3D and family.page is MeshInstance3D
	_check("E35 a chronology book carries chronology's projection (three rings, two hands, sand, a ghost page); other sections none yet",
		parts_ok and projections[other_at].get("family") == null, "family %s" % [family.get("kind") if family != null else null])
	if not parts_ok:
		return

	# Opened by someone standing before its case.
	var book: LiveBook = lab.live_books[study_at]
	var watcher := Node3D.new()
	add_child(watcher)
	var case: Node3D = lab.sections["chronology"]
	watcher.global_position = book.global_position + case.global_basis.z * 0.9 + Vector3.UP * 0.35
	book.watcher = watcher
	await _frames(90)
	var origin: Vector3 = projection.origin_world()
	var clear: float = projection.clear_height
	var outside := []
	# (Along its board, within the run kept clear for it: never into the shelf books either side.)
	var hinge_x: float = case.to_local(book.global_position).x
	var keep: float = lab.STUDY_KEEP
	var angles := []
	var tips := []
	var grain_moves := 0
	var grain_was: Transform3D = family.sand[0] if not family.sand.is_empty() else Transform3D()
	var ages := []
	for i in 600:
		await get_tree().process_frame
		if i % 30 == 0:
			for part: GeometryInstance3D in family.rings + family.hands + [family.grains, family.page]:
				var box: AABB = part.global_transform * part.get_aabb()
				if box.end.y > origin.y + clear + 0.001 or box.position.y < origin.y - 0.01 \
						or Vector2(box.get_center().x - origin.x, box.get_center().z - origin.z).length() > 0.25:
					outside.append("%s at %d" % [part.name, i])
				for corner in 8:
					var along: float = case.to_local(box.get_endpoint(corner)).x - hinge_x
					if absf(along) > keep:
						outside.append("%s into the shelf books at %d (%.3f)" % [part.name, i, along])
						break
			angles.append(family.rings.map(func(r): return r.quaternion))
			tips.append(family.hands.map(func(h): return h.rotation.z))
			ages.append(family.age)
			var grain: Transform3D = family.sand[0]
			if not grain.origin.is_equal_approx(grain_was.origin):
				grain_moves += 1
			grain_was = grain
	_check("E36 opened, chronology's pieces stay over the pages, under the board above, clear of the shelf books either side",
		family.visible and outside.is_empty(),
		"clear %.2f outside %s" % [clear, outside.slice(0, 4)])

	var turned := [false, false, false]
	for k in 3:
		turned[k] = not angles[0][k].is_equal_approx(angles[1][k])
	var hour_run := absf(angle_difference(tips[0][0], tips[1][0]))
	var minute_run := absf(angle_difference(tips[0][1], tips[1][1]))
	_check("E37 the rings turn, the hands sweep at their own rates, the sand climbs and recycles, the page ages and un-ages",
		turned == [true, true, true] and minute_run > hour_run * 2.0 and grain_moves >= 15 and ages.max() - ages.min() > 0.6,
		"rings %s hands %.3f/%.3f grains moved %d ages %.2f..%.2f" % [turned, hour_run, minute_run, grain_moves, ages.min(), ages.max()])

	watcher.global_position = book.global_position + case.global_basis.z * 4.0
	await _frames(120)
	_check("E38 shut again, chronology's projection is gone", not family.visible and projection.presence == 0.0,
		"visible %s presence %.2f" % [family.visible, projection.presence])
	book.watcher = null
	watcher.queue_free()


## Where a family's pieces stray: above the board over the book, below the pages, or along the board out of the run
## kept clear for the book (into the shelf books either side).
func _strays(family: Node3D, parts: Array, projection: Node3D, book: LiveBook, case: Node3D) -> Array:
	var out := []
	var origin: Vector3 = projection.origin_world()
	var clear: float = projection.clear_height
	var hinge_x: float = case.to_local(book.global_position).x
	for part: GeometryInstance3D in parts:
		if not part.is_visible_in_tree():
			continue
		var box: AABB = part.global_transform * part.get_aabb()
		if box.end.y > origin.y + clear + 0.001 or box.position.y < origin.y - 0.01:
			out.append("%s height %.3f..%.3f" % [part.name, box.position.y - origin.y, box.end.y - origin.y])
		for corner in 8:
			var along: float = case.to_local(box.get_endpoint(corner)).x - hinge_x
			if absf(along) > lab.STUDY_KEEP:
				out.append("%s along %.3f" % [part.name, along])
				break
	return out


## Necromancy's projection (Task 3's second family): over an opened necromancy study, a skull rising out of
## chartreuse spirit-fire at the gutter, its jaw working; a skeletal hand reaching up out of the right-hand page,
## its fingers curling and opening; the dead's faces carried up out of the left-hand page on smoke; all within the
## room above the pages and the run kept clear for the book.
func _necromancy(effects: Node3D) -> void:
	var projections: Array = effects.get("projections")
	var studies: Array = lab.live_books.filter(func(b): return b.kind == LiveBook.Kind.STUDY and b.section == &"necromancy")
	var families: Array = studies.map(func(b): return projections[lab.live_books.find(b)].get("family"))
	var book: LiveBook = studies[0]
	var projection: Node3D = projections[lab.live_books.find(book)]
	var family: Node3D = families[0]
	var parts_ok: bool = family != null and family.get("kind") == &"necromancy" and families.all(func(f): return f != null) \
		and family.skull is Node3D and family.jaw is MeshInstance3D and family.fire is MeshInstance3D \
		and family.bones.size() >= 15 and family.faces.size() >= 3
	_check("E39 a necromancy book carries necromancy's projection (spirit-fire, a skull with its jaw, a skeletal hand, faces in smoke)",
		parts_ok, "family %s bones %s faces %s" % [family.get("kind") if family != null else null,
		family.bones.size() if family != null else 0, family.faces.size() if family != null else 0])
	if not parts_ok:
		return

	var watcher := Node3D.new()
	add_child(watcher)
	var case: Node3D = lab.sections["necromancy"]
	watcher.global_position = book.global_position + case.global_basis.z * 0.9 + Vector3.UP * 0.35
	book.watcher = watcher
	await _frames(90)
	var strays := []
	var jaw := []
	var curls := []
	var face_heights := []
	var resets := 0
	var was_heights: Array = family.face_heights.duplicate()
	for i in 600:
		await get_tree().process_frame
		if i % 20 == 0:
			strays.append_array(_strays(family, family.parts(), projection, book, case))
			jaw.append(family.jaw.rotation.x)
			curls.append(family.curl)
			face_heights.append_array(family.face_heights)
			for k in family.face_heights.size():
				if family.face_heights[k] < was_heights[k] - 0.05:
					resets += 1
			was_heights = family.face_heights.duplicate()
	_check("E40 opened, necromancy's pieces stay over the pages, under the board above, clear of the shelf books either side",
		family.visible and strays.is_empty(), "clear %.2f strays %s" % [projection.clear_height, strays.slice(0, 4)])
	_check("E41 the jaw works, the fingers curl and open, the faces climb and are carried off and come again",
		jaw.max() - jaw.min() > 0.15 and curls.max() - curls.min() > 0.6 and face_heights.max() - face_heights.min() > 0.12 and resets >= 2,
		"jaw %.2f..%.2f curl %.2f..%.2f faces %.2f..%.2f resets %d" % [jaw.min(), jaw.max(), curls.min(), curls.max(),
		face_heights.min(), face_heights.max(), resets])

	watcher.global_position = book.global_position + case.global_basis.z * 4.0
	await _frames(120)
	_check("E42 shut again, necromancy's projection is gone", not family.visible and projection.presence == 0.0,
		"visible %s presence %.2f" % [family.visible, projection.presence])
	book.watcher = null
	watcher.queue_free()


## Alchemy's projection (Task 3's third family): over an opened alchemy study, an ouroboros turning as it swallows
## itself; a homunculus curled in a round flask of glass over the left-hand page, drifting in its glowing water;
## alchemical symbols rising round the serpent, flaring gold and burning out, then rising again.
func _alchemy(effects: Node3D) -> void:
	var projections: Array = effects.get("projections")
	var studies: Array = lab.live_books.filter(func(b): return b.kind == LiveBook.Kind.STUDY and b.section == &"alchemy")
	var book: LiveBook = studies[0]
	var projection: Node3D = projections[lab.live_books.find(book)]
	var family: Node3D = projection.get("family")
	var parts_ok: bool = family != null and family.get("kind") == &"alchemy" \
		and studies.all(func(b): return projections[lab.live_books.find(b)].get("family") != null) \
		and family.ouroboros is MeshInstance3D and family.flask is MeshInstance3D and family.homunculus is MeshInstance3D \
		and family.symbols.size() >= 5
	_check("E43 an alchemy book carries alchemy's projection (an ouroboros, a homunculus in a flask, burning symbols)",
		parts_ok, "family %s" % [family.get("kind") if family != null else null])
	if not parts_ok:
		return

	var watcher := Node3D.new()
	add_child(watcher)
	var case: Node3D = lab.sections["alchemy"]
	watcher.global_position = book.global_position + case.global_basis.z * 0.9 + Vector3.UP * 0.35
	book.watcher = watcher
	await _frames(90)
	var strays := []
	var serpent := []
	var little := []
	var heights := []
	var burns := []
	var resets := 0
	var was: Array = family.symbol_heights.duplicate()
	for i in 600:
		await get_tree().process_frame
		if i % 20 == 0:
			strays.append_array(_strays(family, family.parts(), projection, book, case))
			serpent.append(family.ouroboros.quaternion)
			little.append(family.homunculus.position.y)
			heights.append_array(family.symbol_heights)
			burns.append_array(family.symbol_burns)
			for k in family.symbol_heights.size():
				if family.symbol_heights[k] < was[k] - 0.04:
					resets += 1
			was = family.symbol_heights.duplicate()
	_check("E44 opened, alchemy's pieces stay over the pages, under the board above, clear of the shelf books either side",
		family.visible and strays.is_empty(), "clear %.2f strays %s" % [projection.clear_height, strays.slice(0, 4)])
	_check("E45 the serpent turns, the little man drifts, the symbols rise, flare, burn out and come again",
		not serpent[0].is_equal_approx(serpent[1]) and little.max() - little.min() > 0.004
		and heights.max() - heights.min() > 0.1 and burns.max() - burns.min() > 0.5 and resets >= 3,
		"drift %.3f symbols %.2f..%.2f burn %.2f..%.2f resets %d" % [little.max() - little.min(), heights.min(), heights.max(),
		burns.min(), burns.max(), resets])

	watcher.global_position = book.global_position + case.global_basis.z * 4.0
	await _frames(120)
	_check("E46 shut again, alchemy's projection is gone", not family.visible and projection.presence == 0.0,
		"visible %s presence %.2f" % [family.visible, projection.presence])
	book.watcher = null
	watcher.queue_free()


func _radiance(effects: Node3D) -> void:
	var projection: Node3D = effects.projections[7]
	var radiance: Node3D = projection.get("radiance")
	_check("E24 opening books have light filaments and glints on the paper", radiance != null, "radiance present %s" % (radiance != null))
	if radiance == null:
		return
	var book: LiveBook = lab.live_books[7]
	book.set_process(false)
	book.open = 1.0
	await _frames(4)
	var Layers := preload("res://scripts/Visual/Layers.gd")
	var draws := radiance.find_children("*", "GeometryInstance3D", true, false)
	var shaped := draws.size() == 2
	for draw in draws:
		shaped = shaped and draw.layers == Layers.FX and draw.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mesh: Mesh = draw.multimesh.mesh if draw is MultiMeshInstance3D else draw.mesh
		shaped = shaped and mesh is ArrayMesh and mesh.surface_get_material(0) is ShaderMaterial
	_check("E25 filaments and glints are actual effect-layer meshes without shadows", shaped, "%d draws" % draws.size())
	var sparks: MultiMeshInstance3D = radiance.get("sparks")
	var before := sparks.multimesh.get_instance_transform(0)
	await _frames(20)
	var after := sparks.multimesh.get_instance_transform(0)
	var bounded := sparks.multimesh.instance_count == 4
	for i in sparks.multimesh.instance_count:
		var pos := sparks.multimesh.get_instance_transform(i).origin
		bounded = bounded and pos.y >= 0.0 and pos.y < projection.clear_height
	# The dummy headless RenderingServer returns identity for MultiMesh readback.
	# Exercise real movement/bounds on the renderer that actually stores the draws.
	if DisplayServer.get_name() != "headless":
		_check("E26 page glints move within the book's measured headroom in a fixed pool", bounded and before.origin.distance_to(after.origin) > 0.005,
			"sparks %d moved %.3f m" % [sparks.multimesh.instance_count, before.origin.distance_to(after.origin)])
	var paper: MeshInstance3D
	for part: MeshInstance3D in book.parts:
		if part.get_meta("book_part", "") == "live_block_right":
			paper = part
	var glow: Material = paper.get_surface_override_material(0)
	_check("E27 open pages carry animated light tracery", glow.next_pass is ShaderMaterial,
		"page light pass present %s" % (glow.next_pass != null))
	book.open = 0.0
	await _frames(3)
	_check("E28 shutting the book removes wisps, sparks and page tracery", not radiance.visible and glow.next_pass == null,
		"visible %s light pass %s" % [radiance.visible, glow.next_pass])
	book.set_process(true)
	var cage_radiance: Array = effects.lighting.get("cage_radiance")
	_check("E29 quarantine light belongs to the physical books", cage_radiance.size() == 3
		and cage_radiance.all(func(r): return r in lab.quarantine.books), str(cage_radiance.size()))
	var auras: Variant = effects.lighting.get("section_radiance")
	var anchored: bool = auras != null and auras.size() == 5
	var aura_details := []
	if auras != null:
		for section in auras:
			var aura: Node3D = auras[section]
			var box: AABB = aura.get_meta("source_book_box")
			anchored = anchored and aura.visible and box.grow(0.04).has_point(aura.global_position)
			aura_details.append("%s visible %s on book %s" % [section, aura.visible, box.grow(0.04).has_point(aura.global_position)])
	_check("E30 each section's tracery sits on an actual shelf book", anchored, str(aura_details))


func _lighting(effects: Node3D) -> void:
	var lighting: Node3D = effects.get("lighting")
	_check("E11 the library has its own supernatural lighting", lighting != null, "lighting present %s" % (lighting != null))
	if lighting == null:
		return
	var corridor: OmniLight3D = lab.get("corridor_light")
	_check("E12 shop work lights start off; corridor sodium and warm desk lamp stay lit", lab.work_lights.size() == 2
		and lab.work_lights.all(func(l): return not l.visible) and corridor != null and corridor.visible and lab.lamp_light.visible,
		"work lights %d corridor %s lamp %s" % [lab.work_lights.size(), corridor != null and corridor.visible, lab.lamp_light.visible])
	var section_lights: Dictionary = lighting.get("section_lights")
	var palette := {&"chronology": Color("e5ae48"), &"necromancy": Color("b2ea3a"), &"alchemy": Color("ef8b40"),
		&"metaphysics": Color("a486ed"), &"hunting": Color("d55b55")}
	var wrong := []
	var energy_before := []
	for section in palette:
		var light: OmniLight3D = section_lights.get(section)
		if light == null or not light.light_color.is_equal_approx(palette[section]) or light.shadow_enabled:
			wrong.append(section)
		energy_before.append(light.light_energy if light != null else 0.0)
	_check("E13 all five cases have distinct unshadowed book-colour light", section_lights.size() == 5 and wrong.is_empty(), str(wrong))
	await _frames(60)
	var changed := []
	for section in palette:
		var light: OmniLight3D = section_lights.get(section)
		changed.append(light.light_energy - energy_before[changed.size()] if light != null else 0.0)
	var different := changed.any(func(v): return absf(v - changed[0]) > 0.005)
	_check("E14 section lights breathe on separate phases", changed.all(func(v): return absf(v) > 0.001) and different, str(changed))
	var cage: OmniLight3D = lighting.get("cage_light")
	_check("E15 cage glows chartreuse from its books", cage != null and cage.light_color.is_equal_approx(palette[&"necromancy"])
		and cage.light_energy > 0.0 and not cage.shadow_enabled, "light %s" % cage)
	var cage_looks: Array = lighting.get("_cage_looks")
	_check("E21 cage page materials glow with valid defaults even on the headless renderer", cage_looks.size() >= 7
		and cage_looks.all(func(m): return m.has_meta("ambient_sky") and m.has_meta("ambient_ground") \
			and m.get_shader_parameter("ambient_amount") > float(m.get_meta("ambient_amount")) + 0.05),
		"glowing paper materials %d" % cage_looks.size())
	var spells: Array = lab.live_books.filter(func(b): return b.kind == LiveBook.Kind.SPELL)
	_check("E16 both spellbooks have an explicit section", spells.size() == 2
		and spells.all(func(b): return palette.has(b.section)), str(spells.map(func(b): return b.section)))

	var book_lights: Array = lighting.get("book_lights")
	var book: LiveBook = lab.live_books[7]
	book.set_process(false)
	book.open = 0.5
	await _frames(3)
	var half: float = book_lights[7].light_energy
	book.open = 1.0
	await _frames(3)
	var full: float = book_lights[7].light_energy
	book.open = 0.0
	await _frames(3)
	_check("E17 live-book light tracks partial opening and turns off shut", book_lights.size() == 12 and full > 0.0
		and absf(half / full - 0.5) < 0.01 and book_lights[7].light_energy == 0.0,
		"half %.3f full %.3f shut %.3f" % [half, full, book_lights[7].light_energy])
	book.set_process(true)

	var lamp: MeshInstance3D = lab.corner["lamp"]
	var lamp_override := lamp.material_override
	var materials := []
	for i in lamp.mesh.get_surface_count():
		materials.append(lamp.get_surface_override_material(i))
	var restored := true
	for work_on in [false, true]:
		lab.set_work_lights(work_on)
		lab.set_form(true)
		await _frames(2)
		restored = restored and not lab.lamp_light.visible and lab.work_lights.all(func(l): return not l.visible)
		restored = restored and section_lights.values().all(func(l): return not l.visible) and not cage.visible
		lab.set_form(false)
		await _frames(2)
		restored = restored and lab.work_lights.all(func(l): return l.visible == work_on) and corridor.visible and lab.lamp_light.visible
		restored = restored and section_lights.values().all(func(l): return l.visible) and cage.visible
		restored = restored and lamp.material_override == lamp_override
		for i in lamp.mesh.get_surface_count():
			restored = restored and materials[i] == lamp.get_surface_override_material(i)
	_check("E18 F2 restores both F1 states and lamp materials exactly", restored, "restored %s" % restored)
	lab.set_work_lights(false)
	lab.set_form(true)
	var toggle := InputEventKey.new()
	toggle.keycode = KEY_F1
	toggle.pressed = true
	lab._unhandled_input(toggle)
	lab._unhandled_input(toggle)
	lab.set_form(false)
	_check("E22 F1 toggles remembered lighting even while the form light hides it", lab.work_lights.all(func(l): return not l.visible),
		"two F1 presses under F2 restore off")
	lab.set_work_lights(false)

	# The room's persistent book light is real illumination; cosmetic flashes will be fx_light.
	var Layers := preload("res://scripts/Visual/Layers.gd")
	var real: Array = section_lights.values() + book_lights + [cage]
	_check("E19 intentional book illumination reaches the probe and the arithmetic estimator", real.all(
		func(l): return (l.light_cull_mask & Layers.GEM_PROBE) != 0 and not l.is_in_group(&"fx_light")), "all real book lights included")
	var Probe := preload("res://scripts/StimuliSystem/LightProbe.gd")
	var estimates := []
	for at: Vector3 in [Vector3(-2.45, 1.1, -1.7), Vector3(2.45, 1.1, -4.3), Vector3(0, 1.1, -2.7)]:
		estimates.append(Probe.light_at(lab, at))
	_check("E20 shelf pools leave dark standing paths between them", estimates.all(func(v): return v >= 0.0 and v < 0.7), str(estimates))

	# An open book's light rises out of its pages: shadowed (the table or lectern under it cuts it off, no full disc
	# printed on the wall), its reach short, its colour the page's white tinted by the book's, not a coloured gel.
	var gel := []
	for light: OmniLight3D in lighting.get("book_lights"):
		if not light.shadow_enabled or light.omni_range > 1.3 or light.light_color.s > 0.45:
			gel.append("%s shadow %s range %.2f sat %.2f" % [light.name, light.shadow_enabled, light.omni_range, light.light_color.s])
	_check("E33 open books light like pages: shadowed, short reach, paper white tinted by their colour",
		gel.is_empty(), str(gel.slice(0, 3)))

	# The caged books leak their light between their leaves: their paper only faintly lifted (flooded, whole faces glowed
	# flat), the light in the seams.
	var flooded := []
	for look: ShaderMaterial in lighting.get("_cage_looks"):
		var lift: float = float(look.get_shader_parameter("ambient_amount")) - float(look.get_meta("ambient_amount"))
		var seams: ShaderMaterial = look.next_pass
		if lift > 0.4 or seams == null or not seams.get_shader_parameter("caged"):
			flooded.append("lift %.2f seams %s" % [lift, seams != null])
	_check("E34 caged books leak light along their leaves' seams, their paper only faintly lifted",
		lighting.get("_cage_looks").size() >= 7 and flooded.is_empty(), str(flooded.slice(0, 3)))

	# The shop's own air: its painted materials take a warm bounce instead of the corridor's cool night (their own
	# ambient and rim light, laid on as emission), and its fog is thinned.
	var air_looks: Array = lab.get("shop_looks") if lab.get("shop_looks") != null else []
	var cold := []
	for look: ShaderMaterial in air_looks:
		var sky: Color = look.get_shader_parameter("ambient_sky")
		var rim: Color = look.get_shader_parameter("rim_colour")
		if sky.b >= sky.r or rim.b >= rim.r or float(look.get_shader_parameter("ambient_amount")) < 0.12:
			cold.append(look.resource_name)
	var haze: FogVolume = lab.get("shop_haze")
	_check("E31 the shop has its own warm, dark air: warm bounce and rim on its painted materials, its fog thinned",
		air_looks.size() >= 4 and cold.is_empty() and haze != null and (haze.material as FogMaterial).density < 0.0,
		"looks %d cold %s haze %s" % [air_looks.size(), cold, haze != null])

	# Its painted materials shade softly: no blotchy broken terminator or coarse macro, shadows not tinted blue.
	var looks: Array = lab.get("shop_looks") if lab.get("shop_looks") != null else []
	var harsh := []
	for look: ShaderMaterial in looks:
		var cool: Vector3 = look.get_shader_parameter("shadow_cool")
		if float(look.get_shader_parameter("terminator_break")) > 0.4 or float(look.get_shader_parameter("macro_amount")) > 0.12 \
				or float(look.get_shader_parameter("band_softness")) < 0.25 \
				or cool.z > cool.x + 0.06:
			harsh.append(look.resource_name)
	_check("E32 the shop's painted materials shade softly: a gentle terminator, little macro, shadows not blue",
		looks != null and looks.size() >= 4 and harsh.is_empty(), "looks %d harsh %s" % [looks.size() if looks != null else 0, harsh])
	if DisplayServer.get_name() != "headless":
		var start: Vector3 = lab.player.global_position
		lab.player.set_physics_process(false)
		var readings := []
		for at: Vector3 in [Vector3(-2.45, 1.05, -1.7), Vector3(2.45, 1.05, -4.3), Vector3(0, 1.05, -2.7)]:
			lab.player.global_position = at
			lab.player.reset_physics_interpolation()
			for k in 15:
				RenderingServer.force_draw(false)
				await _frames(2)
			readings.append(lab.player.get_light_level())
		lab.player.global_position = start
		lab.player.reset_physics_interpolation()
		lab.player.set_physics_process(true)
		_check("E23 real rendered lightgem stays below 0.7 at the three standing positions", readings.all(func(v): return v >= 0.0 and v < 0.7), str(readings))


func _check(label: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		failures += 1
