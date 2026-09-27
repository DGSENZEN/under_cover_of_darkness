// A surface of a light fixture that shines from inside when lit: a torch's
// pitch head, a brazier's coals, a lantern's horn panes. Its slot's photo or
// flat colour, shaded by the model's baked vertex colour like every other
// surface; glowing with the flame's colour as the flame flickers; charred
// once it has gone cold. `glow` and `charred` are per fixture.
shader_type spatial;

uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap, repeat_enable;
uniform bool has_texture = false;
uniform vec4 albedo : source_color = vec4(1.0);
uniform vec4 char_colour : source_color = vec4(0.11, 0.09, 0.08, 1.0);

instance uniform float glow = 0.0;
instance uniform float charred = 0.0;
instance uniform vec4 heat_tint : source_color = vec4(1.0, 0.6, 0.16, 1.0);

void fragment() {
	vec3 base = has_texture ? texture(albedo_texture, UV).rgb : albedo.rgb;
	base *= COLOR.rgb;
	base = mix(base, char_colour.rgb, clamp(charred, 0.0, 1.0));
	ALBEDO = base;
	ROUGHNESS = 0.9;
	// Hot pitch and coals glow deep red-orange, only a little of the flame's
	// own colour in them.
	vec3 ember = mix(vec3(0.85, 0.22, 0.04), heat_tint.rgb, 0.35);
	EMISSION = ember * clamp(glow, 0.0, 1.5) * 1.2;
}
