extends Node3D
## The candle lane set (docs/superpowers/plans/2026-10-23-candle-lane.md): quick checks, headless with --fixed-fps 60.

const LANE := preload("res://maps/candle_lane.tscn")
## How far a person's body reaches from its feet, any way (m).
const BODY := 0.35

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
	await _crowding()
	await _vents()
	await _nahual_ways()
	await _wisps()
	await _people()
	await _pockets()
	await _crowd_of_shades()
	await _landmarks()
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
	# (Through the lane's own keys, as F2 and F3 are pressed in it: they reach the shop.)
	var meshes: Array = shop.find_children("*", "MeshInstance3D", true, false)
	var before := meshes.map(func(m): return [m.material_override, m.get_surface_override_material(0)])
	lane.set_form(true)
	var formed: bool = shop.get("_form") == true
	lane.set_form(false)
	var after := meshes.map(func(m): return [m.material_override, m.get_surface_override_material(0)])
	lane.set_decals(false)
	var hidden: bool = shop.decals.all(func(d): return not d.visible)
	lane.set_decals(true)
	_check("C5 the shop's keys work through the lane: F2 forms it and gives back every material, F3 hides and restores its decals",
		formed and before == after and hidden and shop.decals.all(func(d): return d.visible),
		"formed %s materials same %s decals %s" % [formed, before == after, hidden])


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


## The revision after the first look: the candles massed, the pipes' works, the vents and the culvert; and nothing of
## the bay left where the lane moved it.
func _crowding() -> void:
	var wicks: Array = lane.get("candle_wicks") if lane.get("candle_wicks") != null else []
	var masses: Array = lane.find_children("candle_mass*", "MeshInstance3D", false, false)
	var lit := masses.filter(func(m): return lane.find_children("votives_%s" % m.name, "Node3D", false, false).size() == 1)
	var at_niche: bool = masses.any(func(m): return (m as Node3D).position.distance_to(lane.places["niche"]) < 0.6)
	_check("L1 the candles mass: seventy and more on the ledges, four masses on the floor each alight, one under her niche",
		wicks.size() >= 70 and masses.size() == 4 and lit.size() == 4 and at_niche,
		"ledge wicks %d masses %d lit %d at niche %s" % [wicks.size(), masses.size(), lit.size(), at_niche])

	# The works on their mains: the gauge's riser on the water main, the meter's tee on the gas line, each hood's drop
	# off the air line; the hoods and culvert at the walls' feet.
	var on_main := func(kind: String, main_kind: String) -> bool:
		var piece: Node3D = lane.find_children(kind + "*", "MeshInstance3D", false, false).front() if not lane.find_children(kind + "*", "MeshInstance3D", false, false).is_empty() else null
		if piece == null:
			return false
		for main: MeshInstance3D in lane.services:
			var box: AABB = main.global_transform * main.get_aabb()
			if String(main.get_meta("kind", "")) == main_kind and box.position.x < piece.position.x and box.end.x > piece.position.x \
					and absf(box.get_center().z - piece.position.z) < 0.5:
				return true
		return false
	var hoods: Array = lane.find_children("air_branch*", "MeshInstance3D", false, false)
	var hoods_on: bool = hoods.size() >= 2 and hoods.all(func(h):
		for main: MeshInstance3D in lane.services:
			var box: AABB = main.global_transform * main.get_aabb()
			if String(main.get_meta("kind", "")) == "pipe_blue_4" and box.position.x < h.position.x and box.end.x > h.position.x:
				return true
		return false)
	var culvert: Node3D = lane.get_node_or_null("culvert")
	# Nothing of the bay's far wall left in the shopfront's span (its tablet, bills, splashes), and her niche's soot
	# where her niche is.
	var in_front := []
	for n: Node in lane.get_children():
		if (n is Decal or String(n.name).begins_with("name_tablet")) and n.global_position.z > lane.FAR_WALL - 0.3 \
				and n.global_position.x > lane.SHOP_FRONT.x - 0.3 and n.global_position.x < lane.SHOP_FRONT.y + 0.3:
			in_front.append(String(n.name))
	var soot: Node3D = lane.get_node_or_null("decal_soot_niche")
	var soot_ok: bool = soot != null and Vector2(soot.position.x, soot.position.z).distance_to(
		Vector2(lane.places["niche"].x, lane.places["niche"].z)) < 0.3
	_check("L2 the pipes' works stand on their mains, the hoods at the air line's feet, the culvert in the far wall; nothing of the bay left behind the shopfront, her soot over her niche",
		on_main.call("main_gauge", "pipe_green_4") and on_main.call("gas_meter", "pipe_ochre_4") and hoods_on
		and culvert != null and absf(culvert.position.z - lane.FAR_WALL) < 0.05 and in_front.is_empty() and soot_ok,
		"gauge %s meter %s hoods %d on %s culvert %s in front %s soot %s" % [on_main.call("main_gauge", "pipe_green_4"),
			on_main.call("gas_meter", "pipe_ochre_4"), hoods.size(), hoods_on, culvert != null, in_front, soot_ok])


