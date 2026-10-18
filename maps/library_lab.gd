extends Node3D
## The rare-book librarian's shop's look-dev bay (docs/superpowers/specs/2026-10-17-librarian-shop-design.md;
## docs/superpowers/plans/2026-10-17-librarian-shop-part-1.md): his vaulted room off a strip of the Metro
## corridor, painted in the bespoke blend. The player starts in the corridor, looking in through the arch.
##   F1  work lights on / off
##   F2  form light: everything neutral grey under one white light, to judge shape

const PLAYER := preload("res://Player.tscn")
const Painterly := preload("res://scripts/Visual/Painterly.gd")
const RetroScript := preload("res://scripts/Visual/Retro.gd")

## The room's kit (tools/eclipse/library_room.py), set at the origin: the shopfront's corridor face at
## z = FRONT_T, the room from z = 0 back to -DEPTH.
const ROOM_KIT := "res://assets/eclipse/kit/library_room.glb"
const DEPTH := 6.0
const WIDTH := 8.0
const FRONT_T := 0.4
## The arch's opening and the fascia's span (the corridor's tiles stop at the bookseller's front).
const FRONT_W := 3.0
const FRONT_REACH := 2.4
## The corridor outside: how far either way, and its far wall's tile face; its ceiling.
const RUN := 6.0
const FAR_WALL := 3.7
const CEILING := 4.0
const FLOOR_KIT := "res://assets/eclipse/kit/underground_floor.glb"
const WALL_KIT := "res://assets/eclipse/kit/underground_walls.glb"
const MODULE := 1.2
const EDGE_DEPTH := 0.9
const WALL_FACE := 0.067
## Where the player starts: in the corridor before the arch, facing in.
const SPAWN := Vector3(0.0, 1.05, 2.2)
const SODIUM := Color(1.0, 0.76, 0.5)
## His lamp until his desk stands (Task 2): warm, low, at the back.
const LAMP_AT := Vector3(0.0, 1.45, -4.3)
const LAMP_COLOUR := Color(1.0, 0.78, 0.5)

var atlas_dir := "res://textures/painted/underground/"
var missing := PackedStringArray()
var player: Node3D
var world: WorldEnvironment
## The room's pieces by name.
var room := {}
var corridor: Array[MeshInstance3D] = []
var lamp_light: OmniLight3D
var work_lights: Array[Light3D] = []
var form_light: DirectionalLight3D
var form_material: StandardMaterial3D
var keys_label: Label
var _form := false


func _ready() -> void:
	reset_physics_interpolation.call_deferred()
	_environment()
	_room()
	_corridor()
	_lights()
	_keys()
	player = PLAYER.instantiate()
	player.debug_traversal = false
	add_child(player)
	player.global_position = SPAWN


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	match event.keycode:
		KEY_F1:
			set_work_lights(not work_lights[0].visible)
		KEY_F2:
			set_form(not _form)


func set_work_lights(on: bool) -> void:
	for light in work_lights:
		light.visible = on

	_name_keys()


## The form light: every mesh of the bay a neutral grey under one white light, the work lights and his lamp
## off; or everything as it was. (Effects keep their own look: they cast no shadow and draw with a shader.)
func set_form(on: bool) -> void:
	_form = on

	for mesh: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		if is_instance_valid(player) and player.is_ancestor_of(mesh):
			continue

		if mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and mesh.mesh != null \
				and (mesh.get_surface_override_material(0) is ShaderMaterial or mesh.mesh.surface_get_material(0) is ShaderMaterial):
			continue

		mesh.material_override = form_material if on else null

	form_light.visible = on
	lamp_light.visible = not on
	set_work_lights(not on)


# The room

