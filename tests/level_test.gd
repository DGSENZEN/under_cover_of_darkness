extends Node3D
## Levels built with the kit (tools/level) put together in Godot
## (scripts/Level): the fixture level (tools/level/layouts/fixture.py), then
## the garrison.
##   Godot --headless --fixed-fps 60 --path . res://tests/level_test.tscn

const AtmosphereScript := preload("res://scripts/Visual/Atmosphere.gd")
const LevelLoader := preload("res://scripts/Level/LevelLoader.gd")
const Materials := preload("res://scripts/Visual/Materials.gd")
const GARRISON := preload("res://maps/garrison.tscn")
const MapScript := preload("res://maps/npc_showcase.gd")
const SoundBus := preload("res://scripts/StimuliSystem/SoundBus.gd")
const LevelGameplay := preload("res://scripts/Level/LevelGameplay.gd")
const NavBakerScript := preload("res://scripts/AISystem/NavBaker.gd")
const TemperamentScript := preload("res://scripts/AISystem/Temperament.gd")
const GUARD := preload("res://Guard.tscn")
## The harbour's photo slots (tools/textures/recipes), K10.
const HARBOUR_PHOTO_SLOTS := [&"granite", &"granite_rough", &"ashlar_gold", &"render_ochre", &"render_salmon", &"render_blue",
	&"render_straw", &"whitewash", &"azulejo_green", &"azulejo_cube", &"azulejo_blue", &"azulejo_blue2", &"azulejo_border",
	&"waterline_tide", &"waterline_algae", &"calcada", &"terracotta", &"terracotta_hex", &"roof_spanish", &"brick", &"rock",
	&"cliff", &"hull_tarred", &"hull_bare", &"sailcloth", &"rope_lay", &"rope_coil", &"net", &"manueline"]

var results: Array[String] = []


## A listener that keeps every sound it hears (K9).
class Ear:
	extends RefCounted
	var heard: Array = []

	func hear_sound(event: Dictionary) -> void:
		heard.append(event)


func _ready() -> void:
	await _fixture()
	await _gameplay()
	await _garrison()
	print("\n==== RESULTS ====")

	for r in results:
		print(r)

	get_tree().quit()