## The ánimas come up by the vents too: each way up its own kind (the hood by the mouth small and shy, the one mid-lane
## hungry, the old grille's big lurkers), from the face of a hood or grille on the wall.
func _vents() -> void:
	var sources: Array = lane.get("vent_souls") if lane.get("vent_souls") != null else []
	var at_vents := sources.all(func(s):
		var by := false
		for kind in ["air_branch", "vent_grille"]:
			for piece: Node3D in lane.find_children(kind + "*", "MeshInstance3D", false, false):
				by = by or Vector2(piece.position.x, piece.position.z).distance_to(Vector2(s.position.x, s.position.z)) < 0.3
		return by and s.mouth == "wall")
	var means: Array = sources.map(func(s): return s._souls.reduce(func(a, x): return a + float(x["size"]), 0.0) / s.count)
	var kinds: Array = sources.map(func(s): return s.tempers.keys())
	var apart: bool = means.size() == 3 and means[0] < means[1] and means[1] < means[2] and "shy" in kinds[0] \
		and "hungry" in kinds[1] and kinds[2] == ["lurker"]
	_check("L3 the ánimas come up by the vents too, three more ways, each its own kind and size",
		sources.size() == 3 and at_vents and apart, "sources %d at vents %s sizes %s kinds %s" % [sources.size(), at_vents, means, kinds])

	# Out of a wall's grille they stay in front of the wall: wandering with no candle about (any way round it), or
	# flinching from someone stood against the wall.
	var souls: Node3D = (load("res://scripts/Visual/Animas.gd") as GDScript).new()
	souls.mouth = "wall"
	souls.lanes = PackedFloat32Array([0.25, 0.45])
	souls.count = 4
	souls.want_out = 4
	souls.seed = 5
	souls.candles = PackedVector3Array()
	var someone := Node3D.new()
	add_child(someone)
	someone.global_position = Vector3(60.0, 0.0, 60.0)
	souls.flee_from = someone
	add_child(souls)
	souls.global_position = Vector3(40.0, 0.0, 40.0)
	var behind := []
	for k in 120:
		souls.rise_now()
		await _frames(10)
		for i in souls.count:
			var state: String = souls.state_of(i)
			var at: Vector3 = souls._souls[i]["at"]
			if state in ["seeking", "warming", "straining", "pleading", "escorting", "hiding"] and at.z < 0.0:
				behind.append("%s %.2f" % [state, at.z])
	someone.global_position = souls.to_global(Vector3(0.0, 0.0, 0.4))
	var flinched: Vector3 = souls._flinch(Vector3(0.0, 0.8, 0.1))
	souls.queue_free()
	someone.queue_free()
	_check("L4 a wall's ánimas stay in front of their wall, wandering or flinching",
		behind.is_empty() and flinched.z >= 0.0, "behind %d %s; flinched to %s" % [behind.size(), behind.slice(0, 4), flinched])


