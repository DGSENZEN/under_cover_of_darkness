extends "res://maps/npc_showcase.gd"
## The garrison (the garrison spec): the NPC showcase's night in a walled
## keep on the canal bank, built in Blender with the level kit (tools/level:
## assets/level/garrison) and put together here from its markers.
##
## Everything the yard's script does once the place exists is the yard's
## (maps/npc_showcase.gd: the cast's configuration, the rota's engine, the
## director, the camera, the overlay, the weather's key, the intruder); this
## script answers only for the place: the level loaded, and the game's nodes
## made from its markers (doors, lights, stations, the bell, the canal, the
## climb, chests and crates, routes, gathering places, landmarks, the marks
## the story plays on), where the cast stands, the night's duties and air.
##   Godot --path . res://maps/garrison.tscn

const LevelLoader := preload("res://scripts/Level/LevelLoader.gd")
const ClimbScript := preload("res://scripts/PlayerUtils/ClimbVolume.gd")
const Materials := preload("res://scripts/Visual/Materials.gd")
const LEVEL := "res://assets/level/garrison"
## The night it plays: six acts on the level's marks.
const GARRISON_STORY := "res://scripts/Showcase/GarrisonNight.gd"

## The marker's archetype names to the game's.
const ARCHETYPES := {"watchman": &"", "arms_master": &"trainer"}
## Where the air's leaves blow (Atmosphere: centred on the origin).
const GROUNDS := Vector2(60.0, 52.0)
## The ladder that can be pulled up onto the range's roof (its climb's
## marker), and the roof's height there.
const LADDER := "range_ladder"
const LADDER_ON_ROOF := 3.25
## Lightning through the chapel's glass: its shafts of light flare this many
## times their own and die back over this long (s).
const GLASS_FLARE := 7.0
## The smallest island of navmesh kept (m²): the tops of sack piles, barrels
## and crates left out. The highest step a man walks up (m): the garrison's
## risers are 0.2, and a sack pile's or a bench's top (0.5) must not be one.
const MIN_ISLAND := 1.2
const MAX_CLIMB := 0.3
const GLASS_FADE := 0.9
## The moon's way (its light, as garrison_lights sets it); the chapel's north
## glass line (z); dust boxes this big, at these distances (m) down a shaft.
const MOON_TOWARD := Vector3(0.62, -0.5, 0.6)
## Screen-space reflections this fine (the canal, the puddles).
const SSR_STEPS := 48
## Decals: how much of their picture over the wall's; faded out from this far.
const DECAL_MIX := 0.85
const DECAL_FADE := 40.0
const GLASS_LINE := -25.2
const DUST_BOX := Vector3(1.0, 1.1, 1.0)
const DUST_STEPS := [1.6, 3.2, 4.8, 6.3]

var level: LevelLoader.Level = null
## Every door by its marker's name.
var doors := {}


func _story_path() -> String:
	return GARRISON_STORY


## The show's camera starts high over the south-west corner, over the walls.
func camera_home() -> Array:
	return [Vector3(-22.0, 24.0, 44.0), Vector3(2.0, 0.0, 0.0)]


## The place: the level from its markers, the moon and the sky, the night.
func build() -> void:
	level = LevelLoader.load_level(self, LEVEL)
	_doors()
	_things()
	_stations_from_markers()
	_routes_from_markers()
	_marks_from_markers()
	_garrison_lights()
	_baker = NavigationRegion3D.new()
	_baker.set_script(NavBakerScript)
	# (Nobody routed over a sack pile, a bench or a barrel's top.)
	_baker.min_island = MIN_ISLAND
	_baker.agent_max_climb = MAX_CLIMB
	add_child(_baker)


# ---------------------------------------------------------------------------
# Markers into the game's nodes
# ---------------------------------------------------------------------------

