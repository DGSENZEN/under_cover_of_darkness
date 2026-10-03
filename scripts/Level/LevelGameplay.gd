extends RefCounted
## Builds gameplay nodes from LevelLoader marker records: doors, lights, water/climbing, routes/stations, pickups, and mission places.
## build_all() creates everything except guards; create guards after navigation baking.
## Mechanisms expose metadata stubs, with physical raised/lowered portcullis grids.
## Marker props and returned collections are documented in docs/systems/world.md.

const Props := preload("res://scripts/Interaction/Props.gd")
const Lights := preload("res://scripts/Visual/Lights/Lights.gd")
const Materials := preload("res://scripts/Visual/Materials.gd")
const Layers := preload("res://scripts/Visual/Layers.gd")
const SoundBus := preload("res://scripts/StimuliSystem/SoundBus.gd")
const WaterScript := preload("res://scripts/Interaction/WaterVolume.gd")
const ClimbScript := preload("res://scripts/PlayerUtils/ClimbVolume.gd")
const RopeScript := preload("res://scripts/PlayerUtils/VerletRope.gd")
const AlarmBellScript := preload("res://scripts/Interaction/AlarmBell.gd")
const GuardStationScript := preload("res://scripts/AISystem/GuardStation.gd")
const GROUND_STAIN := preload("res://scripts/Visual/ground_stain.gdshader")
const BlowholeScript := preload("res://scripts/Visual/Blowhole.gd")
const ChimneySmokeScript := preload("res://scripts/Visual/ChimneySmoke.gd")

## A marker's archetype to the game's (Guard.archetype).
const ARCHETYPES := {"watchman": &"", "arms_master": &"trainer"}
## A tool marker's kind to the belt's: [id, name, mesh shape, colour].
const TOOLS := {
	"flask": [&"waterflask", "water flask", "flask", Color(0.4, 0.6, 0.9)],
	"flash_bomb": [&"flashbomb", "flash bomb", "ball", Color(0.3, 0.28, 0.26)],
	"lockpick": [&"lockpick", "lockpick", "rod", Color(0.6, 0.6, 0.65)],
}
## A prop marker's kind: [size (m), mass (kg)].
const PROPS := {"crate": [0.5, 5.0], "crate_small": [0.3, 1.0]}
## Decals: how much of their picture over the wall's; faded out from this
## far; floor stains ([strength, curve]) laid this far over their floor
## (their marker FLOOR_MARK over it).
const DECAL_MIX := 0.85
const DECAL_FADE := 40.0
const STAINS := {"soot": [1.2, 0.75], "dirt": [1.3, 0.3]}
const STAIN_LIFT := 0.012
const FLOOR_MARK := 0.05
## A portcullis's bars: this far apart, this thick; raised, it rises all but
## this much of its height.
const BAR_GAP := 0.3
const BAR := 0.07
const RAISED_SHOWS := 0.35


## Creates marker-driven nodes under parent and returns collections keyed by system name (world.md), chimney smoke included.
## level is a dynamic Level-like object exposing of(), marks, and marker dictionaries. Guards require a separate call after navigation baking.
static func build_all(parent: Node3D, level) -> Dictionary:
	var made := {
		"doors": doors(parent, level), "lights": lights(parent, level), "water": water(parent, level),
		"ladders": ladders(parent, level), "ropes": ropes(parent, level), "bells": bells(parent, level),
		"decals": decals(parent, level), "routes": routes(parent, level), "stations": stations(parent, level),
		"pickups": pickups(parent, level), "chests": chests(parent, level), "props": props(parent, level),
		"noise_zones": noise_zones(parent, level), "mechanisms": mechanisms(parent, level),
		"smokes": smokes(parent, level),
	}
	mission_marks(parent, level)
	return made


