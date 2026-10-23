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
	await _metaphysics(effects)
	await _hunting(effects)
	await _novels_spells_auras(effects)
	await _words(effects)
	await _floating()

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
	var other_at: int = lab.live_books.find(lab.live_books.filter(func(b): return b.kind == LiveBook.Kind.STUDY and b.section == &"hunting")[0])
	var projection: Node3D = projections[study_at]
	var family: Node3D = projection.get("family")
	var parts_ok: bool = family != null and family.get("kind") == &"chronology" and family.rings.size() == 3 \
		and family.hands.size() == 2 and family.grains is MultiMeshInstance3D and family.page is MeshInstance3D
	_check("E35 a chronology book carries chronology's projection (three rings, two hands, sand, a ghost page)",
		parts_ok, "family %s" % [family.get("kind") if family != null else null])
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


## Occult metaphysics' projection (Task 3's fourth family): over an opened metaphysics study, nested sigils at their
## own depths turning against each other, an eye at their heart opening, looking about and closing; over the left-hand
## page five planes folding up from a flat cross into an open box and back, each with its front and its back.
func _metaphysics(effects: Node3D) -> void:
	var projections: Array = effects.get("projections")
	var studies: Array = lab.live_books.filter(func(b): return b.kind == LiveBook.Kind.STUDY and b.section == &"metaphysics")
	var book: LiveBook = studies[0]
	var projection: Node3D = projections[lab.live_books.find(book)]
	var family: Node3D = projection.get("family")
	var parts_ok: bool = family != null and family.get("kind") == &"metaphysics" and family.sigils.size() >= 3 \
		and family.eye is Node3D and family.folds.size() >= 4
	var depths := {}
	if parts_ok:
		for sigil: Node3D in family.sigils:
			depths[snappedf(sigil.position.z, 0.001)] = true
	_check("E47 a metaphysics book carries its projection (nested sigils at their own depths, an eye, folding planes)",
		parts_ok and depths.size() == family.sigils.size(), "family %s depths %s" % [family.get("kind") if family != null else null,
		depths.keys()])
	if not parts_ok:
		return

	var watcher := Node3D.new()
	add_child(watcher)
	var case: Node3D = lab.sections["metaphysics"]
	watcher.global_position = book.global_position + case.global_basis.z * 0.9 + Vector3.UP * 0.35
	book.watcher = watcher
	await _frames(90)
	var strays := []
	var turns := []
	var opens := []
	var folds := []
	for i in 600:
		await get_tree().process_frame
		if i % 20 == 0:
			strays.append_array(_strays(family, family.parts(), projection, book, case))
			turns.append(family.sigils.map(func(g): return g.rotation.z))
			opens.append(family.eye_open)
			folds.append(family.fold)
	var against: bool = signf(angle_difference(turns[0][0], turns[1][0])) != signf(angle_difference(turns[0][1], turns[1][1]))
	_check("E48 opened, metaphysics' pieces stay over the pages, under the board above, clear of the shelf books either side",
		family.visible and strays.is_empty(), "clear %.2f strays %s" % [projection.clear_height, strays.slice(0, 4)])
	_check("E49 the sigils turn against each other, the eye opens and shuts, the planes fold up and lie flat again",
		against and opens.max() - opens.min() > 0.8 and folds.max() - folds.min() > 0.8,
		"against %s eye %.2f..%.2f fold %.2f..%.2f" % [against, opens.min(), opens.max(), folds.min(), folds.max()])

	watcher.global_position = book.global_position + case.global_basis.z * 4.0
	await _frames(120)
	_check("E50 shut again, metaphysics' projection is gone", not family.visible and projection.presence == 0.0,
		"visible %s presence %.2f" % [family.visible, projection.presence])
	book.watcher = null
	watcher.queue_free()