## The nahual travels the works: gone from one haunt, back at another out of sight; while it is away its eyes look
## out of the culvert, and close when someone comes near, or when it is back.
func _nahual_ways() -> void:
	var nahual: Node3D = lane.get("nahual")
	var eyes: Node3D = lane.get("culvert_eyes")
	var haunts: Array = nahual.haunts if nahual != null else []
	var camera := get_viewport().get_camera_3d()
	var left: Vector3 = nahual.position if nahual != null else Vector3.ZERO
	var elsewhere := false
	var unseen := true
	if nahual != null and haunts.size() >= 3:
		nahual._go()
		nahual.set("_back_in", 0.0)
		await _frames(3)
		elsewhere = nahual.visible and nahual.position.distance_to(left) > 0.5 \
			and haunts.any(func(h): return Vector3(h.x, h.y, h.z).distance_to(nahual.position) < 0.01)
		unseen = camera == null or not camera.is_position_in_frustum(nahual.global_position + Vector3(0.0, 0.6, 0.0))
	_check("N1 the nahual comes back at another of its haunts, out of sight, never where it left",
		haunts.size() >= 3 and elsewhere and unseen, "haunts %d elsewhere %s unseen %s" % [haunts.size(), elsewhere, unseen])

	var opened := false
	var closed_near := false
	var closed_back := false
	if nahual != null and eyes != null:
		var player: Node3D = lane.get("player")
		player.global_position = eyes.global_position + Vector3(6.0, 0.0, -2.5)
		nahual._go()
		nahual.set("_back_in", 1000.0)
		eyes.set("_want", true)
		eyes.set("_next", 30.0)
		await _frames(30)
		opened = eyes.open > 0.99 and eyes.eyes.all(func(e): return e.visible)
		player.global_position = eyes.global_position + Vector3(0.0, 0.0, -1.2)
		await _frames(30)
		closed_near = eyes.open < 0.01
		player.global_position = eyes.global_position + Vector3(6.0, 0.0, -2.5)
		nahual.appear()
		await _frames(30)
		closed_back = eyes.open < 0.01
	_check("N2 while it is away its eyes open in the culvert's dark; they close when someone comes near, and when it is back",
		opened and closed_near and closed_back, "opened %s closed near %s closed when back %s" % [opened, closed_near, closed_back])


## Now and then a wisp of their warmth slips out of a vent or the drain and is drawn along the lane into a flame:
## from where they come up, into a candle, a few at most at once, and none left when it is done.
func _wisps() -> void:
	var wisps: Node3D = lane.get("wisps")
	var from_vent := false
	var into_flame := false
	var most := 0
	if wisps != null:
		wisps.next_in = 0.0
		for f in 1200:
			await get_tree().process_frame
			most = maxi(most, wisps.flying())
			for w: Dictionary in wisps.flights:
				if w["t"] < 0.05:
					from_vent = from_vent or Array(wisps.sources).any(func(s): return s.distance_to(w["head"]) < 0.4)
				if w["t"] > 0.97:
					into_flame = into_flame or Array(wisps.targets).any(func(c): return c.distance_to(w["head"]) < 0.3)
	_check("W1 wisps slip out of the vents and the drain and are drawn into the candles' flames, a few at most at once",
		wisps != null and from_vent and into_flame and most >= 1 and most <= wisps.AT_ONCE,
		"from a vent %s into a flame %s most at once %d" % [from_vent, into_flame, most])


