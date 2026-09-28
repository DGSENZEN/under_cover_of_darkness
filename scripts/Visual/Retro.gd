extends CanvasLayer
## The look: PS1 grit with PS2 light. Autoloaded as "Retro", so every scene
## gets it without doing anything.
##
##   the screen   drawn on a coarse grid of big pixels (virtual_height lines),
##                each a flat block of colour, quantised to color_levels a
##                channel with an ordered 4x4 dither: the PS1's crunch. The
##                HUD sits above it and stays sharp, and so do the words over
##                men's heads: drawn just above the grid (CrispText), so the
##                big pixels never break them into blocks.
##   textures     every material in the tree samples its textures nearest-
##                neighbour, with mipmaps, so texels are crisp squares and
##                distant walls do not crawl.
##   light        left modern: shadows, volumetric fog, glow. Godrays through
##                big pixels are the PS2 half of the mix.
##   motion       the PS1's wobble, gently: every vertex of the world snaps
##                to the grid's cells (psx.gdshaderinc), so edges step and
##                polygons shiver a little as they move. The plain materials
##                draw through snapping twins of themselves (psx_surface,
##                made here: colour, texture, baked shade, Godot's own world
##                mapping), which follow them as they change (the night wets
##                the stones); the world's own shaders snap alike; the hands
##                and held things (the view's layer), 'retro_skip' and what
##                psx_surface cannot draw alike stay smooth. No texture swim (affine) on the
##                world; the retro_psx shader has it, for props that want it.
##
## The 3D view is rendered at a fraction of the window (render_scale), just
## enough for the grid, which pays for all of this.
##
## Switch it all off with Retro.enabled = false, or tune it live:
## Retro.virtual_height = 240 (PS1) .. 448 (PS2) .. 0 (off).
##
## In debug builds, anywhere in the game:
##   F3  debug overlays: guards' senses, the traversal readout, sound events
##   F6  grid lines: 360 / 240 (PS1) / 448 (PS2) / off
##   F7  colour depth: 24 / 32 / full
##   F8  dither on / off
##   F4  vertex snap on / off

const SCREEN_SHADER := preload("res://scripts/Visual/retro_screen.gdshader")
const CrispTextScript := preload("res://scripts/Visual/CrispText.gd")
const SoundBus := preload("res://scripts/StimuliSystem/SoundBus.gd")
const Layers := preload("res://scripts/Visual/Layers.gd")
const PSX_INCLUDE := "res://scripts/Visual/psx.gdshaderinc"
## A twin copies these from its material this often (s): what code changes
## while the game runs (the night's wetting, a flash, a fade).
const SYNC_EVERY := 0.25

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
## Vertices snap to the grid's cells (psx_snap_lines = its lines).
@export var snap := true:
	set(value):
		snap = value
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
## Snapping twins are made where frames are drawn (headless, for a test that
## asks: other suites read the plain materials).
static var twin_headless := false
## base material id -> [weakref(base), weakref(twin)]; generated code -> the
## snapping shader made of it; the geometry drawing through twins.
var _twins := {}
var _shaders := {}
var _twinned: Array[WeakRef] = []
var _sync_in := 0.0


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
		KEY_F4:
			snap = not snap
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


# ---------------------------------------------------------------------------
# The screen
# ---------------------------------------------------------------------------

## The grid for the window as it is now: square cells, virtual_height tall.
func virtual_size() -> Vector2:
	var window := Vector2(get_viewport().get_visible_rect().size)

	if virtual_height <= 0 or window.y <= 0.0:
		return window

	return Vector2(roundf(float(virtual_height) * window.x / window.y), float(virtual_height))


## The lines vertices snap to: the grid's, while the look, the grid and the
## snap are all on; else 0 (smooth).
func snap_lines() -> float:
	return float(virtual_height) if enabled and snap and virtual_height > 0 else 0.0


func _fit() -> void:
	if _material == null or not is_inside_tree():
		return

	var on := enabled and virtual_height > 0
	_rect.visible = on
	_crisp.active = on
	var cells := virtual_size()
	_material.set_shader_parameter("virtual_size", cells)
	_material.set_shader_parameter("levels", color_levels)
	var shape := Vector2(get_tree().root.size)
	RenderingServer.global_shader_parameter_set(&"psx_snap_lines", snap_lines())
	RenderingServer.global_shader_parameter_set(&"psx_snap_aspect", shape.x / shape.y if shape.y > 0.0 else 16.0 / 9.0)
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