## Monster hunting's projection (Task 3's fifth family): over an opened hunting study, the nahual (the approved model)
## as a small spectre prowling round a hunter's binding ring on the right-hand page, and the rack's own weapons (the
## crossbow, the sword cane, the stakes) as black ghosts rimmed in iron-red fire circling above it, each aimed at it;
## now and then the crossbow looses a bolt and the beast flinches, frays and gathers itself again.
func _hunting(effects: Node3D) -> void:
	var projections: Array = effects.get("projections")
	var studies: Array = lab.live_books.filter(func(b): return b.kind == LiveBook.Kind.STUDY and b.section == &"hunting")
	var book: LiveBook = studies[0]
	var projection: Node3D = projections[lab.live_books.find(book)]
	var family: Node3D = projection.get("family")
	var parts_ok: bool = family != null and family.get("kind") == &"hunting" and family.beast is Node3D \
		and family.weapons.size() == 3 and family.ring is MeshInstance3D
	_check("E51 a hunting book carries its projection (the nahual, three weapons from the rack, a binding ring)",
		parts_ok, "family %s" % [family.get("kind") if family != null else null])
	if not parts_ok:
		return

	var watcher := Node3D.new()
	add_child(watcher)
	var case: Node3D = lab.sections["hunting"]
	watcher.global_position = book.global_position + case.global_basis.z * 0.9 + Vector3.UP * 0.35
	book.watcher = watcher
	await _frames(90)
	var strays := []
	var aims := []
	var prowl := []
	var whole := []
	var shots := 0
	var was_shots: int = family.shots
	for i in 900:
		await get_tree().process_frame
		if i % 20 == 0:
			strays.append_array(_strays(family, family.parts(), projection, book, case))
			for w: Node3D in family.weapons:
				aims.append(family.aim_of(w))
			prowl.append(family.beast.position)
			whole.append(family.beast_whole)
	shots = family.shots - was_shots
	var moved := 0.0
	for k in prowl.size() - 1:
		moved += prowl[k].distance_to(prowl[k + 1])
	_check("E52 opened, hunting's pieces stay over the pages, under the board above, clear of the shelf books either side",
		family.visible and strays.is_empty(), "clear %.2f strays %s" % [projection.clear_height, strays.slice(0, 4)])
	_check("E53 every weapon aims at the beast as it prowls; the crossbow looses and the beast frays and gathers itself again",
		aims.min() > 0.9 and moved > 0.1 and shots >= 2 and whole.min() < 0.6 and whole.max() > 0.95,
		"aim %.2f prowled %.2f shots %d whole %.2f..%.2f" % [aims.min(), moved, shots, whole.min(), whole.max()])

	watcher.global_position = book.global_position + case.global_basis.z * 4.0
	await _frames(120)
	_check("E54 shut again, hunting's projection is gone", not family.visible and projection.presence == 0.0,
		"visible %s presence %.2f" % [family.visible, projection.presence])
	book.watcher = null
	watcher.queue_free()


