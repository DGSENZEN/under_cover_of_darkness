extends Node3D
## The Metro Underground's greybox (maps/metro, the Metro Underground part 1
## plan, Task 15): loaded, the player arriving on the north platform, then
## the real player walking the spine up to a kiosk's exit, and down into the
## market and the old passages, along the plan's own shortest walks
## (plan.json "walks", tools/level/layouts/metro/walk.py). Headless:
##   Godot --headless --fixed-fps 60 --path . res://tests/metro_test.tscn

const MAP := preload("res://maps/metro.tscn")
const Layers := preload("res://scripts/Visual/Layers.gd")
## How near a waypoint counts as reached (m, across).
const REACHED := 0.6
## Frames a leg may take before it counts as stuck.
const LEG_FRAMES := 900


## Every error the engine reports while the suite runs (M6).
class Errors extends Logger:
	var lines: Array[String] = []
	var _lock := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool,
			error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return

		_lock.lock()
		lines.append("%s %s (%s:%d %s)" % [code, rationale, file, line, function])
		_lock.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass


var results: Array[String] = []
var map: Node3D
var errors := Errors.new()


func _ready() -> void:
	OS.add_logger(errors)
	await _run()
	OS.remove_logger(errors)

	print("\n==== RESULTS ====")
	for r in results:
		print(r)

	get_tree().quit()


func _run() -> void:
	map = MAP.instantiate()
	add_child(map)
	await _frames(20)

	# M1 the player stands on the north platform's floor at the arrival
	var arrival: Vector3 = map.spawn_point()
	var platform := _rect("platform_n")
	var stand: Vector3 = map.player.global_position
	_check("M1 the map loads and the player stands on the platform (-14) at the arrival",
		map.player.is_on_floor() and absf(stand.y - 1.05 + 14.0) < 0.1 and platform.has_point(Vector2(stand.x, stand.z))
		and Vector2(stand.x - arrival.x, stand.z - arrival.z).length() < 0.3,
		"stands %s, arrival %s, on floor %s" % [stand, arrival, map.player.is_on_floor()])

	# M2 the spine: from the arrival to the kiosk exit, never dropping below a floor
	var spine := await _tour(map.plan["walks"]["spine"])
	var at_exit := false

	for m in map.landmarks("exit_zocalo"):
		var end: Vector3 = spine["end"]
		at_exit = at_exit or (Vector2(end.x - m["at"][0], end.z - m["at"][2]).length() < 2.0
			and absf(end.y - 1.05 - m["at"][1]) < 0.3)
	_check("M2 the player walks the spine from the arrival up to a kiosk's exit", spine["ok"] and at_exit,
		"%s" % [spine])

	# M3 from the arrival again: into the market, and down into the old passages
	var market := await _tour(map.plan["walks"]["market"], true)
	var old := await _tour(map.plan["walks"]["old"], true)
	_check("M3 the player walks into the market (layer 2) and the old passages (layer 3)",
		market["ok"] and old["ok"] and _layer_at(market["end"]) == 2 and _layer_at(old["end"]) == 3,
		"market %s (layer %d), old %s (layer %d)" % [market, _layer_at(market["end"]), old, _layer_at(old["end"])])

	# M4 every climb is a ladder the player can take hold of
	var climbs: int = map.plan["routes"].filter(func(r): return r["kind"] == "climb").size()
	var volumes: int = map.greybox.find_children("*", "Area3D", true, false).filter(func(a): return a is ClimbVolume).size()
	_check("M4 every climb is a ladder", climbs >= 4 and volumes == climbs, "%d climbs, %d ladders" % [climbs, volumes])

	# M5 the pixel grid is off (Track A's default)
	_check("M5 the pixel grid is off", Retro.virtual_height == 0, "virtual_height %d" % Retro.virtual_height)

	await _sets()
	await _judder()

	# M6 nothing reported an error
	await _frames(2)
	_check("M6 no engine errors", errors.lines.is_empty(), "%s" % [errors.lines.slice(0, 4)])