func _doors() -> void:
	for m in level.of("door"):
		var at: Transform3D = m["transform"]
		var props: Dictionary = m["props"]
		var width := float(props.get("width", 1.2))
		# The marker is the opening's middle; a door's node is its hinge (at the
		# opening's left, looking along its front).
		var hinge := at.origin - at.basis.x * width * 0.5
		var key := StringName(String(props.get("key", "")))
		var door: Node3D = Props.door(self, hinge, at.basis.get_euler().y, width, float(props.get("height", 2.2)), bool(props.get("locked", false)),
			key, String(props.get("label", "")) if String(props.get("label", "")) != "" else "door")
		door.name = m["name"]
		doors[m["name"]] = door

		# Studded planks on the panel (its own UVs: the photo swings with it).
		for panel in door.find_children("*", "MeshInstance3D", true, false):
			if (panel as MeshInstance3D).get_aabb().size.y > 1.0:
				(panel as MeshInstance3D).material_override = Materials.surface(&"wood_studded")


func _things() -> void:
	for m in level.of("bell"):
		var at: Transform3D = m["transform"]
		var bell: StaticBody3D = AlarmBellScript.build(self, at.origin, at.basis.get_euler().y)
		bell.set("ring_db", float(m["props"].get("db", 90.0)))

	for m in level.of("water"):
		var water: Area3D = WaterScript.build(self, (m["transform"] as Transform3D).origin, m["size"])
		water.set("clarity", 1.0 - float(m["props"].get("murk", 0.6)))
		# The canal catches the lamps and the lit windows in streaks.
		water.call_deferred(&"ripple")

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
		add_child(volume)
		volume.global_transform = m["transform"]

	# Decals: grime, leaks and moss, projected into their walls.
	for m in level.of("decal"):
		_decal(m)

	# Chests (a rummaging man's), the carrier's crates, the woodpile.
	for m in level.of("mark"):
		var name: String = m["name"]
		var at: Transform3D = m["transform"]

		if name.begins_with("chest_box_"):
			var chest: Node3D = Props.chest(self, at.origin, at.basis.get_euler().y, Vector3(0.9, 0.55, 0.55))
			chest.name = name
		elif name.begins_with("cargo_"):
			var crate := Props.crate(self, at.origin, 0.5, 5.0)
			crate.add_to_group(&"cargo")
		elif name == "woodpile":
			var pile := Marker3D.new()
			pile.name = "Woodpile"
			pile.add_to_group(&"woodpiles")
			add_child(pile)
			pile.global_position = at.origin


func _stations_from_markers() -> void:
	for m in level.of("station"):
		var at: Transform3D = m["transform"]
		var station := GuardStationScript.new()
		station.name = m["name"]
		station.kind = StringName(String(m["props"]["kind"]))
		add_child(station)
		station.global_transform = at
		_stations[m["name"]] = station

	for m in level.of("station"):
		var station: Node = _stations[m["name"]]
		var chest := String(m["props"].get("chest", ""))
		var drop := String(m["props"].get("drop_to", ""))

		if chest != "" and has_node(chest):
			station.chest = station.get_path_to(get_node(chest))

		if drop != "":
			var target: Node = level.marks.get(drop)

			if target != null:
				station.drop_to = station.get_path_to(target)


func _routes_from_markers() -> void:
	for route in level.of("route"):
		var node := Node3D.new()
		node.name = _route_name(route["name"])
		add_child(node)
		var points := level.of("waypoint").filter(func(w): return w["props"].get("route") == route["name"])
		points.sort_custom(func(a, b): return int(a["props"]["order"]) < int(b["props"]["order"]))

		for w in points:
			var point := Marker3D.new()
			node.add_child(point)
			point.global_transform = w["transform"]

		_routes[route["name"]] = node


## The yard's routes were "WallRoute" and "YardRoute": wall_round -> WallRoute.
static func _route_name(marker_name: String) -> String:
	return marker_name.trim_suffix("_round").capitalize().replace(" ", "") + "Route"


func _marks_from_markers() -> void:
	for m in level.markers:
		if m["ucd"] in ["mark", "spawn"]:
			marks[m["name"]] = (m["transform"] as Transform3D).origin

	# Landmarks the talk and the call-outs name places by.
	for m in level.of("landmark"):
		var node: Node = level.marks.get(m["name"])

		if node != null:
			node.add_to_group(&"landmarks")
			node.set_meta(&"landmark", String(m["props"]["label"]))

	# The gathering places: dice by the fire, the story at it.
	if marks.has("gather_dice"):
		var dice: Vector3 = marks["gather_dice"]
		_gathering_place(&"dice", dice, [[Vector3(0.9, 0, 0), &"squat", &"any"], [Vector3(-0.9, 0, 0), &"squat", &"any"], [Vector3(0, 0, 0.9), &"squat", &"any"]])

	if marks.has("gather_story"):
		var at: Vector3 = marks["gather_story"]
		_gathering_place(&"story", at, [[Vector3(1.5, 0, 0), &"stand", &"teller"], [Vector3(-1.2, 0, 0.9), &"stand", &"listener"],
			[Vector3(-1.2, 0, -0.9), &"stand", &"listener"], [Vector3(0, 0, 1.6), &"stand", &"listener"]])


