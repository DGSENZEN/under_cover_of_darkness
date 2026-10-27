// A threshold of the astral passage (scripts/Visual/AstralPassage.gd): a membrane filling a gap of it, what is seen
// through it rippling and bent, a cold sheen over it, the city's glyph ring (the wards' circle, its glyphs the invented
// script, standing in for the user's) glowing round it, brighter as the walker comes near.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled, blend_mix;

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D ring : filter_linear_mipmap, repeat_disable;
uniform sampler3D noise : filter_linear, repeat_enable;
uniform vec3 walker = vec3(0.0, -1000.0, 0.0);
uniform vec3 sheen : source_color = vec3(0.32, 0.72, 0.9);
uniform vec3 marigold : source_color = vec3(1.0, 0.62, 0.18);
// Its size (m: width, height), so the ring stays round on a long gap.
uniform vec2 size = vec2(3.0, 3.0);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// The ripple: slow rings of it spreading from its middle, a fine shiver over them.
	vec2 p = (UV - 0.5) * size;
	float r = length(p);
	float wave = sin(r * 5.0 - TIME * 1.6) * 0.5 + 0.5;
	float shiver = texture(noise, vec3(UV * 3.0, TIME * 0.05)).r - 0.5;
	vec2 bend = normalize(p + 0.0001) * (wave - 0.5) * 0.012 + vec2(shiver) * 0.01;
	vec3 seen = texture(screen, SCREEN_UV + bend).rgb;
	// Its glyph ring, round, some seven tenths of the gap's height, and nearer, brighter.
	float side = min(size.x, size.y);
	vec2 ring_uv = p / (side * 1.4) + 0.5;
	float glyphs = 0.0;
	if (ring_uv.x >= 0.0 && ring_uv.x <= 1.0 && ring_uv.y >= 0.0 && ring_uv.y <= 1.0) {
		glyphs = texture(ring, ring_uv).a;
	}
	float near = 1.0 - smoothstep(1.0, 6.0, distance(world_pos, walker + vec3(0.0, 0.9, 0.0)));
	// (Laid over what is behind it, the void too, not a screen: what was drawn before the void, bent, a sheen.)
	vec3 col = seen * 0.7 + sheen * (0.1 + 0.15 * wave);
	col = mix(col, marigold, glyphs * (0.25 + 0.75 * near));
	ALBEDO = col;
	ALPHA = clamp(0.38 + 0.12 * wave + glyphs * (0.3 + 0.6 * near), 0.0, 1.0);
}
