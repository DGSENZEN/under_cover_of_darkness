extends Node3D
## The Zócalo's greybox (the Zócalo plan, Task 6): loaded, the player spawned
## on the street, the sunken places and underground spaces where the plan
## puts them, and the real player walking its stairs and a roof plank.
## Headless:
##   Godot --headless --fixed-fps 60 --path . res://tests/zocalo_test.tscn

const MAP := preload("res://maps/zocalo.tscn")
const KINDS := ["ground", "raised", "sunken", "plot", "space", "route", "brink"]

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

	# (Dressed, the street and the plaza are the kit's ground, not the greybox's.)
	var expected := KINDS.filter(func(k): return not (map.dressing and k in ["ground", "raised"]))
	_check("Z1 the greybox loads every kind of mesh, each solid", expected.all(func(k): return kinds.has(k)) and bare.is_empty(),
		"kinds %s, without colliders %s" % [kinds.keys(), bare.slice(0, 4)])

	# Z1b its ground faces up (clockwise from above: Godot's front)
	var down := 0
	var triangles := 0
	var grounds: Array = map.district_ground.find_children("mesh", "MeshInstance3D", true, false) if map.dressing \
		else [map.greybox.get_node("ground")]

	for ground: MeshInstance3D in grounds:
		var arrays := (ground.mesh as ArrayMesh).surface_get_arrays(0)
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()

		if index.is_empty():
			index = PackedInt32Array(range(v.size()))

		for t in range(0, index.size(), 3):
			down += int((v[index[t + 1]] - v[index[t]]).cross(v[index[t + 2]] - v[index[t]]).y > 0.0)

		triangles += index.size() / 3

	_check("Z1b the ground faces up", down == 0 and triangles > 0, "%d of %d triangles face down" % [down, triangles])

	# Z2 the spawn stands on street ground, not in a plot
	await _frames(2)
	var spawn: Vector3 = map.spawn_point()
	var hit := _ray(spawn + Vector3(0, 3, 0), spawn + Vector3(0, -3, 0))
	var in_plot: bool = map.plan["plots"].any(func(p): return Geometry2D.is_point_in_polygon(Vector2(spawn.x, spawn.z), _poly(p["polygon"])))
	_check("Z2 the spawn stands on street ground", not hit.is_empty() and absf(hit["position"].y) < 0.05 and not in_plot,
		"spawn %s, hit %s, in a plot %s" % [spawn, hit.get("position"), in_plot])

	# Z2b the plaza is a pavement 0.2 up (its kerbs 0.2 proud of the ring)
	var pavement := [_ray(Vector3(50, 3, 50), Vector3(50, -3, 50)), _ray(Vector3(-60, 3, -40), Vector3(-60, -3, -40))]
	var on_pavement := pavement.all(func(h): return not h.is_empty() and absf(h["position"].y - 0.2) < 0.01)
	_check("Z2b the plaza stands 0.2 above the street", on_pavement, "%s" % [pavement.map(func(h): return h.get("position"))])

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
	var platform := _rect("platform_w")
	var well := _rect("well_nw")
	var walk := await _walk(Vector3(-90, 1.05, -106.5), PI, func(p): return p.z > well.end.y - 1.5, 600)
	_check("Z5 the player walks down a kiosk's stair into the station's well",
		walk["ok"] and absf(walk["end"].y - 1.05 + 8.0) < 0.5 and well.has_point(Vector2(walk["end"].x, walk["end"].z))
		and walk["lowest"] > -8.0 + 1.05 - 0.5,
		"%s" % [walk])

	# Z5b on from the well, never put anywhere: along the corridors into the
	#     ticket hall, then down to the west platform
	var legs := [
		[-PI / 2, func(p): return p.x > -87.5],      # east, off the stair's line
		[0.0, func(p): return p.z < -97.5],          # north on the well's floor, level with its corridor
		[-PI / 2, func(p): return p.x > -27.0],      # east along the first corridor
		[PI, func(p): return p.z > -12.0],           # south down the second, into the hall
		[PI, func(p): return p.z > -6.2],            # on, level with the platform stair
		[PI / 2, func(p): return p.x < -50.0],       # west, down to the platform
	]
	var route_ok := true
	var stops := []

	for leg in legs:
		walk = await _walk(map.player.global_position, leg[0], leg[1], 900)
		route_ok = route_ok and walk["ok"]
		stops.append(walk["end"])

	var hall := _rect("station_hall")
	_check("Z5b the player walks on from the well through the corridors into the ticket hall and down to a platform",
		route_ok and absf(stops[1].y - 1.05 + 8.0) < 0.5 and hall.has_point(Vector2(stops[3].x, stops[3].z))
		and absf(stops[3].y - 1.05 + 8.0) < 0.5
		and platform.has_point(Vector2(walk["end"].x, walk["end"].z)) and absf(walk["end"].y - 1.05 + 14.0) < 0.5,
		"stops %s" % [stops])

	# Z5c through the tunnel from the ticket hall to the crypt
	var crypt := _rect("crypt")
	walk = await _walk(Vector3(0, -8 + 1.05, -10), 0.0, func(p): return p.z < crypt.end.y - 3.0, 1800)
	_check("Z5c the player walks the tunnel from the ticket hall to the crypt",
		walk["ok"] and crypt.has_point(Vector2(walk["end"].x, walk["end"].z)) and absf(walk["end"].y - 1.05 + 8.0) < 0.5,
		"%s" % [walk])

	# Z5d across a bridge over the canal
	walk = await _walk(Vector3(-150, 1.05, 161.5), PI, func(p): return p.z > 185.0, 900)
	_check("Z5d the player crosses a bridge over the canal", walk["ok"] and walk["lowest"] > 0.9, "%s" % [walk])

	# Z6 from the street up the town hall's ladder on to its roof, along it
	#    and across the plank to the other roof (no teleport on to a roof)
	var climb := _route("climb_up_town_hall_w")
	var foot := Vector3(climb["points"][0][0], 1.05, climb["points"][0][2])
	var into := Vector3(climb["points"][1][0] - climb["points"][0][0], 0, climb["points"][1][2] - climb["points"][0][2])
	var up := await _walk(foot - into.normalized() * 0.6, atan2(-into.x, -into.z),
		func(p): return p.y > 14.5 and map.player.movement_state == map.player.MoveState.LOCOMOTION, 900)
	# To the plank's line (145), from whichever side the ladder came up.
	var north: bool = map.player.global_position.z > 145.0
	var along := await _walk(map.player.global_position, 0.0 if north else PI,
		func(p): return p.z < 145.2 if north else p.z > 144.8, 600)
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

	if map.dressing:
		await _dressed()


