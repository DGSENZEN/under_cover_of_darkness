// A ring of a ward-gate (scripts/Visual/AstralPassage.gd): one of the three rings of the invented script on
// astral_rings.png (tools/textures/astral_glyphs.py; standing in for the user's own), burning ward cyan-white with a
// soft glow round its strokes, a pulse running round it, brighter as the walker comes near.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled, blend_add;

uniform sampler2D sheet : filter_linear_mipmap, repeat_disable;
// Which of the sheet's three rings.
uniform float cell = 0.0;
uniform vec3 walker = vec3(0.0, -1000.0, 0.0);
uniform vec3 ward : source_color = vec3(0.812, 0.91, 0.941);
uniform vec3 marigold : source_color = vec3(1.0, 0.62, 0.16);
uniform float seed = 0.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = vec2((clamp(UV.x, 0.002, 0.998) + cell) / 3.0, UV.y);
	float ink = texture(sheet, uv).a;
	float glow = textureLod(sheet, uv, 2.5).a;
	float near = 1.0 - smoothstep(1.0, 7.0, distance(world_pos, walker + vec3(0.0, 0.9, 0.0)));
	// A pulse running round it.
	vec2 p = UV - 0.5;
	float a = atan(p.y, p.x);
	float pulse = 0.55 + 0.45 * pow(0.5 + 0.5 * sin(a * 2.0 - TIME * 1.3 + seed * 5.0), 6.0);
	vec3 col = ward * ink * (0.55 + 0.6 * near) * pulse;
	col += mix(ward, marigold, 0.25) * glow * (0.15 + 0.3 * near);
	ALBEDO = col;
}