## M20: nothing seen judders: the project interpolates physics, so a visual drawn interpolated but moved between
## physics ticks (in _process) stutters against the interpolated camera. With the physics at 20 ticks a second under
## 60 frames, no visible interpolated visual may move on a frame with no tick before it, wherever the player stands
## (the Pasaje, the candle lane, the corridors either side of the Pasaje). (tests/diag_judder.tscn names them all.)
func _judder() -> void:
	var found := {}
	var ticks_were := Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = 20
	for spot in [Vector3(-9.0, -11.0, 70.0), Vector3(-2.0, -11.0, 75.45), Vector3(19.0, -11.0, 78.0),
			Vector3(-10.0, -11.0, 40.0), Vector3(-9.0, -11.0, 105.0)]:
		map.player.global_position = spot + Vector3(0.0, 1.05, 0.0)
		await _frames(30)
		var was := {}
		for node: Node in map.find_children("*", "VisualInstance3D", true, false):
			was[node] = (node as Node3D).global_transform
		var ticks := Engine.get_physics_frames()
		for i in 60:
			await get_tree().process_frame
			var ticked := Engine.get_physics_frames() != ticks
			ticks = Engine.get_physics_frames()
			for key in was.keys():
				# (Some go while watched: a crowd's shade leaving, a spark.)
				if not is_instance_valid(key):
					was.erase(key)
					continue
				var node := key as Node3D
				var now := node.global_transform
				if not ticked and node.is_visible_in_tree() and node.is_physics_interpolated_and_enabled() \
						and not now.is_equal_approx(was[node]):
					found[String(map.get_path_to(node))] = true
				was[node] = now
	Engine.physics_ticks_per_second = ticks_were
	map.player.global_position = map.spawn_point() + Vector3(0.0, 1.05, 0.0)
	await _frames(10)
	_check("M20 nothing seen judders: no interpolated visual moved between physics ticks", found.is_empty(),
		"%d: %s" % [found.size(), found.keys().slice(0, 6)])


## The candle lane set into the map (docs/superpowers/plans/2026-10-23-candle-lane.md, Task 9): in its place, the
## greybox gone from its spaces only, no stub of its own, and walked through from the Pasaje to the shop's desk and on
## through the chapel to lane_se, the floors level across both seams.
func _sets() -> void:
	var lane: Node3D = map.get_node_or_null("candle_lane")
	var names: Array = map.greybox.get_children().map(func(n): return String(n.name))
	var placed: bool = lane != null and lane.position.is_equal_approx(lane.PLAN_ORIGIN)
	var replaced: bool = not names.any(func(n): return n.begins_with("candle_lane") or n.begins_with("librarian_shop")) \
		and names.any(func(n): return n.begins_with("pasaje")) and names.any(func(n): return n.begins_with("chapel"))
	_check("M7 the candle lane stands in its place, the greybox gone from its spaces and nowhere else",
		placed and replaced, "placed %s at %s; greybox %s" % [placed, lane.position if lane else null,
			names.filter(func(n): return n.contains("lane") or n.contains("shop") or n.contains("pasaje") or n.contains("chapel"))])

	# No stub: its own Pasaje and chapel glimpse hidden; none of its building standing out into the map's Pasaje or
	# chapel (its people and its smoke may walk there).
	var stub: Node3D = lane.get("stub") if lane else null
	var out_into := []
	if lane != null:
		for mesh: MeshInstance3D in lane.find_children("*", "MeshInstance3D", true, false):
			if not mesh.is_visible_in_tree() or mesh.mesh == null:
				continue
			var moving: bool = lane.crowd_of_shades != null and lane.crowd_of_shades.is_ancestor_of(mesh)
			var box: AABB = mesh.global_transform * mesh.get_aabb()
			if moving or box.size.length() < 0.6:
				continue
			if box.position.x < -4.0 - 0.5 or box.end.x > 29.6 + 0.5:
				out_into.append("%s %.1f..%.1f" % [mesh.name, box.position.x, box.end.x])
	_check("M8 no stub inside the Metro: the set's own Pasaje and chapel hidden, none of its building out in the map's spaces",
		stub != null and not stub.visible and out_into.is_empty(), "stub hidden %s; out %s" % [stub != null and not stub.visible, out_into.slice(0, 4)])

	# Walked: the Pasaje into the lane, to his desk; back out and on through the chapel into lane_se.
	var to_desk := await _tour([[-8.0, -11.0, 75.45], [-2.2, -11.0, 75.45], [17.8, -11.0, 74.85], [19.0, -11.0, 75.35],
		[19.0, -11.0, 78.35], [19.0, -11.0, 81.35], [19.0, -11.0, 82.75]], true)
	var through := await _tour([[19.0, -11.0, 82.75], [19.0, -11.0, 78.35], [19.0, -11.0, 75.35], [28.4, -11.0, 74.55],
		[31.0, -11.0, 74.55], [44.0, -11.0, 72.5], [47.0, -11.0, 72.5]])
	var in_se: bool = _rect("lane_se").has_point(Vector2(through["end"].x, through["end"].z))
	# The floors either side of each seam (the mouth's, the chapel doorway's) level.
	var seams := []
	for seam in [[Vector3(-4.4, -10.0, 75.45), Vector3(-3.6, -10.0, 75.45)], [Vector3(29.4, -10.0, 74.55), Vector3(30.3, -10.0, 74.55)]]:
		var a := _floor_below(seam[0])
		var b := _floor_below(seam[1])
		seams.append(absf(a - b))
	_check("M9 the player walks from the Pasaje into the lane, to the shop's desk, and through the chapel into lane_se",
		to_desk["ok"] and through["ok"] and in_se and seams.all(func(d): return d <= 0.01),
		"desk %s through %s in lane_se %s seams %s" % [to_desk, through, in_se, seams])

	await _set_in_place(lane)
	await _pasaje_in_place()
	_one_crowd()
	_pasaje_shows()
	await _station()


