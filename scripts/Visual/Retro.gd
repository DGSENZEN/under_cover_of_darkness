extends CanvasLayer
## Retro autoload: coarse screen grid and Bayer colour dither, nearest/mipmapped standard-material textures,
## and reduced 3D render scale. Modern shadows, fog, and glow remain part of the scene.
## HUD and CrispText draw above the grid; optional retro_psx materials add vertex snap and affine texture mapping.
## enabled restores converted resources when disabled; shared shader materials are not converted.

const SCREEN_SHADER := preload("res://scripts/Visual/retro_screen.gdshader")
const CrispTextScript := preload("res://scripts/Visual/CrispText.gd")
const SoundBus := preload("res://scripts/StimuliSystem/SoundBus.gd")

## Lines on screen. 240 is a PS1, 448 a PS2; 0 turns the grid off.
@export var virtual_height := 360:
	set(value):
		virtual_height = value
		_fit()
## Levels per colour channel: 32 is the PS1's 15-bit colour; fewer, and its
## dither reads in the night's dark gradients. 0 is off.
@export var color_levels := 24.0:
	set(value):
		color_levels = value
		_fit()
## How strongly the ordered dither breaks up banding, 0..1.
@export_range(0.0, 1.0, 0.05) var dither := 1.0:
	set(value):
		dither = value
		_fit()
## Render the 3D view only as sharp as the grid needs.
@export var auto_render_scale := true:
	set(value):
		auto_render_scale = value
		_fit()
## How textures are sampled everywhere.
@export var texture_filter := BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS

var enabled := true:
	set(value):
		enabled = value
		_fit()

		if is_inside_tree():
			if enabled:
				_convert_tree.call_deferred(get_tree().root)
			else:
				_restore_all()

var _rect: ColorRect
var _material: ShaderMaterial
## The words over men's heads, sharp over the grid while it is on.
var _crisp: Control
## Converted materials, by instance id: the material and its own filter.
var _seen := {}
var _scene: Node = null
var _grids := [360, 240, 448, 0]
var _levels := [24.0, 32.0, 0.0]


func _ready() -> void:
	# Under the HUD (layer 5), over the world.
	layer = 4
	process_mode = Node.PROCESS_MODE_ALWAYS
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF

	_material = ShaderMaterial.new()
	_material.shader = SCREEN_SHADER
	_rect = ColorRect.new()
	_rect.name = "RetroScreen"
	_rect.material = _material
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_rect)
	# After the grid, so drawn over it (and not read into it).
	_crisp = CrispTextScript.new()
	_crisp.name = "CrispText"
	add_child(_crisp)

	get_tree().node_added.connect(_on_node_added)
	get_viewport().size_changed.connect(_fit)
	_fit()
	_convert_tree.call_deferred(get_tree().root)


## Development keys for comparing looks.
func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return

	var key := event as InputEventKey

	if key == null or not key.pressed or key.echo:
		return

	match key.physical_keycode:
		KEY_F3:
			_toggle_debug()
		KEY_F6:
			var i := _grids.find(virtual_height)
			virtual_height = _grids[(i + 1) % _grids.size()]
		KEY_F7:
			var i := _levels.find(color_levels)
			color_levels = _levels[(i + 1) % _levels.size()]
		KEY_F8:
			dither = 0.0 if dither > 0.0 else 1.0
		_:
			return

	get_viewport().set_input_as_handled()


## Every debug overlay on or off together, following the player's.
func _toggle_debug() -> void:
	var player := get_tree().get_first_node_in_group(&"player")
	var on: bool = not (player != null and player.get("debug_traversal") == true)

	if player != null:
		player.set("debug_traversal", on)

	for guard in get_tree().get_nodes_in_group(&"guards"):
		guard.set("debug_ai", on)

	SoundBus.debug = on


# The screen

## The grid for the window as it is now: square cells, virtual_height tall.
func virtual_size() -> Vector2:
	var window := Vector2(get_viewport().get_visible_rect().size)

	if virtual_height <= 0 or window.y <= 0.0:
		return window

	return Vector2(roundf(float(virtual_height) * window.x / window.y), float(virtual_height))


func _fit() -> void:
	if _material == null or not is_inside_tree():
		return

	var on := enabled and virtual_height > 0
	_rect.visible = on
	_crisp.active = on
	var cells := virtual_size()
	_material.set_shader_parameter("virtual_size", cells)
	_material.set_shader_parameter("levels", color_levels)
	_material.set_shader_parameter("dither_strength", dither)

	# Two rendered pixels to each cell is plenty: the rest would be averaged
	# away. Pixels of the window itself: the visible rect is in the HUD's
	# units, scaled with the window (project stretch, canvas_items).
	var root := get_tree().root
	var window := Vector2(root.size)
	var scale := 1.0

	if on and auto_render_scale and window.y > 0.0:
		scale = clampf(2.0 * cells.y / window.y, 0.25, 1.0)

	root.scaling_3d_scale = scale


