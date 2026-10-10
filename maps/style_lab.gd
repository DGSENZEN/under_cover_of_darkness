extends Node3D
## The Eclipse city's style lab (docs/superpowers/plans/2026-10-09-eclipse-style-lab.md):
## the Metro kiosk and a run of Zócalo arcade bays, three times side by side,
## each station in one blend of the painted atlas and the painterly shader
## (Painterly.PRESETS): painted-led, even, shader-led. By night under a cold
## moon with the Company's lamps lit, or by day for a look at the joints.
##   F11  day / night
##
## Atlases come from the painted files, the user's own (<piece>.png,
## <piece>_normal.png) before the painter's (<piece>_base.png, ...).

const PLAYER := preload("res://Player.tscn")
const Painterly := preload("res://scripts/Visual/Painterly.gd")
const RetroScript := preload("res://scripts/Visual/Retro.gd")

const STATIONS: Array[StringName] = [&"painted_led", &"even", &"shader_led"]
const STATION_X := [-20.0, 0.0, 20.0]
const KIOSK_Z := 8.0
const BAYS_Z := -3.0
const BAY := 4.5
## The kiosk's stair opening, from its origin (the glTF is Y up, its run along -Z).
const OPENING := Rect2(-1.5, -6.0, 3.0, 6.0)
## The lamp globes, from the kiosk's origin.
const LAMPS := [Vector3(-1.6875, 3.5, -0.15), Vector3(1.6875, 3.5, -0.15)]
const LAMP_COLOUR := Color("#e8d8a8")
## Variant D's painted pools: the spot's strength, reach and cone, and the
## lamp's own glow while it throws one.
const POOL_ENERGY := 6.0
const POOL_RANGE := 8.0
const POOL_ANGLE := 55.0
const POOL_GLOW := 0.5
const MOON_COLOUR := Color("#d8e4f0")
const GROUND := Rect2(-35, -15, 70, 30)
## The kiosk's coping round its opening (m), and a bay's depth behind its
## façade line and in front of it, and the run's end column (m).
const COPING := 0.375
const BAY_BACK := 4.3
const BAY_FRONT := 0.35
const END_COLUMN := 0.5

## Where the pieces and the painted files are (the suites point these elsewhere).
var lab_dir := "res://assets/eclipse/lab/"
var atlas_dir := "res://textures/painted/eclipse/"
## The pieces that could not be found, by path.
var missing := PackedStringArray()

var world: WorldEnvironment
var moon: DirectionalLight3D
var sun: DirectionalLight3D
var player: Node3D

var _night: Environment
var _day: Environment
var _materials := {}
## The painted ground (scripts/Visual/Ground.gd).
var ground: Ground
## The line naming which look layers are on (F1, F2, F4).
var layer_label: Label
## The layers F1, F2 and F4 flip, by key: the shader parameter, whether on,
## and the materials it was on in (a mesh without vertex colours never gets it).
var _layers := {
	KEY_F1: {"name": "vertex paint", "param": &"vertex_paint", "on": true, "materials": []},
	KEY_F2: {"name": "macro", "param": &"macro_amount", "on": true, "materials": []},
	KEY_F4: {"name": "hex", "param": &"hex_tiling", "on": true, "materials": []},
}


func _ready() -> void:
	reset_physics_interpolation.call_deferred()
	_lights()
	var kiosk := _piece(&"kiosk")
	var bay := _piece(&"arcade_bay")

	for k in STATIONS.size():
		_station(STATIONS[k], STATION_X[k], kiosk, bay)

	_ground()
	_look_layers()
	# Variant D (the user's choice): the lamps throw their painted pools.
	set_pools(true)
	player = PLAYER.instantiate()
	player.debug_traversal = false
	add_child(player)
	player.global_position = Vector3(0, 1.05, 14)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		set_day(not sun.visible)
	elif event is InputEventKey and event.pressed and not event.echo and _layers.has(event.keycode):
		set_layer(event.keycode, not _layers[event.keycode]["on"])


# The look's layers (the vertex-paint spec, section 9): played live

## The materials a layer (by its shader parameter) is laid on.
func layer_materials(param: StringName) -> Array:
	for key in _layers:
		if _layers[key]["param"] == param:
			return _layers[key]["materials"]

	return []


## A layer (by its key, F1, F2 or F4) on or off on every material it is laid on.
func set_layer(key: Key, on: bool) -> void:
	var layer: Dictionary = _layers[key]
	layer["on"] = on

	for m: ShaderMaterial in layer["materials"]:
		m.set_shader_parameter(layer["param"], 1.0 if on else 0.0)

	_name_layers()