## The station set (docs/superpowers/plans/2026-10-30-metro-station.md, Task 3).
## M21: in its place, the greybox gone from its spaces and their flights only (the corridors, the market stairs and
## the siding still there).
## M22: walked from the arrival up the north stairwell into the hall, through the west bank's free lane out into the
## west corridor; across the paid hall out into the east corridor; down into the market stairs; down the south
## stairwell onto the south platform.
## M23: out of the pit: from the bed up each track's steps onto its platform.
func _station() -> void:
	var station: Node3D = map.get_node_or_null("metro_station")
	if station == null:
		_check("M21 the station in its place, the greybox gone from its spaces only", false, "no metro_station")
		return
	var taken: Array = station.SPACES + station.ROUTES_TAKEN
	var left: Array = map.greybox.get_children().map(func(n): return String(n.name))
	var gone := taken.filter(func(n): return left.has(n))
	var kept := ["corridor_w", "corridor_e", "market_stairs", "siding"].filter(func(n): return not left.has(n))
	# (Its seams to the lane's standard, as the Pasaje's: none of it in the map's other spaces, no face flush with a
	# greybox wall's.)
	var meshes: Array = station.find_children("*", "MeshInstance3D", true, false).filter(func(m):
		return m.is_visible_in_tree() and m.mesh != null)
	var into := _intrusions(meshes, map.SETS["metro_station"][1])
	var flush := _flush(meshes.filter(func(m): return m.mesh is BoxMesh or m.has_meta("built")))
	_check("M21 the station in its place, the greybox gone from its spaces only, its seams clean",
		station.position.is_equal_approx(station.PLAN_ORIGIN) and gone.is_empty() and kept.is_empty() \
			and into.is_empty() and flush.is_empty() and map.SETS["metro_station"][1] == taken,
		"at %s; still greybox %s; gone too %s; into %s; flush %s" % [station.position, gone, kept, into.slice(0, 4),
			flush.slice(0, 4)])

	var west := await _tour([[0, -14, -9], [-2, -14, -13], [-2, -14, -29.2], [-6, -14, -29.2], [-6, -14, -28.5],
		[-6, -8, -14], [-6, -8, -12.5], [-10, -8, -2], [-18, -8, -2], [-32, -8, 0]], true)
	var east := await _tour([[-10, -8, 2], [10, -8, 2], [18, -8, 2], [32, -8, 0]], true)
	var market := await _tour([[-6, -8, 4], [-10, -8, 12.5], [-10, -8, 14], [-10, -8.6, 16]], true)
	var south := await _tour([[2, -8, 6], [6, -8, 12.5], [6, -8, 14], [6, -14, 28.5], [6, -14, 29.2], [2, -14, 29.2],
		[2, -14, 13], [2, -14, 10]], true)
	_check("M22 walked from the arrival up into the hall, out into both corridors and the market stairs, down onto the south platform",
		west["ok"] and east["ok"] and market["ok"] and south["ok"],
		"west %s east %s market %s south %s" % [west, east, market, south])

	var north_up := await _tour([[-20, -15.2, -2.5], [49, -15.2, -2.5], [49, -15.2, -8.3], [48.5, -15.2, -8.3],
		[42.5, -14, -8.3], [40, -14, -10]], true)
	var south_up := await _tour([[20, -15.2, 2.5], [-49, -15.2, 2.5], [-49, -15.2, 8.3], [-48.5, -15.2, 8.3],
		[-42.5, -14, 8.3], [-40, -14, 10]], true)
	_check("M23 out of the pit: from the bed up each track's steps onto its platform", north_up["ok"] and south_up["ok"],
		"north %s south %s" % [north_up, south_up])
	# M24: nothing inside the car's envelope: no face the set draws (its meshes, each of its many pieces where it laid
	# them) and no light inside the box CAR wide by CAR.y tall over PAD_TOP, centred on each track, over x -50...50.
	var envelopes := []
	for z: float in station.TRACKS_Z:
		envelopes.append(AABB(Vector3(-50.0, float(station.PAD_TOP) + 0.01, z - station.CAR.x / 2.0 + 0.001),
			Vector3(100.0, station.CAR.y - 0.01, station.CAR.x - 0.002)))
	var inside := []
	for node in station.find_children("*", "GeometryInstance3D", true, false):
		if not (node as Node3D).is_visible_in_tree():
			continue
		var to_set: Transform3D = station.global_transform.affine_inverse() * (node as Node3D).global_transform
		# ([its mesh, where it is laid in the set's frame], each instance of many its own.)
		var drawn := []
		if node is MultiMeshInstance3D:
			var many := (node as MultiMeshInstance3D).multimesh
			if many == null or many.mesh == null:
				continue
			for t: Transform3D in node.get_meta("transforms", []):
				drawn.append([many.mesh, to_set * t])
		elif node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
			drawn.append([(node as MeshInstance3D).mesh, to_set])
		for piece: Array in drawn:
			var aabb: AABB = piece[1] * (piece[0] as Mesh).get_aabb()
			for envelope: AABB in envelopes:
				# (Its box first; then its faces, a frame round an opening only boxing the opening.)
				if envelope.intersects(aabb) and _faces_inside(piece[0], piece[1], envelope):
					inside.append("%s %s" % [node.name, aabb.get_center().snapped(Vector3.ONE * 0.1)])
	for light: Node in map.find_children("*", "Light3D", true, false):
		var at: Vector3 = station.to_local((light as Node3D).global_position)
		for envelope: AABB in envelopes:
			if envelope.has_point(at):
				inside.append("light %s %s" % [light.name, at.snapped(Vector3.ONE * 0.1)])
	_check("M24 nothing inside the car's envelope", inside.is_empty(), "%d: %s" % [inside.size(), inside.slice(0, 6)])
	# M25: the station lit by its own fittings: no plan lamp (the map's sodium glow at each sign and scene) stands in
	# its spaces.
	var in_station := []
	for lamp: OmniLight3D in map.lamps:
		var p := lamp.global_position
		for s in map.plan["spaces"]:
			if s["name"] in station.SPACES and Geometry2D.is_point_in_polygon(Vector2(p.x, p.z), _poly(s["polygon"])) \
					and p.y >= float(s["floor"]) - 0.01 and p.y <= float(s["floor"]) + float(s["height"]) + 0.01:
				in_station.append("%s in %s" % [lamp.name, s["name"]])
	_check("M25 the station lit by its own fittings, no plan lamp in its spaces", in_station.is_empty(), "%s" % [in_station])
	# M26: and no light of the map's beyond it reaches it through its walls or floors: none but its own lights its
	# levels' layers (the vaults' sodium lamp under the platforms turned their pit faces red).
	var station_layers: int = Layers.STATION_HALL | Layers.STATION_STAIRS | Layers.STATION_BELOW
	var through := []
	for light: Node in map.find_children("*", "Light3D", true, false):
		# (The player's own, which go where they go, light it as they light anything.)
		if not station.is_ancestor_of(light) and not map.player.is_ancestor_of(light) \
				and (light as Light3D).light_cull_mask & station_layers != 0:
			through.append(String(light.name))
	_check("M26 no light beyond the station lights it through its walls", through.is_empty(), "%d: %s" % [through.size(),
		through.slice(0, 6)])
	map.player.global_position = map.spawn_point() + Vector3(0.0, 1.05, 0.0)
	await _frames(10)


