extends Node3D
## The Zócalo station set (docs/superpowers/plans/2026-10-30-metro-station.md): quick checks, headless with
## --fixed-fps 60:
##   Godot --headless --fixed-fps 60 --path . res://tests/metro_station_test.tscn

const STATION := preload("res://maps/metro_station.tscn")
const Layers := preload("res://scripts/Visual/Layers.gd")
## The MP-68's running pads, centred this far either side of a track's centre (m).
const PAD_FROM_CENTRE := 1.0

var results: Array[String] = []
var failures := 0
var station: Node3D


func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	station = STATION.instantiate()
	add_child(station)
	await _frames(5)
	_shell()
	await _walked()
	_mouths()
	_track()
	_dressed()
	_lit()
	_taquillas()
	print("\n==== RESULTS ====")
	for result in results:
		print(result)
	get_tree().quit(1 if failures > 0 else 0)


## Task 5: the track laid for the MP-68.
## S5: two tracks laid end to end: for each track, both its running pads' tops at PAD_TOP (± 1 cm) at every metre of x
## from -50 to 50, found by a ray down onto them (what a foot or a tyre stands on).
func _track() -> void:
	var wrong := []
	for z: float in station.TRACKS_Z:
		for side in [-1.0, 1.0]:
			var pad_z: float = z + side * PAD_FROM_CENTRE
			for x in range(-50, 51):
				var at := Vector3(float(x), float(station.PAD_TOP) + 2.0, pad_z)
				var top := _ray(at, at + Vector3(0.0, -3.0, 0.0)).y
				if absf(top - float(station.PAD_TOP)) > 0.01:
					wrong.append("pad at x %d, z %.1f: %.2f" % [x, pad_z, top])
	_check("S5 two tracks laid end to end", wrong.is_empty(), "%d: %s" % [wrong.size(), wrong.slice(0, 6)])


## Task 7: the taquillas.
## The booths' places (the plan's): the east against the hall's north wall at x 16…24 (the plan's ticket booth), the
## west against its south wall at x −24…−16; the windows each has.
const TAQUILLAS := {"east": [16.0, 24.0, -1.0, 3], "west": [-24.0, -16.0, 1.0, 2]}
## How far in front of a window the queue stands clear, and how wide (m).
const QUEUE := Vector2(2.0, 1.0)


## S7: each booth stands against its wall (its back on the wall's tiles), within its x range, its windows facing into
## the hall. S7b: 2 m of clear floor in front of each window, nothing solid in it and no dressing drawn in it.
func _taquillas() -> void:
	var booths = station.get("taquillas")
	var wrong := []
	var crowded := []
	var tiles := 14.0 - float(station.WALL) - 0.067
	var hall_floor: float = station.spaces()["hall"]["floor"]
	var drawn := _drawn()
	if booths == null or (booths as Array).size() != TAQUILLAS.size():
		wrong.append("booths: %s" % [booths])
		booths = []
	for booth: Node3D in booths:
		var place: Array = TAQUILLAS.get(booth.get_meta("side", ""), [])
		if place.is_empty():
			wrong.append("%s: no side" % booth.name)
			continue
		var box := _box_of(booth)
		var back := box.position.z if place[2] < 0.0 else box.end.z
		if absf(absf(back) - tiles) > 0.02 or signf(back) != place[2]:
			wrong.append("%s: back at z %.3f, the tiles at %.3f" % [booth.name, back, place[2] * tiles])
		if box.position.x < place[0] - 0.01 or box.end.x > place[1] + 0.01:
			wrong.append("%s: x %.2f…%.2f" % [booth.name, box.position.x, box.end.x])
		var windows: Array = booth.get_meta("windows", [])
		if windows.size() != place[3]:
			wrong.append("%s: %d windows" % [booth.name, windows.size()])
		var facing: Vector3 = booth.get_meta("facing", Vector3.ZERO)
		if facing.distance_to(Vector3(0.0, 0.0, -place[2])) > 0.01:
			wrong.append("%s: facing %s" % [booth.name, facing])
		for w: Vector3 in windows:
			# (The queue's room: from the counter's edge out, a window wide, a head tall.)
			var room := AABB(Vector3(w.x - QUEUE.y / 2.0, hall_floor + 0.1, minf(w.z, w.z + facing.z * QUEUE.x)),
				Vector3(QUEUE.y, 1.9, QUEUE.x))
			var shape := BoxShape3D.new()
			shape.size = room.size
			var q := PhysicsShapeQueryParameters3D.new()
			q.shape = shape
			q.transform = station.global_transform * Transform3D(Basis.IDENTITY, room.get_center())
			var player: CharacterBody3D = station.get("player")
			if player != null:
				q.exclude = [player.get_rid()]
			if not station.get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty():
				crowded.append("%s at x %.1f: solid" % [booth.name, w.x])
			for b: Dictionary in drawn["boxes"]:
				if (b["aabb"] as AABB).intersects(room):
					crowded.append("%s at x %.1f: %s" % [booth.name, w.x, b["kind"]])
	_check("S7 the taquillas against their walls, their windows facing the hall", wrong.is_empty(), "%s" % [wrong])
	_check("S7b a queue's room in front of every window", crowded.is_empty() and not (booths as Array).is_empty(),
		"%s" % [crowded.slice(0, 6)])


