extends RefCounted
## The painterly look's materials (the Eclipse city's style lab): a painted
## atlas blended with the shader's strokes and palette (painterly.gdshaderinc).
## The presets are the three blends the lab shows side by side; the Retro
## autoload leaves shader materials alone, and this one samples nearest itself.

const SHADER := preload("res://scripts/Visual/painterly.gdshader")
const BRUSH: Texture2D = preload("res://textures/painted/eclipse/brush.png")
const ZOCALO: Texture2D = preload("res://textures/painted/eclipse/palette_zocalo.png")

## How much the shader does over the painted atlas.
const PRESETS := {
	&"painted_led": {"paint_mix": 0.25, "stroke_strength": 0.06},
	&"even": {"paint_mix": 0.5, "stroke_strength": 0.12},
	&"shader_led": {"paint_mix": 0.85, "stroke_strength": 0.2},
}


## A material drawing `atlas` in the preset's blend, mapped onto `palette`,
## its relief from the painted `normal` map if one is given.
static func material(atlas: Texture2D, preset: StringName, palette: Texture2D = ZOCALO, normal: Texture2D = null) -> ShaderMaterial:
	var out := ShaderMaterial.new()
	out.shader = SHADER
	out.set_shader_parameter("atlas", atlas)
	out.set_shader_parameter("palette", palette)
	out.set_shader_parameter("brush", BRUSH)

	if normal != null:
		out.set_shader_parameter("normal_atlas", normal)
		out.set_shader_parameter("normal_depth", 1.0)

	for key in PRESETS[preset]:
		out.set_shader_parameter(key, PRESETS[preset][key])

	return out