## Whether any face of `mesh`, laid by `at`, keeps an area inside `box` (each triangle clipped by its six planes).
func _faces_inside(mesh: Mesh, at: Transform3D, box: AABB) -> bool:
	var planes := [Plane(Vector3.RIGHT, box.end.x), Plane(Vector3.LEFT, -box.position.x), Plane(Vector3.UP, box.end.y),
		Plane(Vector3.DOWN, -box.position.y), Plane(Vector3.BACK, box.end.z), Plane(Vector3.FORWARD, -box.position.z)]
	var faces := mesh.get_faces()
	for i in range(0, faces.size(), 3):
		var kept := PackedVector3Array([at * faces[i], at * faces[i + 1], at * faces[i + 2]])
		for plane: Plane in planes:
			kept = Geometry3D.clip_polygon(kept, plane)
			if kept.size() < 3:
				break
		if kept.size() >= 3:
			var area := 0.0
			for k in range(1, kept.size() - 1):
				area += (kept[k] - kept[0]).cross(kept[k + 1] - kept[0]).length() / 2.0
			if area > 1e-6:
				return true
	return false


## The Pasaje set (docs/superpowers/plans/2026-10-26-pasaje-market.md): in its place, the greybox gone from its middle
## only; its seams to the lane's standard; walked from the market stairs down it into the lane.
## M17: everything the Pasaje set lights, sounds and shows stands in the map's Pasaje, at its floor's level (its crowd,
## which walks, excepted; and what is drawn in the world's frame).
func _pasaje_shows() -> void:
	var pasaje: Node3D = map.get_node_or_null("pasaje")
	if pasaje == null:
		_check("M17 everything the Pasaje lights, sounds and shows stands in the Pasaje", false, "no Pasaje")
		return
	var own: Rect2 = _rect("pasaje").grow(0.5)
	var crowd: Node3D = pasaje.get("crowd_of_shades")
	var strays := []
	for node: Node in pasaje.find_children("*", "VisualInstance3D", true, false) + pasaje.find_children("*", "AudioStreamPlayer3D", true, false):
		if (crowd != null and crowd.is_ancestor_of(node)) or not (node as Node3D).is_visible_in_tree():
			continue
		var drawn_in_world := false
		var up: Node = node
		while up != pasaje and up != null:
			drawn_in_world = drawn_in_world or (up is Node3D and up.top_level and up.global_transform.origin == Vector3.ZERO)
			up = up.get_parent()
		if drawn_in_world:
			continue
		var at: Vector3 = (node as Node3D).global_position
		if not own.has_point(Vector2(at.x, at.z)) or at.y < -11.5 or at.y > -11.0 + 5.5:
			strays.append("%s %s" % [node.name, at])
	_check("M17 everything the Pasaje lights, sounds and shows stands in the Pasaje", strays.is_empty(),
		"%d out: %s" % [strays.size(), strays.slice(0, 6)])