# ---------------------------------------------------------------------------
# The light: the moon and the sky (as the yard's), and every light marker
# ---------------------------------------------------------------------------

func _garrison_lights() -> void:
	var environment := RetroScript.night_environment(Color(0.34, 0.34, 0.42), AMBIENT_ENERGY)
	environment.volumetric_fog_density = 0.01
	# The canal and the puddles reflect what is lit (the lamps, the windows).
	environment.ssr_enabled = true
	environment.ssr_max_steps = SSR_STEPS
	environment.tonemap_exposure = EXPOSURE
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.65, 0.95)
	moon.light_energy = MOON_ENERGY
	moon.shadow_enabled = true
	moon.light_volumetric_fog_energy = 4.0
	moon.directional_shadow_max_distance = 90.0
	add_child(moon)
	moon.global_basis = Basis.looking_at(Vector3(0.62, -0.5, 0.6).normalized(), Vector3.UP)

	for m in level.of("light"):
		_light(m)

	night = NightScript.new()
	night.name = "Night"
	night.moon = moon
	night.environment = environment
	night.seed = 1932
	var puddles: Array[Vector3] = []

	for at in [Vector3(-10, 0.02, 12), Vector3(6, 0.02, -8), Vector3(-2, 0.02, 16), Vector3(4, 0.02, 20), Vector3(-12, 0.02, -6), Vector3(20, 0.02, 21)]:
		puddles.append(at)

	night.puddles = puddles
	var mist: Array[AABB] = [AABB(Vector3(-46, -0.5, -46), Vector3(92, 3.0, 92))]
	night.mist_boxes = mist
	add_child(night)
	night.flashed.connect(_lightning_through_glass)

	for body in level.root.find_children("*", "MeshInstance3D", true, false):
		for i in (body as MeshInstance3D).get_surface_override_material_count():
			var material := (body as MeshInstance3D).get_surface_override_material(i) as StandardMaterial3D

			if material != null:
				night.register_wet(material)


func _light(m: Dictionary) -> void:
	var at: Transform3D = m["transform"]
	var props: Dictionary = m["props"]
	var kind := String(props["kind"])
	var overrides := {}

	if float(props.get("energy", 0.0)) > 0.0:
		overrides["energy"] = float(props["energy"])

	if float(props.get("range", 0.0)) > 0.0:
		overrides["light_range"] = float(props["range"])

	if String(props.get("color", "")) != "":
		overrides["color"] = Color(String(props["color"]))

	var yaw := at.basis.get_euler().y

	match kind:
		"torch":
			Lights.torch_at(self, at.origin, float(overrides.get("energy", 1.6)), float(overrides.get("light_range", 9.0)), float(overrides.get("energy", 1.6)) > 1.0)
		"brazier":
			if m["name"] == "fire":
				fire = FireScript.brazier(self, at.origin)
				fire.fuel = FIRE_FUEL
				fire.fuel_seconds = FIRE_BURNS
			else:
				Lights.brazier(self, at.origin, overrides)
		"candle":
			Lights.candelabra(self, at.origin, 3, yaw, overrides)
		"lantern":
			Lights.hanging_lantern(self, at.origin, 0.4, overrides)
		"lamp_post":
			Lights.lamp_post(self, at.origin, yaw, overrides)
		"chandelier":
			Lights.chandelier(self, at.origin, 8, float(props.get("chain", 1.0)), overrides)
		"hearth":
			Lights.hearth(self, at.origin, yaw, overrides)
		"fire":
			Lights.campfire(self, at.origin, overrides)
		"glow", "window":
			var glow := OmniLight3D.new()
			glow.light_color = overrides.get("color", Color(1.0, 0.55, 0.25))
			glow.light_energy = float(overrides.get("energy", 0.6))
			glow.omni_range = float(overrides.get("light_range", 4.0))
			add_child(glow)
			glow.global_position = at.origin
		"window_shaft":
			# Moonlight through the glass: a spot along the moon's way, caught in
			# the chapel's dusty fog.
			var shaft := SpotLight3D.new()
			shaft.light_color = overrides.get("color", Color(1.0, 0.7, 0.4))
			shaft.light_energy = float(overrides.get("energy", 2.0))
			shaft.spot_range = float(overrides.get("light_range", 12.0))
			shaft.spot_angle = 12.0
			shaft.light_volumetric_fog_energy = 3.0
			shaft.shadow_enabled = false
			# (The glass's picture cast through it, when the photo is here.)
			shaft.light_projector = Materials.photo(&"stained_glass")
			shaft.set_meta(&"calm", shaft.light_energy)
			shaft.add_to_group(&"glass_shafts")
			add_child(shaft)
			shaft.global_position = at.origin
			shaft.global_basis = Basis.looking_at(Vector3(0.62, -0.5, 0.6).normalized(), Vector3.UP)


