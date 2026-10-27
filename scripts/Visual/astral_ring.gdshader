// A ring of a ward-gate (scripts/Visual/AstralPassage.gd): one of the three rings of the invented script on
// astral_rings.png (tools/textures/astral_glyphs.py; standing in for the user's own), its strokes burning ward
// cyan-white in a soft cold glow drawn close round them, a marigold pulse running round it, brighter as the walker
// comes near.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled, blend_add;

uniform sampler2D sheet : filter_linear_mipmap, repeat_disable;
// Which of the sheet's three rings.
uniform float cell = 0.0;
uniform vec3 walker = vec3(0.0, -1000.0, 0.0);
uniform vec3 ward : source_color = vec3(0.812, 0.91, 0.941);
uniform vec3 cold : source_color = vec3(0.36, 0.72, 0.86);
uniform vec3 marigold : source_color = vec3(1.0, 0.62, 0.16);
uniform float seed = 0.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float ink_at(vec2 uv) {
	return texture(sheet, vec2((clamp(uv.x, 0.002, 0.998) + cell) / 3.0, uv.y)).a;
}

void fragment() {
	float ink = ink_at(UV);
	// Its glow: twelve taps round it, close in (no boxes from the far mips).
	float glow = 0.0;
	for (int i = 0; i < 12; i++) {
		float a = float(i) * 0.5235988;
		glow += ink_at(UV + vec2(cos(a), sin(a)) * (0.006 + 0.006 * float(i % 2)));
	}
	glow /= 12.0;
	float near = 1.0 - smoothstep(1.0, 7.0, distance(world_pos, walker + vec3(0.0, 0.9, 0.0)));
	// A pulse running round it.
	vec2 p = UV - 0.5;
	float a = atan(p.y, p.x);
	float pulse = pow(0.5 + 0.5 * sin(a * 2.0 - TIME * 1.3 + seed * 5.0), 8.0);
	vec3 col = mix(ward, marigold, pulse * 0.6) * ink * (0.8 + 0.7 * near + 0.6 * pulse);
	col += cold * glow * (0.35 + 0.4 * near);
	ALBEDO = col;
}