## Which materials each layer is laid on: vertex paint where a piece's
## meshes carry it, the macro layer where the preset lays it, hex-tiling on
## every painterly material; the ground takes all three.
func _look_layers() -> void:
	var painterly: Array = _materials.values() + [ground.get_node("mesh").material_override]

	for m: ShaderMaterial in painterly:
		for key in _layers:
			var param: StringName = _layers[key]["param"]
			var value: Variant = m.get_shader_parameter(param)

			if param == &"hex_tiling" or (value != null and float(value) > 0.5):
				_layers[key]["materials"].append(m)

	var screen := CanvasLayer.new()
	add_child(screen)
	layer_label = Label.new()
	layer_label.position = Vector2(12, 8)
	layer_label.add_theme_font_size_override("font_size", 14)
	screen.add_child(layer_label)

	for key in _layers:
		set_layer(key, true)


func _name_layers() -> void:
	var parts := []

	for key in _layers:
		parts.append("%s %s %s" % [OS.get_keycode_string(key), _layers[key]["name"], "ON" if _layers[key]["on"] else "off"])

	layer_label.text = "  ·  ".join(parts) + "  ·  F11 day/night"


# The look

func set_day(day: bool) -> void:
	world.environment = _day if day else _night
	sun.visible = day
	moon.visible = not day

	for light in find_children("lamp_*", "OmniLight3D", true, false):
		light.visible = not day


## Variant D's painted lamp pools: each Company lamp throws its painted pool
## down (a spot with the pool as its projector) and dims its own round glow,
## or the pools go and the glow comes back.
func set_pools(on: bool) -> void:
	for lamp: OmniLight3D in find_children("lamp_*", "OmniLight3D", true, false):
		var pool: Node = lamp.get_node_or_null("pool")

		if on and pool == null:
			lamp.set_meta(&"glow", lamp.light_energy)
			lamp.light_energy = POOL_GLOW
			var spot := SpotLight3D.new()
			spot.name = "pool"
			spot.light_color = LAMP_COLOUR
			spot.light_energy = POOL_ENERGY
			spot.spot_range = POOL_RANGE
			spot.spot_angle = POOL_ANGLE
			spot.light_projector = Painterly.POOL
			spot.shadow_enabled = true
			lamp.add_child(spot)
			spot.rotation_degrees = Vector3(-90, 0, 0)   # straight down
		elif not on and pool != null:
			lamp.remove_child(pool)
			pool.queue_free()
			lamp.light_energy = lamp.get_meta(&"glow", lamp.light_energy)


## The atlas to paint `piece` with: the user's overpaint, else the painter's.
func atlas_for(piece: StringName) -> Texture2D:
	return _painted([String(piece) + ".png", String(piece) + "_base.png"], false)


func normal_for(piece: StringName) -> Texture2D:
	return _painted([String(piece) + "_normal.png", String(piece) + "_normal_base.png"], true)


## What a piece wears through to under vertex paint, and its relief.
func under_for(piece: StringName) -> Texture2D:
	return _painted([String(piece) + "_under.png"], false)


func under_normal_for(piece: StringName) -> Texture2D:
	return _painted([String(piece) + "_under_normal.png"], true)


func _painted(names: Array, normal: bool) -> Texture2D:
	for file in names:
		var path: String = atlas_dir + file

		if FileAccess.file_exists(path):
			var image := Image.load_from_file(path)
			image.convert(Image.FORMAT_RGB8)
			image.generate_mipmaps(normal)
			return ImageTexture.create_from_image(image)

	push_warning("style lab: none of %s in %s" % [names, atlas_dir])
	return null


func _painterly(piece: StringName, preset: StringName) -> ShaderMaterial:
	var key := "%s/%s" % [piece, preset]

	if not _materials.has(key):
		_materials[key] = Painterly.material(atlas_for(piece), preset, Painterly.ZOCALO, normal_for(piece),
			under_for(piece), under_normal_for(piece))

	return _materials[key]


func _glass(lit: bool) -> StandardMaterial3D:
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass.albedo_color = Color(0.72, 0.8, 0.82, 0.3)
	glass.roughness = 0.1
	glass.metallic_specular = 0.8

	if lit:   # the Company's globes
		glass.albedo_color = Color(LAMP_COLOUR, 0.5)
		glass.emission_enabled = true
		glass.emission = LAMP_COLOUR
		glass.emission_energy_multiplier = 2.5

	return glass


# The stations

func _piece(piece: StringName) -> PackedScene:
	var path := lab_dir + String(piece) + ".glb"

	if not ResourceLoader.exists(path):
		missing.append(path)
		push_warning("style lab: %s is not built (tools/eclipse/lab.sh all)" % path)
		return null

	return load(path)