# Materials

func _on_node_added(node: Node) -> void:
	if not enabled:
		return

	# At the end of the frame, not now: whoever added it often gives it its
	# material just after (a textured block, a weapon in a hand).
	if node is GeometryInstance3D:
		_convert_later.call_deferred(node)

	# A new level (a reload after death, a change of map): sweep all of it.
	var scene := get_tree().current_scene

	if scene != null and scene != _scene:
		_scene = scene
		_forget_gone()
		_convert_tree.call_deferred(scene)


## Untyped: the node may have been freed before the call comes round.
func _convert_later(node) -> void:
	if is_instance_valid(node) and node is GeometryInstance3D:
		retro_geometry(node as GeometryInstance3D)


## The look switched off: every converted material samples as it did.
func _restore_all() -> void:
	for id in _seen:
		var entry: Array = _seen[id]
		var material: BaseMaterial3D = entry[0].get_ref() as BaseMaterial3D

		if material != null:
			material.texture_filter = entry[1]

	_seen.clear()


## The materials of levels gone by are let go of (a long night of reloads
## would otherwise keep a note of every one).
func _forget_gone() -> void:
	for id in _seen.keys():
		if (_seen[id][0] as WeakRef).get_ref() == null:
			_seen.erase(id)


func _convert_tree(root: Node) -> void:
	if not enabled:
		return

	for node in root.find_children("*", "GeometryInstance3D", true, false):
		retro_geometry(node as GeometryInstance3D)


## Every material a piece of geometry draws with, made retro.
func retro_geometry(geometry: GeometryInstance3D) -> void:
	retro_material(geometry.material_override)
	retro_material(geometry.material_overlay)

	var mesh: Mesh = null

	if geometry is MeshInstance3D:
		var instance := geometry as MeshInstance3D
		mesh = instance.mesh

		for i in range(instance.get_surface_override_material_count()):
			retro_material(instance.get_surface_override_material(i))
	elif geometry is MultiMeshInstance3D and (geometry as MultiMeshInstance3D).multimesh != null:
		mesh = (geometry as MultiMeshInstance3D).multimesh.mesh
	elif geometry is CSGShape3D:
		retro_material(geometry.get("material"))
		mesh = geometry.get("mesh") as Mesh
	elif geometry is SpriteBase3D:
		(geometry as SpriteBase3D).texture_filter = texture_filter as BaseMaterial3D.TextureFilter

	if mesh != null:
		if mesh is PrimitiveMesh:
			retro_material((mesh as PrimitiveMesh).material)

		for i in range(mesh.get_surface_count()):
			retro_material(mesh.surface_get_material(i))


## Nearest-neighbour texels. Leaves alone anything marked with the meta
## "retro_skip", and shader materials (which choose their own sampling).
func retro_material(material: Material) -> void:
	if material == null or not (material is BaseMaterial3D):
		return

	var id := material.get_instance_id()

	if _seen.has(id):
		return

	if material.has_meta(&"retro_skip"):
		return

	var base := material as BaseMaterial3D
	_seen[id] = [weakref(base), base.texture_filter]
	base.texture_filter = texture_filter as BaseMaterial3D.TextureFilter

	# A chain of next passes is part of the same look.
	retro_material(material.next_pass)


# Atmosphere

## An environment for dark interiors in this look: volumetric fog that turns
## every shadowed light into shafts, glow on flames and sparks, a filmic curve
## with some bite, and ambient low enough to hide in.
static func night_environment(ambient := Color(0.24, 0.27, 0.4), ambient_energy := 0.14) -> Environment:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.01, 0.012, 0.02)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = ambient
	environment.ambient_light_energy = ambient_energy
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED

	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.05
	environment.tonemap_white = 6.0

	environment.glow_enabled = true
	environment.glow_normalized = true
	environment.glow_intensity = 0.9
	environment.glow_strength = 1.0
	environment.glow_bloom = 0.04
	environment.glow_hdr_threshold = 0.85
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT

	# Dense enough to catch light, short enough that the froxels stay fine,
	# and scattering sideways as well as forward, so shafts show from the
	# side and not only when you look into the light.
	environment.volumetric_fog_enabled = true
	environment.volumetric_fog_density = 0.045
	environment.volumetric_fog_albedo = Color(0.9, 0.9, 1.0)
	environment.volumetric_fog_anisotropy = 0.35
	environment.volumetric_fog_length = 32.0
	environment.volumetric_fog_detail_spread = 1.6
	environment.volumetric_fog_ambient_inject = 0.05
	environment.volumetric_fog_sky_affect = 0.0

	environment.ssao_enabled = true
	environment.ssao_radius = 1.2
	environment.ssao_intensity = 1.6

	environment.adjustment_enabled = true
	environment.adjustment_contrast = 1.08
	environment.adjustment_saturation = 1.1
	return environment