## Task 4: the novels show their characters as emblems (a hat, a sword, a rose), each its own colour, black with a
## coloured rim; the spellbooks throw interlocking wards and a thin shell of aura in their section's colour; and from
## each of the five sections sparse tendrils of its colour rise from real books on its boards, whether or not anyone
## is near. One book shutting leaves another's open.
func _novels_spells_auras(effects: Node3D) -> void:
	var projections: Array = effects.get("projections")
	var palette: Dictionary = preload("res://scripts/Visual/Library/LibraryLight.gd").COLOURS
	var novels: Array = lab.live_books.filter(func(b): return b.kind == LiveBook.Kind.NOVEL)
	var spells: Array = lab.live_books.filter(func(b): return b.kind == LiveBook.Kind.SPELL)
	var novel_families: Array = novels.map(func(b): return projections[lab.live_books.find(b)].get("family"))
	var spell_families: Array = spells.map(func(b): return projections[lab.live_books.find(b)].get("family"))
	var emblems := {}
	var tints := {}
	for f in novel_families:
		if f != null and f.get("kind") == &"novel":
			emblems[f.emblem] = true
			tints[f.colour.to_html()] = true
	_check("E55 the three novels show three different characters' emblems (a hat, a sword, a rose), each its own colour",
		emblems.keys().size() == 3 and emblems.has(&"hat") and emblems.has(&"sword") and emblems.has(&"rose") and tints.size() == 3,
		"emblems %s colours %d" % [emblems.keys(), tints.size()])
	var spells_ok := spell_families.size() == 2
	for k in spell_families.size():
		var f: Node3D = spell_families[k]
		spells_ok = spells_ok and f != null and f.get("kind") == &"spell" and f.wards.size() >= 2 and f.shell is MeshInstance3D \
			and f.colour.is_equal_approx(palette[spells[k].section])
	_check("E56 the two spellbooks throw interlocking wards and an aura shell in their section's colour, not characters",
		spells_ok, "families %s" % [spell_families.map(func(f): return f.get("kind") if f != null else null)])
	if not (emblems.size() == 3 and spells_ok):
		return

	# The section auras, with every book shut: five, each rising from books on its own case, under the board above.
	var auras: Dictionary = effects.get("auras") if effects.get("auras") != null else {}
	var wrong := []
	for section: StringName in palette:
		var root: Node3D = auras.get(section)
		if root == null or not root.visible or root.tendrils.size() < 3:
			wrong.append("%s missing" % section)
			continue
		var case: MeshInstance3D = lab.sections[section]
		var case_box: AABB = (case.global_transform * case.get_aabb()).grow(0.02)
		for t: MeshInstance3D in root.tendrils:
			var foot: Vector3 = t.global_position
			var top: AABB = t.global_transform * t.get_aabb()
			if not case_box.has_point(foot) or top.end.y > root.ceiling_of(t) + 0.001:
				wrong.append("%s %s foot %s top %.3f ceiling %.3f" % [section, t.name, foot, top.end.y, root.ceiling_of(t)])
	_check("E57 five section auras rise from books on their own cases, under the board above, with every book shut",
		auras.size() == 5 and wrong.is_empty(), str(wrong.slice(0, 4)))

	# Open a novel and a spellbook; the novel's emblem turns, the spell's wards turn, the auras sway.
	var novel: LiveBook = novels[0]
	var spell: LiveBook = spells[0]
	var novel_family: Node3D = novel_families[0]
	var spell_family: Node3D = spell_families[0]
	var near_novel := Node3D.new()
	var near_spell := Node3D.new()
	add_child(near_novel)
	add_child(near_spell)
	near_novel.global_position = novel.global_position + Vector3(0.0, 0.6, 0.0)
	near_spell.global_position = spell.global_position + Vector3(0.0, 0.6, 0.0)
	novel.watcher = near_novel
	spell.watcher = near_spell
	await _frames(90)
	var aura: Node3D = auras[&"alchemy"]
	var before := [novel_family.emblem_node.rotation.y, spell_family.wards[0].quaternion, aura.tendrils[0].get_surface_override_material(0).get_shader_parameter("sway")]
	var strays := []
	for i in 120:
		await get_tree().process_frame
		if i % 30 == 0:
			for pair in [[novel_family, novel], [spell_family, spell]]:
				var projection: Node3D = projections[lab.live_books.find(pair[1])]
				var origin: Vector3 = projection.origin_world()
				for part: GeometryInstance3D in pair[0].parts():
					if not part.is_visible_in_tree():
						continue
					var box: AABB = part.global_transform * part.get_aabb()
					if box.end.y > origin.y + projection.clear_height + 0.001 or \
							Vector2(box.get_center().x - origin.x, box.get_center().z - origin.z).length() > 0.3:
						strays.append("%s/%s" % [pair[0].name, part.name])
	var after := [novel_family.emblem_node.rotation.y, spell_family.wards[0].quaternion, aura.tendrils[0].get_surface_override_material(0).get_shader_parameter("sway")]
	_check("E58 open, the novel's emblem turns, the spell's wards turn, the auras sway; all within their room above the book",
		novel_family.visible and spell_family.visible and absf(after[0] - before[0]) > 0.05 and not after[1].is_equal_approx(before[1])
		and after[2] != before[2] and strays.is_empty(), "strays %s" % [strays.slice(0, 4)])

	# The novel's reader walks off: it shuts, the spellbook stays open.
	near_novel.global_position = novel.global_position + Vector3(0.0, 0.0, 5.0)
	await _frames(120)
	var spell_projection: Node3D = projections[lab.live_books.find(spell)]
	_check("E59 one book shutting leaves another open: the novel's emblem gone, the spell's wards still there",
		not novel_family.visible and spell_family.visible and spell_projection.presence > 0.95,
		"novel %s spell %s presence %.2f" % [novel_family.visible, spell_family.visible, spell_projection.presence])
	near_spell.global_position = spell.global_position + Vector3(0.0, 0.0, 5.0)
	await _frames(120)
	novel.watcher = null
	spell.watcher = null
	near_novel.queue_free()
	near_spell.queue_free()


