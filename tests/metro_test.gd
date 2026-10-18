extends Node3D
## The Metro Underground's greybox (maps/metro, the Metro Underground part 1
## plan, Task 15): loaded, the player arriving on the north platform, then
## the real player walking the spine up to a kiosk's exit, and down into the
## market and the old passages, along the plan's own shortest walks
## (plan.json "walks", tools/level/layouts/metro/walk.py). Headless:
##   Godot --headless --fixed-fps 60 --path . res://tests/metro_test.tscn

const MAP := preload("res://maps/metro.tscn")
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

	# M6 nothing reported an error
	await _frames(2)
	_check("M6 no engine errors", errors.lines.is_empty(), "%s" % [errors.lines.slice(0, 4)])


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

	for k in range(1, points.size()):
		var target := _v(points[k])
		var floor_low := minf(_v(points[k - 1]).y, target.y)
		var leg := await _leg(target)

		if not leg["ok"] or leg["lowest"] < floor_low + 1.05 - 0.5:
			ok = false
			worst = "leg %d to %s: %s" % [k, target, leg]
			break

	return {"ok": ok and player.is_on_floor(), "end": player.global_position, "failed": worst}


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
