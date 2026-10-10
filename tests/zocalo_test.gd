extends Node3D
## The Zócalo's greybox (the Zócalo plan, Task 6): loaded, the player spawned
## on the street, the sunken places and underground spaces where the plan
## puts them, and the real player walking its stairs and a roof plank.
## Headless:
##   Godot --headless --fixed-fps 60 --path . res://tests/zocalo_test.tscn

const MAP := preload("res://maps/zocalo.tscn")
const KINDS := ["ground", "sunken", "plot", "space", "route", "brink"]

var results: Array[String] = []
var map: Node3D


func _ready() -> void:
	await _run()

	print("\n==== RESULTS ====")
	for r in results:
		print(r)

	get_tree().quit()


func _run() -> void:
	map = MAP.instantiate()
	add_child(map)
	await _frames(10)

	# Z1 the greybox loads: every kind of mesh, each with its collider
	var kinds := {}
	var bare := []

	for mesh: MeshInstance3D in map.greybox.find_children("*", "MeshInstance3D", true, false):
		kinds[mesh.get_meta("kind", "")] = true

		# (A ladder's board is only seen: its ladder is taken hold of.)
		if mesh.get_meta("route", "") != "climb" and mesh.find_children("*", "CollisionShape3D", true, false).is_empty():
			bare.append(String(mesh.name))

	_check("Z1 the greybox loads every kind of mesh, each solid", KINDS.all(func(k): return kinds.has(k)) and bare.is_empty(),
		"kinds %s, without colliders %s" % [kinds.keys(), bare.slice(0, 4)])

	# Z1b its ground faces up (clockwise from above: Godot's front)
	var ground: MeshInstance3D = map.greybox.get_node("ground")
	var arrays := (ground.mesh as ArrayMesh).surface_get_arrays(0)
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var down := 0

	for t in range(0, v.size(), 3):
		down += int((v[t + 1] - v[t]).cross(v[t + 2] - v[t]).y > 0.0)

	_check("Z1b the ground faces up", down == 0 and v.size() > 0, "%d of %d triangles face down" % [down, v.size() / 3])

	# Z2 the spawn stands on street ground, not in a plot
	await _frames(2)
	var spawn: Vector3 = map.spawn_point()
	var hit := _ray(spawn + Vector3(0, 3, 0), spawn + Vector3(0, -3, 0))
	var in_plot: bool = map.plan["plots"].any(func(p): return Geometry2D.is_point_in_polygon(Vector2(spawn.x, spawn.z), _poly(p["polygon"])))
	_check("Z2 the spawn stands on street ground", not hit.is_empty() and absf(hit["position"].y) < 0.05 and not in_plot,
		"spawn %s, hit %s, in a plot %s" % [spawn, hit.get("position"), in_plot])

	# Z3 the canal lies 2 m down, the dig 6 m
	# (Midway between bridges: one crosses the canal's middle.)
	var canal := Vector2(-75.0, _centre("ground", "canal").y)
	var dig := _centre("ground", "dig_s")
	var canal_hit := _ray(Vector3(canal.x, 5, canal.y), Vector3(canal.x, -10, canal.y))
	var dig_hit := _ray(Vector3(dig.x, 5, dig.y), Vector3(dig.x, -10, dig.y))
	_check("Z3 the canal lies 2 m down and the dig 6 m", not canal_hit.is_empty() and absf(canal_hit["position"].y + 2.0) < 0.05
		and not dig_hit.is_empty() and absf(dig_hit["position"].y + 6.0) < 0.05,
		"canal %s, dig %s" % [canal_hit.get("position"), dig_hit.get("position")])

	# Z4 every underground space has its floor and its ceiling
	var open := []

	for s in map.plan["spaces"]:
		var c := _centre_of(s["polygon"])
		var at := Vector3(c.x, s["floor"] + 1.0, c.y)
		var f := _ray(at, at + Vector3(0, -2, 0))
		var ceil := _ray(at, at + Vector3(0, s["height"] + 1.0, 0))

		if f.is_empty() or absf(f["position"].y - s["floor"]) > 0.05 or ceil.is_empty() \
				or absf(ceil["position"].y - (s["floor"] + s["height"])) > 0.05:
			open.append(s["name"])

	_check("Z4 every underground space has its floor and ceiling", open.is_empty(), "open: %s" % [open])

	# Z5 down the north-west kiosk's stair into its well
	var well := _rect("well_nw")
	var walk := await _walk(Vector3(-90, 1.05, -106.5), PI, func(p): return p.z > well.end.y - 1.5, 600)
	_check("Z5 the player walks down a kiosk's stair into the station's well",
		walk["ok"] and absf(walk["end"].y - 1.05 + 8.0) < 0.5 and well.has_point(Vector2(walk["end"].x, walk["end"].z)),
		"%s" % [walk])

	# Z5b from the ticket hall down to the west platform
	var platform := _rect("platform_w")
	walk = await _walk(Vector3(-24, -8 + 1.05, -6), PI / 2, func(p): return p.x < -50.0, 600)
	_check("Z5b the player walks from the ticket hall down to a platform",
		walk["ok"] and absf(walk["end"].y - 1.05 + 14.0) < 0.5 and platform.has_point(Vector2(walk["end"].x, walk["end"].z)),
		"%s" % [walk])

	# Z6 from the street up the town hall's ladder on to its roof, along it
	#    and across the plank to the other roof (no teleport on to a roof)
	var climb := _route("climb_up_town_hall_w")
	var foot := Vector3(climb["points"][0][0], 1.05, climb["points"][0][2])
	var into := Vector3(climb["points"][1][0] - climb["points"][0][0], 0, climb["points"][1][2] - climb["points"][0][2])
	var up := await _walk(foot - into.normalized() * 0.6, atan2(-into.x, -into.z),
		func(p): return p.y > 14.5 and map.player.movement_state == map.player.MoveState.LOCOMOTION, 900)
	var along := await _walk(map.player.global_position, PI, func(p): return p.z > 144.8, 600)
	var across := await _walk(map.player.global_position, -PI / 2, func(p): return p.x > 10.0, 600)
	_check("Z6 the player climbs the town hall's ladder from the street and crosses its roof plank",
		up["ok"] and along["ok"] and across["ok"] and along["lowest"] > 14.0 and across["lowest"] > 14.0 - 0.5,
		"up %s along %s across %s" % [up, along, across])

	# Z6b every climb is a ladder the player can take hold of
	var climbs: int = map.plan["routes"].filter(func(r): return r["kind"] == "climb").size()
	var volumes: int = map.greybox.find_children("*", "Area3D", true, false).filter(func(a): return a is ClimbVolume).size()
	_check("Z6b every climb is a ladder", climbs > 0 and volumes == climbs, "%d climbs, %d ladders" % [climbs, volumes])

	# Z7 down to the canal's west landing
	var landing := _rect("landing_w")
	walk = await _walk(Vector3(-63, 1.05, 163.5), -PI / 2, func(p): return p.x > -50.0, 600)
	_check("Z7 the player walks down to a canal landing",
		walk["ok"] and absf(walk["end"].y - 1.05 + 1.0) < 0.4 and landing.has_point(Vector2(walk["end"].x, walk["end"].z)),
		"%s" % [walk])