## The street and canal kit laid over the greybox (the kit's plan, Task 9),
## walked with the real player.
func _dressed() -> void:
	# Z8 every piece the dressing places is drawn, none of what it replaces is
	var counts := {}

	for p in map.dressing["pieces"]:
		counts[p["piece"]] = counts.get(p["piece"], 0) + 1

	var drawn := {}

	for mm: MultiMeshInstance3D in map.kit.find_children("*", "MultiMeshInstance3D", true, false):
		var piece: String = mm.get_meta("piece")
		drawn[piece] = drawn.get(piece, 0) + mm.multimesh.instance_count

	var left := (map.dressing["skip"] as Array).filter(func(n): return map.greybox.has_node(NodePath(n)))
	_check("Z8 the dressing loads: every piece drawn, the greybox it replaces gone", drawn == counts and left.is_empty(),
		"%d kinds placed, %d drawn, greybox left %s" % [counts.size(), drawn.size(), left])

	_ground_clear()
	await _street_life()
	await _scenes()

	# Z9 over a kerb from the street on to the plaza, away from a crossing
	var walk := await _walk(Vector3(6, 1.05, 115), 0.0, func(p): return p.z < 104.0, 600)
	_check("Z9 the player steps up a kerb on to the plaza", walk["ok"] and _floor(walk["end"]) > 0.15,
		"%s, floor %.3f" % [walk, _floor(walk["end"])])

	# Z10 through the south crossing's drop
	walk = await _walk(Vector3(0, 1.05, 115), 0.0, func(p): return p.z < 104.0, 600)
	_check("Z10 the player walks through a dropped kerb on to the plaza", walk["ok"] and _floor(walk["end"]) > 0.15,
		"%s, floor %.3f" % [walk, _floor(walk["end"])])

	# Z11 across the tram's south-east curve: never below the street, never stuck
	walk = await _walk(Vector3(105, 1.05, 100), PI, func(p): return p.z > 126.0, 900)
	_check("Z11 the player crosses a tram curve without falling or snagging", walk["ok"] and walk["lowest"] > 0.95
		and walk["stall"] < 18, "%s" % [walk])

	# Z12 over the stone bridge and the steel one, quay to quay, up to their crowns
	for b in [[-150.0, 0.6], [150.0, 0.3]]:
		walk = await _walk(Vector3(b[0], 1.05, 161.5), PI, func(p): return p.z > 187.0, 1200)
		var rest: float = walk["start"].y
		_check("Z12 the player crosses the bridge at x %d over its crown" % b[0], walk["ok"]
			and absf(walk["highest"] - rest - b[1]) < 0.1, "%s, rose %.2f" % [walk, walk["highest"] - rest])

	# Z13 from the quay over the west landing's wall on to its steps, down
	#     them to the landing, then down to the water
	walk = await _walk(Vector3(-62, 1.05, 160.75), -PI / 2, func(p): return p.x > -58.65, 300)
	walk = await _walk(map.player.global_position, PI, func(p): return p.z > 163.2, 600)
	var on_landing := _floor(walk["end"])
	walk = await _walk(map.player.global_position, -PI / 2, func(p): return p.x > -48.2, 600)
	walk = await _walk(map.player.global_position, PI, func(p): return p.z > 170.6, 600)
	var on_floor := _floor(walk["end"])
	_check("Z13 the player walks down a landing's steps and on down to the canal's floor", walk["ok"]
		and absf(on_landing + 1.0) < 0.05 and absf(on_floor + 2.0) < 0.05,
		"landing %.3f, canal %.3f, %s" % [on_landing, on_floor, walk])