## M16: in the Metro the Pasaje walks its own crowd and the lane its own: no lane route runs in the Pasaje (but where
## into_lane begins and out_of_lane ends, at the mouth), and no Pasaje route enters the lane.
func _one_crowd() -> void:
	var lane: Node3D = map.get_node_or_null("candle_lane")
	var pasaje: Node3D = map.get_node_or_null("pasaje")
	var doubled := []
	if lane == null or pasaje == null or pasaje.get("crowd_of_shades") == null:
		_check("M16 no shades doubled where the lane and the Pasaje meet", false, "no lane, Pasaje or Pasaje crowd")
		return
	var inside := func(p: Vector3) -> bool:
		var at: Vector3 = pasaje.to_local(p)
		return absf(at.x) < pasaje.HALF_W - pasaje.WALL and absf(at.z) < pasaje.HALF_L
	for route: Dictionary in lane.crowd_of_shades.routes:
		var points: PackedVector3Array = route["points"]
		for i in points.size():
			var at: Vector3 = lane.crowd_of_shades.to_global(points[i])
			var end: bool = (route["name"] == "into_lane" and i == 0) or (route["name"] == "out_of_lane" and i == points.size() - 1)
			if inside.call(at) and not end:
				doubled.append("lane %s point %d" % [route["name"], i])
	for route: Dictionary in pasaje.crowd_of_shades.routes:
		for p: Vector3 in route["points"]:
			var at: Vector3 = pasaje.crowd_of_shades.to_global(p)
			if not inside.call(at):
				doubled.append("Pasaje %s at %s" % [route["name"], pasaje.to_local(at)])
	_check("M16 no shades doubled where the lane and the Pasaje meet", doubled.is_empty(), "%s" % [doubled])


