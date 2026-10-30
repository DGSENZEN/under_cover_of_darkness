extends Node3D
## The Zócalo station set (docs/superpowers/plans/2026-10-30-metro-station.md): quick checks, headless with
## --fixed-fps 60:
##   Godot --headless --fixed-fps 60 --path . res://tests/metro_station_test.tscn

const STATION := preload("res://maps/metro_station.tscn")

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
	print("\n==== RESULTS ====")
	for result in results:
		print(result)
	get_tree().quit(1 if failures > 0 else 0)


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
				if not run.is_empty() and Geometry2D.get_closest_point_to_segment(s, run[0], run[1]).distance_to(s) < 0.01:
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


## The edge of `outline` that the run `a`-`b` lies on ([its two ends]; empty if none).
func _edge_of(outline: Array, a: Vector2, b: Vector2) -> Array:
	for i in outline.size():
		var p := Vector2(outline[i][0], outline[i][1])
		var q := Vector2(outline[(i + 1) % outline.size()][0], outline[(i + 1) % outline.size()][1])
		if Geometry2D.get_closest_point_to_segment(a, p, q).distance_to(a) < 0.02 \
				and Geometry2D.get_closest_point_to_segment(b, p, q).distance_to(b) < 0.02:
			return [p, q]
	return []


func _ray(from: Vector3, to: Vector3) -> Vector3:
	var space := station.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(station.to_global(from), station.to_global(to))
	var player: CharacterBody3D = station.get("player")
	if player != null:
		q.exclude = [player.get_rid()]
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