## A decal marker made a Decal: its photo ("decal_<kind>") projected into
## the wall it faces (its -z), or straight down onto a floor. Nothing when
## the photo is not on this machine (the flat-colour fallback has no stains).
func _decal(m: Dictionary) -> void:
	var texture := Materials.picture("decal_" + String(m["props"]["kind"]))

	if texture == null:
		return

	var at: Transform3D = m["transform"]
	var size: Vector3 = m["size"]
	var decal := Decal.new()
	decal.name = m["name"]
	decal.texture_albedo = texture
	decal.albedo_mix = DECAL_MIX
	decal.distance_fade_enabled = true
	decal.distance_fade_begin = DECAL_FADE
	decal.distance_fade_length = 10.0
	add_child(decal)

	if bool(m["props"].get("floor", false)):
		decal.size = Vector3(size.x, size.y, size.z)
		decal.global_transform = Transform3D(Basis(Vector3.UP, at.basis.get_euler().y), at.origin)
		return

	# Its projection (-y) into the wall, its picture's top up.
	decal.size = Vector3(size.x, size.z, size.y)
	decal.global_transform = Transform3D(Basis(at.basis.x, at.basis.z, Vector3.DOWN), at.origin)


## The ladder up the range's roof pulled up by a man on it (ShowNight's
## intruder going to ground): it lies on the roof now, and nobody climbs
## after him (its climb and the navmesh's ways up it gone).
func pull_up_ladder() -> void:
	var volume := get_node_or_null(LADDER)

	if volume != null:
		for link in find_children("*", "NavigationLink3D", true, false):
			if link.has_meta(&"volume") and link.get_meta(&"volume") == volume:
				(link as NavigationLink3D).enabled = false

		volume.queue_free()

	for piece in level.root.find_children("ladder_3*", "", true, false):
		var at: Vector3 = (piece as Node3D).global_position
		# Tipped over onto its back, lying on the roof from the eaves inward.
		(piece as Node3D).global_transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(at.x, LADDER_ON_ROOF, at.z + 0.6))


## A flash outside (Night): the chapel's shafts of light flare through the
## glass and die back.
func _lightning_through_glass() -> void:
	for shaft in get_tree().get_nodes_in_group(&"glass_shafts"):
		var light := shaft as Light3D
		var calm := float(light.get_meta(&"calm", light.light_energy))
		light.light_energy = calm * GLASS_FLARE
		var fade := light.create_tween()
		fade.tween_property(light, "light_energy", calm, GLASS_FADE).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


# ---------------------------------------------------------------------------
# The cast where the markers put them; the night's duties and air
# ---------------------------------------------------------------------------