func _fixture() -> void:
	var environment := Environment.new()
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var level: RefCounted = LevelLoader.load_level(self, "res://assets/level/fixture")
	await _frames(3)

	# K1 its sectors, drawn in their slots' materials
	var meshes: Array = level.root.find_children("*", "MeshInstance3D", true, false)
	var dressed: bool = meshes.any(func(m): return range((m as MeshInstance3D).get_surface_override_material_count()).any(
		func(i): return (m as MeshInstance3D).get_surface_override_material(i) == Materials.level_surface(&"cobble")))
	_check("K1 the level's sectors come in, their surfaces in their slots' materials",
		level.sectors.has("yard") and level.sectors.has("room") and meshes.size() >= 2 and dressed,
		"sectors %s, meshes %d, cobble dressed %s" % [level.sectors.keys(), meshes.size(), dressed])

	# K2 floors say what they are underfoot
	var yard_floor := _ray(Vector3(1, 2, 1), Vector3(1, -1, 1))
	var room_floor := _ray(Vector3(1, 2, -8.6), Vector3(1, -1, -8.6))
	_check("K2 a foot on the yard's cobbles is on stone, on the room's boards on wood",
		_surface(yard_floor) == "stone" and _surface(room_floor) == "wood", "yard %s, room %s" % [_surface(yard_floor), _surface(room_floor)])

	# K3 a wall stands in the way; its doorway does not
	var walled := _ray(Vector3(-3, 1.2, -4), Vector3(-3, 1.2, -8))
	var doorway := _ray(Vector3(0, 1.2, -4), Vector3(0, 1.2, -8))
	_check("K3 the wall blocks, its doorway lets through", not walled.is_empty() and doorway.is_empty(), "wall hit %s, doorway hit %s" % [not walled.is_empty(), not doorway.is_empty()])

	# K4 every marker comes through: its own kinds made, the rest handed on
	var vantages := get_tree().get_nodes_in_group(&"cine_vantage")
	var hides := get_tree().get_nodes_in_group(&"hide_spot")
	var areas := get_tree().get_nodes_in_group(&"hunt_area")
	var guard: Dictionary = level.get_marker("Hendrik")
	var bench: Dictionary = level.get_marker("bench_seat")
	var facing: Vector3 = -(bench["transform"] as Transform3D).basis.z if not bench.is_empty() else Vector3.ZERO
	var ok4: bool = vantages.size() == 1 and StringName((vantages[0] as Node).get_meta(&"lens", &"")) == &"long" and hides.size() == 1 \
		and areas.size() == 1 and ((areas[0] as Node).get_meta(&"box") as AABB).has_point(Vector3(3, 1, 3)) and level.marks.has("well_spot") \
		and level.marks.has("start") and guard.get("props", {}).get("archetype") == "watchman" and guard["props"].get("route") == "yard_round" \
		and bench.get("props", {}).get("kind") == "sit" and facing.distance_to(Vector3(0, 0, 1)) < 0.01 and level.of("waypoint").size() == 2
	_check("K4 the markers come through: vantages, hide spots, hunt areas and marks made; guards, stations and routes handed on",
		ok4, "vantages %d, hides %d, areas %d, marks %s, bench faces %s" % [vantages.size(), hides.size(), areas.size(), level.marks.keys(), facing])

	# K5 an atmosphere zone: the camera in it eases its grade in
	var camera := Camera3D.new()
	add_child(camera)
	camera.make_current()
	camera.global_position = Vector3(0, 1.6, 3)
	await _seconds(1.5)
	var outside: String = level.zones.current
	camera.global_position = Vector3(0, 1.6, -8.6)
	await _seconds(0.3)
	var partway := float(level.zones.look()["saturation"])
	await _seconds(2.5)
	var inside: String = level.zones.current
	var saturation := environment.adjustment_saturation
	_check("K5 the camera walking into a zone eases its grade in (indoors: warm, saturation 1.05)",
		outside == "outside" and inside == "indoors" and absf(saturation - 1.05) < 0.01 and partway < 1.04 and environment.adjustment_color_correction != null,
		"outside %s, inside %s, saturation %.3f (after 0.3 s %.3f)" % [outside, inside, saturation, partway])

	# K6 the bank beside the yard is terrain: solid, gravel underfoot
	var bank_hit := _ray(Vector3(10, 5, 0), Vector3(10, -5, 0))
	var bank_y: float = (bank_hit["position"] as Vector3).y if not bank_hit.is_empty() else -99.0
	_check("K6 the fixture's bank is solid terrain: a ray down onto it hits gravel at its height",
		_surface(bank_hit) == "gravel" and absf(bank_y - 1.0) < 0.05, "surface %s, height %.3f" % [_surface(bank_hit), bank_y])

	# K7 its collider is the mesh it is drawn with
	var bank_body := level.root.find_child("terrain_bank", true, false) as StaticBody3D
	var bank_mesh := level.root.find_child("bank", true, false) as MeshInstance3D
	var shape_faces := 0
	var mesh_faces := 0
	var same_box := false

	if bank_body != null and bank_mesh != null:
		var concave := (bank_body.get_child(0) as CollisionShape3D).shape as ConcavePolygonShape3D
		shape_faces = concave.get_faces().size() / 3 if concave != null else 0

		for s in bank_mesh.mesh.get_surface_count():
			mesh_faces += (bank_mesh.mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3

		var drawn := bank_mesh.global_transform * bank_mesh.get_aabb()
		var solid := AABB()

		if concave != null:
			var faces := concave.get_faces()
			var to_world := (bank_body.get_child(0) as CollisionShape3D).global_transform
			solid = AABB(to_world * faces[0], Vector3.ZERO)

			for p in faces:
				solid = solid.expand(to_world * p)

		same_box = drawn.position.distance_to(solid.position) < 0.01 and drawn.size.distance_to(solid.size) < 0.01

	_check("K7 the terrain's collider is its drawn mesh", bank_body != null and shape_faces > 0 and shape_faces == mesh_faces and same_box,
		"body %s, shape faces %d, mesh faces %d, same box %s" % [bank_body != null, shape_faces, mesh_faces, same_box])
	level.root.queue_free()
	camera.queue_free()
	await _frames(2)

	# K8 two levels side by side: their own roots, sectors and colliders,
	# one set of zones between them
	var holder := Node3D.new()
	add_child(holder)
	var level_a: RefCounted = LevelLoader.load_level(holder, "res://assets/level/fixture", "fixture_a")
	var level_b: RefCounted = LevelLoader.load_level(holder, "res://assets/level/fixture", "fixture_b")
	await _frames(2)
	var bodies_a: Array = level_a.root.find_children("*", "StaticBody3D", true, false)
	var bodies_b: Array = level_b.root.find_children("*", "StaticBody3D", true, false)
	var ok8: bool = level_a.root.name == "fixture_a" and level_b.root.name == "fixture_b" and level_a.sectors.has("yard") \
		and level_b.sectors.has("room") and not bodies_a.is_empty() and bodies_a.size() == bodies_b.size() \
		and not bodies_a.any(func(b): return bodies_b.has(b)) and level_b.of("guard").size() == 1 \
		and level_a.zones != null and level_a.zones == level_b.zones and holder.find_children("*", "", true, false).filter(func(n): return n.name == "Zones").size() == 1
	_check("K8 two levels load side by side under their own roots, their zones shared", ok8,
		"roots %s %s, bodies %d %d, guards %d, zones shared %s" % [level_a.root.name, level_b.root.name, bodies_a.size(), bodies_b.size(),
			level_b.of("guard").size(), level_a.zones == level_b.zones])
	holder.queue_free()
	world.queue_free()
	await _frames(2)

	# K9 a noise zone masks what is made inside it
	var ear := Ear.new()
	SoundBus.add_listener(ear)
	var zone := SoundBus.add_zone(AABB(Vector3(-2, -1, -2), Vector3(4, 3, 4)), 40.0)
	SoundBus.emit_sound(Vector3(0, 0, 0), 50.0, null, &"test")
	var inside_range: float = ear.heard[-1]["range"] if not ear.heard.is_empty() else -1.0
	SoundBus.emit_sound(Vector3(10, 0, 0), 50.0, null, &"test")
	var outside_range: float = ear.heard[-1]["range"] if ear.heard.size() > 1 else -1.0
	SoundBus.remove_zone(zone)
	SoundBus.emit_sound(Vector3(0, 0, 0), 50.0, null, &"test")
	var after_range: float = ear.heard[-1]["range"] if ear.heard.size() > 2 else -1.0
	SoundBus.remove_listener(ear)
	SoundBus.clear_zones()
	_check("K9 a noise zone masks what is made inside it (and nothing once it is gone)",
		absf(inside_range - SoundBus.range_for(10.0)) < 0.01 and absf(outside_range - SoundBus.range_for(50.0)) < 0.01
		and absf(after_range - SoundBus.range_for(50.0)) < 0.01,
		"inside %.2f m, outside %.2f m, after %.2f m" % [inside_range, outside_range, after_range])

	# K10 a fresh clone (no bought photos): every harbour slot in its flat
	# colour, nothing missing
	var photos_at: String = Materials.folder
	Materials.folder = "res://no_photos_here/"
	Materials.clear_cache()
	var bare10: Array = []

	for slot in HARBOUR_PHOTO_SLOTS:
		var entry: Dictionary = Materials.SLOTS.get(slot, {})
		var drawn := Materials.level_surface(slot) as StandardMaterial3D

		if entry.is_empty() or drawn == null or drawn.albedo_texture != null or not drawn.albedo_color.is_equal_approx(entry["colour"]):
			bare10.append(slot)

	Materials.folder = photos_at
	Materials.clear_cache()
	_check("K10 with no photos on the machine every harbour slot draws in its flat colour", bare10.is_empty(), "wrong: %s" % [bare10])

	# K11 the waterline's photo is anchored to the sea: its top row at 1.4 m
	var tide := Materials.level_surface(&"waterline_tide") as StandardMaterial3D
	var tile11: Array = Materials.SLOTS[&"waterline_tide"]["tile"]
	var v11 := -(1.4 * tide.uv1_scale.y + tide.uv1_offset.y)
	_check("K11 a waterline band is anchored to the sea: its photo's top row falls at y 1.4 on a quay face",
		absf(v11 - roundf(v11)) < 0.0001 and is_equal_approx(tide.uv1_scale.x, 1.0 / float(tile11[0])) and is_equal_approx(tide.uv1_scale.y, 1.0 / float(tile11[1])),
		"v at 1.4 m %.4f, scale %s" % [v11, tide.uv1_scale])

	# K12 our own paintings for the harbour are all here
	var missing12: Array = []

	for slot in [&"iron_rail", &"window_grille", &"ratlines", &"palm_frond", &"cypress", &"agave", &"orange_leaves"]:
		if Materials.photo(slot) == null:
			missing12.append(slot)

	if Materials.picture("decal_salt") == null:
		missing12.append("decal_salt")

	_check("K12 every new painted slot finds its painting (and the salt decal its picture)", missing12.is_empty(), "missing %s" % [missing12])


## The fixture's markers made into the game's nodes by LevelGameplay (any
## level's, not the garrison's own map).
func _gameplay() -> void:
	var was_rolling: bool = TemperamentScript.rolling
	TemperamentScript.rolling = false
	var environment := Environment.new()
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var holder := Node3D.new()
	holder.name = "Gameplay"
	add_child(holder)
	var level: RefCounted = LevelLoader.load_level(holder, "res://assets/level/fixture", "gameplay")
	var made: Dictionary = LevelGameplay.build_all(holder, level)
	var baker := NavigationRegion3D.new()
	baker.set_script(NavBakerScript)
	baker.bake_bounds = AABB(Vector3(-8.0, -2.0, -12.0), Vector3(24.0, 8.0, 20.0))
	holder.add_child(baker)
	await baker.baked
	await _frames(2)

	# K13 every new marker is made into its node
	var pickups: Dictionary = made["pickups"]
	var purse: Node = pickups.get("purse")
	var key: Node = pickups.get("room_key")
	var flask: Node = pickups.get("flask_1")
	var chest: Node = made["chests"].get("strongbox")
	var ok13: bool = purse != null and int(purse.get("value")) == 25 and key != null and StringName(key.get("key_id")) == &"room" \
		and flask != null and int(flask.get("count")) == 2 and chest != null and bool(chest.get("locked")) and not bool(chest.get("pickable")) \
		and made["props"].size() == 1 and made["ropes"].size() == 1 and made["noise_zones"].size() == 1 and made["mechanisms"].size() == 1 \
		and get_tree().get_nodes_in_group(&"district_exit").size() == 1 and get_tree().get_nodes_in_group(&"probe").size() == 1
	_check("K13 every marker of the fixture is made into its node by LevelGameplay", ok13,
		"pickups %s, chest %s, props %d, ropes %d, noise %d, mechanisms %d, exits %d, probes %d" % [pickups.keys(), chest != null,
			made["props"].size(), made["ropes"].size(), made["noise_zones"].size(), made["mechanisms"].size(),
			get_tree().get_nodes_in_group(&"district_exit").size(), get_tree().get_nodes_in_group(&"probe").size()])

	# K14 the portcullis stub: down it bars the way, up it does not
	var bars: Node3D = made["mechanisms"][0]
	var down14 := not _ray(Vector3(0, 1.0, 4.5), Vector3(0, 1.0, 6.5)).is_empty()
	LevelGameplay.raise(bars, true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var up14 := _ray(Vector3(0, 1.0, 4.5), Vector3(0, 1.0, 6.5)).is_empty()
	_check("K14 a portcullis down bars the way; raised, it lets through", down14 and up14, "down blocks %s, up clear %s" % [down14, up14])

	# K15 a guard made by LevelGameplay walks his route
	var guards: Dictionary = LevelGameplay.guards(holder, level, made["routes"], made["stations"], GUARD)
	var hendrik: Node3D = guards.get("Hendrik")
	var reached := [false]

	if hendrik != null:
		await _until(func(): return hendrik.global_position.distance_to(Vector3(4, 0, 3)) < 1.2, 1200)
		reached[0] = hendrik.global_position.distance_to(Vector3(4, 0, 3)) < 1.2

	_check("K15 a guard from LevelGameplay walks his route to its second point", reached[0],
		"guard %s at %s" % [hendrik != null, hendrik.global_position if hendrik != null else Vector3.INF])

	# K16 walking into an exit's box is seen
	var exit: Area3D = get_tree().get_nodes_in_group(&"district_exit")[0]
	var entered := [false]
	exit.body_entered.connect(func(_body): entered[0] = true)
	var walker := CharacterBody3D.new()
	var capsule := CollisionShape3D.new()
	capsule.shape = CapsuleShape3D.new()
	walker.add_child(capsule)
	holder.add_child(walker)
	walker.global_position = Vector3(-8, 1, -4)
	await get_tree().physics_frame
	walker.global_position = Vector3(-4, 1, -4)

	for i in 4:
		await get_tree().physics_frame

	_check("K16 walking into an exit's box is seen, its label on it", entered[0] and String(exit.get_meta(&"label", "")) == "the way out",
		"entered %s, label %s" % [entered[0], exit.get_meta(&"label", "")])
	holder.queue_free()
	world.queue_free()
	SoundBus.clear_zones()
	TemperamentScript.rolling = was_rolling
	await _frames(3)


func _garrison() -> void:
	MapScript.run_show = false
	var map: Node3D = GARRISON.instantiate()
	add_child(map)
	var frames := [0]

	while not (map.get("_baker") != null and map._baker.is_baked) and frames[0] < 3600:
		await get_tree().process_frame
		frames[0] += 1

	await _frames(30)

	# G1 the garrison builds, bakes and is peopled
	_check("G1 the garrison builds, its navmesh bakes and its twelve are at their places",
		map._baker.is_baked and map.cast.size() == 12, "baked %s after %d frames, cast %d" % [map._baker.is_baked, frames[0], map.cast.size()])

	# G18 nobody walks the ceilings under the pitched roofs (the barracks',
	# the chapel's): no navmesh up there
	var ceilings18 := []

	for at in [Vector3(22.0, 6.4, 0.0), Vector3(18.0, 6.4, -14.0), Vector3(4.0, 12.4, -20.8)]:
		var near18 := NavigationServer3D.map_get_closest_point(map.get_world_3d().navigation_map, at)

		if near18.distance_to(at) < 1.0:
			ceilings18.append("navmesh at %s" % near18.snapped(Vector3.ONE * 0.1))

	_check("G18 nobody walks the ceilings under the pitched roofs", ceilings18.is_empty(), "%s" % [ceilings18])

	# G23 nor the tops of small things (a sack pile, a barrel, a crate, a
	# bench): no navmesh up there for a man to be routed over (a 0.5 m top is
	# a climb, never a step)
	var tops23 := []
	var nav23: RID = map.get_world_3d().navigation_map

	for at in [Vector3(-22.0, 0.7, 2.0), Vector3(-21.2, 1.1, 7.0), Vector3(-28.5, 0.9, 0.0), Vector3(27.8, 1.1, -14.2), Vector3(22.0, 0.7, -3.9)]:
		var near23 := NavigationServer3D.map_get_closest_point(nav23, at)

		if near23.distance_to(at) < 0.5:
			tops23.append("navmesh at %s" % near23.snapped(Vector3.ONE * 0.1))

	_check("G23 no navmesh on the tops of small things (sacks, barrels, crates, benches)", tops23.is_empty(), "%s" % [tops23])

	# G2 every man's place, station, hiding spot and round is on the navmesh
	# and reachable from the courtyard
	var nav_map: RID = map.get_world_3d().navigation_map
	var start := NavigationServer3D.map_get_closest_point(nav_map, Vector3(0, 0, 10))
	var level: RefCounted = map.level
	var lost := []

	for m in level.markers:
		if not (m["ucd"] in ["station", "hide", "guard", "waypoint"]):
			continue

		var at: Vector3 = (m["transform"] as Transform3D).origin
		var on := NavigationServer3D.map_get_closest_point(nav_map, at)

		if on.distance_to(at) > 0.8:
			lost.append("%s off the mesh (%.1f m)" % [m["name"], on.distance_to(at)])
			continue

		var path := NavigationServer3D.map_get_path(nav_map, start, on, true)

		if path.is_empty() or path[path.size() - 1].distance_to(on) > 0.8:
			lost.append("%s unreachable (the way ends at %s)" % [m["name"], path[path.size() - 1].snapped(Vector3.ONE * 0.1) if not path.is_empty() else "nowhere"])

	_check("G2 every post, station, hiding place and round point is on the navmesh and reachable from the courtyard",
		lost.is_empty(), "%s" % [lost.slice(0, 12)])

	# G25 a man's way keeps his shoulders off the walls: along the ways
	# between the stations (each to the next three), a sphere the width of
	# his shoulders at their height brushes a wall at under 1% of points
	var stations25 := []

	for m in level.markers:
		if m["ucd"] == "station":
			stations25.append(NavigationServer3D.map_get_closest_point(nav_map, (m["transform"] as Transform3D).origin))

	var shoulders25 := SphereShape3D.new()
	shoulders25.radius = 0.36
	var query25 := PhysicsShapeQueryParameters3D.new()
	query25.shape = shoulders25
	query25.collision_mask = 1
	var space25 := map.get_world_3d().direct_space_state
	var points25 := 0
	var brushes25 := 0
	var where25 := {}

	for i in stations25.size():
		for k in range(1, 4):
			var way25 := NavigationServer3D.map_get_path(nav_map, stations25[i], stations25[(i + k) % stations25.size()], true)

			for j in range(1, way25.size()):
				var leg25: Vector3 = way25[j] - way25[j - 1]
				var steps25 := int(leg25.length() / 0.25)

				for s in steps25:
					var p25: Vector3 = way25[j - 1] + leg25 * (float(s) / float(steps25))
					query25.transform = Transform3D(Basis(), p25 + Vector3.UP * 1.25)
					points25 += 1

					for hit in space25.intersect_shape(query25, 4):
						if hit["collider"] is StaticBody3D and not (hit["collider"] as Node).is_in_group(&"nav_ignore"):
							brushes25 += 1
							where25[Vector3i(p25.round())] = true
							break

	_check("G25 a man's way keeps his shoulders off the walls (under 1% of its points brush one)",
		points25 > 1000 and brushes25 <= points25 * 0.01, "%d of %d points (%.1f%%), at %s" % [brushes25, points25, 100.0 * brushes25 / maxf(points25, 1.0), where25.keys().slice(0, 8)])

	# G26 no floor on the navmesh that nobody can reach from the courtyard
	# (a house's roof, the far bank): a man asked for the nearest floor to a
	# point is never sent up there
	var unreached26 := {}
	var land26: NavigationMesh = map._baker.navigation_mesh
	var corners26 := land26.get_vertices()

	for i in land26.get_polygon_count():
		var middle26 := Vector3.ZERO

		for index in land26.get_polygon(i):
			middle26 += corners26[index]

		middle26 = map._baker.global_transform * (middle26 / float(land26.get_polygon(i).size()))

		# (Through any doorway, locked ones too: the man with the key gets there.)
		if not _reaches(nav_map, start, middle26, 0xFFFFFFFF) and not _reaches(nav_map, middle26, start, 0xFFFFFFFF):
			unreached26[Vector3i((middle26 / 4.0).round() * 4.0)] = true

	_check("G26 no floor on the navmesh that nobody can reach from the courtyard", unreached26.is_empty(),
		"%d places, about %s" % [unreached26.size(), unreached26.keys().slice(0, 10)])

	# G28 every flight of stairs is walked, not climbed: from before its foot
	# to past its head the way keeps to the navmesh (no link: no scramble up
	# a missing step, no leap across to the walk), and gets there (the
	# tower's steep flights between its corner landings, the wall's onto the
	# walk, the barracks', the chapel loft's, the cellar's)
	var flights28 := [[Vector3(-28.2, 0.0, -25.6), 180.0, 3.0, 3.0], [Vector3(-29.4, 3.0, -29.8), -90.0, 3.0, 3.0], [Vector3(-33.8, 6.0, -28.6), 0.0, 3.0, 3.0],
		[Vector3(-32.4, 9.0, -24.2), 90.0, 3.0, 3.0], [Vector3(-15.4, 0.0, 25.3), 90.0, 7.5, 5.0, Vector3(-7.5, 5.0, 26.9)], [Vector3(15.4, 0.0, 25.3), -90.0, 7.5, 5.0, Vector3(7.5, 5.0, 26.9)],
		[Vector3(22.5, 0.0, -18.0), -90.0, 4.5, 3.0], [Vector3(22.5, 0.0, 16.0), -90.0, 4.5, 3.0], [Vector3(7.6, 0.0, -17.2), 90.0, 4.5, 3.0],
		[Vector3(-27.0, -3.0, 10.0), 180.0, 4.5, 3.0]]
	var climbed28 := []

	for flight in flights28:
		var way28 := Vector3(sin(deg_to_rad(flight[1])), 0.0, cos(deg_to_rad(flight[1])))
		var foot28: Vector3 = flight[0] - way28 * 0.7
		# (Past its head, or onto the walk it gives on to.)
		var head28: Vector3 = flight[4] if flight.size() > 4 else flight[0] + way28 * (float(flight[2]) + 0.7) + Vector3.UP * float(flight[3])
		var query28 := NavigationPathQueryParameters3D.new()
		query28.map = nav_map
		query28.start_position = NavigationServer3D.map_get_closest_point(nav_map, foot28)
		query28.target_position = NavigationServer3D.map_get_closest_point(nav_map, head28)
		query28.metadata_flags = NavigationPathQueryParameters3D.PATH_METADATA_INCLUDE_TYPES
		var result28 := NavigationPathQueryResult3D.new()
		NavigationServer3D.query_path(query28, result28)
		var path28 := result28.path
		var linked28: bool = Array(result28.path_types).has(NavigationPathQueryResult3D.PATH_SEGMENT_TYPE_LINK)
		var there28: bool = not path28.is_empty() and path28[path28.size() - 1].distance_to(head28) < 0.8 and query28.target_position.distance_to(head28) < 0.8

		if linked28 or not there28:
			climbed28.append("%s: %s" % [flight[0], "a link on it" if linked28 else "never gets up (ends %s)" % (path28[path28.size() - 1].snapped(Vector3.ONE * 0.1) if not path28.is_empty() else "nowhere")])

	_check("G28 every flight of stairs is walked foot to head, never climbed", climbed28.is_empty(), "%s" % [climbed28])

	# G3 its doors, its lights
	var doors := get_tree().get_nodes_in_group(&"doors")
	var torches := get_tree().get_nodes_in_group(&"torches")
	_check("G3 every door is made (20), and the lights are lit (torches and the rest)",
		doors.size() == 20 and torches.size() >= 20 and map.fire != null, "doors %d, torches %d, fire %s" % [doors.size(), torches.size(), map.fire != null])

	# G4 a zone: the camera in the chapel is in its red and gold
	var camera := Camera3D.new()
	add_child(camera)
	camera.make_current()
	camera.global_position = Vector3(4, 1.7, -20.8)
	await _seconds(2.5)
	_check("G4 the camera in the chapel is in the chapel's grade", level.zones.current == "chapel", "grade %s" % level.zones.current)

	# G14 the level is drawn in its slots' level materials: stone, plaster,
	# floors and roofs mapped to the world at their slot's size (no seams from
	# piece to piece), each with its photo when the photo is on this machine,
	# its flat colour when not; leaves cut out where the photo is
	var drawn14 := {}
	var wrong14 := []

	for mesh in level.root.find_children("*", "MeshInstance3D", true, false):
		for i in (mesh as MeshInstance3D).get_surface_override_material_count():
			var material := (mesh as MeshInstance3D).get_surface_override_material(i) as StandardMaterial3D

			if material != null:
				drawn14[material] = true

	for slot in [&"ashlar", &"plaster", &"cobble", &"boards", &"slate"]:
		var material: StandardMaterial3D = Materials.level_surface(slot)
		var tile: float = float(Materials.SLOTS[slot]["tile"])
		var textured: bool = Materials.photo(slot) != null

		if not drawn14.has(material):
			wrong14.append("%s not used" % slot)
		elif not (material.uv1_triplanar and material.uv1_world_triplanar and is_equal_approx(material.uv1_scale.x, 1.0 / tile)):
			wrong14.append("%s not world-mapped at %.1f m" % [slot, tile])
		elif textured != (material.albedo_texture != null):
			wrong14.append("%s photo %s, texture %s" % [slot, textured, material.albedo_texture != null])

	var leaves14: StandardMaterial3D = Materials.level_surface(&"leaves")
	var cut14: bool = leaves14.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR or Materials.photo(&"leaves") == null
	_check("G14 the level is drawn in its slots' level materials, mapped to the world at each slot's size, photo or flat colour, leaves cut out",
		wrong14.is_empty() and cut14 and drawn14.size() >= 8, "%s, leaves cut %s, materials %d" % [wrong14, cut14, drawn14.size()])

	# G15 the chapel's glass: every lancet glazed with the stained glass
	# (glowing, as moonlit), the moonlight's shafts projecting it when the
	# photo is here; reliefs on its walls
	var glass15: StandardMaterial3D = Materials.level_surface(&"stained_glass")
	var panes15: int = level.root.find_children("glass_lancet*", "", true, false).size()
	var reliefs15: int = level.root.find_children("relief_*", "", true, false).size()
	# (Drawn unlit, as the PS2 drew glass: its own colours, whatever shines on it.)
	var glows15: bool = glass15.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED
	var photo15: bool = Materials.photo(&"stained_glass") != null
	var cast15: bool = get_tree().get_nodes_in_group(&"glass_shafts").all(func(l): return ((l as Light3D).light_projector != null) == photo15)
	_check("G15 the chapel's lancets are glazed (the glass in its own colours, unlit), its shafts project the glass, reliefs on its walls",
		panes15 >= 9 and glows15 and cast15 and reliefs15 >= 3, "panes %d, glowing %s, shafts projecting (photo %s) %s, reliefs %d" % [panes15, glows15, photo15, cast15, reliefs15])

	# G16 the level's shading baked into its vertex colours (the PS2 way):
	# the walls carry colours that darken into corners, soot and damp, and
	# brighten out in the open
	var shades16: Array[float] = []
	var coloured16 := 0
	var walls16 := 0

	for mesh in level.root.find_children("wall_*", "MeshInstance3D", true, false):
		walls16 += 1
		var arrays := ((mesh as MeshInstance3D).mesh as ArrayMesh).surface_get_arrays(0)
		var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()

		if not colours.is_empty():
			coloured16 += 1

			for c in colours:
				shades16.append((c.r + c.g + c.b) / 3.0)

	shades16.sort()
	var spread16: bool = not shades16.is_empty() and shades16[int(shades16.size() * 0.05)] < 0.75 and shades16[int(shades16.size() * 0.95)] > 0.9
	_check("G16 the walls carry their baked shading in vertex colours, dark in corners and bright in the open",
		walls16 > 50 and coloured16 == walls16 and spread16,
		"walls %d, coloured %d, 5th/95th percentile %s" % [walls16, coloured16, [shades16[int(shades16.size() * 0.05)], shades16[int(shades16.size() * 0.95)]] if not shades16.is_empty() else []])

	# G17 dust hangs in the chapel's shafts of moonlight
	await _seconds(3.0)
	var chapel17: AABB = get_tree().get_nodes_in_group(&"hunt_area").filter(func(n): return String(n.name) == "area_chapel")[0].get_meta(&"box")
	var dust17: Array = map.atmosphere.motes(&"dust")
	var in17: int = dust17.filter(func(p): return chapel17.has_point(p)).size()
	var out17: Array = dust17.filter(func(p): return not chapel17.has_point(p)).slice(0, 4).map(func(p): return (p as Vector3).snapped(Vector3.ONE * 0.1))
	_check("G17 dust hangs in the chapel's shafts of moonlight", in17 >= 20 and in17 == dust17.size(), "dust motes %d, in the chapel %d, outside %s" % [dust17.size(), in17, out17])

	# G19 the canal is dark water drawn by its own shader (water.gdshader):
	# opaque, so the night's screen reflections land on it (the lamps and
	# the lit windows in streaks: its ripples drawn out along it, packed
	# across it); it flows; the sky is in it; rain rings it
	var canal19: Node = get_tree().get_nodes_in_group(&"water").filter(func(w): return w.get("_surface_mesh") != null)[0] if not get_tree().get_nodes_in_group(&"water").is_empty() else null
	var paint19: Material = (canal19._surface_mesh as MeshInstance3D).material_override if canal19 != null else null
	var shader19: Shader = (paint19 as ShaderMaterial).shader if paint19 is ShaderMaterial else null
	var drawn19: bool = shader19 != null and shader19.resource_path == "res://scripts/Visual/water.gdshader" and not shader19.code.contains("ALPHA")
	var rippled19: bool = drawn19 and paint19.get_shader_parameter(&"ripples") != null and float(paint19.get_shader_parameter(&"stretch")) >= 2.0
	var flows19: bool = drawn19 and (paint19.get_shader_parameter(&"flow") as Vector2).length() > 0.0
	var sky19: bool = drawn19 and (paint19.get_shader_parameter(&"sky_zenith") as Color).get_luminance() > 0.0
	var reflects19: bool = map.night.environment.ssr_enabled
	map.night.to(&"rain", 0.0)
	await _seconds(1.0)
	var rain19: float = float(paint19.get_shader_parameter(&"rain")) if drawn19 else 0.0
	map.night.to(&"clear", 0.0)
	await _seconds(1.0)
	var dry19: float = float(paint19.get_shader_parameter(&"rain")) if drawn19 else 1.0
	_check("G19 the canal is its own water: opaque (the screen reflections on it), rippled in streaks, flowing, the sky in it, rain rings it",
		drawn19 and rippled19 and flows19 and sky19 and reflects19 and rain19 > 0.5 and dry19 < 0.05,
		"drawn %s, rippled %s, flows %s, sky %s, screen reflections %s, rain %.2f, dry %.2f" % [drawn19, rippled19, flows19, sky19, reflects19, rain19, dry19])

	# G27 nature round the walls: oaks, a yew and dead trees, shrubs, grass,
	# weeds, reeds by the canal, ivy up the stone; their leaves our own
	# paintings drawn in the swaying foliage, stirring more in a storm than
	# on a still night; ground cover casts no shadow
	var kinds27 := {"tree_oak": 0, "tree_yew": 0, "tree_dead": 0, "bush": 0, "grass_tuft": 0, "weeds": 0, "reeds_clump": 0, "ivy_": 0}

	for node in level.root.find_children("*", "Node3D", true, false):
		for kind in kinds27:
			if String(node.name).begins_with(kind) and (node.get_parent() == null or not String(node.get_parent().name).begins_with(kind)):
				kinds27[kind] += 1

	var leaves27: Material = Materials.level_surface(&"leaf_crown")
	var foliage27: bool = leaves27 is ShaderMaterial and (leaves27 as ShaderMaterial).shader.resource_path == "res://scripts/Visual/foliage.gdshader" \
		and (leaves27 as ShaderMaterial).get_shader_parameter(&"albedo_texture") != null
	var lit27 := []

	for node in level.root.find_children("grass_tuft*", "GeometryInstance3D", true, false) + level.root.find_children("reeds_clump*", "GeometryInstance3D", true, false):
		if (node as GeometryInstance3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			lit27.append(node.name)

	map.night.to(&"clear", 0.0)
	await _seconds(1.0)
	var calm27: float = (leaves27.get_shader_parameter(&"wind") as Vector3).length() if foliage27 else 0.0
	map.night.to(&"storm", 0.0)
	await _seconds(1.0)
	var storm27: float = (leaves27.get_shader_parameter(&"wind") as Vector3).length() if foliage27 else 0.0
	map.night.to(&"clear", 0.0)
	await _seconds(1.0)
	var enough27: bool = kinds27["tree_oak"] >= 6 and kinds27["tree_yew"] >= 1 and kinds27["tree_dead"] >= 2 and kinds27["bush"] >= 6 \
		and kinds27["grass_tuft"] >= 120 and kinds27["weeds"] >= 40 and kinds27["reeds_clump"] >= 20 and kinds27["ivy_"] >= 12
	_check("G27 nature round the walls: trees, shrubs, grass, weeds, reeds, ivy; painted leaves swaying, more in a storm; ground cover casts no shadow",
		enough27 and foliage27 and storm27 > calm27 * 3.0 and calm27 > 0.0 and lit27.is_empty(),
		"%s, foliage %s, wind calm %.2f storm %.2f, shadowed cover %s" % [kinds27, foliage27, calm27, storm27, lit27.slice(0, 4)])

	# G29 night creatures: bats flitting round the chapel's spire, the
	# watchtower's top and over the yard, fireflies low over the grassy
	# banks, both gone to ground in rain; moths at the lamp posts in the lanes
	# and on the quay, and at no other light (not a torch, a lantern, a
	# chandelier, a candle)
	var bats29: Array = get_tree().get_nodes_in_group(&"bats")
	var flies29: Array = get_tree().get_nodes_in_group(&"fireflies")
	var air29: Node = get_tree().get_first_node_in_group(&"atmosphere")
	var moths29: Array = air29.moths() if air29 != null else []
	# (Each lamp post's flame: its burner, the torch inside a lamp_post fixture.)
	var marked29: int = level.markers.filter(func(m): return m["ucd"] == "light" and String(m["props"].get("kind", "")) == "lamp_post").size()
	var posts29: Array = get_tree().get_nodes_in_group(&"torches").filter(func(t): return AtmosphereScript._draws_moths(t)).map(func(t): return (t as Node3D).global_position)
	var roosts29 := [Vector3(9.0, 21.5, -20.8), Vector3(-31.0, 14.0, -27.0), Vector3(0.0, 12.5, 2.0)]
	var was29: Array = bats29.map(func(b): return (b as Node3D).global_position)
	await _seconds(0.5)
	var flew29: bool = not bats29.is_empty() and range(bats29.size()).all(func(k): return (bats29[k] as Node3D).global_position.distance_to(was29[k]) > 0.2)
	var near29: bool = bats29.all(func(b): return roosts29.any(func(r): return (b as Node3D).global_position.distance_to(r) < 14.0))
	var at_posts29: bool = not moths29.is_empty() and moths29.all(func(m): return posts29.any(func(p): return (m as Node3D).global_position.distance_to(p) < 2.5))
	var every_post29: bool = posts29.all(func(p): return moths29.any(func(m): return (m as Node3D).global_position.distance_to(p) < 2.5))
	var out29: bool = (bats29 + flies29).all(func(n): return (n as Node3D).is_visible_in_tree())
	map.night.to(&"rain", 0.0)
	await _seconds(1.0)
	var gone29: bool = (bats29 + flies29).all(func(n): return not (n as Node3D).is_visible_in_tree())
	map.night.to(&"clear", 0.0)
	await _seconds(1.0)
	var back29: bool = (bats29 + flies29).all(func(n): return (n as Node3D).is_visible_in_tree())
	_check("G29 bats round the spire, the tower and over the yard, fireflies over the banks, gone in rain; moths at every lamp post and no other light",
		bats29.size() >= 8 and flew29 and near29 and flies29.size() >= 2 and out29 and gone29 and back29 and posts29.size() == marked29 and marked29 >= 8 and at_posts29 and every_post29,
		"bats %d (flying %s, near their roosts %s), fireflies %d, out %s, gone in rain %s, back %s, moths %d all at lamp posts %s, every post %s (%d posts)" % [bats29.size(), flew29, near29, flies29.size(), out29, gone29, back29, moths29.size(), at_posts29, every_post29, posts29.size()])

	# G20 grime, leaks and moss decals where the level marks them (each its
	# photo when here); crimson banners in rows down the mess
	# (The level's own: the night's puddles are decals too.)
	var photo_kinds20 := ["grime", "leak_1", "leak_2", "moss"]
	var decals20: Array = map.find_children("decal_*", "Decal", true, false).filter(func(d): return String((d as Decal).get_meta(&"kind", "")) in photo_kinds20)
	var marked20: int = level.of("decal").filter(func(m): return String(m["props"]["kind"]) in photo_kinds20).size()
	var photo20: bool = Materials.picture("decal_moss") != null
	var textured20: bool = decals20.all(func(d): return ((d as Decal).texture_albedo != null) == photo20)
	var banners20: int = level.root.find_children("banner*", "", true, false).filter(func(n): return Rect2(16.6, -8.0, 13.0, 18.0).has_point(Vector2((n as Node3D).global_position.x, (n as Node3D).global_position.z))).size()
	_check("G20 grime, leak and moss decals where marked (photos when here); crimson banners in rows down the mess",
		marked20 >= 30 and (decals20.size() == marked20 or not photo20) and textured20 and banners20 >= 8,
		"decals %d of %d marked, textured %s (photo %s), banners in the mess %d" % [decals20.size(), marked20, textured20, photo20, banners20])

	# G30 the ground lived on, in our own paintings (there without the
	# photos): soot under each brazier and before the mess hearth, trodden
	# dirt at the yard's doors and down the gate passage (stains that darken
	# whatever light is on the ground: cards laid on it, multiplying), straw
	# spilt by the lean-to, leaves blown into the yard's corners (decals);
	# each flat on the floor (the hearth's soot lies before its stone slab,
	# 1.7 m from its fire)
	var floor30: Array = map.find_children("decal_*", "", true, false).filter(func(n): return String(n.get_meta(&"kind", "")) in ["soot", "dirt", "straw", "leaves"])
	var kinds30 := {}

	for n in floor30:
		kinds30[String(n.get_meta(&"kind"))] = int(kinds30.get(String(n.get_meta(&"kind")), 0)) + 1

	var fires30: Array = level.of("light").filter(func(m): return String(m["props"].get("kind", "")) in ["brazier", "hearth"])
	var sooted30: bool = fires30.all(func(m): return floor30.any(func(n): return String(n.get_meta(&"kind")) == "soot" \
		and Vector2(n.global_position.x - (m["transform"] as Transform3D).origin.x, n.global_position.z - (m["transform"] as Transform3D).origin.z).length() < 2.0))
	var stains30: bool = floor30.filter(func(n): return String(n.get_meta(&"kind")) in ["soot", "dirt"]).all(func(n): return n is MeshInstance3D \
		and (n as MeshInstance3D).material_override is ShaderMaterial and ((n as MeshInstance3D).material_override as ShaderMaterial).shader.code.contains("blend_mul") \
		and ((n as MeshInstance3D).material_override as ShaderMaterial).get_shader_parameter(&"stain") != null)
	var strewn30: bool = floor30.filter(func(n): return String(n.get_meta(&"kind")) in ["straw", "leaves"]).all(func(n): return n is Decal \
		and (n as Decal).texture_albedo != null and (n as Decal).texture_albedo.resource_path.begins_with("res://textures/painted/"))
	var flat30: bool = floor30.all(func(n): return (n as Node3D).global_basis.y.normalized().dot(Vector3.UP) > 0.99)
	_check("G30 the ground lived on (our paintings): soot at every brazier and the hearth, dirt at the doors and the gate (darkening stains), straw by the lean-to, leaves in the corners",
		fires30.size() >= 3 and sooted30 and int(kinds30.get("dirt", 0)) >= 10 and int(kinds30.get("straw", 0)) >= 2 and int(kinds30.get("leaves", 0)) >= 4 and stains30 and strewn30 and flat30,
		"fires %d sooted %s, kinds %s, stains multiply %s, straw and leaves painted decals %s, flat %s" % [fires30.size(), sooted30, kinds30, stains30, strewn30, flat30])

	# G31 our own paintings are always here (committed, no photo in them):
	# every painted slot finds its painting; the chapel's runner is one (it
	# was the one slot left on its flat colour: no photo was ever made)
	var painted31: Array = Materials.SLOTS.keys().filter(func(k): return bool(Materials.SLOTS[k].get("painted", false)))
	var found31: bool = painted31.all(func(k): return Materials.photo(k) != null)
	var runner31: bool = painted31.has(&"carpet") and Materials.photo(&"carpet") != null
	_check("G31 every painted slot finds its painting; the chapel's runner is painted, not flat", found31 and runner31,
		"painted %d all found %s, runner %s" % [painted31.size(), found31, runner31])

	# G21 drawn only as near as it shows: small dressing fades out at its
	# range; the big walls occlude what is behind them (occlusion culling on)
	var small21: Array = level.root.find_children("weeds*", "MeshInstance3D", true, false) + level.root.find_children("candle_stand*", "MeshInstance3D", true, false)
	var ranged21: bool = not small21.is_empty() and small21.all(func(m): return (m as GeometryInstance3D).visibility_range_end > 0.0)
	var occluders21: int = map.find_children("*", "OccluderInstance3D", true, false).size()
	var culling21: bool = ProjectSettings.get_setting("rendering/occlusion_culling/use_occlusion_culling", false)
	_check("G21 small dressing is drawn only as near as it shows; the big walls occlude (occlusion culling on)",
		ranged21 and occluders21 >= 100 and culling21, "small %d ranged %s, occluders %d, culling %s" % [small21.size(), ranged21, occluders21, culling21])

	# G22 the doors are studded planks (their own UVs: the photo swings with
	# the door), when the photo is here
	var studded22: Material = Materials.surface(&"wood_studded")
	var photo22: bool = Materials.photo(&"wood_studded") != null
	var plain22 := []

	for door in map.doors.values():
		var panels: Array = (door as Node).find_children("*", "MeshInstance3D", true, false).filter(func(m): return (m as MeshInstance3D).get_aabb().size.y > 1.0)

		if panels.is_empty() or (panels[0] as MeshInstance3D).material_override != studded22:
			plain22.append(String((door as Node).name))

	_check("G22 the doors are drawn in studded planks", not photo22 or plain22.is_empty(), "photo %s, plain doors %s" % [photo22, plain22.slice(0, 5)])

	# G6 lightning through the stained glass: the chapel's shafts of light
	# flare with a flash and die back after it
	var shafts: Array = get_tree().get_nodes_in_group(&"glass_shafts")
	var calm6: Array = shafts.map(func(s): return float((s as Light3D).light_energy))
	map.night.flash()
	await _frames(3)
	var lit6: Array = shafts.map(func(s): return float((s as Light3D).light_energy))
	await _seconds(2.0)
	var after6: Array = shafts.map(func(s): return float((s as Light3D).light_energy))
	var flared6 := not shafts.is_empty() and range(shafts.size()).all(func(i): return lit6[i] >= 3.0 * calm6[i] and after6[i] <= calm6[i] * 1.1)
	_check("G6 a lightning flash flares the chapel's shafts of light through the glass, and they die back after it",
		flared6, "shafts %d, calm %s, in the flash %s, after %s" % [shafts.size(), calm6, lit6, after6])

	# G24 god rays: a shaft of coloured moonlight falls steeply from every
	# moonward lancet of the chapel (its low tier and its clerestory) into the
	# nave and stops at its floor and walls; a cloud over the moon or rain
	# dims it, never puts it out (the chapel is never without them), and it
	# flares with lightning
	var rays24: Node = get_tree().get_first_node_in_group(&"god_rays")
	var beams24: Array = rays24.beams if rays24 != null else []
	var nave24 := AABB(Vector3(-5.7, -0.4, -25.4), Vector3(19.4, 12.0, 9.1))
	var strays24 := beams24.filter(func(b): return not nave24.encloses((b as MeshInstance3D).global_transform * (b as MeshInstance3D).get_aabb()))
	await _frames(10)
	var clear24: float = rays24.strength if rays24 != null else 0.0
	map.night.cover_moon(12.0)
	await _seconds(6.0)
	var covered24: float = rays24.strength if rays24 != null else 0.0
	map.night.to(&"rain", 0.0)
	await _frames(5)
	var rain24: float = rays24.strength if rays24 != null else 0.0
	map.night.to(&"clear", 0.0)
	await _seconds(9.0)
	map.night.flash()
	await _frames(3)
	var flash24: float = rays24.strength if rays24 != null else 0.0
	await _seconds(1.0)
	var steep24: float = (rays24.direction as Vector3).normalized().y if rays24 != null else 0.0
	_check("G24 god rays fall steeply from the chapel's eight moonward lancets and stay in the nave; cloud and rain dim them but never put them out; lightning flares them",
		beams24.size() == 8 and strays24.is_empty() and steep24 <= -0.7 and clear24 > 0.5 and covered24 < clear24 * 0.95 and covered24 >= clear24 * 0.5
		and rain24 >= clear24 * 0.55 and flash24 > clear24 * 2.0,
		"beams %d (out of the nave %d), falling %.2f, clear %.2f, covered %.2f, rain %.2f, flash %.2f" % [beams24.size(), strays24.size(), steep24, clear24, covered24, rain24, flash24])

	# G7 the story's ways: every leg the intruder runs is on the navmesh end
	# to end (over the wall and into the canal by the breach and the roof)
	var legs := [["drop_in", "colonnade_wait"], ["colonnade_post", "gone_to_ground"], ["gone_to_ground", "sneak_3"], ["gone_to_ground", "sneak_1"], ["sneak_1", "sneak_2"],
		["sneak_2", "sneak_3"], ["sneak_3", "chapel_hide"], ["chapel_fight", "captain_door_at"], ["captain_door_at", "escape_stairs"],
		["escape_stairs", "escape_door"], ["escape_door", "escape_climb"], ["escape_climb", "escape_walk"], ["escape_walk", "escape_over"],
		["escape_over", "canal_edge"], ["canal_edge", "canal_swim"], ["captain_door_at", "courtyard_fight"], ["courtyard_fight", "gate_out"]]
	var broken7 := []

	for leg in legs:
		if not (map.marks.has(leg[0]) and map.marks.has(leg[1])):
			broken7.append("%s-%s: no mark" % leg)
			continue

		var a := NavigationServer3D.map_get_closest_point(nav_map, map.marks[leg[0]])
		var b := NavigationServer3D.map_get_closest_point(nav_map, map.marks[leg[1]])
		var way := NavigationServer3D.map_get_path(nav_map, a, b, true)

		if a.distance_to(map.marks[leg[0]]) > 1.0 or b.distance_to(map.marks[leg[1]]) > 1.0 or way.is_empty() or way[way.size() - 1].distance_to(b) > 0.8:
			broken7.append("%s-%s ends at %s" % [leg[0], leg[1], way[way.size() - 1].snapped(Vector3.ONE * 0.1) if not way.is_empty() else "nowhere"])

	# (Over the wall by the breach and the lean-to's roof, not round by the
	# postern.)
	var over7 := NavigationServer3D.map_get_path(nav_map, NavigationServer3D.map_get_closest_point(nav_map, map.marks.get("escape_walk", Vector3.ZERO)),
		NavigationServer3D.map_get_closest_point(nav_map, map.marks.get("escape_over", Vector3.ZERO)), true)
	var over_length := 0.0

	for i in range(1, over7.size()):
		over_length += over7[i - 1].distance_to(over7[i])

	# (And from the chapel's loft straight through onto the barracks' gallery.)
	var loft7 := NavigationServer3D.map_get_path(nav_map, NavigationServer3D.map_get_closest_point(nav_map, map.marks.get("sneak_3", Vector3.ZERO)),
		NavigationServer3D.map_get_closest_point(nav_map, map.marks.get("sneak_2", Vector3.ZERO)), true)
	var loft_length := 0.0

	for i in range(1, loft7.size()):
		loft_length += loft7[i - 1].distance_to(loft7[i])

	# (Up onto the range's roof by the crates: somewhere to go to ground.)
	var roof7: bool = map.marks.has("gone_to_ground") and (map.marks["gone_to_ground"] as Vector3).y > 3.0

	_check("G7 every leg of the intruder's night is a way on the navmesh, onto the range's roof, over the wall (by the breach), through the loft, and into the canal",
		broken7.is_empty() and roof7 and over_length > 0.0 and over_length < 12.0 and loft_length > 0.0 and loft_length < 20.0,
		"%s; to ground on the roof %s, over the wall %.1f m, the loft to the gallery %.1f m" % [broken7, roof7, over_length, loft_length])

	# G5 a man at prayer in the chapel: down on his knees, his head bowed, a
	# murmured line now and then; stirred, he gets up off his knees
	var gideon: Node3D = map.cast["Gideon"]
	var gideon_said := []
	gideon.barked.connect(func(t): gideon_said.append([t, gideon.last_delivery]))
	gideon._rota.set_stations([map._stations["pray_0"]])
	var seen5 := {}
	var bowed5 := [0.0]
	var frame5 := [0]
	await _until(func():
		frame5[0] += 1
		seen5[StringName(gideon.activity())] = true
		if StringName(gideon.activity()) == &"pray":
			bowed5[0] = minf(bowed5[0], gideon._head.rotation.x)
		return seen5.has(&"pray") and gideon_said.any(func(l): return l[1] == &"murmur" and gideon._rota.PRAY_LINES.has(l[0])) and frame5[0] > 600, 5400)
	gideon._rota.stir()
	await _frames(2)
	var rose5 := StringName(gideon.activity())
	var at5: float = gideon.global_position.distance_to((map._stations["pray_0"] as Node3D).global_position)
	_check("G5 a man at prayer kneels at the pew, bows his head and murmurs; stirred, he gets up off his knees",
		seen5.has(&"kneel_down") and seen5.has(&"pray") and bowed5[0] < -0.3 and gideon_said.any(func(l): return l[1] == &"murmur" and gideon._rota.PRAY_LINES.has(l[0])) and rose5 == &"kneel_up" and at5 < 1.0,
		"showed %s, head %.2f, said %s, stirred: %s, %.1f m from the pew" % [seen5.keys(), bowed5[0], gideon_said, rose5, at5])

	# G8 the divided hunt's ground: men sent to search a hunt area look only
	# in it, whatever word comes from outside it, and keep at it
	var areas8 := {}

	for node in get_tree().get_nodes_in_group(&"hunt_area"):
		areas8[String(node.name)] = node.get_meta(&"box")

	var sent8 := {"Col": "area_barracks", "Osric": "area_barracks", "Ned": "area_west", "Piers": "area_west", "Wat": "area_walls"}
	var spots8 := {}
	var stray8 := []

	for name in sent8:
		var man: Node3D = map.cast[name]
		# Word of him in the courtyard, then the orders: each his ground.
		man.last_known_position = Vector3(0, 0, 10)
		man.has_last_known = true
		man.send_to_search(areas8[sent8[name]], StringName(sent8[name]))
		spots8[name] = []

	var frame8 := [0]
	var went8 := []
	await _until(func():
		frame8[0] += 1
		for name in sent8:
			var man: Node3D = map.cast[name]
			# Wherever he is making for, too (not only the places he searches):
			# never off his ground.
			var going: Vector3 = man._agent.target_position
			if frame8[0] > 2 and not (areas8[sent8[name]] as AABB).grow(0.6).has_point(going) and went8.size() < 6:
				went8.append("%s making for %s" % [name, going.snapped(Vector3.ONE * 0.1)])
			var spot: Dictionary = man._spot
			if not spot.is_empty() and not (spots8[name] as Array).has(spot["stand"]):
				(spots8[name] as Array).append(spot["stand"])
				if not (areas8[sent8[name]] as AABB).grow(0.3).has_point(spot["stand"]):
					stray8.append("%s at %s" % [name, (spot["stand"] as Vector3).snapped(Vector3.ONE * 0.1)])
		return false, 2400)
	# A call from outside his ground (another group's find) he leaves to
	# them; one from inside it he answers.
	var col8: Node3D = map.cast["Col"]
	col8.hear_call(Vector3(0, 0, 10))
	# (And word called out through Comms: "He's there!", the bell.)
	col8._hear_message({"message": {"what": &"spotted", "where": Vector3(0, 0, 10), "time": 9999.0}, "position": col8.global_position, "range": 200.0})
	col8._hear_message({"message": {"what": &"alarm", "where": Vector3(0, 0, 10)}, "position": col8.global_position, "range": 200.0})
	var ignored8: bool = (areas8["area_barracks"] as AABB).grow(0.3).has_point(col8.last_known_position)
	col8.hear_call(Vector3(22, 0, 4))
	var answered8: bool = col8.last_known_position.distance_to(Vector3(22, 0, 4)) < 0.1
	var kept8: bool = ignored8 and answered8 and sent8.keys().all(func(n): return int((map.cast[n] as Node).state) == 3 and (map.cast[n] as Node).get_meta(&"hunt_group", &"") == StringName(sent8[n]))
	# Called off: his ground is anywhere again.
	var called8: Node3D = map.cast["Piers"]
	called8.call_off_search()
	var free8: bool = not called8.has_meta(&"hunt_area") and not called8.has_meta(&"hunt_group")
	var counts8 := {}
	var where8 := {}

	for name in sent8:
		counts8[name] = (spots8[name] as Array).size()
		var man8: Node3D = map.cast[name]
		where8[name] = [man8.global_position.snapped(Vector3.ONE * 0.1), man8._agent.target_position.snapped(Vector3.ONE * 0.1), man8.state]

	_check("G8 men sent to a hunt area search only inside it and keep at it; called off, anywhere again",
		stray8.is_empty() and went8.is_empty() and kept8 and free8 and counts8.values().all(func(c): return int(c) >= 3),
		"outside their ground %s, making for places off it %s, a call from outside ignored %s, from inside answered %s, still searching in their groups %s, called off %s, places searched %s; where, making for, state %s" % [stray8.slice(0, 6), went8, ignored8, answered8, kept8, free8, counts8, where8])

	# G9 sent to the bell: a man who is no lookout runs to it and rings it
	var rung9 := [null]
	for bell in get_tree().get_nodes_in_group(&"alarm_bells"):
		bell.rung.connect(func(by): rung9[0] = by)
	var tam9: Node3D = map.cast["Tam"]
	tam9.last_known_position = Vector3(-17.6, 0, -1.5)
	tam9.has_last_known = true
	tam9.send_to_bell()
	await _until(func(): return rung9[0] != null, 3600)
	_check("G9 a man sent to the bell runs to it and rings it", rung9[0] == tam9,
		"rung by %s, Tam at %s" % [rung9[0].name if rung9[0] != null else "nobody", tam9.global_position.snapped(Vector3.ONE * 0.1)])

	# G13 every marker made into its node: doors, stations, the cast, the
	# bell, ladders, vantages, hiding places, hunt areas, rounds, and a light
	# at every light marker
	var unmade := []
	var counts13 := {"door": get_tree().get_nodes_in_group(&"doors").size(), "station": map._stations.size(), "guard": map.cast.size(),
		"bell": get_tree().get_nodes_in_group(&"alarm_bells").size(), "vantage": get_tree().get_nodes_in_group(&"cine_vantage").size(),
		"hide": get_tree().get_nodes_in_group(&"hide_spot").size(), "hunt_area": get_tree().get_nodes_in_group(&"hunt_area").size()}

	for ucd in counts13:
		if int(counts13[ucd]) != level.of(ucd).size():
			unmade.append("%s: %d of %d" % [ucd, counts13[ucd], level.of(ucd).size()])

	for m in level.of("ladder"):
		if map.get_node_or_null(NodePath(String(m["name"]))) == null:
			unmade.append("ladder %s" % m["name"])

	for m in level.of("route"):
		var round13: Node = map._routes.get(m["name"])
		if round13 == null or round13.get_child_count() < 2:
			unmade.append("round %s" % m["name"])

	var lit13: Array = map.find_children("*", "Light3D", true, false).map(func(l): return (l as Node3D).global_position)

	for m in level.of("light"):
		# (In plan: a lamp's light hangs at its head above its foot, a
		# chandelier's below where it hangs from, its chain's length.)
		var at13: Vector3 = (m["transform"] as Transform3D).origin - Vector3(0.0, float(m["props"].get("chain", 0.0)), 0.0)
		if not lit13.any(func(p): return Vector2((p as Vector3).x - at13.x, (p as Vector3).z - at13.z).length() < 1.5 and absf((p as Vector3).y - at13.y) < 4.0):
			unmade.append("no light at %s (%s)" % [m["name"], m["props"]["kind"]])

	_check("G13 every marker is made into its node: doors, stations, the cast, the bell, ladders, vantages, hiding places, hunt areas, rounds, a light at every light",
		unmade.is_empty(), "%s" % [unmade.slice(0, 10)])

	# G11 a door in his way opens for a guard: sent to look at something in
	# the storehouse, the man at the colonnade goes in through its door
	var door11: Node = map.doors.get("storehouse_door")
	var looker11: Node3D = map.cast["Hendrik"]
	var inside11 := Vector3(-24.0, 0.0, 6.5)
	var opened11 := [false]
	looker11.notice(inside11, &"test")
	await _until(func():
		if door11 != null and bool(door11.is_open):
			opened11[0] = true
		return opened11[0] and looker11.global_position.distance_to(inside11) < 2.0, 2400)
	_check("G11 a door in his way opens for a guard: he goes through into the storehouse",
		door11 != null and opened11[0] and looker11.global_position.distance_to(inside11) < 2.0,
		"door %s, opened %s, he is %.1f m from the place" % [door11 != null, opened11[0], looker11.global_position.distance_to(inside11)])

	# G12 every zone: the camera in it (where no smaller zone is) is in its
	# grade, eased in
	var zoned12 := []
	var probe12 := Camera3D.new()
	add_child(probe12)
	probe12.make_current()

	for m in level.of("zone"):
		var size12: Vector3 = m["size"]
		var box12 := AABB((m["transform"] as Transform3D).origin - size12 * 0.5, size12)
		var grade12 := String(m["props"]["grade"])
		var spot12 := Vector3.INF

		for f in [Vector3(0.5, 0.5, 0.5), Vector3(0.2, 0.5, 0.2), Vector3(0.8, 0.5, 0.8), Vector3(0.2, 0.5, 0.8), Vector3(0.8, 0.5, 0.2)]:
			var at12: Vector3 = box12.position + box12.size * (f as Vector3)
			if level.zones.zone_at(at12) == String(m["name"]):
				spot12 = at12
				break

		if spot12 == Vector3.INF:
			zoned12.append("%s: nowhere its own" % m["name"])
			continue

		probe12.global_position = spot12
		# (Eased over Zones.EASE a second: four of them, all but settled.)
		await _seconds(4.0)
		var eased12: bool = absf(float(level.zones.look()["saturation"]) - float(level.zones.GRADES[grade12]["saturation"])) < 0.03

		if level.zones.current != grade12 or not eased12:
			zoned12.append("%s: %s, saturation %.2f" % [m["name"], level.zones.current, float(level.zones.look()["saturation"])])

	probe12.queue_free()
	camera.make_current()
	_check("G12 every zone's grade eases in with the camera in it", zoned12.is_empty(), "%s" % [zoned12])

	# G10 the ladder pulled up behind a man on the range's roof: nobody
	# follows him straight up (the only way now is round by the flights and
	# the wall-walk), and he can still come down by the drop at its corner
	var yard10 := NavigationServer3D.map_get_closest_point(nav_map, Vector3(-22.0, 0.0, -17.0))
	var roof10 := NavigationServer3D.map_get_closest_point(nav_map, map.marks["gone_to_ground"])
	var up_before := _way_length(nav_map, yard10, roof10)
	map.pull_up_ladder()
	await _frames(10)
	var up_after := _way_length(nav_map, yard10, roof10)
	var down_after := _reaches(nav_map, roof10, yard10)
	var lying10: bool = map.level.root.find_children("ladder_3*", "", true, false).all(func(n): return (n as Node3D).global_position.y > 3.0)
	_check("G10 the ladder pulled up onto the range's roof: nobody follows him straight up (round by the walls only), and he can still get down",
		up_before > 0.0 and up_before < 15.0 and up_after > 40.0 and down_after and lying10,
		"the way up before %.1f m, after %.1f m, down after %s, the ladder on the roof %s" % [up_before, up_after, down_after, lying10])
	camera.queue_free()
	map.queue_free()
	await _frames(3)
	MapScript.run_show = true


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	return get_world_3d().direct_space_state.intersect_ray(query)


func _surface(hit: Dictionary) -> String:
	var body: Object = hit.get("collider")
	return String(body.get_meta(&"surface", "")) if body != null else ""


func _seconds(seconds: float) -> void:
	for f in int(round(seconds * 60.0)):
		await get_tree().process_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## The navmesh's way from `a` all the way to `b`, how long (-1: none).
func _way_length(nav_map: RID, a: Vector3, b: Vector3) -> float:
	var way := NavigationServer3D.map_get_path(nav_map, a, b, true)

	if way.is_empty() or way[way.size() - 1].distance_to(b) >= 0.8:
		return -1.0

	var length := 0.0

	for i in range(1, way.size()):
		length += way[i - 1].distance_to(way[i])

	return length


## Whether the navmesh has a way from `a` all the way to `b` (on `layers`).
func _reaches(nav_map: RID, a: Vector3, b: Vector3, layers := 1) -> bool:
	var way := NavigationServer3D.map_get_path(nav_map, a, b, true, layers)
	return not way.is_empty() and way[way.size() - 1].distance_to(b) < 0.8


func _until(cond: Callable, max_frames: int) -> void:
	for i in max_frames:
		if cond.call():
			return

		await get_tree().physics_frame


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