## Task 7: the people, black cut-outs in their pockets, each side-on to the way and clear of it.
func _people() -> void:
	var people: Array = lane.get("people") if lane.get("people") != null else []
	var middle: float = (lane.BACK_WALL + lane.FAR_WALL) / 2.0
	var stall_x: float = (lane.stall as Node3D).position.x if lane.stall != null else 0.0
	var pockets := {"stall": [], "ledges": [], "mouth": [], "arch": [], "niche": []}
	for p: Node3D in people:
		var at := p.position
		var pose: String = p.get_meta("pose", "")
		if absf(at.x - stall_x) < 3.0:
			pockets["stall"].append(pose)
		if at.x > 9.0:
			pockets["ledges"].append(pose)
		if at.x < -13.0:
			pockets["mouth"].append(pose)
		if at.x > lane.SHOP_FRONT.x and at.x < lane.SHOP_FRONT.y and at.z > middle:
			pockets["arch"].append(pose)
		if at.distance_to(lane.places["niche"]) < 2.0:
			pockets["niche"].append(pose)
	pockets["stall"].sort()
	_check("C12 people stand in their pockets: two at the stall (bargaining, waiting, moving), two kneeling at the ledges; none standing at his arch, the niche or the mouth (the mouth's people walk)",
		pockets["stall"] == ["idle_waiting", "talk_bargaining"] and pockets["ledges"].size() == 2
		and pockets["ledges"].all(func(s): return s.begins_with("kneeling")) and pockets["mouth"].is_empty()
		and pockets["arch"].is_empty() and pockets["niche"].is_empty(),
		"%s" % [pockets])

	# Side-on to the way (its face toward the walking line down the lane's middle), on the floor, clear of the way.
	var wrong := []
	for p: MeshInstance3D in people:
		var box: AABB = p.global_transform * p.get_aabb()
		var line := Vector3(clampf(p.global_position.x, -lane.LANE_HALF, lane.LANE_HALF), p.global_position.y, middle)
		var to_line := line - p.global_position
		to_line.y = 0.0
		var normal := p.global_basis.z
		normal.y = 0.0
		var faces := to_line.length() < 0.01 or rad_to_deg(normal.angle_to(to_line)) <= 60.0
		var floored := absf(box.position.y) <= 0.01
		# (Its body, not the clear card round it: within BODY of its feet.)
		var clear := absf(p.position.z - middle) - BODY >= 0.55
		if not (faces and floored and clear):
			wrong.append("%s faces %s floored %s clear %s" % [p.get_meta("pose", ""), faces, floored, clear])
	_check("C13 every silhouette faces within 60° of the nearest point of the lane's walking line, stands on the floor (foot within 1 cm), and leaves the 1.1 m way clear",
		people.size() == 4 and wrong.is_empty(), "people %d wrong %s" % [people.size(), wrong])

	# Seen down the lane they are never edge-on: each turns toward the eye, never more than TURN from where it stands.
	var eye := Camera3D.new()
	add_child(eye)
	eye.make_current()
	var thinnest := INF
	var most_turned := 0.0
	for spot in [Vector3(-16.0, 1.6, 1.1), Vector3(16.0, 1.6, 1.1), Vector3(0.0, 1.6, 1.1)]:
		eye.global_position = spot
		await _frames(2)
		for p: MeshInstance3D in people:
			var to_eye := eye.global_position - p.global_position
			to_eye.y = 0.0
			var normal := p.global_basis.z
			normal.y = 0.0
			if to_eye.length() > 3.0:
				thinnest = minf(thinnest, absf(normal.normalized().dot(to_eye.normalized())))
			most_turned = maxf(most_turned, rad_to_deg(absf(wrapf(p.rotation.y - float(p.get("rest_yaw")), -PI, PI))))
	eye.queue_free()
	_check("C14 seen down the lane, no silhouette shows edge-on: each turns toward the eye, never more than 55° from where it stands",
		thinnest > 0.5 and most_turned <= 55.5, "thinnest %.2f most turned %.1f°" % [thinnest, most_turned])

	# Shades, not paper: each drawn in the shade's ink, fraying into its smoke, here in full.
	var shaded := people.filter(func(p):
		var look := (p as MeshInstance3D).mesh.surface_get_material(0) as ShaderMaterial
		return look != null and look.shader.resource_path.ends_with("shade_cutout.gdshader") \
			and look.get_shader_parameter(&"noise") != null and is_equal_approx(float(look.get_shader_parameter(&"presence")), 1.0))
	_check("C15 the people are shades: Mignola's ink fraying into climbing smoke, their feet lost in mist",
		people.size() == 4 and shaded.size() == 4, "shaded %d of %d" % [shaded.size(), people.size()])

	# The standing pair at her stall move: their frames change by the clock.
	var stirred := 0
	var was := people.map(func(p): return p.frame)
	await _frames(90)
	for i in people.size():
		if not people[i].loop.is_empty() and people[i].frame != was[i]:
			stirred += 1
	_check("C19 the pair at her stall move: her hands as she bargains, his weight as he waits, their frames turning with the clock",
		stirred == 2, "moving %d of 2" % stirred)


