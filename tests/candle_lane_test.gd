extends Node3D
## The candle lane set (docs/superpowers/plans/2026-10-23-candle-lane.md): quick checks, headless with --fixed-fps 60.

const LANE := preload("res://maps/candle_lane.tscn")

var results: Array[String] = []
var failures := 0
var lane: Node3D


func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	lane = LANE.instantiate()
	add_child(lane)
	await _frames(5)
	await _shell()
	await _order()
	await _ends()
	print("\n==== RESULTS ====")
	for result in results:
		print(result)
	get_tree().quit(1 if failures > 0 else 0)


## Task 3: the lane's shell at the layout's measure, the shop in its far wall, its ends open.
func _shell() -> void:
	var floor_mesh: MeshInstance3D = lane.get_node_or_null("floor")
	var length := floor_mesh.get_aabb().size.x if floor_mesh != null else 0.0
	_check("C1 the lane is the bay's section, 33.6 m long", is_equal_approx(length, 33.6)
		and is_equal_approx(lane.BACK_WALL, -2.35) and is_equal_approx(lane.FAR_WALL, 4.55) and is_equal_approx(lane.HEIGHT, 4.0),
		"length %.2f" % length)

	# The shop's front: centred at plan x 19; nothing of the far wall between its front's ends.
	var shop: Node3D = lane.get("shop")
	var arch_x: float = lane.plan_point(shop.position).x if shop != null else INF
	var in_front := []
	for panel: MeshInstance3D in lane.wall_panels:
		var box: AABB = panel.global_transform * panel.get_aabb()
		# (Across the arch's 3 m opening, nothing: the two panels at the front's ends stay half behind it, by ruling.)
		var arch := Vector2(6.2 - 1.5, 6.2 + 1.5)
		if box.position.z > lane.FAR_WALL - 0.05 and box.end.x > arch.x + 0.01 and box.position.x < arch.y - 0.01:
			in_front.append(String(panel.name))
	await get_tree().physics_frame
	var through := _ray(Vector3(6.2, 1.0, 3.5), Vector3(6.2, 1.0, 12.0))
	var walled := _ray(Vector3(0.0, 1.0, 3.5), Vector3(0.0, 1.0, 12.0))
	_check("C2 the shop's front stands in the far wall, its arch centred at plan x 19",
		absf(arch_x - 19.0) < 0.05 and in_front.is_empty() and through.z > lane.FAR_WALL + 1.0 and walled.z < lane.FAR_WALL + 0.5,
		"arch at plan x %.2f, panels in front %s, through to z %.2f, wall at %.2f" % [arch_x, in_front.slice(0, 3), through.z, walled.z])

	# The ends: west open its whole width; east open only through the chapel's 3 m doorway.
	var west_open := true
	var door_open := true
	var east_walled := true
	for h in [1.0, 1.7]:
		for z in [-1.8, 1.1, 4.0]:
			west_open = west_open and _ray(Vector3(-10.0, h, z), Vector3(-20.0, h, z)).x <= -19.99
		door_open = door_open and _ray(Vector3(10.0, h, 0.15), Vector3(18.0, h, 0.15)).x >= 17.99
		east_walled = east_walled and _ray(Vector3(10.0, h, 3.5), Vector3(20.0, h, 3.5)).x < 17.5
	_check("C3 the west end lies open on the Pasaje; the east end opens only through a 3 m doorway",
		west_open and door_open and east_walled and lane.get("chapel_door") != null,
		"west %s door %s east walled %s" % [west_open, door_open, east_walled])

	# On foot: from the lane's mouth into the shop to his desk's front; and through the chapel's doorway.
	var spawn := Vector3(-15.0, 1.05, 1.1)
	var to_desk: Array[Vector3] = [Vector3(5.0, 1.05, 0.5), Vector3(6.2, 1.05, 1.0), Vector3(6.2, 1.05, 4.0), Vector3(6.2, 1.05, 7.0), Vector3(6.2, 1.05, 8.4)]
	var desk := await _walk_path(spawn, to_desk, 2400)
	var to_chapel: Array[Vector3] = [Vector3(15.5, 1.05, 0.15), Vector3(17.6, 1.05, 0.15)]
	var chapel := await _walk_path(spawn, to_chapel, 2400)
	_check("C4 the player walks from the lane's mouth into the shop to his desk's front, and through the chapel doorway",
		desk["ok"] and chapel["ok"], "desk %s chapel %s" % [desk, chapel])

	# The shop's keys, embedded: F2 on and off gives back its materials; F3 hides and shows its decals.
	var meshes: Array = shop.find_children("*", "MeshInstance3D", true, false)
	var before := meshes.map(func(m): return [m.material_override, m.get_surface_override_material(0)])
	shop.set_form(true)
	shop.set_form(false)
	var after := meshes.map(func(m): return [m.material_override, m.get_surface_override_material(0)])
	shop.set_decals(false)
	var hidden: bool = shop.decals.all(func(d): return not d.visible)
	shop.set_decals(true)
	_check("C5 the shop's keys still work embedded: F2 gives back every material, F3 hides and restores its decals",
		before == after and hidden and shop.decals.all(func(d): return d.visible), "materials same %s decals %s" % [before == after, hidden])


