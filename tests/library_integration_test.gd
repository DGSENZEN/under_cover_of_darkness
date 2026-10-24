extends Node3D
## One continuous Underground/library, physical book effects and haunted motion.
const LIBRARY := preload("res://maps/library_lab.tscn")
var failures := 0
var results: Array[String] = []

func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	await _run()
	print("\n==== RESULTS ====")
	for result in results:
		print(result)
	get_tree().quit(1 if failures else 0)

func _run() -> void:
	var path := "res://maps/underground_library_lab.tscn"
	_check("J1 a combined Underground/library scene exists", ResourceLoader.exists(path), path)
	if not ResourceLoader.exists(path):
		return
	var map: Node3D = (load(path) as PackedScene).instantiate()
	add_child(map)
	await _frames(8)
	var shop: Node3D = map.get("library")
	_check("J2 one player, one environment and one HUD serve the whole map", shop != null
		and map.find_children("*", "WorldEnvironment", true, false).size() == 1
		and map.find_children("*", "CharacterBody3D", true, false).size() == 1 and shop.player == map.player and shop.keys_label == null,
		"shared player %s" % (shop != null and shop.player == map.player))
	if shop == null:
		return
	_check("J3 stall, shrine, trains and twelve live books coexist", map.stall != null and map.niche_flames != null
		and map.train != null and shop.live_books.size() == 12 and shop.missing.is_empty(), str(shop.missing))
	var wrong := []
	for book: LiveBook in shop.live_books:
		if not (shop.global_transform * AABB(Vector3(-4.4, 0, -6.2), Vector3(8.8, 3.0, 6.6))).has_point(book.global_position):
			wrong.append(book.name)
	_check("J4 rotated embedded books and lamp stay inside their shop", wrong.is_empty()
		and shop.lamp_light.global_position.distance_to(shop.lamp_bulb()) < 0.001, str(wrong))
	_check("J13 corridor services end inside the shopfront wall", map.services.all(func(piece):
		return (piece.global_transform * piece.get_aabb()).end.x <= map.RUN + 0.201), "no floating pipe ends inside the shop")
	# The corridor's work lamps are shaded: their light falls on the corridor, never on the vault above them (a bright
	# disc there read as a moon in a night sky).
	var Layers := preload("res://scripts/Visual/Layers.gd")
	var lit_vault := []
	for light: Light3D in map.work_lights:
		for span: MeshInstance3D in map.vault_spans:
			if (span.layers & light.light_cull_mask) != 0:
				lit_vault.append("%s/%s" % [light.name, span.name])
	_check("J14 the corridor's shaded work lamps leave the vault above them unlit", map.vault_spans.size() > 0
		and lit_vault.is_empty(), "lit %s" % [lit_vault.slice(0, 4)])

	# The ceiling over them takes a warm bounce off the lit tiles (dark navy, it read as a night sky with stars).
	var plaster: ShaderMaterial = map.vault_spans[0].get_surface_override_material(0) if map.vault_spans.size() > 0 else null
	var bounce: Variant = plaster.get_shader_parameter("ambient_ground") if plaster != null else null
	# (And each lamp's light coming back up off the tiles: a soft light low under each, lighting only the ceiling.)
	var bounces: Array = map.get("bounce_lights") if map.get("bounce_lights") != null else []
	var bounced: bool = bounces.size() == map.work_lights.size()
	for l: OmniLight3D in bounces:
		bounced = bounced and l.light_cull_mask == Layers.SHADED_ABOVE and l.global_position.y < 1.0 and not l.shadow_enabled \
			and l.light_color.r > l.light_color.b
	var shade: Variant = plaster.get_shader_parameter("shadow_cool") if plaster != null else null
	_check("J16 the corridor's ceiling takes a warm bounce off its lit floor, not a night sky's navy", plaster != null
		and bounce is Color and bounce.r > bounce.b + 0.1 and float(plaster.get_shader_parameter("ambient_amount")) >= 0.2
		and shade is Vector3 and shade.z <= shade.x
		and bounced, "bounce %s amount %s bounce lights %d of %d" % [bounce, plaster.get_shader_parameter("ambient_amount")
		if plaster != null else null, bounces.size(), map.work_lights.size()])

	# The shopfront is lit from the corridor: a work lamp near enough, in sight of its fascia and both pilasters.
	var front_unlit := []
	for local: Vector3 in [Vector3(0.0, 3.6, 0.5), Vector3(-1.9, 1.6, 0.5), Vector3(1.9, 1.6, 0.5)]:
		var at: Vector3 = shop.to_global(local)
		var reached := false
		for light: OmniLight3D in map.work_lights:
			if light.global_position.distance_to(at) < light.omni_range * 0.6:
				var ray := PhysicsRayQueryParameters3D.create(light.global_position, at)
				ray.exclude = [map.player.get_rid()]
				var hit := get_world_3d().direct_space_state.intersect_ray(ray)
				if hit.is_empty() or hit.position.distance_to(at) < 0.15:
					reached = true
		if not reached:
			front_unlit.append(local)
	_check("J15 a corridor work lamp lights the shopfront: its fascia and both pilasters, near and in sight",
		front_unlit.is_empty(), "unlit %s" % [front_unlit])

	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.49
	capsule.height = 2.0
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.collision_mask = 1
	query.exclude = [map.player.get_rid()]
	var blocked := []
	for i in 41:
		var local := Vector3(0.0, 1.05, lerpf(2.0, -3.2, i / 40.0))
		query.transform = Transform3D(Basis.IDENTITY, shop.to_global(local))
		if not get_world_3d().direct_space_state.intersect_shape(query).is_empty():
			blocked.append(local.z)
	_check("J5 a metre-wide body passes from corridor through the arch to the desk", blocked.is_empty(), str(blocked))
	map.player.global_position = Vector3(8.8, 1.05, 1.1)
	map.player.rotation.y = -PI / 2.0
	map.player.velocity = Vector3.ZERO
	map.player.reset_physics_interpolation()
	await _frames(10)
	Input.action_press("move_forward")
	for i in 360:
		await get_tree().physics_frame
		if map.player.global_position.x > 15.3:
			break
	Input.action_release("move_forward")
	_check("J12 the actual player walks from the Underground into the library", map.player.global_position.x > 15.3,
		"reached %s" % map.player.global_position)
	map.player.global_position = Vector3(4.8, 1.05, 0.9)
	map.player.velocity = Vector3.ZERO
	map.player.reset_physics_interpolation()
	var parts: Array = shop.quarantine.books
	var starts: Array = parts.map(func(b): return b.global_transform * b.get_aabb().get_center())
	var travel := 0.0
	var idle_travel := 0.0
	for i in 360:
		await _frames(1)
		for j in parts.size():
			var moved: float = (parts[j].global_transform * parts[j].get_aabb().get_center()).distance_to(starts[j])
			travel = maxf(travel, moved)
			if i < 30:
				idle_travel = maxf(idle_travel, moved)
	_check("J6 caged books breathe between their larger struggles", idle_travel > 0.003 and travel > 0.025,
		"idle %.3f m, struggle %.3f m" % [idle_travel, travel])
	var study: LiveBook = shop.live_books[10]
	var eye := Node3D.new()
	add_child(eye)
	eye.global_position = study._middle() + Vector3.UP * 0.1
	study.watcher = eye
	await _frames(90)
	var projection: Node3D = shop.effects.projections[10]
	var page: MeshInstance3D = projection.get("_page")
	_check("J7 effects share the moving page's orientation", projection.global_basis.is_equal_approx(page.global_basis.orthonormalized()),
		"page aligned")
	var leaf: Node3D = study._leaves[0].get_parent()
	var angle := leaf.rotation.z
	await _frames(30)
	_check("J10 open books keep fluttering their actual leaves", study._leaves.any(func(p): return p.visible)
		and absf(leaf.rotation.z - angle) > 0.01, "leaf movement %.3f rad" % absf(leaf.rotation.z - angle))
	shop.chained.strain_now()
	var peak := 0.0
	var gap := 0.0
	for i in 150:
		await _frames(1)
		peak = maxf(peak, shop.chained.angle)
		gap = maxf(gap, shop.chained.staple_gap())
	_check("J11 the chained cover bucks harder while staying attached", peak > 16.0 and gap < 0.01, "peak %.1f gap %.4f" % [peak, gap])
	if DisplayServer.get_name() != "headless":
		var sparks: MultiMeshInstance3D = projection.radiance.sparks
		var attached := true
		for i in sparks.multimesh.instance_count:
			attached = attached and absf(sparks.multimesh.get_instance_transform(i).origin.y) < 0.035
		_check("J8 page sparks cling to the paper instead of hovering overhead", attached, "within 3.5 cm")
	map.set_form(true)
	await _frames(2)
	map.set_form(false)
	_check("J9 shared inspection restores both labs and their materials", not shop._form and not map._form
		and shop.room["room_front"].material_override == null
		and map.keys_label.text.contains("Library through the east arch"), "restored, guidance retained")
	eye.queue_free()
	map.queue_free()
	await _frames(3)

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _check(label: String, ok: bool, detail: String) -> void:
	results.append("%s  %s [%s]" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		failures += 1
