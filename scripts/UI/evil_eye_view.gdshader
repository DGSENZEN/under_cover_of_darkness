shader_type canvas_item;
// The evil eye, on the screen: it says what is happening to you, in paint.
//   - stared: being looked at, before any curse. Veins creep in from the edge, and a
//     small painted eye (gazers: x, y in the screen's 0..1, z how open) opens on
//     the side each one watching you is on.
//   - curse: the curse itself. Lids of ink close in, the edges of your view double
//     (your aim strays) and bruise, and six eyes in the lids (ring, how open) stare
//     at your aim, closing one by one as it runs out.
//   - clean: the egg breaking, a pale wash outward; cleansed: a thin ring of ward
//     colour at the frame's edge for as long as no gaze can stick.

uniform float stared = 0.0;
uniform float curse = 0.0;
uniform float clean = 0.0;
uniform float cleansed = 0.0;
uniform vec3 gazers[4];
uniform float ring[6];
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap, repeat_disable;

const vec3 VEIN = vec3(0.36, 0.03, 0.035);
const vec3 INK = vec3(0.03, 0.018, 0.02);
const vec3 BRUISE = vec3(0.24, 0.05, 0.05);
const vec3 WARD = vec3(0.81, 0.91, 0.94);
const vec3 EGG = vec3(0.95, 0.9, 0.74);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// A painted eye at `c`, `size` half-wide, open 0..1, its iris turned along `look`:
// flat cream, amber, black, in an ink outline, as the monster is painted.
vec4 eye_mark(vec2 a, vec2 c, float size, float open, vec2 look) {
	vec2 q = (a - c) / size;

	if (open <= 0.01 || abs(q.x) >= 1.06) {
		return vec4(0.0);
	}

	float lid = open * 0.6 * max(1.0 - q.x * q.x, 0.0);
	float outline = 1.0 - smoothstep(lid + 0.1, lid + 0.14, abs(q.y));
	float inside = 1.0 - smoothstep(lid - 0.015, lid + 0.015, abs(q.y));
	vec2 iris_at = q - look * 0.22;
	float r = length(iris_at);
	vec3 c_out = vec3(0.5, 0.44, 0.3);
	c_out = mix(c_out, vec3(0.74, 0.34, 0.04), 1.0 - smoothstep(0.4, 0.42, r));
	c_out = mix(c_out, INK, smoothstep(0.34, 0.36, r) * (1.0 - smoothstep(0.42, 0.45, r)));
	c_out = mix(c_out, INK, 1.0 - smoothstep(0.19, 0.21, r));
	return vec4(mix(INK, c_out, inside), outline);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 a = vec2(p.x * aspect, p.y);
	float out_from_middle = length(p);
	float edges = smoothstep(0.5, 1.2, out_from_middle);

	// The edges of your view double, and sway: your aim is not your own.
	vec2 slip = vec2(sin(TIME * 0.9), cos(TIME * 0.63)) * 0.014 * curse * edges;
	vec3 sharp = texture(screen_tex, SCREEN_UV).rgb;
	vec3 doubled = (texture(screen_tex, SCREEN_UV + slip).rgb + texture(screen_tex, SCREEN_UV - slip * 0.7).rgb) * 0.5;
	vec3 col = mix(sharp, doubled, edges * curse * 0.85);
	col = mix(col, col * vec3(1.05, 0.62, 0.62) + BRUISE * 0.05, edges * curse * 0.8);

	// Veins, in from the edge as the stare builds, all the way with the curse.
	float reach = max(stared * 0.62, curse * 0.9);

	if (reach > 0.001) {
		// Long runs reaching in along the way from the middle, not loops: stretched
		// across the angle, so they point at your aim.
		float turn = atan(a.y, a.x);
		vec2 grown = vec2(turn * 5.0, out_from_middle * 1.1 - TIME * 0.015);
		float line = min(abs(noise(grown) - 0.5), abs(noise(grown * 2.3 + 5.0) - 0.5) * 1.4);
		float vein = 1.0 - smoothstep(0.003, 0.012 + reach * 0.006, line);
		float beat = 0.8 + 0.2 * sin(TIME * mix(3.0, 7.0, curse));
		float limit = smoothstep(1.5 - reach * 0.85, 1.65 - reach * 0.85, out_from_middle);
		col = mix(col, VEIN * beat, vein * limit * 0.9);
	}

	// The lids: dry brush, bruised at the rim.
	float closing = max(curse, stared * 0.3);
	float lid_open = 1.0;

	if (closing > 0.001) {
		float streak = noise(vec2(p.x * 2.5 + TIME * 0.05, p.y * 26.0)) * 0.6 + noise(vec2(p.x * 7.0 - TIME * 0.03, p.y * 9.0)) * 0.4;
		lid_open = mix(1.3, 0.84, closing) * (1.0 - p.x * p.x * 0.55) + sin(TIME * 0.7) * 0.015;
		float past = abs(p.y) - lid_open + (streak - 0.5) * 0.2;
		float lid = smoothstep(-0.03, 0.07, past);
		float rim = smoothstep(-0.05, 0.02, past) * (1.0 - smoothstep(0.02, 0.2, past));
		vec3 ink = mix(INK, vec3(0.2, 0.05, 0.05), rim);
		col = mix(col, ink, max(lid * 0.8, rim * 0.5) * smoothstep(0.0, 0.3, closing));
	}

	// The six in the lids, staring at your aim.
	for (int i = 0; i < 6; i++) {
		if (ring[i] > 0.01) {
			float across = (float(i % 3) - 1.0) * 0.72;
			float side = i < 3 ? -1.0 : 1.0;
			float rest = mix(1.3, 0.84, curse) * (1.0 - across * across * 0.55);
			vec2 at = vec2((across + (side > 0.0 ? 0.12 : -0.12)) * aspect, side * min(rest + 0.1, 0.84));
			vec4 mark = eye_mark(a, at, 0.1, ring[i] * (0.86 + 0.14 * sin(TIME * 1.3 + float(i) * 2.1)), -normalize(at));
			col = mix(col, mark.rgb, mark.a * smoothstep(0.1, 0.4, curse));
		}
	}

	// Whoever is looking at you, from where they are.
	for (int i = 0; i < 4; i++) {
		if (gazers[i].z > 0.01) {
			vec2 at = vec2((gazers[i].x * 2.0 - 1.0) * aspect, gazers[i].y * 2.0 - 1.0);
			vec4 mark = eye_mark(a, at, 0.075 + stared * 0.05, gazers[i].z, -normalize(at + vec2(0.0001)));
			col = mix(col, mark.rgb, mark.a);
		}
	}

	// The egg breaks: a pale wash, out from the middle.
	if (clean > 0.001) {
		float front = 1.0 - clean;
		// A wave, not a fog: thin, torn by the brush, leaving the middle clear.
		float band = 1.0 - smoothstep(0.0, 0.16, abs(out_from_middle - front * 1.5 - 0.2));
		float broken = smoothstep(0.32, 0.62, noise(vec2(atan(a.y, a.x) * 7.0, out_from_middle * 3.0)));
		col = mix(col, EGG, band * broken * min(clean * 1.6, 1.0) * 0.7);
	}

	// Clean: a thin ring of ward colour, gone as it runs out.
	if (cleansed > 0.001) {
		float to_frame = 1.0 - max(abs(p.x), abs(p.y));
		float width = 0.004 + noise(a * 9.0 + TIME * 0.2) * 0.012;
		float band = 1.0 - smoothstep(width, width + 0.006, to_frame);
		// Broken, a dry line, and it thins as it runs out.
		float gaps = smoothstep(0.62 - cleansed * 0.4, 0.72 - cleansed * 0.4, noise(a * 3.0 + vec2(TIME * 0.05, 0.0)));
		col = mix(col, WARD, band * gaps * 0.75);
	}

	COLOR = vec4(col, 1.0);
}