func _pasaje_in_place() -> void:
	var pasaje: Node3D = map.get_node_or_null("pasaje")
	var names: Array = map.greybox.get_children().map(func(n): return String(n.name))
	var placed: bool = pasaje != null and pasaje.position.is_equal_approx(pasaje.PLAN_ORIGIN)
	_check("M14 the Pasaje stands in its place, the greybox gone from its middle only",
		placed and not "pasaje" in names and "pasaje_n" in names and "pasaje_s" in names,
		"placed %s; greybox %s" % [placed, names.filter(func(n): return n.begins_with("pasaje"))])

	var into := []
	var flush := []
	var sized := false
	if pasaje != null:
		var meshes: Array = pasaje.find_children("*", "MeshInstance3D", true, false).filter(func(m):
			return m.is_visible_in_tree() and m.mesh != null)
		into = _intrusions(meshes, map.SETS["pasaje"][1])
		flush = _flush(meshes.filter(func(m): return m.mesh is BoxMesh or m.has_meta("built")))
		# (The greybox's openings onto it as big as its own: the herb market's.)
		var herb: Dictionary = _gaps_onto("pasaje").get("herb_market", {})
		var own: Array = pasaje.OPENINGS["herb_market"]
		var wide := Vector2(herb["a"][0], herb["a"][1]).distance_to(Vector2(herb["b"][0], herb["b"][1])) if not herb.is_empty() else 0.0
		sized = not herb.is_empty() and absf(wide - (own[2] - own[1])) < 0.02 and absf(herb["y1"] - herb["y0"] - own[3]) < 0.02
	_check("M15 the Pasaje's seams: none of it in the map's other spaces, no face flush with a greybox wall's, its openings their own size",
		pasaje != null and into.is_empty() and flush.is_empty() and sized,
		"into %s; flush %s; herb opening sized %s" % [into.slice(0, 4), flush.slice(0, 4), sized])

	var down := await _tour([[-10.0, -11.0, 36.0], [-9.0, -11.0, 56.0], [-9.0, -11.0, 75.45], [-2.2, -11.0, 75.45]], true)
	_check("M9b the player walks from the market stairs down the Pasaje into the candle lane", down["ok"], "%s" % [down])


## The parts of `meshes` standing deeper than 6 cm in the map's spaces other than `own`.
func _intrusions(meshes: Array, own: Array) -> Array:
	var into := []
	for s in map.plan["spaces"]:
		if s["name"] in own:
			continue
		var r := _rect(s["name"])
		var room := AABB(Vector3(r.position.x, s["floor"], r.position.y), Vector3(r.size.x, s["height"], r.size.y))
		for mesh: MeshInstance3D in meshes:
			var box: AABB = mesh.global_transform * mesh.get_aabb()
			var cut := box.intersection(room)
			if cut.has_volume() and minf(cut.size.x, minf(cut.size.y, cut.size.z)) > 0.06:
				into.append("%s into %s %s" % [mesh.name, s["name"], cut.size])
	return into


## The greybox's faces the map builds (every set's spaces left out: none of their greybox stands).
func _built_faces() -> Array:
	var taken := []
	for set_name in map.SETS:
		taken += map.SETS[set_name][1]
	var faces := []
	var grey: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(map.GREYBOX))
	for g in grey["meshes"]:
		if not String(g["name"]) in taken:
			faces += g.get("faces", [])
	return faces


## The greybox's openings onto `space`, by the space they open from.
func _gaps_onto(space: String) -> Dictionary:
	var gaps := {}
	var grey: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(map.GREYBOX))
	for g in grey["meshes"]:
		for gap in g.get("gaps", []):
			if gap["to"] == space:
				gaps[g["name"]] = gap
	return gaps


## The faces of `built`'s boxes lying in the plane of a built greybox face, over it.
func _flush(built: Array) -> Array:
	var faces := _built_faces()
	var flush := []
	for mesh: MeshInstance3D in built:
		var box: AABB = mesh.global_transform * mesh.get_aabb()
		for f in faces:
			var n: Vector3 = _v(f["normal"]).abs()
			var axis := 0 if n.x > 0.9 else (2 if n.z > 0.9 else (1 if n.y > 0.9 else -1))
			if axis < 0:
				continue
			var lo := Vector3.INF
			var hi := -Vector3.INF
			for p in f["points"]:
				lo = lo.min(_v(p))
				hi = hi.max(_v(p))
			var plane: float = lo[axis]
			if absf(box.position[axis] - plane) > 0.005 and absf(box.end[axis] - plane) > 0.005:
				continue
			var shared := 1.0
			for other in 3:
				if other != axis:
					shared *= maxf(0.0, minf(box.end[other], hi[other]) - maxf(box.position[other], lo[other]))
			if shared > 0.0001:
				flush.append("%s %s=%.3f" % [mesh.name, "xyz"[axis], plane])
	return flush