## The street's life (the street-life plan, Task 7): lit, walked among.
func _street_life() -> void:
	# Z15 one light a lit lamp
	var lights: Array = map.kit.find_children("*", "OmniLight3D", true, false)
	_check("Z15 the Company's lamps are lit, one light each", lights.size() == map.dressing["lights"].size()
		and lights.size() > 40, "%d lights for %d lamps" % [lights.size(), map.dressing["lights"].size()])

	# Z16 round the Bound God, then down a market lane, never snagged
	var stall := 0
	var arrived := true
	map.player.global_position = Vector3(7.0 * cos(PI / 8), 1.25, 7.0 * sin(PI / 8))

	for k in 9:
		var a := PI / 8 + PI / 4 * (k + 1)
		var to := Vector3(7.0 * cos(a), 0, 7.0 * sin(a))
		var from: Vector3 = map.player.global_position
		var walk := await _walk(from, atan2(-(to.x - from.x), -(to.z - from.z)),
			func(p): return Vector2(p.x - to.x, p.z - to.z).length() < 0.7, 300)
		stall = maxi(stall, walk["stall"])
		arrived = arrived and walk["ok"]

	# (Down the lane's walkway, its middle kept clear of the scenes.)
	var lane := await _walk(Vector3(-50, 1.05, 207), PI, func(p): return p.z > 278.0, 1800)
	_check("Z16 the player walks round the god and down a market lane without snagging", arrived and lane["ok"]
		and stall < 18 and lane["stall"] < 18, "round stall %d, lane %s" % [stall, lane])

	# Z17 a pole stops the player; marigold petals do not
	var pole: Dictionary = map.dressing["pieces"].filter(func(p): return p["piece"] == "tram_pole")[0]
	var at := Vector3(pole["at"][0], pole["at"][1], pole["at"][2])
	var toward := await _walk(at + Vector3(3, 1.05, 0), PI / 2, func(p): return p.x < at.x - 1.0, 240)
	# (A heap clear of any pole: the ones under dead lamps lie beside them.)
	var poles: Array = map.dressing["pieces"].filter(func(p): return p["piece"].contains("pole") or p["piece"].contains("lamp"))
	var petal: Dictionary = {}

	# (The petals the god's devotees strew are the only ones; the ward lamps
	# ring the god 9 m out, clear of the walk across them.)
	for p in map.dressing["pieces"]:
		if p["piece"] != "petals_marigold":
			continue

		var clear := true

		for q in poles:
			clear = clear and Vector2(q["at"][0] - p["at"][0], q["at"][2] - p["at"][2]).length() > 2.5

		if clear:
			petal = p
			break

	var over := Vector3(petal["at"][0], petal["at"][1], petal["at"][2])
	var across := await _walk(over + Vector3(2.5, 1.05, 0), PI / 2, func(p): return p.x < over.x - 2.0, 300)
	_check("Z17 a pole stops the player, petals do not", not toward["ok"] and toward["end"].x > at.x + 0.2
		and across["ok"], "pole at %s, ended %s; petals %s" % [at, toward["end"], across])

	# Z18 lit at night, dark by day
	map.set_day(false)
	var lit := lights.all(func(l): return l.visible and l.light_energy > 0.0)
	map.set_day(true)
	var dark := lights.all(func(l): return not l.visible)
	_check("Z18 the lamps light at night and go out by day", lit and dark, "night %s, day %s" % [lit, dark])