static func doors(parent: Node3D, level) -> Dictionary:
	var out := {}

	for m in level.of("door"):
		var at: Transform3D = m["transform"]
		var props: Dictionary = m["props"]
		var width := float(props.get("width", 1.2))
		# The marker is the opening's middle; a door's node is its hinge.
		var hinge := at.origin - at.basis.x * width * 0.5
		var label := String(props.get("label", ""))
		var door: Node3D = Props.door(parent, hinge, at.basis.get_euler().y, width, float(props.get("height", 2.2)), bool(props.get("locked", false)),
			StringName(String(props.get("key", ""))), label if label != "" else "door")
		door.name = m["name"]
		door.set("pickable", bool(props.get("pick", true)))
		out[m["name"]] = door

		for panel in door.find_children("*", "MeshInstance3D", true, false):
			if (panel as MeshInstance3D).get_aabb().size.y > 1.0:
				(panel as MeshInstance3D).material_override = Materials.surface(&"wood_studded")

	return out


## Every light marker made into its light, named after its marker (the
## district's memory finds it by name), dousable as its marker says: marker
## name → node. A torch is a bare flame for two ticks, then its fixture
## (Lights.torch_at), which takes over its name and its place here.
static func lights(parent: Node3D, level) -> Dictionary:
	var out := {}

	for m in level.of("light"):
		var made := _light(parent, m)

		if made == null:
			continue

		var marker_name := String(m["name"])
		made.name = marker_name
		made.set_meta(&"marker", marker_name)
		made.set_meta(&"made_in", out)

		if made.get("can_douse") != null:
			made.set("can_douse", bool(m["props"].get("douse", true)))

		out[marker_name] = made

	return out


static func _light(parent: Node3D, m: Dictionary) -> Node3D:
	var at: Transform3D = m["transform"]
	var props: Dictionary = m["props"]
	var overrides := {}

	if float(props.get("energy", 0.0)) > 0.0:
		overrides["energy"] = float(props["energy"])

	if float(props.get("range", 0.0)) > 0.0:
		overrides["light_range"] = float(props["range"])

	if String(props.get("color", "")) != "":
		overrides["color"] = Color(String(props["color"]))

	var yaw := at.basis.get_euler().y

	match String(props["kind"]):
		"torch":
			var energy := float(overrides.get("energy", 1.6))
			return Lights.torch_at(parent, at.origin, energy, float(overrides.get("light_range", 9.0)), energy > 1.0)
		"brazier":
			return Lights.brazier(parent, at.origin, overrides)
		"candle":
			return Lights.candelabra(parent, at.origin, 3, yaw, overrides)
		"lantern":
			return Lights.hanging_lantern(parent, at.origin, 0.4, overrides)
		"lamp_post":
			return Lights.lamp_post(parent, at.origin, yaw, overrides)
		"chandelier":
			return Lights.chandelier(parent, at.origin, 8, float(props.get("chain", 1.0)), overrides)
		"hearth":
			return Lights.hearth(parent, at.origin, yaw, overrides)
		"fire":
			return Lights.campfire(parent, at.origin, overrides)
		"glow", "window":
			var glow := OmniLight3D.new()
			glow.light_color = overrides.get("color", Color(1.0, 0.55, 0.25))
			glow.light_energy = float(overrides.get("energy", 0.6))
			glow.omni_range = float(overrides.get("light_range", 4.0))
			parent.add_child(glow)
			glow.global_position = at.origin
			return glow
		"window_shaft":
			var shaft := SpotLight3D.new()
			shaft.light_color = overrides.get("color", Color(1.0, 0.7, 0.4))
			shaft.light_energy = float(overrides.get("energy", 2.0))
			shaft.spot_range = float(overrides.get("light_range", 12.0))
			shaft.spot_angle = 12.0
			shaft.light_volumetric_fog_energy = 3.0
			shaft.shadow_enabled = false
			shaft.light_projector = Materials.photo(&"stained_glass")
			shaft.set_meta(&"calm", shaft.light_energy)
			shaft.add_to_group(&"glass_shafts")
			parent.add_child(shaft)
			shaft.global_transform = at
			return shaft

	return null


static func water(parent: Node3D, level) -> Array:
	var out := []

	for m in level.of("water"):
		var body: Area3D = WaterScript.build(parent, (m["transform"] as Transform3D).origin, m["size"])
		body.name = m["name"]
		body.set("clarity", 1.0 - float(m["props"].get("murk", 0.6)))
		body.call_deferred(&"ripple")
		out.append(body)

	return out


