extends "res://maps/underground_lab.gd"
## One continuous map: the Underground corridor ends at the librarian's arch.
## One player, environment, audio space and F-key controller serve both rooms.
const LIBRARY_ROOM := preload("res://maps/library_lab.tscn")
var library: Node3D
## The corridor's last work lamp, near the shop: it lights the bookseller's front and spills through the arch.
const END_LAMP := Vector3(RUN - 2.6, HEIGHT - 0.4, (BACK_WALL + FAR_WALL) / 2.0)

func _ready() -> void:
	super._ready()
	# Replace the eastern tiled end, including its backing collision wall.
	# The complete shopfront closes the corridor around its actual arched opening.
	for child in get_children():
		if child is MeshInstance3D and str(child.name).begins_with("end_") and child.position.x > RUN:
			child.free()
	for panel: MeshInstance3D in wall_panels.duplicate():
		if absf(panel.position.x - (RUN + WALL_FACE)) < 0.001 and absf(panel.rotation.y + PI / 2.0) < 0.001:
			wall_panels.erase(panel)
			panel.free()
	_trim_services()
	_end_lamp()
	library = LIBRARY_ROOM.instantiate()
	library.name = "Library"
	library.standalone = false
	library.player = player
	library.transform = Transform3D(Basis(Vector3.UP, -PI / 2.0), Vector3(RUN + 0.4, 0.0, (BACK_WALL + FAR_WALL) / 2.0))
	add_child(library)
	inspection_sections.append(library)
	player.global_position = Vector3(4.8, 1.05, 0.9)
	player.rotation.y = -PI / 2.0
	player.reset_physics_interpolation()
	_name_keys()

## One more of the corridor's shaded sodium work lamps, over the way to the shop (the others are 9 m back).
func _end_lamp() -> void:
	var light := OmniLight3D.new()
	light.name = "work_end"
	light.light_color = SODIUM
	light.light_energy = 1.9
	light.omni_range = 9.0
	light.shadow_enabled = true
	light.light_cull_mask &= ~Layers.SHADED_ABOVE
	add_child(light)
	light.position = END_LAMP
	work_lights.append(light)
	_bounce(light)
	for lamp: Light3D in [light, light.get_child(0)]:
		_full[lamp] = lamp.light_energy
	_box(light.position + Vector3(-0.25, 0.25, -0.12), light.position + Vector3(0.25, 0.4, 0.12),
		_flat(Color(0.1, 0.1, 0.1)), "fixture_end")

## The isolated bay hides overlong terminal modules behind its end wall.
## Shorten those modules into the shopfront's thickness before embedding it.
func _trim_services() -> void:
	var stop := RUN + 0.2
	for piece: MeshInstance3D in services.duplicate():
		var bounds := piece.global_transform * piece.get_aabb()
		if bounds.end.x <= stop:
			continue
		if bounds.position.x >= stop:
			services.erase(piece)
			piece.free()
			continue
		var ratio := (stop - bounds.position.x) / bounds.size.x
		var trim := Transform3D(Basis.from_scale(Vector3(ratio, 1.0, 1.0)), Vector3(bounds.position.x * (1.0 - ratio), 0.0, 0.0))
		piece.global_transform = trim * piece.global_transform

func _name_keys() -> void:
	super._name_keys()
	if is_instance_valid(keys_label):
		keys_label.text += "  ·  Library through the east arch"

func set_work_lights(on: bool) -> void:
	super.set_work_lights(on)
	if is_instance_valid(library):
		library.set_work_lights(on)

func set_form(on: bool) -> void:
	super.set_form(on)
	if is_instance_valid(library):
		library.set_form(on)
		# The shared white form light already illuminates the whole map.
		library.form_light.visible = false

func set_decals(on: bool) -> void:
	super.set_decals(on)
	if is_instance_valid(library):
		library.set_decals(on)