## Task 8: the walk's pockets of loud and quiet, made with light and (marked, silent) sound.
func _pockets() -> void:
	var pockets: Array = lane.get("pockets") if lane.get("pockets") != null else []
	# (Chapel to mouth: from the highest plan x down.)
	var order := pockets.duplicate()
	order.sort_custom(func(a, b): return a["x"].y > b["x"].y)
	var walk := order.map(func(p): return "%s %s" % [p["name"], "loud" if p["loud"] else "quiet"])
	_check("C16 the pockets alternate along the lane, chapel to mouth: quiet, quiet (arch), loud (stall), quiet (niche), loud (mouth)",
		walk == ["chapel quiet", "arch quiet", "stall loud", "niche quiet", "mouth loud"], "%s" % [walk])

	# Each pocket's light at eye height in the lane's middle: what lights it most (its colour), and how much in all.
	var middle: float = (lane.BACK_WALL + lane.FAR_WALL) / 2.0
	var seen := {}
	for p: Dictionary in order:
		var at := lane.to_global(Vector3((p["x"].x + p["x"].y) / 2.0 - lane.PLAN_ORIGIN.x, 1.6, middle))
		var most := 0.0
		var colour := Color.BLACK
		var total := 0.0
		for light: OmniLight3D in lane.find_children("*", "OmniLight3D", true, false):
			if not light.is_visible_in_tree() or light.light_energy <= 0.0:
				continue
			var d := light.global_position.distance_to(at)
			var e := light.light_energy * pow(maxf(0.0, 1.0 - d / light.omni_range), 2.0)
			total += e
			if e > most:
				most = e
				colour = light.light_color
		seen[p["name"]] = [colour, total]
	var apart := []
	for i in order.size():
		if not order[i]["loud"]:
			continue
		for j in [i - 1, i + 1]:
			if j < 0 or j >= order.size() or order[j]["loud"]:
				continue
			var a: Array = seen[order[i]["name"]]
			var b: Array = seen[order[j]["name"]]
			var hue := absf(a[0].h - b[0].h) * 360.0
			hue = minf(hue, 360.0 - hue)
			var bright := absf(a[1] - b[1]) / maxf(maxf(a[1], b[1]), 0.001)
			if hue < 30.0 or bright < 0.25:
				apart.append("%s/%s hue %.0f° brightness %.2f" % [order[i]["name"], order[j]["name"], hue, bright])
	_check("C17 a loud pocket is lit by a different light from its quiet neighbours: neon or bulb against candle (hues ≥ 30° apart) and its brightness at 1.6 m differs",
		pockets.size() == 5 and apart.is_empty(), "too alike %s; %s" % [apart, seen])

	# Marked sound: every pocket's emitters named for what will sound there, all silent; nothing of the bay's rejected
	# sounds playing in the lane (the shop's own are its).
	var empty := pockets.filter(func(p): return p["emitters"].is_empty()).map(func(p): return p["name"])
	# (Found first: a check that finds no players proves nothing. Then again after both trains have passed by, which
	# load the bay's sounds of their own.)
	var players := _players()
	var sounding := _sounding(players)
	if lane.train != null:
		lane.train.began.emit()
		lane.train.peaked.emit()
	if lane.dark_train != null:
		lane.dark_train.began.emit()
		lane.dark_train.peaked.emit()
	await _frames(5)
	sounding += _sounding(_players())
	_check("C18 every pocket has its emitters, all silent (no stream), and none of the bay's sounds plays in the lane, even after the trains",
		pockets.size() == 5 and empty.is_empty() and players.size() >= 6 and sounding.is_empty(),
		"without emitters %s; players %d; sounding %s" % [empty, players.size(), sounding.slice(0, 6)])


## Every sound player in the lane but the shop's (its sounds are its own).
## The lane's sound players, but the shop's (its own) and the ánimas' voices (the user's pick, Oct 24).
func _players() -> Array:
	var found := lane.find_children("*", "AudioStreamPlayer", true, false) + lane.find_children("*", "AudioStreamPlayer3D", true, false)
	var voices := []
	for souls in lane.find_children("*", "Node3D", true, false).filter(func(n): return n.get_script() == lane.AnimasScript):
		voices.append_array(souls.voices)
	return found.filter(func(p): return (lane.shop == null or not lane.shop.is_ancestor_of(p)) and not p in voices)


func _sounding(players: Array) -> Array:
	return players.filter(func(p): return p.get("stream") != null or p.call("is_playing")).map(func(p): return String(p.name))