## The scenes (the scenes plan, Task 6): their stand-ins and trees drawn,
## day and night swapped, a queue in the way, a night collider waiting for
## the player to step out, the ambient running, a stuttering lamp, the F1
## labels.
func _scenes() -> void:
	map.set_day(true)
	await _frames(2)
	var drawn := _drawn_figures()
	var by_day: int = map.dressing["stations"].filter(func(st): return st["when"] != "night").size()
	var trees := 0

	for draw: MultiMeshInstance3D in map.kit.find_children("*", "MultiMeshInstance3D", true, false):
		if String(draw.get_meta("piece", "")) in ["tree_ash", "tree_ash_young", "palm_canary", "tree_laurel", "tree_willow",
				"ahuehuete_split"]:
			trees += draw.multimesh.instance_count

	var planted: int = map.dressing["pieces"].filter(func(p): return p["piece"] in ["tree_ash", "tree_ash_young",
		"palm_canary", "tree_laurel", "tree_willow", "ahuehuete_split"]).size()
	_check("Z19 the scenes load: the day's stand-ins drawn, every tree", drawn == by_day and trees == planted and planted > 100,
		"%d drawn of %d stations by day; %d of %d trees" % [drawn, by_day, trees, planted])

	# Z20 night swaps the day's scenes for the night's, colliders and all
	var day_shapes: Array = map.kit.switched.filter(func(c): return c.get_meta("when") == "day")
	var night_shapes: Array = map.kit.switched.filter(func(c): return c.get_meta("when") == "night")
	map.player.global_position = Vector3(0, 1.05, 120)
	map.set_day(false)
	await _frames(3)
	var at_night := [_drawn_figures(), day_shapes.all(func(c): return c.disabled), night_shapes.all(func(c): return not c.disabled)]
	map.set_day(true)
	await _frames(3)
	var by_day_again := [_drawn_figures(), day_shapes.all(func(c): return not c.disabled), night_shapes.all(func(c): return c.disabled)]
	var by_night: int = map.dressing["stations"].filter(func(st): return st["when"] != "day").size()
	_check("Z20 night swaps the day's scenes for the night's, colliders too",
		at_night[0] == by_night and at_night[1] and at_night[2] and by_day_again[0] == by_day and by_day_again[1] and by_day_again[2],
		"night %s (%d stations), day %s" % [at_night, by_night, by_day_again])

	# Z21 a queue stops the player
	var scene_index := -1

	for k in map.dressing["scenes"].size():
		if map.dressing["scenes"][k]["name"] == "tamale_stop":
			scene_index = k
			break

	var queued: Dictionary = map.dressing["stations"].filter(func(st): return st["scene"] == scene_index and st["pose"] == "fig_queue")[0]
	var q := Vector3(queued["at"][0], queued["at"][1], queued["at"][2])
	var yaw := deg_to_rad(float(map.dressing["scenes"][scene_index]["yaw"]))
	var front := Vector3(sin(yaw), 0, cos(yaw))
	var start := q + front * 3.0 + Vector3(0, 1.05, 0)
	var into := await _walk(start, atan2(front.x, front.z), func(p): return Vector2(p.x - q.x, p.z - q.z).length() < 0.15, 240)
	_check("Z21 a queue stops the player short of it", not into["ok"] and Vector2(into["end"].x - q.x, into["end"].z - q.z).length() > 0.2,
		"queue at %s, ended %s" % [q, into["end"]])

	# Z22 a night collider over the player at nightfall waits till they step out
	var waiting: CollisionShape3D = night_shapes[0]
	map.player.global_position = waiting.global_position + Vector3(0, 0.2, 0)
	map.player.velocity = Vector3.ZERO
	map.set_day(false)
	await _frames(5)
	var held := waiting.disabled
	map.player.global_position = waiting.global_position + Vector3(4, 1.05, 4)
	await _frames(5)
	var on := not waiting.disabled
	map.set_day(true)
	await _frames(2)
	_check("Z22 a night collider over the player at nightfall waits till they step out", held and on,
		"held %s, then on %s" % [held, on])

	# Z23 the ambient runs at the god, forty at most
	map.player.global_position = Vector3(0, 1.25, 9.5)
	await _frames(30)
	var running: Array = map.ambient.running()
	var copal := running.any(func(i): return map.dressing["emitters"][i]["effect"] == "copal")
	_check("Z23 the ambient runs at the god (its copal), forty at most", copal and running.size() <= 40,
		"%d running, copal %s" % [running.size(), copal])

	# Z23b a stuttering lamp's light at night
	map.set_day(false)
	var lamp: OmniLight3D = map.kit.stuttering[0] if map.kit.stuttering.size() > 0 else null
	var lo := INF
	var hi := -INF

	for i in 300:
		await get_tree().process_frame

		if lamp:
			lo = minf(lo, lamp.light_energy)
			hi = maxf(hi, lamp.light_energy)

	map.set_day(true)
	_check("Z23b a stuttering lamp's light wavers at night", lamp != null and hi - lo > 0.3,
		"%d stuttering, energy %.2f..%.2f" % [map.kit.stuttering.size(), lo, hi])

	# Z25 by day the volumetric fog runs, at no density: the seeped mist and
	# the copal's haze (fog volumes) draw by day too
	var day_env: Environment = map._day
	_check("Z25 by day the volumetric fog runs at no density", day_env.volumetric_fog_enabled
		and day_env.volumetric_fog_density == 0.0, "on %s, density %.3f" % [day_env.volumetric_fog_enabled, day_env.volumetric_fog_density])
	# Z25b at night the fog reaches over the sky: the lamps' halos show
	# against it (at none they drew only where a wall stood behind)
	var night_env: Environment = map._night
	_check("Z25b at night the lamps' halos show against the sky", night_env.volumetric_fog_sky_affect >= 0.4,
		"sky affect %.2f" % night_env.volumetric_fog_sky_affect)

	# Z24 F1 labels the scenes near; F1 again takes them away
	var key := InputEventKey.new()
	key.keycode = KEY_F1
	key.pressed = true
	map._unhandled_input(key)
	await _frames(2)
	var group: Node = map.get_node_or_null("labels")
	var labels: Array = group.get_children() if group else []
	var named := labels.any(func(l): return (l as Label3D).text.begins_with("god_devotion"))
	map._unhandled_input(key)
	await _frames(2)
	var gone: bool = map.get_node_or_null("labels") == null
	_check("Z24 F1 labels the scenes with their stories, F1 again hides them", named and gone,
		"%d labels, the god's %s, gone %s" % [labels.size(), named, gone])


