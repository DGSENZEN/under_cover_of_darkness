extends Node3D
## The Metro Underground's look-dev bay (docs/superpowers/plans/2026-10-16-metro-underground-part-1.md,
## Task 9): the hero stall against the wall of a stretch of tiled corridor,
## painted in the bespoke blend, its neon and bulb lit, the conduit its
## cable draws from running along the wall, two sodium work lights.
##   F1  work lights on / off
##   F2  form light: everything neutral grey under one white light, to judge shape
##   F3  grime decals on / off
##
## The stall's atlas is the committed painted file (the user's overpaint
## stall.png before the painter's stall_base.png); the bay never reads the
## user's local brush sheets.

const PLAYER := preload("res://Player.tscn")
const Painterly := preload("res://scripts/Visual/Painterly.gd")
const RetroScript := preload("res://scripts/Visual/Retro.gd")

## The corridor (m): its run along X, the wall the stall backs onto, the far wall, the vault.
const RUN := 12.0
const BACK_WALL := -1.45
const FAR_WALL := 4.5
const HEIGHT := 4.0
const WALL := 0.3
## Godot positions of what the stall's script built (Blender x, z, -y).
const BULB := Vector3(0.0, 1.70, -0.62)
const SIGN := Vector3(0.0, 2.36, 0.6)
const JUNCTION_TOP := Vector3(1.12, 2.54, -1.26)
const CONDUIT := Vector3(0.0, 3.05, -1.26)
const SODIUM := Color(1.0, 0.76, 0.5)
const BULB_COLOUR := Color(1.0, 0.76, 0.48)
## The sign's colour until the user gives the sign its words and colour.
const NEON_COLOUR := Color(1.0, 0.3, 0.6)
const TILE := Color(0.42, 0.45, 0.46)
const LINE_2 := Color(0.16, 0.3, 0.55)
const FLOOR := Color(0.2, 0.19, 0.18)

## Where the piece and its painted files are.
var lab_dir := "res://assets/eclipse/lab/"
var atlas_dir := "res://textures/painted/underground/"
var missing := PackedStringArray()

var stall: Node3D
var neon: NeonSign
var bulb: OmniLight3D
var work_lights: Array[Light3D] = []
var form_light: DirectionalLight3D
var form_material: StandardMaterial3D
var decals: Array[Decal] = []
var player: Node3D
var world: WorldEnvironment
var keys_label: Label

var _form := false


func _ready() -> void:
	reset_physics_interpolation.call_deferred()
	_environment()
	_corridor()
	_stall()
	_lights()
	_decals()
	_keys()
	player = PLAYER.instantiate()
	player.debug_traversal = false
	add_child(player)
	player.global_position = Vector3(0.0, 1.05, 4.0)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	match event.keycode:
		KEY_F1:
			set_work_lights(not work_lights[0].visible)
		KEY_F2:
			set_form(not _form)
		KEY_F3:
			set_decals(not decals[0].visible)


func set_work_lights(on: bool) -> void:
	for light in work_lights:
		light.visible = on

	_name_keys()


## The form light: every mesh of the bay a neutral grey under one white
## light, the work lights off; or everything as it was.
func set_form(on: bool) -> void:
	_form = on

	for mesh: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		if is_instance_valid(player) and player.is_ancestor_of(mesh):
			continue

		if on:
			mesh.material_override = form_material
		elif neon != null and mesh == neon.tube:
			mesh.material_override = neon.tube_material()
		else:
			mesh.material_override = null

	form_light.visible = on
	set_work_lights(not on)


func set_decals(on: bool) -> void:
	for d in decals:
		d.visible = on

	_name_keys()


# The stall