## Task 5: the living words. Our invented script, drawn from a distance-field atlas; any font's atlas in its place
## (the user's Spanish and Latin, accents and all); chains of words laid along paths and flowing, from open novels and
## spellbooks and in slow waves between the stands.
func _words(effects: Node3D) -> void:
	var Glyphs := load("res://scripts/Visual/Library/LibraryGlyphs.gd")
	var Chain := load("res://scripts/Visual/Library/WordChain.gd")
	if Glyphs == null or Chain == null:
		_check("E60 the invented script: the same seed the same words, another seed others, words of two to seven glyphs",
			false, "no LibraryGlyphs or WordChain")
		return

	var script_atlas: Dictionary = Glyphs.atlas("script")
	var latin: Dictionary = Glyphs.atlas("latin")
	var a: String = Glyphs.script(7, 60)
	var b: String = Glyphs.script(8, 60)
	var said: Array = Array(a.split(" ", false))
	var known := true
	for ch in a.replace(" ", ""):
		known = known and script_atlas["chars"].has(ch)
	_check("E60 the invented script: the same seed the same words, another seed others, words of two to seven glyphs",
		a == Glyphs.script(7, 60) and a != b and a.replace(" ", "").length() == 60 and known
		and said.all(func(w): return w.length() >= 2 and w.length() <= 7), "words %d known %s" % [said.size(), known])

	var accents := true
	for ch in "áéíóúñüÁÉÍÓÚÑÜ¿¡":
		accents = accents and latin["chars"].has(ch)
	_check("E61 the script's atlas has its forty glyphs; a font's atlas has Spanish and Latin with their accents; any other character falls back",
		script_atlas["chars"].size() >= 40 and accents and Glyphs.cell_of(latin, "\u4e2d") == latin["fallback"]
		and Glyphs.cell_of(latin, "ñ") != latin["fallback"], "script %d accents %s" % [script_atlas["chars"].size(), accents])

	# Chains on their own: edge cases, and that they follow their path and flow along it.
	var arc := PackedVector3Array()
	for i in 21:
		var t := float(i) / 20.0
		arc.append(Vector3(cos(t * PI) * 0.5, 1.5 + sin(t * PI) * 0.3, -2.0))
	var empty: Node3D = Chain.new()
	add_child(empty)
	empty.build(arc, "", latin, Color.WHITE)
	var flat: Node3D = Chain.new()
	add_child(flat)
	flat.build(PackedVector3Array([Vector3(0, 1, -2), Vector3(0, 1, -2)]), "abc", latin, Color.WHITE)
	var spaced: Node3D = Chain.new()
	add_child(spaced)
	spaced.build(arc, "ab cd", latin, Color.WHITE)
	var children := spaced.get_child_count()
	var counts_ok := true
	for i in 20:
		var text: String = "año " + "x".repeat(i % 7) if i % 2 == 0 else Glyphs.script(i, 30)
		spaced.set_text(text, latin if i % 2 == 0 else script_atlas)
		counts_ok = counts_ok and spaced.glyphs.multimesh.instance_count == text.replace(" ", "").length()
	_check("E62 no words, no path, spaces and twenty new texts: nothing drawn, nothing drawn, gaps, and no node or glyph left over",
		empty.count == 0 and flat.glyphs.multimesh.visible_instance_count == 0 and counts_ok
		and spaced.get_child_count() == children, "empty %d flat %d counts %s children %d -> %d" % [empty.count,
		flat.glyphs.multimesh.visible_instance_count, counts_ok, children, spaced.get_child_count()])
	empty.queue_free()
	flat.queue_free()

	spaced.set_text(Glyphs.script(3, 24), script_atlas)
	spaced.loop = true
	spaced.set_presence(1.0)
	await _frames(2)
	var off := 0.0
	var placed: Array = spaced.placed.duplicate()
	for at: Vector3 in placed:
		var nearest := INF
		for i in arc.size() - 1:
			nearest = minf(nearest, Geometry3D.get_closest_point_to_segment(at, arc[i], arc[i + 1]).distance_to(at))
		off = maxf(off, nearest)
	var along: Array = []
	for i in 40:
		await get_tree().process_frame
		along.append(spaced.arc_of(0))
	var backward := 0
	for i in along.size() - 1:
		var step: float = along[i + 1] - along[i]
		if step < 0.0 and step > -spaced.length * 0.5:
			backward += 1
	_check("E63 a chain's glyphs lie on its path and flow along it, round its loop without stepping back",
		off < 0.002 and placed.size() == 24 and backward == 0 and absf(along[-1] - along[0]) > 0.005,
		"off %.4f glyphs %d backward %d moved %.3f" % [off, placed.size(), backward, absf(along[-1] - along[0])])
	spaced.queue_free()

	# In the shop: a stream from each novel and spellbook, flowing only while it is open; two waves between the stands.
	var words: Node3D = effects.get("words")
	var streams: Dictionary = words.streams if words != null else {}
	var waves: Array = words.waves if words != null else []
	var shut_quiet := true
	var loud := []
	for book: LiveBook in streams:
		var quiet: bool = streams[book].presence == 0.0 and not streams[book].visible
		shut_quiet = shut_quiet and quiet
		if not quiet:
			loud.append("%s open %.2f presence %.2f" % [book.name, book.open, streams[book].presence])
	var stands: Array = [lab.FRONT_TABLE_AT] + lab.LECTERNS.map(func(l): return l[0])
	var ends_ok := waves.size() == 2
	for w: Node3D in waves:
		var ends: Array = [w.path[0], w.path[w.path.size() - 1]]
		for e: Vector3 in ends:
			var near := stands.any(func(at): return Vector2(lab.to_local(e).x - at.x, lab.to_local(e).z - at.z).length() < 0.45)
			ends_ok = ends_ok and near
		ends_ok = ends_ok and w.visible and w.count > 20
	var kinds: Array = lab.live_books.filter(func(x): return x.kind != LiveBook.Kind.STUDY)
	_check("E64 every novel and spellbook has its stream, quiet while shut; two waves of words run between the stands",
		streams.size() == kinds.size() and shut_quiet and ends_ok, "streams %d of %d loud %s waves %d ends %s" % [streams.size(),
		kinds.size(), loud, waves.size(), ends_ok])

	var spell: LiveBook = lab.live_books.filter(func(x): return x.kind == LiveBook.Kind.SPELL)[0]
	var near := Node3D.new()
	add_child(near)
	near.global_position = spell.global_position + Vector3(0.0, 0.6, 0.0)
	spell.watcher = near
	await _frames(90)
	var open_stream: Node3D = streams.get(spell)
	var flowing: bool = open_stream != null and open_stream.visible and open_stream.presence > 0.95
	lab.set_form(true)
	await _frames(2)
	var hidden: bool = waves.all(func(w): return not w.is_visible_in_tree()) and not open_stream.is_visible_in_tree()
	lab.set_form(false)
	await _frames(2)
	var back: bool = waves.all(func(w): return w.is_visible_in_tree()) and open_stream.is_visible_in_tree()
	_check("E65 an open spellbook's words flow; the form light hides every word and gives them back",
		flowing and hidden and back, "flowing %s hidden %s back %s" % [flowing, hidden, back])
	near.global_position = spell.global_position + Vector3(0.0, 0.0, 5.0)
	await _frames(120)
	spell.watcher = null
	near.queue_free()