## Task 4: the bay's pieces along the lane in the walk's order, a body passing them all, the services and vault its
## whole length.
func _order() -> void:
	var at := func(node_name: String) -> float:
		var n: Node3D = lane.get_node_or_null(node_name)
		return lane.plan_point(n.position).x if n != null else INF
	var stall_x: float = lane.plan_point((lane.stall as Node3D).position).x if lane.stall != null else INF
	var cart_x: float = at.call("tamale_cart")
	var niche_x: float = at.call("niche")
	var bench_x: float = at.call("bench")
	var nahual: Node3D = lane.get("nahual")
	var bench: Node3D = lane.get_node_or_null("bench")
	var near_bench: bool = nahual != null and bench != null and nahual.position.distance_to(bench.position) < 3.0
	var drain: Node3D = lane.floor_tiles.filter(func(t): return String(t.get_meta("kind", "")) == "floor_border_drain").front() \
		if not lane.floor_tiles.is_empty() else null
	var drain_ok: bool = drain != null and absf(lane.plan_point(drain.position).x + 0.6 - stall_x) < 2.0
	_check("C6 the pieces stand in the walk's order: the stall and cart at plan x 7-13, the niche and bench at 1-4, the nahual by the bench, the drain by the stall",
		stall_x >= 7.0 and stall_x <= 13.0 and cart_x >= 7.0 and cart_x <= 13.0 and niche_x >= 1.0 and niche_x <= 4.0
		and bench_x >= 1.0 and bench_x <= 4.0 and near_bench and drain_ok,
		"stall %.1f cart %.1f niche %.1f bench %.1f nahual by bench %s drain %s" % [stall_x, cart_x, niche_x, bench_x, near_bench, drain_ok])

	var spawn := Vector3(-15.0, 1.05, 1.1)
	var along: Array[Vector3] = [Vector3(-4.0, 1.05, 1.1), Vector3(4.0, 1.05, 0.8), Vector3(15.5, 1.05, 0.15), Vector3(17.6, 1.05, 0.15)]
	var walk := await _walk_path(spawn, along, 3600)
	_check("C7 a body walks the lane from its mouth to the chapel's doorway past every piece", walk["ok"], "%s" % [walk])

	# Each line of services along each wall, and the vault's spans: their spans along x joined end to end.
	var lines := {}
	for piece: MeshInstance3D in lane.services:
		var box: AABB = piece.global_transform * piece.get_aabb()
		var key := "%s@%.1f" % ["far" if box.get_center().z > 1.0 else "back", snappedf(box.get_center().y, 0.5)]
		lines.get_or_add(key, []).append(Vector2(box.position.x, box.end.x))
	var short := []
	for key: String in lines:
		var spans: Array = lines[key]
		# (A line is a run of modules along the wall: a single drop or riser is no line.)
		if spans.size() < 3:
			continue
		spans.sort_custom(func(p, q): return p.x < q.x)
		var reach: float = spans[0].x
		var gap: bool = reach > -lane.LANE_HALF + 0.1
		var to: float = spans[0].y
		for span: Vector2 in spans:
			if span.x > to + 0.1:
				gap = true
			to = maxf(to, span.y)
		# (Nor past them: out of the mouth into the Pasaje, or through the end wall into the chapel.)
		if gap or to < lane.LANE_HALF - 0.1 or reach < -lane.LANE_HALF - 0.1 or to > lane.LANE_HALF + 0.1:
			short.append("%s %.1f..%.1f" % [key, reach, to])
	var vault: Array = lane.find_children("vault_span*", "MeshInstance3D", false, false)
	var vault_x := Vector2(INF, -INF)
	for span: MeshInstance3D in vault:
		var box: AABB = span.global_transform * span.get_aabb()
		vault_x = Vector2(minf(vault_x.x, box.position.x), maxf(vault_x.y, box.end.x))
	_check("C8 the services and the vault run the lane's whole length, ending at its ends",
		short.is_empty() and lines.size() >= 4 and vault_x.x < -lane.LANE_HALF + 0.1 and vault_x.y > lane.LANE_HALF - 0.1,
		"short %s lines %d vault %.1f..%.1f" % [short.slice(0, 4), lines.size(), vault_x.x, vault_x.y])