# ---------------------------------------------------------------------------
# Materials
# ---------------------------------------------------------------------------

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


## The look switched off: every converted material samples as it did, and
## everything drawing through twins draws with its own materials again.
func _restore_all() -> void:
	for held in _twinned:
		var geometry := held.get_ref() as GeometryInstance3D

		if geometry == null or not geometry.has_meta(&"retro_twinned"):
			continue

		var originals: Dictionary = geometry.get_meta(&"retro_twinned")

		for surface in originals:
			if int(surface) < 0:
				geometry.material_override = originals[surface]
			elif geometry is MeshInstance3D:
				(geometry as MeshInstance3D).set_surface_override_material(int(surface), originals[surface])

		geometry.remove_meta(&"retro_twinned")

	_twinned.clear()

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


## Every material a piece of geometry draws with, made retro: nearest
## texels, and (where frames are drawn) snapping twins.
func retro_geometry(geometry: GeometryInstance3D) -> void:
	retro_material(geometry.material_override)
	retro_material(geometry.material_overlay)
	_twin_geometry.call_deferred(geometry)

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


# ---------------------------------------------------------------------------
# The wobble: snapping twins of the plain materials
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	_sync_in -= delta

	if _sync_in > 0.0 or _twins.is_empty():
		return

	_sync_in = SYNC_EVERY

	for id in _twins.keys():
		var base := (_twins[id][0] as WeakRef).get_ref() as BaseMaterial3D
		var twin := (_twins[id][1] as WeakRef).get_ref() as ShaderMaterial

		if base == null or twin == null:
			_twins.erase(id)
			continue

		_follow(base, twin)


func _twinning() -> bool:
	return enabled and (DisplayServer.get_name() != "headless" or twin_headless)


## `geometry`'s plain materials swapped for their snapping twins (its own
## overrides noted, to be given back). Not the view's layer (the hands and
## what they hold), nor 'retro_skip'. Untyped: it may be gone by now.
func _twin_geometry(geometry) -> void:
	if not is_instance_valid(geometry) or not _twinning() or not (geometry is GeometryInstance3D):
		return

	var drawn := geometry as GeometryInstance3D

	if drawn.has_meta(&"retro_twinned") or (drawn.layers & Layers.VIEWMODEL) != 0:
		return

	var originals := {}
	var override := drawn.material_override

	if override != null:
		if override is BaseMaterial3D and not override.has_meta(&"retro_skip"):
			var twin := _twin(override as BaseMaterial3D)

			if twin != null:
				originals[-1] = override
				drawn.material_override = twin
	elif drawn is MeshInstance3D and (drawn as MeshInstance3D).mesh != null:
		var instance := drawn as MeshInstance3D

		for i in range(instance.mesh.get_surface_count()):
			var own := instance.get_surface_override_material(i)
			var source: Material = own if own != null else instance.mesh.surface_get_material(i)

			if source is BaseMaterial3D and not source.has_meta(&"retro_skip"):
				var twin := _twin(source as BaseMaterial3D)

				if twin != null:
					originals[i] = own
					instance.set_surface_override_material(i, twin)
	elif drawn is MultiMeshInstance3D and (drawn as MultiMeshInstance3D).multimesh != null:
		var mesh := (drawn as MultiMeshInstance3D).multimesh.mesh
		var source: Material = mesh.surface_get_material(0) if mesh != null and mesh.get_surface_count() == 1 else null

		if source is BaseMaterial3D and not source.has_meta(&"retro_skip"):
			var twin := _twin(source as BaseMaterial3D)

			if twin != null:
				originals[-1] = null
				drawn.material_override = twin

	if not originals.is_empty():
		drawn.set_meta(&"retro_twinned", originals)
		_twinned.append(weakref(drawn))


