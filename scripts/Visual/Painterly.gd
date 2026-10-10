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
const PRESETS := {
	&"painted_led": {"paint_mix": 0.1, "stroke_strength": 0.12},
	&"even": {"paint_mix": 0.25, "stroke_strength": 0.24},
	# The user's choice (Oct 9 2026).
	&"shader_led": {"paint_mix": 0.45, "stroke_strength": 0.36, "painted_light": 0.0},
}


## A material drawing `atlas` in the preset's blend, mapped onto `palette`,
## its relief from the painted `normal` map if one is given.
static func material(atlas: Texture2D, preset: StringName, palette: Texture2D = ZOCALO, normal: Texture2D = null) -> ShaderMaterial:
	var out := ShaderMaterial.new()
	out.shader = SHADER
	out.set_shader_parameter("atlas", atlas)
	out.set_shader_parameter("palette", palette)
	out.set_shader_parameter("brush", BRUSH)
	out.set_shader_parameter("light_ramp", RAMP)

	if normal != null:
		out.set_shader_parameter("normal_atlas", normal)
		out.set_shader_parameter("normal_depth", 1.0)

	for key in PRESETS[preset]:
		out.set_shader_parameter(key, PRESETS[preset][key])

	return out