## Task 5: the lane's own pieces at its two ends and the way's signs; the stubs only when it stands alone.
func _ends() -> void:
	var half: float = lane.LANE_HALF
	var frame: MeshInstance3D = lane.get("door_frame")
	var frame_box: AABB = frame.global_transform * frame.get_aabb() if frame != null else AABB()
	var framed: bool = frame != null and frame_box.position.x > half - 0.4 and frame_box.end.x < half + 0.6 \
		and frame_box.position.z < lane.DOOR_Z - 1.8 and frame_box.end.z > lane.DOOR_Z + 1.8
	# (The flames stand on every wick; they burn in a few systems along the ledges, each with its light.)
	var wicks: Array = lane.get("candle_wicks") if lane.get("candle_wicks") != null else []
	var candles: Array = lane.get("candles") if lane.get("candles") != null else []
	var lit := candles.filter(func(c): return not (c as Node3D).find_children("*", "OmniLight3D", true, false).is_empty())
	var on_ledges := wicks.all(func(w):
		var x: float = lane.plan_point(w).x
		return x >= 22.0 and x <= 28.0)
	var board: MeshInstance3D = lane.get("milagros")
	var board_at: Vector3 = (board.global_transform * board.get_aabb()).get_center() if board != null else Vector3.INF
	var by_door: bool = board != null and absf(board_at.x - half) < 0.3 \
		and absf(board_at.z - lane.DOOR_Z) > 1.9 and absf(board_at.z - lane.DOOR_Z) < 3.5
	_check("C9 the chapel end: the doorway's frame on the east end, votive ledges with lit flames between plan x 22 and 28, the milagros board beside the doorway",
		framed and lane.get("ledges") != null and wicks.size() >= 20 and not candles.is_empty() and lit.size() == candles.size()
		and on_ledges and by_door,
		"framed %s wicks %d systems %d lit %d on ledges %s board by door %s" % [framed, wicks.size(), candles.size(), lit.size(), on_ledges, by_door])

	# The mouth: the tiles' band runs both walls to the mouth; the sign over it; arrows both ways; no words anywhere.
	var at_mouth := {"back": false, "far": false}
	for panel: MeshInstance3D in lane.wall_panels:
		var box: AABB = panel.global_transform * panel.get_aabb()
		if box.position.x < -half + 1.3:
			at_mouth["far" if box.get_center().z > 1.0 else "back"] = true
	var sign: Node3D = lane.get("mouth_sign")
	var sign_box: AABB = (sign as MeshInstance3D).global_transform * (sign as MeshInstance3D).get_aabb() if sign != null else AABB()
	var hung: bool = sign != null and absf(sign_box.get_center().x + half) < 2.0 and sign_box.position.y >= 2.1 \
		and sign_box.end.y <= lane.HEIGHT + 0.05
	var ways := {"west": 0, "east": 0}
	var arrows: Array = lane.get("arrows") if lane.get("arrows") != null else []
	for arrow: Node3D in arrows:
		var way: String = arrow.get_meta("points", "")
		var along: Vector3 = arrow.global_basis * (Vector3.RIGHT if String(arrow.get_meta("kind", "")) == "arrow_east" else Vector3.LEFT)
		if (way == "west" and along.x < -0.9) or (way == "east" and along.x > 0.9):
			ways[way] += 1
	# (Nothing written on the way's signs: no text, and no decal laid over a sign's face; the bay's soot and grime are
	# no words.)
	var faces: Array = arrows.duplicate()
	if sign != null:
		faces.append(sign)
	# (The player's own hand prompts are the player's, not the lane's.)
	var player: Node = lane.get("player")
	var marked := lane.find_children("*", "Label3D", true, false).filter(
		func(l): return player == null or not player.is_ancestor_of(l)).size()
	for decal: Decal in lane.find_children("*", "Decal", true, false):
		for face: MeshInstance3D in faces:
			if (face.global_transform * face.get_aabb()).grow(0.1).has_point(decal.global_position):
				marked += 1
	# The mouth's portal: across its top and down both walls, where the services' runs end (none of their ends in the
	# open).
	var portal: MeshInstance3D = lane.get("mouth_portal")
	var portal_box: AABB = portal.global_transform * portal.get_aabb() if portal != null else AABB()
	var framing: bool = portal != null and portal_box.position.x <= -half and portal_box.end.x > -half + 0.3 \
		and portal_box.position.z <= lane.BACK_WALL and portal_box.end.z >= lane.FAR_WALL and portal_box.end.y >= lane.HEIGHT - 0.05
	var loose := []
	for piece: MeshInstance3D in lane.services:
		var box: AABB = piece.global_transform * piece.get_aabb()
		if box.position.x < -half + 0.3 and portal != null and box.end.x - box.position.x > 1.0:
			# (Its west end inside the portal: the end's middle within the portal's box.)
			var end := Vector3(box.position.x + 0.02, box.get_center().y, box.get_center().z)
			if not portal_box.grow(0.02).has_point(end):
				loose.append("%s %.2f,%.2f,%.2f" % [piece.name, end.x, end.y, end.z])
	_check("C10 the mouth: the line's band along both walls, the enamel sign over the mouth, arrows toward the trains (west) and to the south-east exit (east), every face blank; a portal frames it, the services ending in it",
		at_mouth["back"] and at_mouth["far"] and hung and ways["west"] >= 1 and ways["east"] >= 1 and marked == 0
		and framing and loose.is_empty(),
		"band %s sign hung %s ways %s words %d portal %s loose ends %s" % [at_mouth, hung, ways, marked, framing, loose.slice(0, 4)])

	# Standalone, the stubs stand; set into the map, they do not.
	var stub: Node3D = lane.get("stub")
	var puestos := stub.find_children("puesto*", "", true, false) if stub != null else []
	var backdrops := stub.find_children("backdrop*", "", true, false) if stub != null else []
	var up_down := backdrops.filter(func(b): return absf(absf((b as Node3D).global_position.z - 1.1) - 6.0) < 1.5 \
		and (b as Node3D).global_position.x < -half).size()
	var glow := stub.find_children("chapel_glow", "OmniLight3D", true, false) if stub != null else []
	var glows: bool = glow.size() == 1 and absf((glow[0] as Node3D).global_position.x - (half + 2.4)) < 0.6 \
		and (glow[0] as OmniLight3D).light_color.r > (glow[0] as OmniLight3D).light_color.b
	var behind := stub.find_children("chapel_backdrop", "", true, false).size() if stub != null else 0
	var inset: Node3D = LANE.instantiate()
	inset.standalone = false
	add_child(inset)
	await _frames(2)
	var inset_stub: Node3D = inset.get("stub")
	var bare: bool = inset_stub == null or (not inset_stub.visible and inset_stub.get_child_count() == 0)
	bare = bare and inset.find_children("puesto*", "", true, false).is_empty() and inset.find_children("backdrop*", "", true, false).is_empty()
	inset.queue_free()
	await _frames(2)
	_check("C11 standalone, the Pasaje stub (two puestos either side of the mouth, lit backdrops 6 m up and down it) and the chapel's glimpse (warm light 2 m inside the doorway, a backdrop) stand; not standalone, neither does",
		stub != null and stub.visible and puestos.size() == 2 and up_down == 2 and glows and behind == 1 and bare,
		"puestos %d backdrops %d/%d glow %s chapel backdrop %d inset bare %s" % [puestos.size(), up_down, backdrops.size(), glows, behind, bare])