## The crowd coming and going: shades forming, walking their routes with their feet stepping, coming apart; busy at the
## mouth, rare at the chapel's end; a surge after the dark train; apart when walked into.
func _crowd_of_shades() -> void:
	var crowd: Node3D = lane.get("crowd_of_shades")
	var player: Node3D = lane.get("player")
	player.global_position = lane.to_global(Vector3(10.0, 1.05, -1.5))
	var formed := false
	var stepped := false
	var gone := 0
	var at_mouth := 0.0
	var at_chapel := 0.0
	var most := 0
	var off_way := []
	var started := 0
	if crowd != null:
		var seen := {}
		for f in 3600:
			await get_tree().process_frame
			most = maxi(most, crowd.walkers.size())
			for w: Dictionary in crowd.walkers:
				var shade: MeshInstance3D = w["shade"]
				var id := shade.get_instance_id()
				if not seen.has(id):
					seen[id] = {"presence": shade.presence, "frame": shade.frame, "rose": false}
				var s: Dictionary = seen[id]
				if shade.presence >= 0.999 and s["presence"] < 0.05:
					s["rose"] = true
				formed = formed or s["rose"]
				stepped = stepped or shade.frame != s["frame"]
				var x: float = lane.plan_point(shade.position).x
				if x < 0.8:
					at_mouth += 1.0 / 60.0
				elif x > 23.0:
					at_chapel += 1.0 / 60.0
				# (In the lane, the way down its middle: clear of its walls' pieces and its standing people.)
				if absf(shade.position.x) < lane.LANE_HALF and (shade.position.z < -0.8 or shade.position.z > 2.8):
					off_way.append("%s %.1f,%.1f" % [w["route"]["name"], shade.position.x, shade.position.z])
			for id in seen.keys():
				if not crowd.walkers.any(func(w): return w["shade"].get_instance_id() == id) and seen[id]["presence"] >= 0.0:
					gone += 1
					seen[id]["presence"] = -1.0
		for n in crowd.started.values():
			started += n
	_check("C20 the crowd comes and goes: shades form out of their mist, walk their routes with their feet stepping, come apart; a dozen at most at once",
		crowd != null and formed and stepped and gone >= 5 and most >= 3 and most <= crowd.POOL + crowd.SURGE.x and off_way.is_empty(),
		"formed %s stepped %s gone %d most at once %d started %d off the way %s" % [formed, stepped, gone, most, started, off_way.slice(0, 3)])
	_check("C21 thick at the mouth, rare at the chapel's end (shade-seconds over a minute)",
		at_mouth > 4.0 * maxf(at_chapel, 1.0), "mouth %.0f s chapel %.0f s" % [at_mouth, at_chapel])

	# A surge after the dark train; a shade walked into comes apart.
	var surged := 0
	var scattered := 0
	var after_company := 0
	if crowd != null and lane.dark_train != null:
		# (The Company's own trains bring no surge: only the dark train, passing.)
		await _frames(300)
		var was_quiet: int = crowd.started["into_lane"]
		lane.train.began.emit()
		lane.train.peaked.emit()
		await _frames(60)
		after_company = crowd.started["into_lane"] - was_quiet
		var before: int = crowd.started["into_lane"]
		lane.dark_train.peaked.emit()
		await _frames(300)
		surged = crowd.started["into_lane"] - before
		var walker: Dictionary = crowd.start("into_lane", true)
		if not walker.is_empty():
			await _frames(30)
			var was: int = crowd.scattered
			player.global_position = walker["shade"].global_position + Vector3(0.0, 1.05, 0.0)
			await _frames(45)
			scattered = crowd.scattered - was
	_check("C22 after the dark train a surge pours in from the mouth (none after the Company's); walked into, a shade comes apart",
		surged >= 4 and after_company <= 1 and scattered >= 1,
		"surged %d after the Company's train %d scattered %d" % [surged, after_company, scattered])