static func ladders(parent: Node3D, level) -> Array:
	var out := []

	for m in level.of("ladder"):
		var volume := Area3D.new()
		volume.set_script(ClimbScript)
		volume.name = m["name"]
		volume.set("rope", bool(m["props"].get("rope", false)))
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = m["size"]
		shape.shape = box
		volume.add_child(shape)
		parent.add_child(volume)
		volume.global_transform = m["transform"]
		out.append(volume)

	return out


## Ropes and chains hanging from their markers (VerletRope: climbed and
## swung on).
static func ropes(parent: Node3D, level) -> Array:
	var out := []

	for m in level.of("rope"):
		var rope := Area3D.new()
		rope.set_script(RopeScript)
		rope.name = m["name"]
		rope.set("style", 1 if bool(m["props"].get("chain", false)) else 0)
		rope.set("length", float(m["props"]["length"]))
		# (Placed before it is added: it hangs its links from where it is.)
		rope.position = (m["transform"] as Transform3D).origin - parent.global_position
		parent.add_child(rope)
		out.append(rope)

	return out


static func bells(parent: Node3D, level) -> Array:
	var out := []

	for m in level.of("bell"):
		var at: Transform3D = m["transform"]
		var bell: StaticBody3D = AlarmBellScript.build(parent, at.origin, at.basis.get_euler().y)
		bell.set("ring_db", float(m["props"].get("db", 90.0)))
		out.append(bell)

	return out


static func decals(parent: Node3D, level) -> Array:
	var out := []

	for m in level.of("decal"):
		var made := _decal(parent, m)

		if made != null:
			out.append(made)

	return out


## A decal marker made a Decal: its picture projected into the wall it faces
## (its -z) or down onto a floor; soot and dirt as darkening cards on the
## floor. Nothing without its picture.
static func _decal(parent: Node3D, m: Dictionary) -> Node3D:
	var kind := String(m["props"]["kind"])
	var texture := Materials.picture("decal_" + kind)

	if texture == null:
		return null

	var at: Transform3D = m["transform"]
	var size: Vector3 = m["size"]

	if STAINS.has(kind):
		var card := MeshInstance3D.new()
		card.name = m["name"]
		card.set_meta(&"kind", kind)
		var plane := PlaneMesh.new()
		plane.size = Vector2(size.x, size.z)
		card.mesh = plane
		var paint := ShaderMaterial.new()
		paint.shader = GROUND_STAIN
		paint.set_shader_parameter(&"stain", texture)
		paint.set_shader_parameter(&"strength", float(STAINS[kind][0]))
		paint.set_shader_parameter(&"curve", float(STAINS[kind][1]))
		card.material_override = paint
		card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		card.visibility_range_end = DECAL_FADE + 10.0
		card.visibility_range_end_margin = 10.0
		card.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		parent.add_child(card)
		card.global_transform = Transform3D(Basis(Vector3.UP, at.basis.get_euler().y), at.origin + Vector3.UP * (STAIN_LIFT - FLOOR_MARK))
		return card

	var decal := Decal.new()
	decal.name = m["name"]
	decal.set_meta(&"kind", kind)
	decal.cull_mask = Layers.WORLD_ALL
	decal.texture_albedo = texture
	decal.albedo_mix = DECAL_MIX
	decal.distance_fade_enabled = true
	decal.distance_fade_begin = DECAL_FADE
	decal.distance_fade_length = 10.0
	parent.add_child(decal)

	if bool(m["props"].get("floor", false)):
		decal.size = size
		decal.global_transform = Transform3D(Basis(Vector3.UP, at.basis.get_euler().y), at.origin)
	else:
		decal.size = Vector3(size.x, size.z, size.y)
		decal.global_transform = Transform3D(Basis(at.basis.x, at.basis.z, Vector3.DOWN), at.origin)

	return decal