## The set at home in the map: its own keys asleep (the map's are the player's), everything it lights, sounds and
## shows standing in its own spaces (its crowd excepted: they walk on into the map's), none of its building in the
## map's other spaces, no face of it in the plane of a greybox wall's, and the greybox's openings onto it its own size.
func _set_in_place(lane: Node3D) -> void:
	var work_was: bool = lane.get("_work_on")
	var form_was: bool = lane.get("_form")
	for key in [KEY_F1, KEY_F2]:
		var press := InputEventKey.new()
		press.keycode = key
		press.pressed = true
		lane._unhandled_input(press)
	var asleep: bool = lane.get("_work_on") == work_was and lane.get("_form") == form_was
	lane.set_work_lights(work_was)
	lane.set_form(form_was)
	_check("M10 the set's own inspection keys are asleep in the map", asleep,
		"work lights %s -> %s, form %s -> %s" % [work_was, lane.get("_work_on"), form_was, lane.get("_form")])

	# Everything placed: its shadow crossing, its flames lit, its sounds, lights, smoke and decals.
	if lane.get("ownerless") != null:
		lane.ownerless.cross_now()
	await _frames(2)
	var own := [_rect("candle_lane").grow(0.5), _rect("librarian_shop").grow(0.5)]
	var strays := []
	for node: Node in lane.find_children("*", "VisualInstance3D", true, false) + lane.find_children("*", "AudioStreamPlayer3D", true, false):
		var moving: bool = lane.crowd_of_shades != null and lane.crowd_of_shades.is_ancestor_of(node)
		var stub: Node3D = lane.get("stub")
		if moving or (stub != null and stub.is_ancestor_of(node)) or not (node as Node3D).is_visible_in_tree():
			continue
		# (Ribbons, word chains and the like drawn in the world's frame stand at its origin, and what they carry.)
		var drawn_in_world := false
		var up: Node = node
		while up != lane and up != null:
			drawn_in_world = drawn_in_world or (up is Node3D and up.top_level and up.global_transform.origin == Vector3.ZERO)
			up = up.get_parent()
		if drawn_in_world:
			continue
		# (Where it is drawn: a mesh's middle, not its origin, which a piece turning on a pivot at its middle swings
		# round it (the shop's armillary).)
		var at: Vector3 = (node as Node3D).global_position
		if node is GeometryInstance3D:
			at = ((node as Node3D).global_transform * (node as GeometryInstance3D).get_aabb()).get_center()
		var flat := Vector2(at.x, at.z)
		# (A pocket's sounds may come from the map's Pasaje or chapel beyond its ends.)
		var spaces: Array = own + ([_rect("pasaje"), _rect("chapel")] if node.has_meta("pocket") else [])
		if not spaces.any(func(r): return r.has_point(flat)) or at.y < -11.5 or at.y > -11.0 + 5.0:
			strays.append("%s %s" % [node.name, at])
	_check("M11 everything the set lights, sounds and shows stands in its own spaces at the map's offset", strays.is_empty(),
		"%d out: %s" % [strays.size(), strays])

	# None of its building in the map's other spaces (deeper than 6 cm).
	var meshes: Array = lane.find_children("*", "MeshInstance3D", true, false).filter(func(m):
		return m.is_visible_in_tree() and m.mesh != null \
			and not (lane.crowd_of_shades != null and lane.crowd_of_shades.is_ancestor_of(m)))
	var into := _intrusions(meshes, map.SETS["candle_lane"][1])
	_check("M12 none of the set's building stands in the map's other spaces", into.is_empty(),
		"%d: %s" % [into.size(), into])

	# No face of its walls, vault or tiles in a greybox wall's plane; the openings onto it as big as its own.
	var gaps := _gaps_onto("candle_lane")
	var flush := _flush(meshes.filter(func(m): return m.mesh is BoxMesh or m in lane.wall_panels))
	var mouth: Dictionary = gaps.get("pasaje", {})
	var door: Dictionary = gaps.get("chapel", {})
	var door_wide := 0.0
	if not door.is_empty():
		door_wide = Vector2(door["a"][0], door["a"][1]).distance_to(Vector2(door["b"][0], door["b"][1]))
	var lane_door := Vector2(lane.DOOR.x + 2.0 * lane.DOOR_INSET, lane.DOOR.y + lane.DOOR_INSET)
	var sized: bool = not mouth.is_empty() and mouth["y1"] - mouth["y0"] >= lane.HEIGHT - 0.01 and not door.is_empty() \
		and absf(door_wide - lane_door.x) < 0.02 and absf(door["y1"] - door["y0"] - lane_door.y) < 0.02
	_check("M13 no face of the set flush with a greybox wall's, and the greybox's openings onto it its own size",
		flush.is_empty() and sized, "%d flush: %s; mouth %s door %s (%.2f wide) against %s" % [flush.size(),
			flush, mouth, door, door_wide, lane_door])


func _floor_below(at: Vector3) -> float:
	var ray := PhysicsRayQueryParameters3D.create(at, at - Vector3(0.0, 3.0, 0.0))
	ray.exclude = [map.player.get_rid()]
	var hit := map.get_world_3d().direct_space_state.intersect_ray(ray)
	return hit["position"].y if not hit.is_empty() else INF


