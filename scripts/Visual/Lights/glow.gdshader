// A surface of a light fixture that shines from inside when lit: a torch's
// pitch head, a brazier's coals, a lantern's horn panes. Its slot's photo or
// flat colour, shaded by the model's baked vertex colour like every other
// surface; glowing with the flame's colour as the flame flickers; charred
// once it has gone cold. `glow` and `charred` are per fixture. Pitch and
// coals glow in hot spots that come and go (`mottle`), never evenly: an even
// glow, lifted by the night's exposure, reads as a pale bulb.
shader_type spatial;

uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap, repeat_enable;
uniform bool has_texture = false;
uniform vec4 albedo : source_color = vec4(1.0);
uniform vec4 char_colour : source_color = vec4(0.11, 0.09, 0.08, 1.0);
// How much of the flame's own colour is in its glow (hot pitch and coals
// deep red-orange, horn panes the flame's amber), and how bright it is.
uniform float flame_share = 0.35;
uniform float brightness = 0.55;
// 0 glows evenly (horn panes); toward 1, in hot spots a few centimetres
// across (in the model's own space, so a carried torch's do not swim).
uniform float mottle = 0.0;

instance uniform float glow = 0.0;
instance uniform float charred = 0.0;
instance uniform vec4 heat_tint : source_color = vec4(1.0, 0.6, 0.16, 1.0);

varying vec3 local;

void vertex() {
	local = VERTEX;
}

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

void fragment() {
	vec3 base = has_texture ? texture(albedo_texture, UV).rgb : albedo.rgb;
	base *= COLOR.rgb;
	base = mix(base, char_colour.rgb, clamp(charred, 0.0, 1.0));
	ALBEDO = base;
	ROUGHNESS = 0.9;
	vec3 ember = mix(vec3(0.85, 0.22, 0.04), heat_tint.rgb, flame_share);
	float spot = hash(floor(local * 32.0));
	float hot = smoothstep(0.5, 1.0, spot * 0.75 + 0.25 * sin(TIME * (1.5 + spot * 2.0) + spot * 6.283));
	EMISSION = ember * clamp(glow, 0.0, 1.5) * brightness * mix(1.0, hot, mottle);
}