func _room() -> void:
	if not ResourceLoader.exists(ROOM_KIT):
		missing.append(ROOM_KIT)
		return

	var meshes := _kit(ROOM_KIT)
	var look := Painterly.material(_painted(["library_room.png", "library_room_base.png"]), &"bespoke")

	for part in ["room_vault", "room_back", "room_front", "room_floor", "room_rug"]:
		if not meshes.has(part):
			missing.append("%s in %s" % [part, ROOM_KIT])
			continue
		# (The room's walls are walked against and its floor walked on: solid to the shape, not its hull.)
		room[part] = _place(meshes[part], look, part, Vector3.ZERO, 0.0, part != "room_rug", true)


# The corridor outside: the Metro's tiled floor and walls either side of his front

func _corridor() -> void:
	# The floor walked on at the tiles' tops, and the corridor's ceiling and ends.
	var walked := StaticBody3D.new()
	walked.name = "corridor_walked"
	var top := CollisionShape3D.new()
	var slab := BoxShape3D.new()
	slab.size = Vector3(2.0 * RUN, 0.2, FAR_WALL - FRONT_T)
	top.shape = slab
	walked.add_child(top)
	add_child(walked)
	walked.position = Vector3(0.0, -0.1, (FAR_WALL + FRONT_T) / 2.0)
	var dark := _flat(Color(0.12, 0.11, 0.1))
	_box(Vector3(-RUN, CEILING, FRONT_T), Vector3(RUN, CEILING + 0.2, FAR_WALL + 0.3), dark, "corridor_ceiling")
	_box(Vector3(-RUN - 0.3, 0.0, FRONT_T), Vector3(-RUN, CEILING, FAR_WALL + 0.3), dark, "corridor_end_w")
	_box(Vector3(RUN, 0.0, FRONT_T), Vector3(RUN + 0.3, CEILING, FAR_WALL + 0.3), dark, "corridor_end_e")
	_box(Vector3(-RUN, 0.0, FAR_WALL + WALL_FACE), Vector3(RUN, CEILING, FAR_WALL + WALL_FACE + 0.3), dark, "corridor_far")

	if ResourceLoader.exists(FLOOR_KIT):
		var meshes := _kit(FLOOR_KIT)
		var look := Painterly.material(_painted(["underground_floor.png", "underground_floor_base.png"]), &"bespoke")
		var columns := int(round(2.0 * RUN / MODULE))

		for c in columns:
			var x := -RUN + MODULE * c
			for r in 2:
				var turned := fposmod(sin(c * 12.9898 + r * 78.233) * 43758.5453, 1.0) > 0.5
				var low := FRONT_T + MODULE * r
				var at := Vector3(x + MODULE, 0.0, low) if turned else Vector3(x, 0.0, low + MODULE)
				corridor.append(_place(meshes["floor_field"], look, "floor_field", at, PI if turned else 0.0, false))
			corridor.append(_place(meshes["floor_edge"], look, "floor_edge", Vector3(x + MODULE, 0.0, FAR_WALL - EDGE_DEPTH), PI, false))
	else:
		missing.append(FLOOR_KIT)

	if ResourceLoader.exists(WALL_KIT):
		var meshes := _kit(WALL_KIT)
		var look := Painterly.material(_painted(["underground_walls.png", "underground_walls_base.png"]), &"bespoke")
		var columns := int(round(2.0 * RUN / MODULE))

		for c in columns:
			var x := -RUN + MODULE * c
			# The far wall, turned to face back across the corridor.
			var kind := "wall_tiled_worn" if c in [2, 7] else "wall_tiled"
			corridor.append(_place(meshes[kind], look, kind, Vector3(x + MODULE, 0.0, FAR_WALL + WALL_FACE), PI, true))
			# The shop's side: tiles on its wall either side of the bookseller's front.
			if x + MODULE <= -FRONT_REACH + 0.001 or x >= FRONT_REACH - 0.001:
				kind = "wall_tiled_worn" if c == 1 else "wall_tiled"
				corridor.append(_place(meshes[kind], look, kind, Vector3(x, 0.0, FRONT_T), 0.0, true))
	else:
		missing.append(WALL_KIT)


# The light

func _environment() -> void:
	var environment := RetroScript.night_environment(Color(0.36, 0.44, 0.58), 0.22)
	environment.volumetric_fog_density = 0.02
	world = WorldEnvironment.new()
	world.environment = environment
	add_child(world)