## Each route as a node of its points in order (a Guard's patrol_route),
## named "<route>_route".
static func routes(parent: Node3D, level) -> Dictionary:
	var out := {}

	for route in level.of("route"):
		var node := Node3D.new()
		node.name = String(route["name"]) + "_route"
		parent.add_child(node)
		var points: Array = level.of("waypoint").filter(func(w): return w["props"].get("route") == route["name"])
		points.sort_custom(func(a, b): return int(a["props"]["order"]) < int(b["props"]["order"]))

		for w in points:
			var point := Marker3D.new()
			node.add_child(point)
			point.global_transform = w["transform"]

		out[route["name"]] = node

	return out


static func stations(parent: Node3D, level) -> Dictionary:
	var out := {}

	for m in level.of("station"):
		var station := GuardStationScript.new()
		station.name = m["name"]
		station.kind = StringName(String(m["props"]["kind"]))
		parent.add_child(station)
		station.global_transform = m["transform"]
		out[m["name"]] = station

	for m in level.of("station"):
		var drop := String(m["props"].get("drop_to", ""))

		if drop != "" and level.marks.has(drop):
			(out[m["name"]] as Node).set("drop_to", (out[m["name"]] as Node).get_path_to(level.marks[drop]))

	return out


## Instantiates scene as CharacterBody3D guards after navigation baking; returns marker-name -> guard.
## level is dynamic; route_nodes/station_nodes supply existing nodes by name. Missing optional references are ignored.
static func guards(parent: Node3D, level, route_nodes: Dictionary, station_nodes: Dictionary, scene: PackedScene) -> Dictionary:
	var out := {}

	for m in level.of("guard"):
		var props: Dictionary = m["props"]
		var at: Transform3D = m["transform"]
		var g: CharacterBody3D = scene.instantiate()
		g.name = m["name"]
		g.set("given_name", String(m["name"]))
		var archetype := String(props.get("archetype", ""))
		g.set("archetype", ARCHETYPES.get(archetype, StringName(archetype)))
		g.set("temperament", StringName(String(props.get("temperament", ""))))
		g.set("look_seed", int(props.get("look_seed", 0)))
		g.set("lookout", bool(props.get("lookout", false)))
		g.set("rounds_light", StringName(String(props.get("light", ""))))
		g.set("debug_ai", false)
		var paths: Array[NodePath] = []

		for key in String(props.get("stations", "")).split(",", false):
			if station_nodes.has(key.strip_edges()):
				paths.append((station_nodes[key.strip_edges()] as Node).get_path())

		g.set("stations", paths)

		if String(props.get("route", "")) != "" and route_nodes.has(String(props["route"])):
			g.set("patrol_route", (route_nodes[String(props["route"])] as Node).get_path())

		g.position = at.origin - parent.global_position
		g.rotation.y = at.basis.get_euler().y
		parent.add_child(g)
		out[m["name"]] = g

	return out


## A man who followed the player through a gate (CityState), made again on
## this side from his spec (Guard.spec): who he was, with no route and no
## stations here; at `at`, named as he was.
static func visitor(parent: Node3D, spec: Dictionary, at: Transform3D, scene: PackedScene) -> CharacterBody3D:
	var g: CharacterBody3D = scene.instantiate()
	g.name = String(spec["name"])
	g.set("given_name", String(spec["name"]))
	g.set("archetype", StringName(spec.get("archetype", &"")))
	g.set("temperament", StringName(spec.get("temperament", &"")))
	g.set("look_seed", int(spec.get("look_seed", 0)))
	g.set("rounds_light", StringName(spec.get("light", &"")))
	g.set("debug_ai", false)
	var keys: Array[StringName] = []

	for key in spec.get("keys", []):
		keys.append(StringName(key))

	g.set("keys", keys)
	g.position = at.origin - parent.global_position
	g.rotation.y = at.basis.get_euler().y
	parent.add_child(g)
	return g