## A node's meshes' box in the set's frame.
func _box_of(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for m in node.find_children("*", "MeshInstance3D", true, false) + ([node] if node is MeshInstance3D else []):
		var mesh := (m as MeshInstance3D).mesh
		if mesh == null:
			continue
		var aabb: AABB = station.global_transform.affine_inverse() * (m as Node3D).global_transform * mesh.get_aabb()
		box = aabb if first else box.merge(aabb)
		first = false
	return box


## S1: the shell at the plan's measure: its floors, its ceilings, and every gap of its spaces open (a ray through its
## middle passes), the wall beside it closed (0.5 m along from either end, where the gap does not run the wall's
## whole length).
func _shell() -> void:
	var wrong := []
	# Its floors: the platforms and the stairwells' feet at 0, the hall at 6, the bed at -1.2.
	for spot in [[Vector3(0.0, 2.0, -10.0), 0.0], [Vector3(-20.0, 2.0, 10.0), 0.0], [Vector3(-2.0, 2.0, -20.0), 0.0],
			[Vector3(-20.0, 8.0, -5.0), 6.0], [Vector3(-20.0, 0.5, -2.5), -1.2]]:
		var at: Vector3 = spot[0]
		var floor_y := _ray(at, at + Vector3(0.0, -4.0, 0.0)).y
		if absf(floor_y - float(spot[1])) > 0.02:
			wrong.append("floor at %s: %.2f" % [at, floor_y])
	# Its ceilings: the platforms' and the track's at 5.5, the hall's at 11.
	for spot in [[Vector3(-40.0, 2.0, -10.0), 5.5], [Vector3(-20.0, 1.0, -2.5), 5.5], [Vector3(-20.0, 8.0, -5.0), 11.0]]:
		var at: Vector3 = spot[0]
		var top := _ray(at, at + Vector3(0.0, 9.0, 0.0)).y
		if absf(top - float(spot[1])) > 0.02:
			wrong.append("ceiling over %s: %.2f" % [at, top])
	var spaces: Dictionary = station.spaces()
	for name: String in spaces:
		var record: Dictionary = spaces[name]
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for q in record["polygon"]:
			lo = Vector2(minf(lo.x, q[0]), minf(lo.y, q[1]))
			hi = Vector2(maxf(hi.x, q[0]), maxf(hi.y, q[1]))
		var middle_of := (lo + hi) / 2.0
		for gap: Dictionary in record["gaps"]:
			var a := Vector2(gap["a"][0], gap["a"][1])
			var b := Vector2(gap["b"][0], gap["b"][1])
			var along := (b - a).normalized()
			var out := Vector2(-along.y, along.x)
			if out.dot((a + b) / 2.0 - middle_of) < 0.0:
				out = -out
			var y := float(gap["y0"]) + 1.5
			var mid := (a + b) / 2.0
			var from := Vector3(mid.x - out.x, y, mid.y - out.y)
			var to := Vector3(mid.x + out.x * 1.5, y, mid.y + out.y * 1.5)
			if _ray(from, to).distance_to(to) > 0.01:
				wrong.append("%s's gap to %s shut" % [name, gap["to"]])
			# (Beside it, where its own run of wall goes on past it: a point on the outline's same edge.)
			var run: Array = _edge_of(record["polygon"], a, b)
			for side in [a - along * 0.5, b + along * 0.5]:
				var s: Vector2 = side
				# (Unless another of its gaps goes on there at that height: two gaps meeting end to end.)
				var in_next: bool = (record["gaps"] as Array).any(func(g): return g != gap \
					and Geometry2D.get_closest_point_to_segment(s, Vector2(g["a"][0], g["a"][1]),
						Vector2(g["b"][0], g["b"][1])).distance_to(s) < 0.01 and y >= float(g["y0"]) and y <= float(g["y1"]))
				if not in_next and not run.is_empty() and Geometry2D.get_closest_point_to_segment(s, run[0], run[1]).distance_to(s) < 0.01:
					var hit := _ray(Vector3(s.x - out.x, y, s.y - out.y), Vector3(s.x + out.x * 1.5, y, s.y + out.y * 1.5))
					if Vector2(hit.x, hit.z).distance_to(s) > 0.35:
						wrong.append("%s beside its gap to %s open" % [name, gap["to"]])
	_check("S1 the shell at the plan's measure, every gap of its spaces open", wrong.is_empty(),
		"%d: %s" % [wrong.size(), wrong.slice(0, 6)])


## S2: walked: along the arrival's platform both ways; up the north stairwell into the hall; across it and down the
## south stairwell onto the south platform.
func _walked() -> void:
	var east := await _walk_path(Vector3(0.0, 1.05, -9.0), [Vector3(40.0, 1.05, -9.0)], 2400)
	var west := await _walk_path(Vector3(0.0, 1.05, -9.0), [Vector3(-45.0, 1.05, -9.0)], 2400)
	var up_way: Array[Vector3] = [Vector3(-2.0, 1.05, -13.0), Vector3(-2.0, 1.05, -29.2), Vector3(-6.0, 1.05, -29.2),
		Vector3(-6.0, 1.05, -14.5), Vector3(-6.0, 1.05, -12.5)]
	var up := await _walk_path(Vector3(0.0, 1.05, -9.0), up_way, 3600)
	var down_way: Array[Vector3] = [Vector3(6.0, 1.05, 12.5), Vector3(6.0, 1.05, 14.5), Vector3(6.0, 1.05, 29.2),
		Vector3(2.0, 1.05, 29.2), Vector3(2.0, 1.05, 13.0), Vector3(2.0, 1.05, 10.0)]
	var down := await _walk_path(Vector3(-6.0, 7.05, -12.5), down_way, 3600)
	var in_hall: bool = up["ok"] and absf(float(up["end"].y) - 7.05) < 0.15
	var on_south: bool = down["ok"] and absf(float(down["end"].y) - 1.05) < 0.15
	_check("S2 walked along the platform, up into the hall, across it and down onto the south platform",
		east["ok"] and west["ok"] and in_hall and on_south, "east %s west %s up %s down %s" % [east, west, up, down])
	# S2b: no lip where a flight arrives in the hall: along each flight's top into the hall, no step over 5 cm.
	var steps := []
	for flight in [[-6.0, -1.0], [6.0, 1.0]]:
		var x: float = flight[0]
		var sz: float = flight[1]
		var last := INF
		for k in 41:
			# (Off the exact planes two touching boxes share, where a ray slips between them.)
			var z := sz * (15.5125 - k * 0.05)
			# (From under the door's lintel, at 9.)
			var y := _ray(Vector3(x, 8.5, z), Vector3(x, 3.0, z)).y
			if last != INF and absf(y - last) > 0.05:
				steps.append("x %.0f z %.2f: %.2f -> %.2f" % [x, z, last, y])
			last = y
	_check("S2b no lip where either flight arrives in the hall", steps.is_empty(), "%s" % [steps])


## S3: each track's tunnel mouth at either end runs on into the dark: a ray along the track from inside the station
## passes its end and meets the black cap 10-13 m beyond it.
func _mouths() -> void:
	var wrong := []
	for track_z: float in station.TRACKS_Z:
		for end in [-1.0, 1.0]:
			var hit := _ray(Vector3(end * 45.0, 1.0, track_z), Vector3(end * 70.0, 1.0, track_z))
			if absf(hit.x) < 60.0 or absf(hit.x) > 63.0:
				wrong.append("track at z %.1f, end %d: met at x %.2f" % [track_z, end, hit.x])
	_check("S3 the tunnel mouths run on into the dark", wrong.is_empty(), "%s" % [wrong])


## Task 4: the shell dressed.
## S4: every run of wall the shell stands in its spaces dressed, tiled or plastered, every 1.2 m along it from a metre
## up to near its top (a run under 0.25 m, a jamb its reveal covers, excepted): sampled just in front of its face
## against where the dressing is drawn.
## S4b: no word on it: no Label3D or Decal under the set (its signs' faces are the kit's blank `sign` slot).
## S4c: nothing hung over a walk lower than 2.4 m over its floor.
func _dressed() -> void:
	var drawn := _drawn()
	var bare := []
	var faces: Array = station.get("faces") if station.get("faces") != null else []
	for face: Dictionary in faces:
		var a: Vector2 = face["a"]
		var b: Vector2 = face["b"]
		var length := a.distance_to(b)
		if length < 0.25:
			continue
		var along := (b - a) / length
		var inward: Vector2 = face["inward"]
		var s := minf(0.6, length / 2.0)
		while s < length:
			for y in [float(face["y0"]) + 1.0, float(face["y1"]) - 0.3]:
				var p := a + along * s + inward * 0.03
				var at := Vector3(p.x, y, p.y)
				if not _covered(drawn, at):
					bare.append("%s %s" % [face["space"], at.snapped(Vector3.ONE * 0.1)])
			s += 1.2
	_check("S4 tiled to every gap and corner, no run of wall left bare", not faces.is_empty() and bare.is_empty(),
		"%d faces; %d bare: %s" % [faces.size(), bare.size(), bare.slice(0, 6)])

	# (The player's own, standing in it when it stands alone, are not the set's.)
	var words: Array = (station.find_children("*", "Label3D", true, false) + station.find_children("*", "Decal", true, false)) \
		.filter(func(n): return not station.player.is_ancestor_of(n))
	_check("S4b no word on it", words.is_empty(), "%s" % [words.slice(0, 4)])

	var low := []
	# (A booth's roof is no walk: its bodies are looked through to the floor.)
	var roofs := []
	for booth: Node3D in station.get("taquillas") if station.get("taquillas") != null else []:
		for body: StaticBody3D in booth.find_children("*", "StaticBody3D", true, false):
			roofs.append(body.get_rid())
	var floors := {}
	for name: String in station.spaces():
		floors[name] = station.spaces()[name]
	for box: Dictionary in drawn["boxes"]:
		if not box["kind"] in ["sign_board", "strip_fitting", "coffer", "ceiling_panel", "line_map"]:
			continue
		var aabb: AABB = box["aabb"]
		if box["kind"] == "line_map":
			continue
		var under := _floor_under(Vector3(aabb.get_center().x, aabb.position.y, aabb.get_center().z), roofs)
		if aabb.position.y - under < 2.4:
			low.append("%s at %s, %.2f over its floor" % [box["kind"], aabb.get_center().snapped(Vector3.ONE * 0.1),
				aabb.position.y - under])
	_check("S4c over the walks, nothing lower than 2.4 m", low.is_empty(), "%s" % [low.slice(0, 5)])

	# S4d: no bare end of wall or lintel's underside: each lined, or inside a door's reveal (sampled at its middle, a
	# hair in front of it).
	var reveals := (drawn["boxes"] as Array).filter(func(b): return String(b["kind"]).begins_with("reveal_"))
	var bare_ends := []
	for end: Dictionary in station.ends:
		var at: Vector2 = end["at"]
		var out: Vector2 = end["out"]
		var inward: Vector2 = end["inward"]
		var mid := at + inward * float(station.WALL) / 2.0 + out * 0.02
		var p := Vector3(mid.x, (float(end["y0"]) + float(end["y1"])) / 2.0, mid.y)
		if not _covered(drawn, p):
			bare_ends.append("end %s" % p.snapped(Vector3.ONE * 0.1))
	for head: Dictionary in station.heads:
		var a: Vector2 = head["from"]
		var b: Vector2 = head["to"]
		var inward: Vector2 = head["inward"]
		var mid := (a + b) / 2.0 + inward * float(station.WALL) / 2.0
		var p := Vector3(mid.x, float(head["y"]) - 0.02, mid.y)
		if not _covered(drawn, p):
			bare_ends.append("head %s" % p.snapped(Vector3.ONE * 0.1))
	_check("S4d no bare end of wall or lintel's underside", bare_ends.is_empty() and not station.ends.is_empty(),
		"%d ends, %d heads; bare %s" % [station.ends.size(), station.heads.size(), bare_ends.slice(0, 6)])

	# S4e: each ramp clad: its sides and its underside covered at every metre along it.
	var bare_ramps := []
	for ramp: MeshInstance3D in station.ramp_boxes:
		var size: Vector3 = (ramp.mesh as BoxMesh).size
		var t: Transform3D = ramp.transform
		var k := 0.5
		while k < size.z:
			var at: Vector3 = t.origin + t.basis.z * (k - size.z / 2.0)
			for p in [at + t.basis.x * (size.x / 2.0 + 0.02), at - t.basis.x * (size.x / 2.0 + 0.02),
					at - t.basis.y * (size.y / 2.0 + 0.02)]:
				if not _covered(drawn, p):
					bare_ramps.append("%s %s" % [ramp.name, (p as Vector3).snapped(Vector3.ONE * 0.1)])
			k += 1.0
	_check("S4e every ramp clad, its sides and underside", bare_ramps.is_empty() and not station.ramp_boxes.is_empty(),
		"%s" % [bare_ramps.slice(0, 6)])

	# S4f: each revealed door has its threshold.
	var sills := (drawn["boxes"] as Array).filter(func(b): return b["kind"] == "sill")
	var unsilled := []
	for reveal: Dictionary in reveals:
		var r: AABB = reveal["aabb"]
		var foot := Vector3(r.get_center().x, r.position.y + 0.005, r.get_center().z)
		if not sills.any(func(b): return (b["aabb"] as AABB).grow(0.02).has_point(foot)):
			unsilled.append(foot.snapped(Vector3.ONE * 0.1))
	_check("S4f every door has its threshold", unsilled.is_empty() and not reveals.is_empty(), "%s" % [unsilled])

	# S4g: the track steps' walls are the platform's where they stand over it: tiled a metre over the platform's floor,
	# plastered near their top, the pit's concrete only under the platform's floor.
	var platform: float = station.spaces()["platform_n"]["floor"]
	var wrong_notch := []
	var notch_faces := 0
	for face: Dictionary in faces:
		if not String(face["space"]).begins_with("track_notch") or float(face["y1"]) < platform + 2.0:
			continue
		notch_faces += 1
		var a: Vector2 = face["a"]
		var b: Vector2 = face["b"]
		var p: Vector2 = (a + b) / 2.0 + (face["inward"] as Vector2) * 0.03
		for want: Array in [[platform - 1.0, "pit_face"], [platform + 1.0, "wall_low"], [float(face["y1"]) - 0.3, "plaster_sheet"]]:
			var at := Vector3(p.x, want[0], p.y)
			var kinds := _kinds_at(drawn, at)
			if not kinds.any(func(k): return String(k).begins_with(want[1])):
				wrong_notch.append("%s %s: %s, wanted %s" % [face["space"], at.snapped(Vector3.ONE * 0.1), kinds, want[1]])
	_check("S4g the track steps' walls the platform's over its floor", notch_faces > 0 and wrong_notch.is_empty(),
		"%d faces; %s" % [notch_faces, wrong_notch.slice(0, 6)])

	# S4h: each cut the track steps go down is guarded where it lies open over its drop: a guard rail along its rim on
	# the platform and along its parapet, every metre of them; the parapet capped; the rim coped (the yellow line round
	# the drop).
	# S4i: nothing stands over the parapet but its rail (no wall's end lined up to the ceiling there).
	var unguarded := []
	var over_parapet := []
	for notch: String in ["track_notch_n", "track_notch_s"]:
		var sz := -1.0 if notch == "track_notch_n" else 1.0
		var xs := []
		for q in station.spaces()[notch]["polygon"]:
			xs.append(float(q[0]))
		var x0: float = xs.min()
		var x1: float = xs.max()
		var rim_z: float = sz * (float(station.EDGE_Z) + float(station.CUT_DEEP))
		var parapet_z: float = sz * (float(station.EDGE_Z) + float(station.WALL) / 2.0)
		# (The parapet runs from the head to the steps' foot, the last 2 m open onto the bed.)
		var p0 := x0 if sz < 0.0 else x0 + float(station.FOOT)
		var p1 := x1 - float(station.FOOT) if sz < 0.0 else x1
		var x := x0 + 0.5
		while x < x1:
			var rim := Vector3(x, platform + 1.0, rim_z + sz * 0.1)
			if not _kinds_at(drawn, rim).has("guard_rail"):
				unguarded.append("%s rail on the rim %s" % [notch, rim.snapped(Vector3.ONE * 0.1)])
			var coped := Vector3(x, platform + 0.005, rim_z + sz * 0.3)
			if not _kinds_at(drawn, coped).has("coping"):
				unguarded.append("%s rim uncoped %s" % [notch, coped.snapped(Vector3.ONE * 0.1)])
			if x > p0 + 0.2 and x < p1 - 0.2:
				var rail := Vector3(x, platform + 1.0, parapet_z)
				if not _kinds_at(drawn, rail).has("guard_rail"):
					unguarded.append("%s rail on the parapet %s" % [notch, rail.snapped(Vector3.ONE * 0.1)])
				var cap := Vector3(x, platform + 0.005, parapet_z)
				if not _kinds_at(drawn, cap).has("parapet_cap"):
					unguarded.append("%s parapet uncapped %s" % [notch, cap.snapped(Vector3.ONE * 0.1)])
				for y in [platform + 1.6, platform + 3.0]:
					var above := Vector3(x, y, parapet_z)
					if not _kinds_at(drawn, above).is_empty():
						over_parapet.append("%s %s: %s" % [notch, above.snapped(Vector3.ONE * 0.1), _kinds_at(drawn, above)])
			x += 1.0
		# (Its end at the steps' foot: lined only as high as it stands.)
		var end_x := p1 + 0.02 if sz < 0.0 else p0 - 0.02
		for y in [platform + 1.6, platform + 3.0]:
			var above_end := Vector3(end_x, y, parapet_z)
			if not _kinds_at(drawn, above_end).is_empty():
				over_parapet.append("%s end %s: %s" % [notch, above_end.snapped(Vector3.ONE * 0.1), _kinds_at(drawn, above_end)])
	# S4j: the track steps stand clear of their cut's walls (the parapet's face toward them, the pit's face under the
	# rim), their handrails clear of the guard rails over them.
	var crowded := []
	for ramp: MeshInstance3D in station.ramp_boxes:
		if not String(ramp.name).begins_with("track_steps"):
			continue
		var sz := -1.0 if ramp.name == "track_steps_n" else 1.0
		var half: float = (ramp.mesh as BoxMesh).size.x / 2.0
		var across := absf(ramp.transform.origin.z)
		var inner := across - half
		var outer := across + half
		var parapet_face: float = float(station.EDGE_Z) + float(station.WALL) + 0.04
		var rim_face: float = float(station.EDGE_Z) + float(station.CUT_DEEP) - 0.04
		if inner < parapet_face + 0.1 or outer > rim_face - 0.1:
			crowded.append("%s spans |z| %.2f..%.2f, the cut's clear %.2f..%.2f" % [ramp.name, inner, outer, parapet_face,
				rim_face])
		for box: Dictionary in drawn["boxes"]:
			if box["kind"] != "handrail" or absf((box["aabb"] as AABB).get_center().x - ramp.transform.origin.x) > 3.0:
				continue
			var z := absf((box["aabb"] as AABB).get_center().z)
			if absf(z - across) < 2.0 and (absf(z - float(station.EDGE_Z) - float(station.WALL) / 2.0) < 0.3 \
					or absf(z - float(station.EDGE_Z) - float(station.CUT_DEEP) - 0.1) < 0.3):
				crowded.append("%s handrail at |z| %.2f on a guard rail's line" % [ramp.name, z])
				break
	_check("S4j the track steps clear of their cut's walls and rails", crowded.is_empty(), "%s" % [crowded])
	_check("S4h the track steps' cut railed, its parapet capped, its rim coped", unguarded.is_empty(),
		"%s" % [unguarded.slice(0, 6)])
	_check("S4i nothing over the parapet but its rail", over_parapet.is_empty(), "%s" % [over_parapet.slice(0, 6)])


## Task 6: the station's light.
## S6: every walk lit: each of S2's waypoints, a metre over its floor, within 70 % of some station light's reach, that
## light's own level (none lit from another floor through a slab).
## S6b: the tunnel mouths dark: no light within 6 m of a mouth's far half.
## S6c: the light in budget: at most 40 shadowless lights and at most 2 with shadows.
## S6d: no light through a floor: each light lights its own level's layer (and the world's movers: the player, actors,
## hands, effects, the lightgem's probe) and never another level's; every dressing piece is on its level's layer.
## S6e: the fittings glow: every fluorescent tube's surface emits.
func _lit() -> void:
	var lights: Array = station.get("lights") if station.get("lights") != null else []
	var hall: int = Layers.STATION_HALL
	var stairs: int = Layers.STATION_STAIRS
	var below: int = Layers.STATION_BELOW
	var levels := hall | stairs | below
	var dark := []
	var walks := [[Vector3(0.0, 1.0, -9.0), below], [Vector3(40.0, 1.0, -9.0), below], [Vector3(-45.0, 1.0, -9.0), below],
		[Vector3(-2.0, 1.0, -20.0), stairs], [Vector3(-2.0, 1.0, -29.0), stairs], [Vector3(-6.0, 4.0, -21.0), stairs],
		[Vector3(-6.0, 7.0, -12.5), hall], [Vector3(6.0, 7.0, 12.5), hall], [Vector3(-25.0, 7.0, 0.0), hall],
		[Vector3(25.0, 7.0, 0.0), hall], [Vector3(0.0, 7.0, 0.0), hall], [Vector3(2.0, 1.0, 29.0), stairs],
		[Vector3(2.0, 1.0, 10.0), below], [Vector3(-40.0, 1.0, 10.0), below], [Vector3(40.0, 1.0, 10.0), below]]
	for walk in walks:
		var at: Vector3 = walk[0]
		var lit := lights.any(func(l): return (l as Light3D).light_cull_mask & int(walk[1]) != 0 \
			and (l as Node3D).position.distance_to(at) < 0.7 * _reach(l))
		if not lit:
			dark.append(at)
	_check("S6 every walk lit by its own level's light", not lights.is_empty() and dark.is_empty(), "%d lights; dark %s" % [
		lights.size(), dark])

	var near_mouth := []
	for light: Light3D in lights:
		for end in [-1.0, 1.0]:
			for z: float in station.TRACKS_Z:
				var far_half := Vector3(end * (50.0 + station.DARK_RUN * 0.75), 1.0, z)
				if light.position.distance_to(far_half) < 6.0:
					near_mouth.append(light.name)
	_check("S6b the tunnel mouths dark", near_mouth.is_empty(), "%s" % [near_mouth])

	var plain := lights.filter(func(l): return not (l as Light3D).shadow_enabled).size()
	var shadowed := lights.size() - plain
	_check("S6c the light in budget", plain <= 40 and shadowed <= 2, "%d shadowless, %d shadowed" % [plain, shadowed])

	var leaks := []
	for light: Light3D in lights:
		var own: int = light.light_cull_mask & levels
		if own != hall and own != stairs and own != below:
			leaks.append("%s lights levels %d" % [light.name, own])
		if light.light_cull_mask & (Layers.WORLD | Layers.ACTORS | Layers.VIEWMODEL | Layers.GEM_PROBE) \
				!= (Layers.WORLD | Layers.ACTORS | Layers.VIEWMODEL | Layers.GEM_PROBE):
			leaks.append("%s misses the movers" % light.name)
	for node in station.find_children("*", "MultiMeshInstance3D", true, false):
		var on: int = (node as VisualInstance3D).layers
		if on & levels == 0 or on & Layers.WORLD != 0:
			leaks.append("%s on layers %d" % [node.name, on])
	_check("S6d no light through a floor", leaks.is_empty(), "%s" % [leaks.slice(0, 6)])

	var unlit := []
	for node in station.find_children("*", "MultiMeshInstance3D", true, false):
		if not node.get_meta("kind", "") in ["strip_fitting", "coffer"]:
			continue
		var mesh := (node as MultiMeshInstance3D).multimesh.mesh
		var glows := false
		for i in mesh.get_surface_count():
			var m := mesh.surface_get_material(i) as BaseMaterial3D
			glows = glows or (m != null and m.emission_enabled and m.emission_energy_multiplier > 0.5)
		if not glows:
			unlit.append(node.name)
	_check("S6e the fittings glow", unlit.is_empty(), "%s" % [unlit])


func _reach(light: Light3D) -> float:
	return (light as OmniLight3D).omni_range if light is OmniLight3D else (light as SpotLight3D).spot_range


## Where the set's dressing is drawn: {"boxes": [{kind, aabb}] in its frame, "grid": {cell: [box indices]}}, its
## MultiMeshes' instances each its own box.
func _drawn() -> Dictionary:
	var boxes := []
	var grid := {}
	for node in station.find_children("*", "MultiMeshInstance3D", true, false):
		var many := (node as MultiMeshInstance3D).multimesh
		if many == null or many.mesh == null:
			continue
		var local := many.mesh.get_aabb()
		var to_set := station.global_transform.affine_inverse() * (node as Node3D).global_transform
		# (Its instances' transforms as the dressing laid them: a headless run's renderer keeps none.)
		var laid: Array = node.get_meta("transforms", [])
		for i in laid.size():
			var aabb: AABB = to_set * (laid[i] as Transform3D) * local
			boxes.append({"kind": node.get_meta("kind", String(node.name)), "aabb": aabb})
			var lo := (aabb.position / 2.0).floor()
			var hi := (aabb.end / 2.0).floor()
			for x in range(lo.x, hi.x + 1):
				for y in range(lo.y, hi.y + 1):
					for z in range(lo.z, hi.z + 1):
						var key := Vector3i(x, y, z)
						if not grid.has(key):
							grid[key] = []
						grid[key].append(boxes.size() - 1)
	return {"boxes": boxes, "grid": grid}


## The kinds of dressing drawn over `at`.
func _kinds_at(drawn: Dictionary, at: Vector3) -> Array:
	var kinds := []
	for i in drawn["grid"].get(Vector3i((at / 2.0).floor()), []):
		if (drawn["boxes"][i]["aabb"] as AABB).grow(0.01).has_point(at):
			kinds.append(drawn["boxes"][i]["kind"])
	return kinds


func _covered(drawn: Dictionary, at: Vector3) -> bool:
	for i in drawn["grid"].get(Vector3i((at / 2.0).floor()), []):
		if (drawn["boxes"][i]["aabb"] as AABB).grow(0.01).has_point(at):
			return true
	return false


## The floor under `at` (the shell's), its height; -INF if none.
func _floor_under(at: Vector3, skip: Array = []) -> float:
	var hit := _ray(at, at - Vector3(0.0, 20.0, 0.0), skip)
	return hit.y if hit != at - Vector3(0.0, 20.0, 0.0) else -INF


## The edge of `outline` that the run `a`-`b` lies on ([its two ends]; empty if none).
func _edge_of(outline: Array, a: Vector2, b: Vector2) -> Array:
	for i in outline.size():
		var p := Vector2(outline[i][0], outline[i][1])
		var q := Vector2(outline[(i + 1) % outline.size()][0], outline[(i + 1) % outline.size()][1])
		if Geometry2D.get_closest_point_to_segment(a, p, q).distance_to(a) < 0.02 \
				and Geometry2D.get_closest_point_to_segment(b, p, q).distance_to(b) < 0.02:
			return [p, q]
	return []


func _ray(from: Vector3, to: Vector3, skip: Array = []) -> Vector3:
	var space := station.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(station.to_global(from), station.to_global(to))
	var player: CharacterBody3D = station.get("player")
	q.exclude = skip + ([player.get_rid()] if player != null else [])
	var hit := space.intersect_ray(q)
	return station.to_local(hit.position) if not hit.is_empty() else to


## Walks the set's player from `start` along `way`, turning toward each point; arrived at each within 0.3 m.
func _walk_path(start: Vector3, way: Array, frames: int) -> Dictionary:
	var player: CharacterBody3D = station.player
	player.global_position = station.to_global(start)
	player.velocity = Vector3.ZERO
	await _frames(10)
	var reached := 0
	var still := 0
	var last := player.global_position
	Input.action_press("move_forward")
	for i in frames:
		var to: Vector3 = station.to_global(way[reached]) - player.global_position
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
	return {"ok": reached == way.size(), "reached": reached, "end": station.to_local(player.global_position)}


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _check(label: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		failures += 1