func _lights() -> void:
	# Two sodium work lights under the vault, one in the corridor.
	for at in [Vector3(-2.2, 3.6, -2.6), Vector3(2.2, 3.6, -2.6), Vector3(0.0, 3.6, 2.0)]:
		var light := OmniLight3D.new()
		light.name = "work_%d" % work_lights.size()
		light.light_color = SODIUM
		light.light_energy = 1.4
		light.omni_range = 7.0
		light.shadow_enabled = true
		add_child(light)
		light.position = at
		work_lights.append(light)

	lamp_light = OmniLight3D.new()
	lamp_light.name = "lamp_light"
	lamp_light.light_color = LAMP_COLOUR
	lamp_light.light_energy = 1.2
	lamp_light.omni_range = 4.0
	lamp_light.shadow_enabled = true
	add_child(lamp_light)
	lamp_light.position = LAMP_AT

	form_light = DirectionalLight3D.new()
	form_light.name = "form_light"
	form_light.light_energy = 1.2
	form_light.shadow_enabled = false
	form_light.visible = false
	add_child(form_light)
	form_light.rotation = Vector3(deg_to_rad(-40), deg_to_rad(30), 0)
	form_material = StandardMaterial3D.new()
	form_material.albedo_color = Color(0.6, 0.6, 0.6)
	form_material.roughness = 1.0


func _keys() -> void:
	var screen := CanvasLayer.new()
	add_child(screen)
	keys_label = Label.new()
	keys_label.position = Vector2(12, 8)
	keys_label.add_theme_font_size_override("font_size", 14)
	screen.add_child(keys_label)
	_name_keys()


func _name_keys() -> void:
	if keys_label == null or work_lights.is_empty():
		return

	keys_label.text = "F1 work lights %s  ·  F2 form light %s" % ["on" if work_lights[0].visible else "off", "on" if _form else "off"]


# Kits, painting, placing

func _kit(path: String) -> Dictionary:
	var meshes := {}
	var kit: Node3D = (load(path) as PackedScene).instantiate()

	for mesh: MeshInstance3D in kit.find_children("*", "MeshInstance3D", true, false):
		meshes[String(mesh.name)] = mesh.mesh

	kit.free()
	return meshes


func _painted(names: Array, alpha := false) -> Texture2D:
	for file in names:
		var path: String = atlas_dir + file

		# The imported texture, as an exported game has it; a file Godot has not imported yet (just painted)
		# read straight from disk meanwhile.
		if ResourceLoader.exists(path):
			return load(path) as Texture2D

		if FileAccess.file_exists(path):
			var image := Image.load_from_file(path)
			image.convert(Image.FORMAT_RGBA8 if alpha else Image.FORMAT_RGB8)
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


## A kit piece set at `at`, turned `yaw` about the vertical; solid if asked, to its shape (`exact`, for walls
## and floors walked against and on) or to its hull.
func _place(mesh: Mesh, material: Material, kind: String, at: Vector3, yaw: float, solid: bool, exact := false) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	piece.name = kind
	piece.mesh = mesh
	piece.set_meta("kind", kind)

	for i in piece.mesh.get_surface_count():
		var slot: Material = piece.mesh.surface_get_material(i)
		var glazed := slot != null and slot.resource_name.begins_with("glass")
		piece.set_surface_override_material(i, _glass() if glazed else material)

	add_child(piece, true)
	piece.position = at
	piece.rotation.y = yaw

	if solid:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		shape.shape = piece.mesh.create_trimesh_shape() if exact else piece.mesh.create_convex_shape()
		body.add_child(shape)
		piece.add_child(body)

	return piece


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
	box.material = material
	mesh.mesh = box
	add_child(mesh)
	mesh.position = (lo + hi) / 2
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var solid := BoxShape3D.new()
	solid.size = hi - lo
	shape.shape = solid
	body.add_child(shape)
	mesh.add_child(body)