## The player walked along waypoints from the first (put there once, at the
## start): each leg turned toward the next point and walked until across
## from it. Fails if a leg stalls or the player drops 0.5 m below the lower
## of a leg's two floors.
func _tour(points: Array, from_start := false) -> Dictionary:
	var player: CharacterBody3D = map.player
	var first := _v(points[0])

	if from_start or player.global_position.distance_to(first + Vector3(0, 1.05, 0)) > 1.0:
		player.global_position = first + Vector3(0, 1.05, 0)
		player.velocity = Vector3.ZERO
		await _frames(10)

	var ok := true
	var worst := ""
	points = _through_lanes(points)

	for k in range(1, points.size()):
		var target := _v(points[k])
		var floor_low := minf(_v(points[k - 1]).y, target.y)
		var leg := await _leg(target)

		if not leg["ok"] or leg["lowest"] < floor_low + 1.05 - 0.5:
			ok = false
			worst = "leg %d to %s: %s" % [k, target, leg]
			break

	return {"ok": ok and player.is_on_floor(), "end": player.global_position, "failed": worst}


## The plan's walks join a space's points in straight lines and know nothing of the station's turnstile banks: a leg
## across a bank goes through its nearest lane instead, as anyone would (2 m before it, along its middle, 2 m after).
func _through_lanes(points: Array) -> Array:
	var station: Node3D = map.get_node_or_null("metro_station")
	var banks = station.get("turnstiles") if station != null else null
	if banks == null or (banks as Array).is_empty():
		return points
	var out := [points[0]]
	for k in range(1, points.size()):
		var a := _v(points[k - 1])
		var b := _v(points[k])
		for bank: Node3D in banks:
			var lanes: Array = bank.get_meta("lanes", [])
			if lanes.is_empty():
				continue
			var line: Vector3 = station.to_global(lanes[0])
			if absf(a.y - line.y) > 0.5 or absf(b.y - line.y) > 0.5 or signf(a.x - line.x) == signf(b.x - line.x):
				continue
			var t := (line.x - a.x) / (b.x - a.x)
			var cross := lerpf(a.z, b.z, t)
			var best: Vector3 = station.to_global(lanes[0])
			for lane: Vector3 in lanes:
				var at: Vector3 = station.to_global(lane)
				if absf(at.z - cross) < absf(best.z - cross):
					best = at
			var way := signf(b.x - a.x)
			out.append([best.x - way * 2.0, best.y, best.z])
			out.append([best.x + way * 2.0, best.y, best.z])
		out.append(points[k])
	return out


func _leg(target: Vector3) -> Dictionary:
	var player: CharacterBody3D = map.player
	var lowest := player.global_position.y
	var from := player.global_position
	var heading := Vector2(target.x - from.x, target.z - from.z)

	if heading.length() < REACHED:
		return {"ok": true, "lowest": lowest}

	Input.action_press("move_forward")
	var arrived := false

	for i in LEG_FRAMES:
		var here := player.global_position
		var to := Vector2(target.x - here.x, target.z - here.z)
		# Steered every frame toward the point (as a player would).
		player.rotation.y = atan2(-to.x, -to.y)
		await get_tree().physics_frame
		lowest = minf(lowest, player.global_position.y)
		here = player.global_position
		to = Vector2(target.x - here.x, target.z - here.z)

		if to.length() < REACHED or to.dot(heading) < 0.0:
			arrived = true
			break

	Input.action_release("move_forward")
	await _frames(6)
	return {"ok": arrived, "lowest": lowest, "end": player.global_position}


## The layer of the space the point stands in (0 if none).
func _layer_at(p: Vector3) -> int:
	for s in map.plan["spaces"]:
		if Geometry2D.is_point_in_polygon(Vector2(p.x, p.z), _poly(s["polygon"])) \
				and p.y - 1.05 > s["floor"] - 0.3 and p.y - 1.05 < s["floor"] + s["height"]:
			return int(s["layer"])

	return 0


func _v(p: Array) -> Vector3:
	return Vector3(p[0], p[1], p[2])


func _poly(points: Array) -> PackedVector2Array:
	var out := PackedVector2Array()

	for p in points:
		out.append(Vector2(p[0], p[1]))

	return out


func _rect(name: String) -> Rect2:
	for s in map.plan["spaces"]:
		if s["name"] == name:
			var r := Rect2(Vector2(s["polygon"][0][0], s["polygon"][0][1]), Vector2.ZERO)

			for p in s["polygon"]:
				r = r.expand(Vector2(p[0], p[1]))

			return r

	return Rect2()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