## The landmarks (docs/superpowers/plans/2026-10-25-lane-landmarks.md): what makes her stall and his shop read from the
## Pasaje, placed, clear of every head over the walk, and greyed by the form light like the rest.
func _landmarks() -> void:
	var marks: Dictionary = lane.get("landmarks") if lane.get("landmarks") != null else {}
	var garland: MeshInstance3D = marks.get("garland")
	var low := []
	if garland != null:
		for s in garland.mesh.get_surface_count():
			for v: Vector3 in garland.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
				var p := garland.transform * v
				if p.z >= 0.2 and p.z <= 2.6 and p.y < 2.6:
					low.append(p)
	_check("L5 her garland hangs across the walk, clear of every head", garland != null and low.is_empty(),
		"garland %s, %d points under 2.6 m over the walk %s" % [garland != null, low.size(), low.slice(0, 2)])

	# The form light greys them and gives their materials back.
	var before := {}
	for mesh: MeshInstance3D in marks.values():
		before[mesh] = mesh.material_override
	lane.set_form(true)
	var greyed: bool = not marks.is_empty() and marks.values().all(func(m): return m.material_override == lane.form_material)
	lane.set_form(false)
	var restored: bool = marks.values().all(func(m): return m.material_override == before[m])
	_check("L5b F2 greys the landmarks and gives back their materials", greyed and restored,
		"%d marks, greyed %s, restored %s" % [marks.size(), greyed, restored])

	# Her tin heart: over every head where it hangs over the walk, clear of her customers, turning on its hook.
	var heart: MeshInstance3D = marks.get("milagro_heart")
	var pivot: Node3D = lane.get("milagro_pivot")
	var heart_low := INF
	var near_customer := INF
	if heart != null:
		var box: AABB = lane.global_transform.affine_inverse() * heart.global_transform * heart.get_aabb()
		if box.end.z >= 0.2:
			heart_low = box.position.y
		for customer in [Vector2(0.65, 0.6), Vector2(1.85, 0.6)]:
			var nearest := Vector2(clampf(customer.x, box.position.x, box.end.x), clampf(customer.y, box.position.z, box.end.z))
			near_customer = minf(near_customer, nearest.distance_to(customer))
	_check("L6 the tin heart hangs over her pitch, above every head over the walk and clear of her customers",
		heart != null and marks.has("milagro_bracket") and heart_low >= 2.1 and near_customer >= 0.4,
		"heart %s, lowest %.2f m, %.2f m from a customer" % [heart != null, heart_low, near_customer])
	var turned := 0.0
	if pivot != null:
		var was := pivot.rotation.y
		await _frames(120)
		turned = absf(pivot.rotation.y - was)
	_check("L6b it turns on its hook", turned > 0.05, "turned %.3f rad in 2 s" % turned)
	var votive: Node3D = lane.get("milagro_flame")
	var lit := false
	if votive != null and heart != null:
		var light: OmniLight3D = votive.find_children("*", "OmniLight3D", true, false).front() if not votive.find_children("*", "OmniLight3D", true, false).is_empty() else null
		lit = light != null and light.global_position.distance_to(heart.global_position) <= light.omni_range * 0.5
	_check("L6c her votive burns under the heart and lights it", votive != null and lit,
		"votive %s, lights the heart %s" % [votive != null, lit])

	# His red lantern over the arch: the lane's only red light (the shop's own aside), sagging with the train.
	var lantern_light: OmniLight3D = lane.get("lantern_light")
	var reds := []
	for light: Light3D in lane.find_children("*", "Light3D", true, false):
		if lane.shop != null and lane.shop.is_ancestor_of(light):
			continue
		var hue := light.light_color.h * 360.0
		if (hue >= 350.0 or hue <= 10.0) and light.light_color.s > 0.45:
			reds.append(String(light.name))
	var lantern_hue := lantern_light.light_color.h * 360.0 if lantern_light != null else -1.0
	_check("L7 his red lantern hangs over the arch, the lane's only red light",
		marks.has("red_lantern") and lantern_light != null and (lantern_hue >= 350.0 or lantern_hue <= 10.0) and reds.size() == 1,
		"lantern %s, its hue %.0f°, red lights %s" % [marks.has("red_lantern"), lantern_hue, reds])
	var sagged := false
	if lantern_light != null and lane.train != null:
		var full: float = lantern_light.light_energy
		lane.train.start_pass()
		for i in 1200:
			await _frames(1)
			if lantern_light.light_energy < full * 0.95:
				sagged = true
				break
	_check("L7b it sags with the train", sagged, "sagged %s" % sagged)


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
