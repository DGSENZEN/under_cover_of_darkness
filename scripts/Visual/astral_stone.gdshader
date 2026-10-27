// A stone of the astral passage's way (scripts/Visual/AstralPassage.gd): its painted stone dim, as if lit from far
// off; a cold rim round it, its top's edge catching the most; the city's glyphs glowing marigold in its cracks, as if
// the ward that tore it loose were still written in it. It clears the stencil where it is seen, so the void never
// draws over it.
shader_type spatial;
render_mode unshaded, cull_back, fog_disabled;
stencil_mode write, compare_always, 0;

uniform sampler2D atlas : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler3D noise : filter_linear, repeat_enable;
uniform vec3 rim_cold : source_color = vec3(0.32, 0.76, 0.9);
uniform vec3 marigold : source_color = vec3(1.0, 0.6, 0.18);
uniform float dim = 0.34;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 paint = texture(atlas, UV).rgb * dim;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	// (Its top's own edge: where the flat top meets its broken side.)
	float top = smoothstep(0.85, 0.99, world_normal.y);
	float cracks = texture(noise, world_pos * 1.3).r;
	float glyph = smoothstep(0.69, 0.71, cracks) * (1.0 - smoothstep(0.71, 0.73, cracks));
	float pulse = 0.6 + 0.4 * sin(TIME * 0.9 + world_pos.x * 1.7 + world_pos.z * 1.1);
	ALBEDO = paint + rim_cold * rim * 0.55 * (1.0 - top * 0.6) + marigold * glyph * top * pulse * 0.9;
}