## The stand-ins drawn now: the instances of the visible figure draws.
func _drawn_figures() -> int:
	var out := 0

	for draw: MultiMeshInstance3D in map.kit.find_children("*", "MultiMeshInstance3D", true, false):
		var piece := String(draw.get_meta("piece", ""))

		if (piece.begins_with("fig_") or piece.begins_with("dog_")) and draw.visible:
			out += draw.multimesh.instance_count

	return out


## Z14 no ground over a flush piece or in an opening, at the ground's own
## level: every chunk's triangles against its area's rectangular inlays and
## openings (bucketed by 10 m).
func _ground_clear() -> void:
	var over := 0
	var area_of := {}

	for a in map.dressing["ground"]["areas"].size():
		var area: Dictionary = map.dressing["ground"]["areas"][a]
		var buckets := {}

		# (Axis-aligned rectangles only: a turned one's box is more than it.)
		for r in area["openings"] + area["inlays"].filter(_axis_aligned).map(_rect_of):
			var rect := Rect2(r[0], r[1], r[2] - r[0], r[3] - r[1]).grow(-1e-3)

			for i in range(floori(rect.position.x / 10.0), floori(rect.end.x / 10.0) + 1):
				for j in range(floori(rect.position.y / 10.0), floori(rect.end.y / 10.0) + 1):
					var key := Vector2i(i, j)
					buckets[key] = buckets.get(key, []) + [rect]

		area_of[a] = buckets

	for chunk: Node in map.district_ground.get_children():
		var a := int(String(chunk.name).split("_")[-3])
		var arrays := ((chunk.get_node("mesh") as MeshInstance3D).mesh as ArrayMesh).surface_get_arrays(0)
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]

		for t in range(0, index.size(), 3):
			var c := (v[index[t]] + v[index[t + 1]] + v[index[t + 2]]) / 3.0
			var at := Vector2(c.x, c.z)

			for rect: Rect2 in area_of[a].get(Vector2i(floori(c.x / 10.0), floori(c.z / 10.0)), []):
				if rect.has_point(at):
					over += 1
					break

	_check("Z14 no ground lies over a flush piece or in an opening", over == 0, "%d triangles" % over)