func _stall() -> void:
	var path := lab_dir + "stall.glb"

	if not ResourceLoader.exists(path):
		missing.append(path)
		push_warning("underground lab: %s is not built (tools/eclipse/lab.sh stall)" % path)
		return

	stall = (load(path) as PackedScene).instantiate()
	stall.name = "stall"
	add_child(stall)
	var atlas := _painted(["stall.png", "stall_base.png"])
	var painted := Painterly.material(atlas, &"bespoke")
	var tube: MeshInstance3D = null

	for mesh: MeshInstance3D in stall.find_children("*", "MeshInstance3D", true, false):
		for i in mesh.mesh.get_surface_count():
			var slot: Material = mesh.mesh.surface_get_material(i)
			var slot_name := slot.resource_name if slot != null else ""

			if slot_name == "glass":
				mesh.set_surface_override_material(i, _glass())
			elif slot_name != "neon":
				mesh.set_surface_override_material(i, painted)

		if mesh.name == "stall_neon":
			tube = mesh
		else:
			var body := StaticBody3D.new()
			var shape := CollisionShape3D.new()
			shape.shape = mesh.mesh.create_trimesh_shape()
			body.add_child(shape)
			mesh.add_child(body)

	# The neon tube lit by its own sign, which takes the first mesh it holds as its tube.
	neon = NeonSign.new()
	neon.name = "neon"
	neon.colour = NEON_COLOUR
	neon.pattern = "mmmmmmmmmmmmmmmammmmmmmmmzmmmmmmmmmmmmmmmmmaam"
	neon.seed = 11
	neon.light_energy = 0.35
	neon.light_range = 2.0

	if tube != null:
		tube.get_parent().remove_child(tube)
		neon.add_child(tube)

	var glow := OmniLight3D.new()
	glow.name = "light"
	neon.add_child(glow)
	glow.position = SIGN
	stall.add_child(neon)


func _painted(names: Array) -> Texture2D:
	for file in names:
		var path: String = atlas_dir + file

		if FileAccess.file_exists(path):
			var image := Image.load_from_file(path)
			image.convert(Image.FORMAT_RGB8)
			image.generate_mipmaps()
			return ImageTexture.create_from_image(image)

	missing.append(atlas_dir + String(names[-1]))
	return null


func _glass() -> StandardMaterial3D:
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass.albedo_color = Color(0.66, 0.78, 0.74, 0.32)
	glass.roughness = 0.1
	glass.metallic_specular = 0.8
	return glass


# The corridor, greybox until its own kit

func _corridor() -> void:
	var tile := _flat(TILE)
	_box(Vector3(-RUN, -0.2, BACK_WALL - WALL), Vector3(RUN, 0.0, FAR_WALL + WALL), _flat(FLOOR), "floor")
	_box(Vector3(-RUN, 0.0, BACK_WALL - WALL), Vector3(RUN, HEIGHT, BACK_WALL), tile, "back_wall")
	_box(Vector3(-RUN, 0.0, FAR_WALL), Vector3(RUN, HEIGHT, FAR_WALL + WALL), tile, "far_wall")
	_box(Vector3(-RUN, HEIGHT, BACK_WALL - WALL), Vector3(RUN, HEIGHT + 0.2, FAR_WALL + WALL), tile, "vault")

	for x in [-RUN - WALL, RUN]:
		_box(Vector3(x, 0.0, BACK_WALL - WALL), Vector3(x + WALL, HEIGHT, FAR_WALL + WALL), tile, "end_%d" % x)

	# Line 2's blue band along both walls at shoulder height.
	_box(Vector3(-RUN, 1.3, BACK_WALL), Vector3(RUN, 1.5, BACK_WALL + 0.02), _flat(LINE_2), "band_back")
	_box(Vector3(-RUN, 1.3, FAR_WALL - 0.02), Vector3(RUN, 1.5, FAR_WALL), _flat(LINE_2), "band_far")

	# The Company's conduit along the wall, and the drop from the stall's junction box up to it.
	var steel := _flat(Color(0.18, 0.25, 0.22))
	_tube(Vector3(-RUN, CONDUIT.y, CONDUIT.z), Vector3(RUN, CONDUIT.y, CONDUIT.z), 0.09, steel, "conduit")
	_tube(Vector3(-RUN, CONDUIT.y - 0.24, CONDUIT.z), Vector3(RUN, CONDUIT.y - 0.24, CONDUIT.z), 0.05,
		_flat(Color(0.55, 0.42, 0.18)), "conduit_brass")
	_tube(JUNCTION_TOP - Vector3(0, 0.02, 0), Vector3(JUNCTION_TOP.x, CONDUIT.y, CONDUIT.z), 0.022, steel, "drop")