func _ray(from: Vector3, to: Vector3) -> Vector3:
	var space := lane.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(lane.to_global(from), lane.to_global(to))
	var player: CharacterBody3D = lane.get("player")
	if player != null:
		q.exclude = [player.get_rid()]
	var hit := space.intersect_ray(q)
	return lane.to_local(hit.position) if not hit.is_empty() else to


## Walks the lane's player from `start` along `way`, turning toward each point; arrived at each within 0.3 m.
func _walk_path(start: Vector3, way: Array[Vector3], frames: int) -> Dictionary:
	var player: CharacterBody3D = lane.player
	player.global_position = lane.to_global(start)
	player.velocity = Vector3.ZERO
	await _frames(10)
	var reached := 0
	var still := 0
	var last := player.global_position
	Input.action_press("move_forward")
	for i in frames:
		var to: Vector3 = lane.to_global(way[reached]) - player.global_position
		to.y = 0.0
		if to.length() < 0.3:
			reached += 1
			if reached == way.size():
				break
			continue
		player.rotation.y = atan2(-to.x, -to.z)
		await get_tree().physics_frame
		still = still + 1 if player.global_position.distance_to(last) < 0.003 else 0
		last = player.global_position
		if still > 30:
			break
	Input.action_release("move_forward")
	await _frames(10)
	return {"ok": reached == way.size(), "reached": reached, "end": lane.to_local(player.global_position)}


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _check(label: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		failures += 1