## The player put at `start` facing `yaw` (0 north), walked forward until
## `done` holds of their position or `frames` pass: where they ended, the
## lowest they went, whether they arrived standing.
func _walk(start: Vector3, yaw: float, done: Callable, frames: int) -> Dictionary:
	var player: CharacterBody3D = map.player
	player.global_position = start
	player.rotation.y = yaw
	player.velocity = Vector3.ZERO
	await _frames(10)
	Input.action_press("move_forward")
	var lowest := player.global_position.y
	var arrived := false

	for i in frames:
		await get_tree().physics_frame
		lowest = minf(lowest, player.global_position.y)

		if done.call(player.global_position):
			arrived = true
			break

	Input.action_release("move_forward")
	await _frames(20)
	return {"ok": arrived and player.is_on_floor(), "end": player.global_position, "lowest": lowest}


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, 0xFFFFFFFF, [map.player.get_rid()])
	return map.get_world_3d().direct_space_state.intersect_ray(query)


func _poly(points: Array) -> PackedVector2Array:
	var out := PackedVector2Array()

	for p in points:
		out.append(Vector2(p[0], p[1]))

	return out


func _centre_of(points: Array) -> Vector2:
	var sum := Vector2.ZERO

	for p in points:
		sum += Vector2(p[0], p[1])

	return sum / points.size()


func _route(name: String) -> Dictionary:
	return _find("routes", name)


func _find(key: String, name: String) -> Dictionary:
	for e in map.plan[key]:
		if e["name"] == name:
			return e

	return {}


func _centre(key: String, name: String) -> Vector2:
	return _centre_of(_find(key, name)["polygon"])


func _rect(name: String) -> Rect2:
	var e := _find("ground", name)

	if e.is_empty():
		e = _find("spaces", name)

	var r := Rect2(Vector2(e["polygon"][0][0], e["polygon"][0][1]), Vector2.ZERO)

	for p in e["polygon"]:
		r = r.expand(Vector2(p[0], p[1]))

	return r


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
