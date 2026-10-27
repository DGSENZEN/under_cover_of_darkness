// A cut-out seen far off in the astral void (scripts/Visual/AstralPassage.gd): the shades walking a way of their own
// across it, the giant hand drifting past; one cell of a sheet drawn as the market's shades are (shade_cutout.gdshader):
// its body solid ink, its outline fraying into smoke that climbs it, cut hard, the last of each tongue a cold grey; and
// out here a soft glow round it in its own colour (`glow`: marigold for the dead, oxblood for what the hand belongs
// to), with a fine line of it where the smoke meets the dark. Seen only through the passage's windows. Its uniforms
// are the shade cut-out's, so a Silhouette shows its cells and walks its loop on it (`presence` only fades it here).
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled, blend_mix;

uniform sampler2D sheet : filter_linear, repeat_disable;
uniform vec2 cell_scale = vec2(0.25, 0.5);
uniform vec2 cell_offset = vec2(0.0, 0.0);
uniform sampler3D noise : filter_linear, repeat_enable;
uniform float presence = 1.0;
uniform vec3 ink : source_color = vec3(0.03, 0.028, 0.036);
uniform vec3 fray_colour : source_color = vec3(0.26, 0.3, 0.32);
uniform vec3 glow : source_color = vec3(1.0, 0.62, 0.16);
// How far in from its outline it frays, how far its glow reaches (of the cell), how strong its glow.
uniform float fray = 0.018;
uniform float reach = 0.05;
uniform float glow_strength = 0.5;
uniform float grain = 3.0;

varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float shape(vec2 uv) {
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		return 0.0;
	}
	return texture(sheet, cell_offset + uv * cell_scale).a;
}

// How much of it lies within `r` of `uv` (eight taps round it).
float near(vec2 uv, float r) {
	float sum = 0.0;
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.7853982;
		sum += shape(uv + vec2(cos(a), sin(a) * 0.5) * r);
	}
	return sum / 8.0;
}

void fragment() {
	vec3 p = world * grain + vec3(0.0, -TIME * 0.25 * grain, 0.0);
	float n = texture(noise, p).r * 0.75 + texture(noise, p * 2.1 + vec3(5.1)).r * 0.25;
	float around = near(UV, fray);
	float inner = shape(UV) * around;
	float by_it = smoothstep(0.05, 0.4, max(around, shape(UV)));
	float solid = inner + (n - 0.5) * 1.1 * (1.0 - inner) * by_it - (1.0 - by_it);
	// Its glow round it, breathing, drawn up a little as its smoke is.
	float aura = near(UV + vec2(0.0, reach * 0.3), reach) * 0.6 + near(UV, reach * 2.0) * 0.4;
	float breath = 0.8 + 0.2 * sin(TIME * 0.6 + world.x);
	if (solid < 0.3) {
		float halo = aura * (0.7 + 0.6 * n) * breath;
		if (halo < 0.02) {
			discard;
		}
		ALBEDO = glow;
		ALPHA = clamp(halo * glow_strength, 0.0, 1.0) * presence;
	} else {
		// The last of each tongue a cold grey, a fine line of its glow, then the ink.
		float tongue = 1.0 - smoothstep(0.3, 0.42, solid);
		vec3 col = mix(ink, fray_colour, tongue);
		col = mix(col, glow, (1.0 - smoothstep(0.3, 0.34, solid)) * 0.7);
		ALBEDO = col;
		ALPHA = presence;
	}
}