func _spawn_cast() -> void:
	for entry in CAST:
		var name: String = entry[0]
		var m: Dictionary = level.get_marker(name)

		if m.is_empty():
			push_error("garrison: no marker for %s" % name)
			continue

		var props: Dictionary = m["props"]
		var at: Transform3D = m["transform"]
		var g: CharacterBody3D = GUARD.instantiate()
		g.name = name
		g.given_name = name
		var archetype := String(props.get("archetype", ""))
		g.archetype = ARCHETYPES.get(archetype, StringName(archetype))
		g.temperament = StringName(String(props.get("temperament", "")))
		g.look_seed = int(props.get("look_seed", entry[3]))
		g.lookout = bool(props.get("lookout", false))
		g.debug_ai = false
		g.habits.assign([&"fidget", &"lean"])
		var paths: Array[NodePath] = []

		for key in String(props.get("stations", "")).split(",", false):
			if _stations.has(key.strip_edges()):
				paths.append((_stations[key.strip_edges()] as Node).get_path())

		g.stations = paths

		if String(props.get("route", "")) != "" and _routes.has(String(props["route"])):
			g.patrol_route = (_routes[String(props["route"])] as Node).get_path()

		g.position = at.origin
		g.rotation.y = at.basis.get_euler().y
		add_child(g)

		if g.get("_bark_label") != null:
			g._bark_label.visible = false

		cast[name] = g
		roles[name] = String(props.get("role", entry[4]))


func _night() -> void:
	rota = NightRotaScript.setup(self, HOUR, &"early")
	rota.post_turn = POST_TURN
	rota.wants_rest = false
	# The colonnade's post (Hendrik's at the start of the night; the watch
	# changes there: ShowNight), the rounds, the bench and the bed.
	var post: Dictionary = level.get_marker("Hendrik")
	rota.add_duty(&"colonnade", &"post", {"transform": post["transform"]})
	rota.add_duty(&"yard_round", &"round", {"route": (_routes["yard_round"] as Node).get_path()})
	rota.add_duty(&"wall_round", &"round", {"route": (_routes["wall_round"] as Node).get_path()})
	rota.add_duty(&"bench", &"bench", {"paths": [(_stations["sit_bench"] as Node).get_path()]})
	rota.add_duty(&"bed", &"bed", {"paths": [(_stations["sleep_tam"] as Node).get_path()]})
	var duties := {"Hendrik": &"colonnade", "Wat": &"wall_round", "Jory": &"bench", "Tam": &"bed"}

	for name in duties:
		var man: Node = cast.get(name)

		if man != null:
			rota.assign(man, duties[name])

	GatheringScript.of(self).spontaneous = false
	set_meta(&"yard_size", GROUNDS)
	atmosphere = AtmosphereScript.new()
	atmosphere.name = "Atmosphere"
	add_child(atmosphere)
	atmosphere.add_crows([Vector3(-12, 6.15, -27.0), Vector3(-2, 6.15, -27.0), Vector3(9, 6.15, -27.0), Vector3(20, 6.15, -27.0), Vector3(31.0, 6.15, 4.0)])
	atmosphere.add_dust(_shaft_dust())


## Where dust hangs in the chapel: boxes down each shaft of moonlight, from
## its lancet on along the moon's way to the floor.
func _shaft_dust() -> Array:
	var boxes := []
	var toward := MOON_TOWARD.normalized()
	# (Inside the chapel only: the east shaft meets its wall before the floor.)
	var inside := AABB()

	for m in level.of("zone"):
		if m["name"] == "zone_chapel":
			inside = AABB((m["transform"] as Transform3D).origin - m["size"] * 0.5, m["size"]).grow(-0.4)

	for m in level.of("light"):
		if String(m["props"]["kind"]) != "window_shaft":
			continue

		# From the glass (the shaft's lancet, in the north wall) on inward.
		var glass: Vector3 = (m["transform"] as Transform3D).origin
		var start := glass + toward * ((glass.z - GLASS_LINE) / -toward.z)

		for step in DUST_STEPS:
			var box := AABB(start + toward * float(step) - DUST_BOX * 0.5, DUST_BOX)

			if inside.has_volume():
				box = box.intersection(inside)

			if box.has_volume():
				boxes.append(box)

	return boxes


func _overview() -> void:
	if get_viewport().get_camera_3d() != null:
		return

	var view := Camera3D.new()
	view.name = "Overview"
	view.fov = 55.0
	add_child(view)
	view.global_position = Vector3(-26, 30, 44)
	view.look_at(Vector3(2, 0, -2), Vector3.UP)
	view.make_current()