func _station(preset: StringName, x: float, kiosk: PackedScene, bay: PackedScene) -> void:
	var station := Node3D.new()
	station.name = String(preset)
	add_child(station)
	station.position = Vector3(x, 0, 0)

	# Which blend this is (a lab label, not the game's words), facing whoever looks.
	var label := Label3D.new()
	label.text = String(preset)
	label.position = Vector3(0, 0.5, KIOSK_Z + 2.5)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.008
	station.add_child(label)

	if kiosk != null:
		var k := _place(kiosk, station, "kiosk", Vector3(0, 0, KIOSK_Z), &"kiosk", preset, [])

		for i in LAMPS.size():
			var lamp := OmniLight3D.new()
			lamp.name = "lamp_%d" % i
			lamp.light_color = LAMP_COLOUR
			lamp.light_energy = 1.6
			lamp.omni_range = 12.0
			lamp.shadow_enabled = true
			k.add_child(lamp)
			lamp.position = LAMPS[i]

	if bay != null:
		# Three bays from the left, the middle one's column the seeped steel;
		# the run's start caps on the first, the end piece after the last.
		for i in 3:
			var hide := ["bay_end_column", "bay_end_caps"]
			hide.append("bay_column_stone" if i == 1 else "bay_column_steel")

			if i > 0:
				hide.append("bay_start_caps")

			_place(bay, station, "bay_%d" % i, Vector3(-1.5 * BAY + i * BAY, 0, BAYS_Z), &"arcade_bay", preset, hide)

		var end := ["bay_end_column", "bay_end_caps"]
		_place(bay, station, "end", Vector3(1.5 * BAY, 0, BAYS_Z), &"arcade_bay", preset, [], end)


## An instance of a piece, drawn in the station's blend, its glass as glass,
## solid to walk on; `hide` names objects left out, `only` (if any) the ones kept.
func _place(scene: PackedScene, parent: Node3D, node_name: String, at: Vector3, piece: StringName,
		preset: StringName, hide: Array, only: Array = []) -> Node3D:
	var instance: Node3D = scene.instantiate()
	instance.name = node_name
	parent.add_child(instance)
	instance.position = at

	for mesh: MeshInstance3D in instance.find_children("*", "MeshInstance3D", true, false):
		if mesh.name in hide or (not only.is_empty() and not mesh.name in only):
			mesh.queue_free()
			continue

		for i in mesh.mesh.get_surface_count():
			var slot: Material = mesh.mesh.surface_get_material(i)

			if slot != null and slot.resource_name == "glass":
				mesh.set_surface_override_material(i, _glass(String(mesh.name).ends_with("_globe")))
			else:
				var painterly := _painterly(piece, preset)

				# Vertex paint only on what carries it (a mesh without reads white).
				if Painterly.has_vertex_colours(mesh.mesh):
					painterly.set_shader_parameter("vertex_paint", 1.0)

				mesh.set_surface_override_material(i, painterly)

		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		shape.shape = mesh.mesh.create_trimesh_shape()
		body.add_child(shape)
		mesh.add_child(body)

	return instance


# The ground and the sky

## The painted ground round the stations, open over each kiosk's stair,
## weathered against the bays and the kiosks' copings.
func _ground() -> void:
	var openings: Array[Rect2] = []
	var footprints: Array[Dictionary] = []

	for x in STATION_X:
		var hole := Rect2(OPENING.position + Vector2(x, KIOSK_Z), OPENING.size)
		openings.append(hole)
		footprints.append({"rect": hole.grow(COPING), "roofed": false})
		# The run of bays, the arcade roofed, from the first bay to the end piece.
		footprints.append({"rect": Rect2(x - 1.5 * BAY, BAYS_Z - BAY_BACK, 3 * BAY + END_COLUMN, BAY_BACK + BAY_FRONT),
			"roofed": true})

	ground = Ground.build(GROUND, openings, footprints, 7)
	add_child(ground)


func _lights() -> void:
	_night = RetroScript.night_environment()
	_night.background_color = Color(0.03, 0.035, 0.06)
	_day = Environment.new()
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	_day.sky = sky
	_day.background_mode = Environment.BG_SKY
	_day.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_day.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world = WorldEnvironment.new()
	world.environment = _night
	add_child(world)

	moon = DirectionalLight3D.new()
	moon.light_color = MOON_COLOUR
	moon.light_energy = 0.9
	moon.shadow_enabled = true
	add_child(moon)
	moon.rotation = Vector3(deg_to_rad(-50), deg_to_rad(30), 0)

	sun = DirectionalLight3D.new()
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	sun.visible = false
	add_child(sun)
	sun.rotation = Vector3(deg_to_rad(-50), deg_to_rad(-35), 0)