func _flat(colour: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.roughness = 0.9
	return m


func _box(lo: Vector3, hi: Vector3, material: Material, node_name: String) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	var box := BoxMesh.new()
	box.size = hi - lo
	mesh.mesh = box
	mesh.material_override = null
	box.material = material
	add_child(mesh)
	mesh.position = (lo + hi) / 2
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var solid := BoxShape3D.new()
	solid.size = hi - lo
	shape.shape = solid
	body.add_child(shape)
	mesh.add_child(body)


func _tube(a: Vector3, b: Vector3, radius: float, material: Material, node_name: String) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	var tube := CylinderMesh.new()
	tube.top_radius = radius
	tube.bottom_radius = radius
	tube.height = a.distance_to(b)
	tube.material = material
	mesh.mesh = tube
	add_child(mesh)
	mesh.position = (a + b) / 2
	var along := (b - a).normalized()
	var side := along.cross(Vector3.FORWARD if absf(along.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	mesh.basis = Basis(side, along, side.cross(along))


# The light

func _environment() -> void:
	# A cool fill under the warm lamps: the colours separate, warm against cool.
	var environment := RetroScript.night_environment(Color(0.36, 0.44, 0.58), 0.28)
	environment.volumetric_fog_density = 0.02
	world = WorldEnvironment.new()
	world.environment = environment
	add_child(world)


func _lights() -> void:
	for x in [-2.6, 2.6]:
		var light := OmniLight3D.new()
		light.name = "work_%d" % int(x)
		light.light_color = SODIUM
		light.light_energy = 2.6
		light.omni_range = 9.0
		light.shadow_enabled = true
		add_child(light)
		light.position = Vector3(x, HEIGHT - 0.4, 2.2)
		work_lights.append(light)
		_box(light.position + Vector3(-0.25, 0.25, -0.12), light.position + Vector3(0.25, 0.4, 0.12),
			_flat(Color(0.1, 0.1, 0.1)), "fixture_%d" % int(x))

	bulb = OmniLight3D.new()
	bulb.name = "bulb"
	bulb.light_color = BULB_COLOUR
	bulb.light_energy = 0.9
	bulb.omni_range = 3.5
	bulb.shadow_enabled = true
	add_child(bulb)
	bulb.position = BULB

	form_light = DirectionalLight3D.new()
	form_light.name = "form_light"
	form_light.light_energy = 1.2
	form_light.shadow_enabled = true
	form_light.visible = false
	add_child(form_light)
	form_light.rotation = Vector3(deg_to_rad(-40), deg_to_rad(30), 0)
	form_material = StandardMaterial3D.new()
	form_material.albedo_color = Color(0.6, 0.6, 0.6)
	form_material.roughness = 1.0


# The grime, each with its cause

func _decals() -> void:
	# Water off the conduit runs down the wall beside the stall.
	_decal("drip", Vector3(-2.0, 2.3, BACK_WALL + 0.1), Vector3(0.9, 0.4, 1.6), Vector3(90, 0, 0))
	# The censer's copal smoke has browned the canvas over it.
	_decal("soot", Vector3(0.62, 2.1, -0.22), Vector3(0.9, 0.5, 0.9), Vector3(180, 0, 0))
	# Feet and spills have worn the floor in front of the counter.
	_decal("grime", Vector3(0.0, 0.0, 0.7), Vector3(2.8, 0.4, 1.4), Vector3.ZERO)


func _decal(kind: String, at: Vector3, size: Vector3, turn: Vector3) -> void:
	var d := Decal.new()
	d.name = "decal_" + kind
	d.size = size
	d.texture_albedo = _painted(["decal_%s.png" % kind])
	d.upper_fade = 0.2
	d.lower_fade = 0.2
	add_child(d)
	d.position = at
	d.rotation_degrees = turn
	decals.append(d)


func _keys() -> void:
	var screen := CanvasLayer.new()
	add_child(screen)
	keys_label = Label.new()
	keys_label.position = Vector2(12, 8)
	keys_label.add_theme_font_size_override("font_size", 14)
	screen.add_child(keys_label)
	_name_keys()


func _name_keys() -> void:
	if keys_label == null or work_lights.is_empty() or decals.is_empty():
		return

	keys_label.text = "F1 work lights %s  ·  F2 form light %s  ·  F3 decals %s" % [
		"ON" if work_lights[0].visible else "off", "ON" if _form else "off", "ON" if decals[0].visible else "off"]