## The vault's underside over `x` (the lab's frame): a segmental arc springing at 3.0 m at the side walls, 4.5 m at its
## crown.
func _vault_at(x: float) -> float:
	var s := 4.0
	var h := 1.5
	var r := (h * h + s * s) / (2.0 * h)
	return 4.5 - r + sqrt(maxf(r * r - x * x, 0.0))


## Task 6: books floating under the vault, slowly, pages fanning; now and then one comes down to its own empty place
## on a shelf, lies there a while, and rises again.
func _floating() -> void:
	var floating: Node3D = lab.get("floating")
	var books: Array = floating.books if floating != null else []
	_check("E66 six to ten books float under the vault, none of them the shop's live books",
		books.size() >= 6 and books.size() <= 10 and books.all(func(b): return b not in lab.live_books),
		"floating %d" % books.size())
	if books.is_empty():
		return

	# Forty seconds: aloft they stay above head height and under the vault, never near each other, never in a case.
	var low := []
	var near := INF
	var into := []
	var fans := {}
	var cases: Array = lab.shelves.map(func(c): return c.transform * c.get_aabb())
	for i in 2400:
		await get_tree().process_frame
		if i % 10 != 0:
			continue
		for k in books.size():
			var book: Node3D = books[k]
			var at: Vector3 = book.position
			var aloft: bool = floating.state_of(k) == &"aloft"
			if aloft and (at.y < 2.1 or at.y > _vault_at(at.x) - 0.15):
				low.append("%d at %s" % [k, at])
			if aloft:
				for box: AABB in cases:
					if box.grow(0.1).has_point(at):
						into.append("%d in a case at %s" % [k, at])
			fans[k] = fans.get(k, []) + [book.open]
			for j in range(k + 1, books.size()):
				near = minf(near, at.distance_to(books[j].position))
	var fanning := fans.values().all(func(o): return o.max() - o.min() > 0.15 and o.max() < 0.9)
	_check("E67 aloft, every book stays above 2.1 m and under the vault, out of the cases, apart from the others, its pages fanning",
		low.is_empty() and into.is_empty() and near > 0.35 and fanning, "low %s into %s nearest %.2f fanning %s" % [low.slice(0, 3),
		into.slice(0, 3), near, fanning])

	# One comes down to its place on a shelf, lies there, and rises again; its place was kept empty for it; it never jumps.
	var k: int = floating.transfers()[0]
	var book: Node3D = books[k]
	var slot: Dictionary = floating.slot_of(k)
	var kept: bool = lab.book_layout.all(func(e):
		var spot: Dictionary = lab.book_spots[e["spot"]]
		return spot["case"] != slot["case"] or absf(spot["top"] - slot["top"]) > 0.001 \
			or e["box"].end.x < slot["x"] - 0.14 or e["box"].position.x > slot["x"] + 0.14)
	floating.come_home(k)
	var states := []
	var rested_at := Vector3.INF
	var jump := 0.0
	var was: Vector3 = book.position
	for i in 3600:
		await get_tree().process_frame
		var st: StringName = floating.state_of(k)
		if states.is_empty() or states[-1] != st:
			states.append(st)
		if st == &"resting":
			rested_at = book.position
		jump = maxf(jump, book.position.distance_to(was))
		was = book.position
		if states.size() > 3 and st == &"aloft":
			break
	var home: Vector3 = floating.rest_of(k).origin
	_check("E68 a book comes down to its kept place on a shelf, rests there, and rises again, never jumping",
		kept and states.has(&"resting") and states[-1] == &"aloft" and rested_at.distance_to(home) < 0.003 and jump < 0.05,
		"kept %s states %s rest off %.4f jump %.3f" % [kept, states, rested_at.distance_to(home), jump])


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