func _axis_aligned(points: Array) -> bool:
	if points.size() != 4:
		return false

	var r := _rect_of(points)

	for p in points:
		var on_x: bool = is_equal_approx(p[0], r[0]) or is_equal_approx(p[0], r[2])
		var on_z: bool = is_equal_approx(p[1], r[1]) or is_equal_approx(p[1], r[3])

		if not (on_x and on_z):
			return false

	return true


func _rect_of(points: Array) -> Array:
	var xs := points.map(func(p): return p[0])
	var zs := points.map(func(p): return p[1])
	return [xs.min(), zs.min(), xs.max(), zs.max()]


## The floor's height under a point.
func _floor(at: Vector3) -> float:
	var hit := _ray(at + Vector3(0, 0.5, 0), at + Vector3(0, -4, 0))
	return hit["position"].y if not hit.is_empty() else -INF


## The player put at `start` facing `yaw` (0 north), walked forward until
## `done` holds of their position or `frames` pass: where they ended, the
## lowest they went, whether they arrived standing.
func _walk(start: Vector3, yaw: float, done: Callable, frames: int) -> Dictionary:
	var player: CharacterBody3D = map.player
	player.global_position = start
	player.rotation.y = yaw
	player.velocity = Vector3.ZERO
	await _frames(10)
	var rest := player.global_position
	Input.action_press("move_forward")
	var lowest := player.global_position.y
	var highest := player.global_position.y
	var arrived := false
	# The most frames in a row it barely moved (snagged on something).
	var stall := 0
	var still := 0
	var last := player.global_position

	for i in frames:
		await get_tree().physics_frame
		lowest = minf(lowest, player.global_position.y)
		highest = maxf(highest, player.global_position.y)
		still = still + 1 if player.global_position.distance_to(last) < 0.005 else 0
		stall = maxi(stall, still)
		last = player.global_position

		if done.call(player.global_position):
			arrived = true
			break

	Input.action_release("move_forward")
	await _frames(20)
	return {"ok": arrived and player.is_on_floor(), "end": player.global_position, "lowest": lowest, "highest": highest,
		"stall": stall, "start": rest}


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
