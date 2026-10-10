extends RefCounted
## The painterly look's materials (the Eclipse city's style lab): a painted
## atlas blended with the shader's strokes and palette (painterly.gdshaderinc).
## The presets are the three blends the lab shows side by side; the Retro
## autoload leaves shader materials alone, and this one samples nearest itself.

const SHADER := preload("res://scripts/Visual/painterly.gdshader")
const BRUSH: Texture2D = preload("res://textures/painted/eclipse/brush.png")
const ZOCALO: Texture2D = preload("res://textures/painted/eclipse/palette_zocalo.png")
## Variant D's light ramp and the Company lamps' painted pool (painterly.py
## drew them; the user may repaint either).
const RAMP: Texture2D = preload("res://textures/painted/eclipse/ramp_zocalo.png")
const POOL: Texture2D = preload("res://textures/painted/eclipse/lamp_pool.png")

## How much the shader does over the painted atlas. The atlas carries the
## paint now (docs/superpowers/refs/mexico_city/painterly_texturing.md), so
## the shader's share is light.
## How Godot hands the kit's vertex paint to shaders: as linear values, as
## Blender baked them (tests/vertex_colour_import.gd pins it).
const VERTEX_COLOUR_SRGB := false

const PRESETS := {
	&"painted_led": {"paint_mix": 0.1, "stroke_strength": 0.12},
	&"even": {"paint_mix": 0.25, "stroke_strength": 0.24},
	# The user's choice (Oct 9 2026): variant D, painted light through the
	# warm ramp, painted ambient and rim (the lamps' painted pools are the map's).
	&"shader_led": {"paint_mix": 0.45, "stroke_strength": 0.36, "painted_light": 1.0, "ramp_amount": 1.0,
		"ambient_amount": 0.15, "rim_amount": 0.25},
}


## A material drawing `atlas` in the preset's blend, mapped onto `palette`,
## its relief from the painted `normal` map if one is given; `under` and
## `under_normal` are what it wears through to under vertex paint (the top
## itself when none is given). Vertex paint stays off: turn it on
## ("vertex_paint" 1) only on meshes that carry colours (has_vertex_colours).
static func material(atlas: Texture2D, preset: StringName, palette: Texture2D = ZOCALO, normal: Texture2D = null,
		under: Texture2D = null, under_normal: Texture2D = null) -> ShaderMaterial:
	var out := ShaderMaterial.new()
	out.shader = SHADER
	out.set_shader_parameter("atlas", atlas)
	out.set_shader_parameter("palette", palette)
	out.set_shader_parameter("brush", BRUSH)
	out.set_shader_parameter("light_ramp", RAMP)

	if normal != null:
		out.set_shader_parameter("normal_atlas", normal)
		out.set_shader_parameter("normal_depth", 1.0)

	out.set_shader_parameter("under_atlas", under if under != null else atlas)

	if under_normal != null or normal != null:
		out.set_shader_parameter("under_normal", under_normal if under_normal != null else normal)

	for key in PRESETS[preset]:
		out.set_shader_parameter(key, PRESETS[preset][key])

	return out


## Whether any of the mesh's surfaces carries vertex colours.
static func has_vertex_colours(mesh: Mesh) -> bool:
	if mesh == null:
		return false

	for i in mesh.get_surface_count():
		if mesh.surface_get_format(i) & Mesh.ARRAY_FORMAT_COLOR:
			return true

	return false