## `base`'s snapping twin (one per material): psx_surface drawn the way
## `base` is (its variant: shading, cull, alpha, mapping), its values copied.
## Null for what psx_surface cannot draw alike (normal maps, billboards,
## rim, detail...): that stays smooth rather than look different.
func _twin(base: BaseMaterial3D) -> ShaderMaterial:
	var id := base.get_instance_id()

	if _twins.has(id):
		var known := (_twins[id][1] as WeakRef).get_ref() as ShaderMaterial

		if known != null:
			return known

	var key := variant_of(base)

	if key.is_empty():
		return null

	var shader: Shader = _shaders.get(key)

	if shader == null:
		shader = Shader.new()
		shader.code = surface_code(key)
		_shaders[key] = shader

	var twin := ShaderMaterial.new()
	twin.shader = shader
	twin.set_shader_parameter(&"texture_albedo", base.albedo_texture)
	twin.set_shader_parameter(&"texture_emission", base.emission_texture if base.emission_enabled else null)
	twin.set_shader_parameter(&"uv1_scale", base.uv1_scale)
	twin.set_shader_parameter(&"uv1_offset", base.uv1_offset)
	twin.set_shader_parameter(&"uv1_blend_sharpness", base.uv1_triplanar_sharpness)
	twin.set_shader_parameter(&"alpha_scissor_threshold", base.alpha_scissor_threshold)
	_follow(base, twin)
	twin.render_priority = base.render_priority

	if base.next_pass is BaseMaterial3D:
		twin.next_pass = _twin(base.next_pass as BaseMaterial3D)
	else:
		twin.next_pass = base.next_pass

	twin.set_meta(&"retro_base", base)
	_twins[id] = [weakref(base), weakref(twin)]
	return twin


## What code changes while the game runs, copied onto the twin.
static func _follow(base: BaseMaterial3D, twin: ShaderMaterial) -> void:
	for pair in [[&"albedo", base.albedo_color], [&"roughness", base.roughness], [&"metallic", base.metallic], [&"specular", base.metallic_specular],
			[&"emission", base.emission if base.emission_enabled else Color.BLACK], [&"emission_energy", base.emission_energy_multiplier if base.emission_enabled else 0.0]]:
		if twin.get_shader_parameter(pair[0]) != pair[1]:
			twin.set_shader_parameter(pair[0], pair[1])


## The psx_surface variant that draws `base` alike ("" if none does): its
## shading, cull, alpha, depth, mapping and vertex colour.
static func variant_of(base: BaseMaterial3D) -> String:
	if base.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED or base.normal_enabled or base.detail_enabled or base.no_depth_test \
			or base.roughness_texture != null or base.metallic_texture != null or base.distance_fade_mode != BaseMaterial3D.DISTANCE_FADE_DISABLED \
			or base.rim_enabled or base.clearcoat_enabled or base.anisotropy_enabled or base.ao_enabled or base.heightmap_enabled \
			or base.subsurf_scatter_enabled or base.backlight_enabled or base.refraction_enabled or base.use_point_size or base.fixed_size \
			or base.proximity_fade_enabled or base.grow or base.vertex_color_is_srgb or base.transparency in [BaseMaterial3D.TRANSPARENCY_ALPHA_HASH, BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS]:
		return ""

	var parts := [base.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED, base.cull_mode, base.transparency, base.depth_draw_mode,
		base.uv1_triplanar, base.uv1_world_triplanar, base.vertex_color_use_as_albedo, base.disable_receive_shadows, base.emission_enabled]
	return "|".join(parts.map(func(part): return str(int(part))))


