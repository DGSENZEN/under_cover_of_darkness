extends RefCounted
## Loads an exported level manifest plus per-sector GLBs under a new root.
## Assigns shared Materials slots, layer-1 surface colliders, visibility ranges, shadows, and geometry occluders.
## Creates loader-owned marks/vantages/hide/hunt/zone nodes; other markers remain records for LevelGameplay.
## Manifest/marker schemas and failure behavior are documented in docs/systems/world.md.

const Materials := preload("res://scripts/Visual/Materials.gd")
## A collider's surface that marks a ceiling (never walked on).
const CEILING := "ceiling"
## Small dressing fades out over this much past its range (m); a collider
## occludes when its two bigger sides are at least these (m).
const RANGE_MARGIN := 4.0
const OCCLUDER_SIZE := Vector2(3.0, 4.0)
## A district's proxy is drawn only this far out (m); nearer, the district
## itself (or the shared wall) is what is seen.
const PROXY_NEAR := 60.0
const ZonesScript := preload("res://scripts/Level/Zones.gd")

## A level put together: its root, its sectors, its markers.
class Level:
	extends RefCounted
	var root: Node3D
	var name := ""
	var sectors := {}
	## Every marker: {name, ucd, sector, transform, size (Vector3 or null), props}.
	var markers: Array = []
	var by_name := {}
	## Marks (and the spawn) by name, as Marker3D.
	var marks := {}
	## Sockets on pieces: {piece, kind, sector, position}.
	var sockets: Array = []
	var zones: Node = null

	## Every marker of `ucd`.
	func of(ucd: String) -> Array:
		return markers.filter(func(m): return m["ucd"] == ucd)

	## The marker called `marker_name` (an empty dictionary if none).
	func get_marker(marker_name: String) -> Dictionary:
		return by_name.get(marker_name, {})


## Loads folder/<folder-name>.json and optional sector GLBs beneath parent using root_name.
## Returns Level records and creates collision/occlusion/marker nodes. An unreadable or empty manifest reports an error and returns a Level with null root.
## JSON structure is trusted: malformed JSON or missing required fields are not validated here.
## The sectors in skip_sectors are left out whole: no holder, mesh, collider,
## terrain, socket or marker of theirs (a district's map leaves out its own
## massing, and the massing of districts drawn by their proxies).
static func load_level(parent: Node3D, folder: String, root_name := "Level", skip_sectors: Array = []) -> Level:
	var level := Level.new()
	level.name = folder.get_file()
	var text := FileAccess.get_file_as_string(folder.path_join(level.name + ".json"))

	if text.is_empty():
		push_error("LevelLoader: no manifest in %s" % folder)
		return level

	var manifest: Dictionary = JSON.parse_string(text)

	if not skip_sectors.is_empty():
		manifest = _without(manifest, skip_sectors.map(func(s): return String(s)))

	level.root = Node3D.new()
	level.root.name = root_name
	parent.add_child(level.root)

	for sector in manifest.get("sectors", []):
		var holder := Node3D.new()
		holder.name = String(sector)
		level.root.add_child(holder)
		level.sectors[String(sector)] = holder
		var path := folder.path_join(String(sector) + ".glb")

		if ResourceLoader.exists(path):
			var scene := (load(path) as PackedScene).instantiate()
			holder.add_child(scene)
			_dress(scene)

	_colliders(level, manifest.get("colliders", []))
	_ranges(level, manifest.get("ranges", {}))
	_shadowless(level, manifest.get("shadowless", []))
	_occluders(level, manifest.get("colliders", []))
	_terrain(level, manifest.get("terrain", []))
	level.sockets = manifest.get("sockets", [])

	for raw in manifest.get("markers", []):
		var marker := _marker(raw)
		level.markers.append(marker)
		level.by_name[marker["name"]] = marker

	_own_markers(level)
	return level


## A manifest with the sectors in `skip` taken out of every list that names
## them.
static func _without(manifest: Dictionary, skip: Array) -> Dictionary:
	var kept := manifest.duplicate()
	kept["sectors"] = manifest.get("sectors", []).filter(func(s): return not skip.has(String(s)))

	for key in ["colliders", "terrain", "sockets", "markers"]:
		kept[key] = manifest.get(key, []).filter(func(item): return not skip.has(String(item.get("sector", ""))))

	return kept