## Loot, keys and tools lying where their markers are: {name: node}. Loot
## marked special is in the group "specials" (a seal: "seals" too).
static func pickups(parent: Node3D, level) -> Dictionary:
	var out := {}

	for m in level.of("loot"):
		var props: Dictionary = m["props"]
		var loot: RigidBody3D = Props.loot(parent, (m["transform"] as Transform3D).origin, int(props["value"]), String(props.get("label", "goblet")))
		loot.name = m["name"]

		if bool(props.get("special", false)):
			loot.set_meta(&"special", true)
			loot.add_to_group(&"specials")

		if String(props.get("kind", "")) == "seal":
			loot.add_to_group(&"seals")

		out[m["name"]] = loot

	for m in level.of("key"):
		var key: RigidBody3D = Props.key(parent, (m["transform"] as Transform3D).origin, StringName(String(m["props"]["key_id"])),
			String(m["props"].get("label", "key")))
		key.name = m["name"]
		out[m["name"]] = key

	for m in level.of("tool"):
		var kind := String(m["props"]["tool"])
		var at: Vector3 = (m["transform"] as Transform3D).origin
		var made: Node = null

		if kind == "arrows":
			made = Props.arrows(parent, at, int(m["props"].get("count", 6)))
		elif TOOLS.has(kind):
			var t: Array = TOOLS[kind]
			var label := String(m["props"].get("label", ""))
			made = Props.tool(parent, at, t[0], label if label != "" else String(t[1]), t[3], String(t[2]), int(m["props"].get("count", 1)))

		if made != null:
			made.name = m["name"]
			out[m["name"]] = made

	return out


static func chests(parent: Node3D, level) -> Dictionary:
	var out := {}

	for m in level.of("chest"):
		var props: Dictionary = m["props"]
		var at: Transform3D = m["transform"]
		var size := Vector3(1.2, 0.7, 0.7) if bool(props.get("large", false)) else Vector3(0.9, 0.55, 0.55)
		var chest: Node3D = Props.chest(parent, at.origin, at.basis.get_euler().y, size, bool(props.get("locked", false)),
			StringName(String(props.get("key", ""))), String(props.get("label", "chest")))
		chest.name = m["name"]
		chest.set("pickable", bool(props.get("pick", true)))
		out[m["name"]] = chest

	return out


## Things to throw (crates) where their markers are.
static func props(parent: Node3D, level) -> Array:
	var out := []

	for m in level.of("prop"):
		var spec: Array = PROPS.get(String(m["props"]["kind"]), PROPS["crate"])
		var mass := float(m["props"].get("mass", 0.0))
		var crate: RigidBody3D = Props.crate(parent, (m["transform"] as Transform3D).origin, float(spec[0]), mass if mass > 0.0 else float(spec[1]))
		crate.name = m["name"]
		out.append(crate)

	return out


## The chimneys' smoke ("smoke" markers: over their pots).
static func smokes(parent: Node3D, level) -> Array:
	var out := []

	for m in level.of("smoke"):
		var smoke: Node3D = ChimneySmokeScript.new()
		smoke.name = m["name"]
		parent.add_child(smoke)
		smoke.global_position = (m["transform"] as Transform3D).origin
		out.append(smoke)

	return out


## Returns a mixed Array of SoundBus integer zone IDs and periodic Blowhole nodes.
## Steady zones are removed on parent.tree_exiting; periodic nodes own their masking lifetime.
static func noise_zones(parent: Node3D, level) -> Array:
	var out := []
	var ids := []

	for m in level.of("noise_zone"):
		var size: Vector3 = m["size"]
		var centre: Vector3 = (m["transform"] as Transform3D).origin
		var box := AABB(centre - size * 0.5, size)

		if float(m["props"].get("period", 0.0)) > 0.0:
			var roar: Node3D = BlowholeScript.new()
			roar.name = m["name"]
			roar.set("zone_box", box)
			roar.set("period", float(m["props"]["period"]))
			roar.set("roar_db", float(m["props"]["db"]))
			roar.position = centre + Vector3.UP * (size.y * 0.5 - 2.0) - parent.global_position
			parent.add_child(roar)
			out.append(roar)
			continue

		var id := SoundBus.add_zone(box, float(m["props"]["db"]))
		out.append(id)
		ids.append(id)

	if not ids.is_empty():
		parent.tree_exiting.connect(func() -> void:
			for id in ids:
				SoundBus.remove_zone(int(id)))

	return out