## psx_surface's code for a variant (variant_of): the plain material the
## world is drawn with, Godot's own mapping, and the snap.
static func surface_code(key: String) -> String:
	var v := key.split("|")
	var unshaded := v[0] == "1"
	var cull: String = ["cull_back", "cull_front", "cull_disabled"][int(v[1])]
	var alpha := int(v[2])
	var depth: String = ["depth_draw_opaque", "depth_draw_always", "depth_draw_never"][int(v[3])]
	var triplanar := v[4] == "1"
	var world := v[5] == "1"
	var coloured := v[6] == "1"
	var no_shadows := v[7] == "1"
	var glowing := v[8] == "1"
	var modes := ["blend_mix", depth, cull, "diffuse_burley", "specular_schlick_ggx"]

	if unshaded:
		modes.append("unshaded")

	if no_shadows:
		modes.append("shadows_disabled")

	var code := "// Retro's twin of a plain material: psx_surface (see Retro.gd).\nshader_type spatial;\nrender_mode %s;\n#include \"%s\"\n\n" % [", ".join(modes), PSX_INCLUDE]
	code += "uniform vec4 albedo : source_color = vec4(1.0);\n"
	code += "uniform sampler2D texture_albedo : source_color, hint_default_white, filter_nearest_mipmap, repeat_enable;\n"
	code += "uniform sampler2D texture_emission : source_color, hint_default_black, filter_nearest_mipmap, repeat_enable;\n"
	code += "uniform float roughness = 1.0;\nuniform float metallic = 0.0;\nuniform float specular = 0.5;\n"
	code += "uniform vec4 emission : source_color = vec4(0.0);\nuniform float emission_energy = 0.0;\n"
	code += "uniform float alpha_scissor_threshold = 0.5;\n"
	code += "uniform vec3 uv1_scale = vec3(1.0);\nuniform vec3 uv1_offset = vec3(0.0);\nuniform float uv1_blend_sharpness = 1.0;\n"

	if triplanar:
		code += "varying vec3 uv1_triplanar_pos;\nvarying vec3 uv1_power_normal;\n\n"
		code += "vec4 triplanar_texture(sampler2D p_sampler, vec3 p_weights, vec3 p_triplanar_pos) {\n"
		code += "\tvec4 samp = vec4(0.0);\n\tsamp += texture(p_sampler, p_triplanar_pos.xy) * p_weights.z;\n"
		code += "\tsamp += texture(p_sampler, p_triplanar_pos.xz) * p_weights.y;\n"
		code += "\tsamp += texture(p_sampler, p_triplanar_pos.zy * vec2(-1.0, 1.0)) * p_weights.x;\n\treturn samp;\n}\n"

	code += "\nvoid vertex() {\n"

	if triplanar:
		if world:
			code += "\tvec3 normal = MODEL_NORMAL_MATRIX * NORMAL;\n"
			code += "\tuv1_triplanar_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz * uv1_scale + uv1_offset;\n"
		else:
			code += "\tvec3 normal = NORMAL;\n\tuv1_triplanar_pos = VERTEX * uv1_scale + uv1_offset;\n"

		code += "\tuv1_power_normal = pow(abs(normal), vec3(uv1_blend_sharpness));\n"
		code += "\tuv1_power_normal /= dot(uv1_power_normal, vec3(1.0));\n"
		code += "\tuv1_triplanar_pos *= vec3(1.0, -1.0, 1.0);\n"
	else:
		code += "\tUV = UV * uv1_scale.xy + uv1_offset.xy;\n"

	code += "\tPOSITION = psx_snapped(PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)), VIEWPORT_SIZE);\n}\n\n"
	code += "void fragment() {\n"
	code += "\tvec4 albedo_tex = %s;\n" % ("triplanar_texture(texture_albedo, uv1_power_normal, uv1_triplanar_pos)" if triplanar else "texture(texture_albedo, UV)")

	if coloured:
		code += "\talbedo_tex *= COLOR;\n"

	code += "\tALBEDO = albedo.rgb * albedo_tex.rgb;\n"

	if alpha == BaseMaterial3D.TRANSPARENCY_ALPHA:
		code += "\tALPHA = albedo.a * albedo_tex.a;\n"
	elif alpha == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
		code += "\tALPHA = albedo.a * albedo_tex.a;\n\tALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;\n"

	if not unshaded:
		code += "\tROUGHNESS = roughness;\n\tMETALLIC = metallic;\n\tSPECULAR = specular;\n"

	if glowing:
		code += "\tvec3 glow_tex = %s.rgb;\n" % ("triplanar_texture(texture_emission, uv1_power_normal, uv1_triplanar_pos)" if triplanar else "texture(texture_emission, UV)")
		code += "\tEMISSION = (emission.rgb + glow_tex) * emission_energy;\n"

	return code + "}\n"


# ---------------------------------------------------------------------------
# Atmosphere
# ---------------------------------------------------------------------------

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