## A district's proxy (folder/proxy.glb: its pieces as boxes, its lit windows,
## its ground thinned), drawn only from `near` m out, casting no shadow and
## colliding with nothing; under parent, named "<level>_proxy". Null (with a
## warning) when the district has none.
static func load_proxy(parent: Node3D, folder: String, near := PROXY_NEAR) -> Node3D:
	var path := folder.path_join("proxy.glb")

	if not ResourceLoader.exists(path):
		push_warning("LevelLoader: no proxy in %s" % folder)
		return null

	var proxy := (load(path) as PackedScene).instantiate() as Node3D
	proxy.name = folder.get_file() + "_proxy"
	parent.add_child(proxy)
	_dress(proxy)

	for node in proxy.find_children("*", "GeometryInstance3D", true, false):
		var drawn := node as GeometryInstance3D
		drawn.visibility_range_begin = near
		drawn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	return proxy


## Each surface drawn with its slot's shared material (the glTF's material
## is named after the slot).
static func _dress(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D

		for i in mesh_node.get_surface_override_material_count():
			var material := mesh_node.mesh.surface_get_material(i)
			var slot := StringName(material.resource_name) if material != null else &""

			if slot != &"" and Materials.SLOTS.has(slot):
				mesh_node.set_surface_override_material(i, Materials.level_surface(slot))

				# (Ground cover and ivy cast no shadow: a lawn of cards
				# would double the moon's shadow pass.)
				if bool(Materials.SLOTS[slot].get("shadowless", false)):
					mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	for child in node.get_children():
		_dress(child)


static func _colliders(level: Level, colliders: Array) -> void:
	var bodies := {}

	for c in colliders:
		var key := "%s_%s" % [c["sector"], c["surface"]]

		if not bodies.has(key):
			var body := StaticBody3D.new()
			body.name = key
			body.collision_layer = 1
			body.set_meta(&"surface", String(c["surface"]))

			# A ceiling (under a pitched roof) stops sight and what is thrown,
			# but nobody walks on it: the navmesh is baked without it.
			if String(c["surface"]) == CEILING:
				body.set_meta(&"surface", "wood")
				body.add_to_group(&"nav_ignore")
			var holder: Node3D = level.sectors.get(String(c["sector"]), level.root)
			holder.add_child(body)
			bodies[key] = body

		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = _vector(c["size"])
		shape.shape = box
		shape.transform = Transform3D(_basis(c["basis"]), _vector(c["centre"]))
		(bodies[key] as StaticBody3D).add_child(shape)


## Small dressing drawn only as near as it shows (the manifest's ranges).
static func _ranges(level: Level, ranges: Dictionary) -> void:
	if ranges.is_empty():
		return

	# (Blender's "weeds.001" is Godot's node "weeds_001".)
	var by_node := {}

	for name in ranges:
		by_node[String(name).replace(".", "_")] = ranges[name]

	for mesh in level.root.find_children("*", "GeometryInstance3D", true, false):
		var reach: Variant = by_node.get(String((mesh as Node).name))

		if reach == null:
			reach = by_node.get(String((mesh as Node).get_parent().name))

		if reach != null:
			(mesh as GeometryInstance3D).visibility_range_end = float(reach)
			(mesh as GeometryInstance3D).visibility_range_end_margin = RANGE_MARGIN


## The city's far massing drawn without shadows (the manifest's
## "shadowless": pieces only a silhouette cost the moon's shadow pass
## nothing).
static func _shadowless(level: Level, names: Array) -> void:
	if names.is_empty():
		return

	var wanted := {}

	for name in names:
		wanted[String(name).replace(".", "_")] = true

	for mesh in level.root.find_children("*", "GeometryInstance3D", true, false):
		if wanted.has(String((mesh as Node).name)) or wanted.has(String((mesh as Node).get_parent().name)):
			(mesh as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## The big walls occlude what is behind them: a box occluder for every
## collider at least OCCLUDER_SIZE across and up (the kit's walls, the
## curtain), under one node.
static func _occluders(level: Level, colliders: Array) -> void:
	var holder := Node3D.new()
	holder.name = "Occluders"
	level.root.add_child(holder)

	for c in colliders:
		# Some movement barriers fill visible openings (the crane wheel).
		# Only the occlusion pass skips them; their physics stays unchanged.
		if not bool(c.get("occluder", true)):
			continue
		var size := _vector(c["size"])
		var sides := [size.x, size.y, size.z]
		sides.sort()

		if String(c["surface"]) == CEILING or sides[1] < OCCLUDER_SIZE.x or sides[2] < OCCLUDER_SIZE.y:
			continue

		var occluder := OccluderInstance3D.new()
		var box := BoxOccluder3D.new()
		box.size = size
		occluder.occluder = box
		holder.add_child(occluder)
		occluder.transform = Transform3D(_basis(c["basis"]), _vector(c["centre"]))


## The terrain (tools/level/terrain.py): each is its own collider, a
## trimesh of the mesh it is drawn with (as sculpted in the .blend), on
## layer 1 with its surface; the big rock that hides what is behind it an
## occluder of the same mesh.
static func _terrain(level: Level, ground: Array) -> void:
	var occluders: Node3D = level.root.get_node_or_null("Occluders")

	for t in ground:
		var holder: Node3D = level.sectors.get(String(t["sector"]), level.root)
		var drawn := holder.find_child(String(t["name"]), true, false) as MeshInstance3D

		if drawn == null:
			push_error("LevelLoader: no mesh for the terrain %s" % t["name"])
			continue

		var body := StaticBody3D.new()
		body.name = "terrain_" + String(t["name"])
		body.collision_layer = 1
		body.set_meta(&"surface", String(t["surface"]))
		var shape := CollisionShape3D.new()
		shape.shape = drawn.mesh.create_trimesh_shape()
		body.add_child(shape)
		holder.add_child(body)
		shape.global_transform = drawn.global_transform

		if bool(t.get("occluder", false)) and occluders != null:
			var occluder := OccluderInstance3D.new()
			var mesh := ArrayOccluder3D.new()
			var points := PackedVector3Array()
			var indices := PackedInt32Array()

			for s in drawn.mesh.get_surface_count():
				var arrays := drawn.mesh.surface_get_arrays(s)
				var base := points.size()
				points.append_array(arrays[Mesh.ARRAY_VERTEX])

				for i in (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array):
					indices.append(base + i)

			mesh.set_arrays(points, indices)
			occluder.occluder = mesh
			occluders.add_child(occluder)
			occluder.global_transform = drawn.global_transform


static func _marker(raw: Dictionary) -> Dictionary:
	return {
		"name": String(raw["name"]), "ucd": String(raw["ucd"]), "sector": String(raw.get("sector", "")),
		"transform": Transform3D(_basis(raw["basis"]), _vector(raw["position"])),
		"size": _vector(raw["size"]) if raw.get("size") != null else null,
		"props": raw.get("props", {}),
	}


static func _own_markers(level: Level) -> void:
	var zones: Array = []

	for m in level.markers:
		var at: Transform3D = m["transform"]

		match m["ucd"]:
			"vantage":
				var node := _placed(level, m, at)
				node.add_to_group(&"cine_vantage")

				if String(m["props"].get("lens", "")) != "":
					node.set_meta(&"lens", StringName(m["props"]["lens"]))
			"hide":
				var node := _placed(level, m, at)
				node.add_to_group(&"hide_spot")
				node.set_meta(&"label", String(m["props"].get("label", "")))
			"hunt_area":
				var node := _placed(level, m, at)
				node.add_to_group(&"hunt_area")
				node.set_meta(&"label", String(m["props"].get("label", "")))
				node.set_meta(&"box", AABB(at.origin - m["size"] * 0.5, m["size"]))
			"mark", "spawn", "landmark":
				var node := _placed(level, m, at)
				level.marks[m["name"]] = node

				if m["ucd"] == "landmark":
					node.add_to_group(&"landmark")
					node.set_meta(&"label", String(m["props"].get("label", "")))
			"zone":
				zones.append(m)

	if not zones.is_empty():
		level.zones = _shared_zones(level)

		for m in zones:
			level.zones.add_zone(m["name"], m["transform"], m["size"], String(m["props"]["grade"]), float(m["props"].get("fog", 1.0)),
				String(m["props"].get("fog_color", "")))


## One set of zones for every level loaded under the same parent (a map of
## several districts): two would each grade the one camera their own way.
static func _shared_zones(level: Level) -> Node:
	var parent := level.root.get_parent()

	for found in level.root.get_tree().get_nodes_in_group(&"level_zones"):
		if parent.is_ancestor_of(found):
			return found

	var zones: Node = ZonesScript.new()
	zones.name = "Zones"
	zones.add_to_group(&"level_zones")
	level.root.add_child(zones)
	return zones


static func _placed(level: Level, m: Dictionary, at: Transform3D) -> Marker3D:
	var node := Marker3D.new()
	node.name = m["name"]
	var holder: Node3D = level.sectors.get(m["sector"], level.root)
	holder.add_child(node)
	node.global_transform = at
	return node


static func _vector(v: Variant) -> Vector3:
	return Vector3(float(v[0]), float(v[1]), float(v[2])) if v is Array else Vector3.ZERO


## A basis from the manifest's rows (Godot's Basis takes its columns).
static func _basis(rows: Array) -> Basis:
	return Basis(Vector3(rows[0][0], rows[1][0], rows[2][0]), Vector3(rows[0][1], rows[1][1], rows[2][1]), Vector3(rows[0][2], rows[1][2], rows[2][2]))