## The mechanisms, stubs until their sub-project: a node per marker in the
## group "mechanism" (metas kind, target, state, label); a portcullis draws
## its iron bars, solid, down or raised (raise()).
static func mechanisms(parent: Node3D, level) -> Array:
	var out := []

	for kind in ["lever", "wheel", "portcullis", "sluice", "hoist", "slider"]:
		for m in level.of(kind):
			var props: Dictionary = m["props"]
			var node := Node3D.new()
			node.name = m["name"]
			node.add_to_group(&"mechanism")
			node.set_meta(&"kind", kind)
			node.set_meta(&"target", String(props.get("target", "")))
			node.set_meta(&"label", String(props.get("label", "")))
			parent.add_child(node)
			node.global_transform = m["transform"]

			if kind == "portcullis":
				_portcullis(node, float(props.get("width", 4.0)), float(props.get("height", 5.0)))
				raise(node, String(props.get("state", "")) == "up")
			else:
				node.set_meta(&"state", String(props.get("state", "")))

			out.append(node)

	return out


static func _portcullis(node: Node3D, width: float, height: float) -> void:
	var grid := StaticBody3D.new()
	grid.name = "Grid"
	grid.collision_layer = 1
	grid.set_meta(&"surface", "metal")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, height, 0.15)
	shape.shape = box
	shape.position = Vector3(0.0, height * 0.5, 0.0)
	grid.add_child(shape)
	var iron := Materials.surface(&"iron")
	var bars := int(width / BAR_GAP)

	for i in bars + 1:
		var bar := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(BAR, height, BAR)
		bar.mesh = mesh
		bar.material_override = iron
		bar.position = Vector3(-width * 0.5 + i * width / bars, height * 0.5, 0.0)
		grid.add_child(bar)

	for y in [0.35, height * 0.5, height - 0.3]:
		var rail := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(width, BAR * 1.4, BAR * 1.4)
		rail.mesh = mesh
		rail.material_override = iron
		rail.position = Vector3(0.0, y, 0.0)
		grid.add_child(rail)

	node.add_child(grid)
	node.set_meta(&"height", height)


## Moves a portcullis Grid and updates state metadata to up/down. Missing Grid is a no-op.
static func raise(node: Node3D, up: bool) -> void:
	var grid := node.get_node_or_null("Grid") as Node3D

	if grid == null:
		return

	grid.position.y = (float(node.get_meta(&"height", 5.0)) - RAISED_SHOWS) if up else 0.0
	node.set_meta(&"state", "up" if up else "down")


## The mission's places: objectives (group "objective"), exits (an Area3D
## over the box, group "district_exit", meta label: the map watches who
## enters), secrets (the same, group "secret"), and the probes the level's
## suite reads the light at (group "probe", meta expect).
static func mission_marks(parent: Node3D, level) -> void:
	for m in level.of("objective"):
		var mark := Marker3D.new()
		mark.name = m["name"]
		mark.add_to_group(&"objective")
		mark.set_meta(&"label", String(m["props"]["label"]))
		mark.set_meta(&"kind", String(m["props"].get("kind", "steal")))
		parent.add_child(mark)
		mark.global_transform = m["transform"]

	for pair in [["exit", &"district_exit"], ["secret", &"secret"]]:
		for m in level.of(pair[0]):
			var area := Area3D.new()
			area.name = m["name"]
			area.add_to_group(pair[1])
			area.set_meta(&"label", String(m["props"].get("label", "")))

			# An exit: the district it leads to and the arrival there.
			if pair[0] == "exit":
				area.set_meta(&"to", StringName(String(m["props"].get("to", ""))))
				area.set_meta(&"arrive", StringName(String(m["props"].get("arrive", ""))))

			area.collision_layer = 0
			area.collision_mask = 1 | 2
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = m["size"]
			shape.shape = box
			area.add_child(shape)
			parent.add_child(area)
			area.global_transform = m["transform"]

	for m in level.of("probe"):
		var probe := Marker3D.new()
		probe.name = m["name"]
		probe.add_to_group(&"probe")
		probe.set_meta(&"expect", String(m["props"]["expect"]))
		parent.add_child(probe)
		probe.global_transform = m["transform"]
