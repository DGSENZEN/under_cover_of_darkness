// A stone of a ward-gate's arch (scripts/Visual/AstralPassage.gd): a carved block of the city's dark stone floating
// with its fellows round the gate's circle, drawn in the void (over its frame, not cut by it). Lit from the gate's fire
// on its inner face, a cold rim from the deep; on its face toward either side one of the script's glyphs (a cell of
// astral_rings.png) cut into it, glowing ward cyan-white and pulsing round the arch in turn; its keystone's glyph
// marigold. Seen only where the void is.
shader_type spatial;
render_mode unshaded, cull_back, depth_test_disabled, depth_draw_never, fog_disabled, blend_mix;
stencil_mode read, compare_equal, 1;

uniform sampler2D rings : filter_linear_mipmap, repeat_disable;
uniform sampler3D noise : filter_linear, repeat_enable;
// Where the gate's middle is, and this stone's place round its arch (0..1; the keystone 0.5) and whether it is the
// keystone.
uniform vec3 gate_at;
uniform float place = 0.0;
uniform bool keystone = false;
// Whether it carries the script's glyph (an arch's stone), or the Pasaje's chequer on its top (an echo of a way
// stone); how much of it is there (a glimpse: below 1 it dissolves).
uniform bool glyphs = true;
uniform bool chequer = false;
uniform float shown = 1.0;
uniform vec3 stone : source_color = vec3(0.19, 0.16, 0.14);
uniform vec3 ink : source_color = vec3(0.025, 0.022, 0.028);
uniform vec3 ward : source_color = vec3(0.812, 0.91, 0.941);
uniform vec3 marigold : source_color = vec3(1.0, 0.62, 0.16);
uniform vec3 oxblood : source_color = vec3(0.431, 0.122, 0.102);

varying vec3 world_pos;
varying vec3 local;
varying vec3 local_n;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	local = VERTEX;
	local_n = NORMAL;
}

void fragment() {
	if (texture(noise, world_pos * 0.15 + vec3(place)).r > shown * 1.1 - 0.05) {
		discard;
	}
	vec3 n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	// Lit warm by the gate's fire on the face toward its middle.
	float to_fire = clamp(dot(n, normalize(gate_at - world_pos)), 0.0, 1.0);
	float grain = texture(noise, world_pos * 2.5).r;
	float chips = texture(noise, world_pos * 9.0).r;
	vec3 col = mix(ink, stone * (0.5 + 0.6 * grain), 0.3 + 0.3 * chips);
	col += mix(oxblood, marigold, 0.35) * to_fire * 0.18;
	// Its glyph, on its faces toward either side of the gate (its local z).
	float glyph = 0.0;
	if (chequer && local_n.y > 0.85) {
		// The Pasaje's chequer on its top, dim, in its grout.
		vec2 cell = floor(local.xz / 0.3);
		vec2 f = fract(local.xz / 0.3);
		float line = 1.0 - smoothstep(0.03, 0.07, min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y)));
		vec3 tiles = mix(vec3(0.8, 0.72, 0.56), vec3(0.6, 0.3, 0.2), mod(cell.x + cell.y, 2.0));
		col = mix(tiles * 0.3 * (0.8 + 0.4 * grain), ink, line);
	}
	if (glyphs && abs(local_n.z) > 0.9) {
		// (A cell of the outer ring's band, picked by its place round the arch.)
		vec2 uv = local.xy * vec2(1.6, 1.6) + 0.5;
		float a = place * 6.2831853;
		vec2 at = vec2(0.5 + cos(a) * 0.44, 0.5 + sin(a) * 0.44);
		vec2 sample_at = at + (uv - 0.5) * 0.08;
		if (uv.x > 0.0 && uv.x < 1.0 && uv.y > 0.0 && uv.y < 1.0) {
			glyph = texture(rings, vec2(sample_at.x / 3.0, sample_at.y)).a;
		}
	}
	float pulse = pow(0.5 + 0.5 * sin(TIME * 1.1 - place * 12.0), 6.0);
	vec3 glow = keystone ? marigold : ward;
	col = mix(col, ink, glyph * 0.5);
	col += glow * glyph * (0.25 + 0.6 * pulse);
	// A cold rim from the deep.
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	col += ward * rim * 0.2;
	ALBEDO = col;
	ALPHA = 1.0;
}
