shader_type canvas_item;
// Your magic and your life being drunk (LifeLeech.gd), on the screen. Two ribbons run out
// of your chest into each hand that has you, red for your life and blue for your magic,
// twisting, a swallow going down them with every gulp, going sick and green where they go
// in; the blue stops when you have no more to give. Round it your sight goes corpse-green
// from the edges in, thin and cold, rot blotching through it, the low sick fire of what
// has hold of you licking at its front, deeper with each one on you. The middle stays
// clear, so you can still fight. Thrown off, colour floods back past where it was
// (`release`). Painted, as evil_eye_view is, and drawn under it.

uniform float drain = 0.0;
uniform float release = 0.0;
// The last gulp: 1 as it lands, down to 0.
uniform float gulp = 0.0;
// How much magic you have left to give, 0..1.
uniform float magic = 1.0;
// Each hand that has you: where it is on the screen, 0..1, and how much to show.
uniform vec3 threads[3];
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D stroke_sheet : repeat_enable, filter_linear_mipmap;

const vec3 CORPSE = vec3(0.5, 0.68, 0.4);
const vec3 GRAVE = vec3(0.1, 0.2, 0.07);
const vec3 ROT = vec3(0.012, 0.03, 0.012);
const vec3 SICK = vec3(0.56, 0.78, 0.12);
const vec3 LIFE_DEEP = vec3(0.3, 0.015, 0.02);
const vec3 LIFE_LIT = vec3(0.95, 0.16, 0.08);
const vec3 MAGIC_DEEP = vec3(0.1, 0.24, 0.5);
const vec3 MAGIC_LIT = vec3(0.68, 0.9, 1.0);
const float RIBBON_WIDE = 0.03;
const vec3 WARM = vec3(1.0, 0.58, 0.28);
const float CLEAR = 0.42;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// The nearest point of a quadratic curve: how far from it, and how far along (0..1).
vec2 on_curve(vec2 pos, vec2 from, vec2 bend, vec2 to) {
	vec2 e = bend - from;
	vec2 f = from - 2.0 * bend + to;
	vec2 g = e * 2.0;
	vec2 d = from - pos;
	float kk = 1.0 / max(dot(f, f), 0.000001);
	float kx = kk * dot(e, f);
	float ky = kk * (2.0 * dot(e, e) + dot(d, f)) / 3.0;
	float kz = kk * dot(d, e);
	float q1 = ky - kx * kx;
	float q3 = q1 * q1 * q1;
	float r = kx * (2.0 * kx * kx - 3.0 * ky) + kz;
	float h = r * r + 4.0 * q3;
	float t;

	if (h >= 0.0) {
		h = sqrt(h);
		vec2 x = (vec2(h, -h) - r) * 0.5;
		vec2 uv = sign(x) * pow(abs(x), vec2(1.0 / 3.0));
		t = clamp(uv.x + uv.y - kx, 0.0, 1.0);
	} else {
		float z = sqrt(-q1);
		float v = acos(clamp(r / (q1 * z * 2.0), -1.0, 1.0)) / 3.0;
		float m = cos(v);
		float n = sin(v) * 1.732050808;
		float t1 = clamp((m + m) * z - kx, 0.0, 1.0);
		float t2 = clamp((-n - m) * z - kx, 0.0, 1.0);
		vec2 w1 = d + (g + f * t1) * t1;
		vec2 w2 = d + (g + f * t2) * t2;
		t = dot(w1, w1) < dot(w2, w2) ? t1 : t2;
	}

	vec2 w = d + (g + f * t) * t;
	return vec2(length(w), t);
}

// A ribbon of what is being drawn out of you: flat and twisting, an ink line and a wet
// edge, what it carries pulsing along it, a swallow going down it with the gulp.
void drunk_ribbon(inout vec3 col, vec2 a, vec2 from, vec2 bend, vec2 to, float wide, vec3 deep, vec3 lit, float seed, float pulse, float grain) {
	vec2 at = a + vec2(sin(a.y * 7.0 + TIME * 2.1 + seed * 5.0), cos(a.x * 6.0 - TIME * 1.7 + seed * 3.0)) * wide * 0.3;
	vec2 near = on_curve(at, from, bend, to);
	float t = near.y;
	float twist = cos(t * 10.0 + seed * 7.0 - TIME * 3.5);
	float swallow_at = (1.0 - pulse) * 1.1 - 0.05;
	float swallow = pulse > 0.001 ? exp(-pow((t - swallow_at) / 0.09, 2.0)) : 0.0;
	float half_wide = wide * (0.4 + 0.6 * abs(twist)) * (1.0 + swallow * 1.3) * mix(1.0, 0.55, t) * (0.82 + grain * 0.36);
	float inside = half_wide - near.x;
	// Its shadow on your sight.
	col *= 1.0 - 0.5 * smoothstep(-0.03, 0.0, inside);

	if (inside > -0.01) {
		float flows = 0.62 + 0.38 * sin(t * 24.0 - TIME * 8.0 + seed);
		vec3 flesh = mix(deep, lit, flows * 0.55 + swallow * 0.7);
		flesh = mix(flesh, deep * 0.45, smoothstep(0.08, -0.08, twist));
		// It goes sick where it goes in.
		flesh = mix(flesh, SICK * 0.8, smoothstep(0.68, 1.0, t));
		col = mix(col, vec3(0.012, 0.01, 0.01), smoothstep(-0.009, -0.002, inside));
		col = mix(col, flesh, smoothstep(0.0, 0.005, inside));
	}
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 a = vec2(p.x * aspect, p.y);
	float out_from_middle = length(p);
	vec3 col = texture(screen_tex, SCREEN_UV).rgb;
	vec2 way_out = a / max(length(a), 0.001);
	float grain = textureLod(stroke_sheet, a * 0.28 + vec2(TIME * 0.008, 0.0), 0.0).r;

	// Bled out from the edges in, pulsed further in by each gulp. Never over the middle.
	float reach = mix(1.5, CLEAR, drain) - gulp * 0.16 * step(0.001, drain);
	float bled = smoothstep(reach - 0.14, reach + 0.2, out_from_middle + (grain - 0.5) * 0.34);
	bled *= smoothstep(CLEAR - 0.08, CLEAR + 0.1, out_from_middle);
	float value = dot(col, vec3(0.3, 0.55, 0.15));
	// Long strokes running in from the edges, so it is a wash of paint and not a fog.
	float streak = textureLod(stroke_sheet, way_out * 0.42 + a * 0.05, 0.0).r;
	bled *= mix(0.45, 1.0, smoothstep(0.3, 0.65, streak));
	// No blood in it: corpse-green and thin, its darks lifted into the grave's colour.
	vec3 thin = value * CORPSE * 0.95 + GRAVE * (0.1 + 0.26 * streak + gulp * 0.16);
	col = mix(col, thin, bled * clamp(drain * 1.3, 0.0, 0.9));
	// Rot blotching through it, dark, in the brush's shapes.
	float blotch = textureLod(stroke_sheet, a * 0.13 + vec2(0.31, TIME * 0.004), 0.0).r;
	float rot = smoothstep(0.5, 0.64, blotch * 0.65 + streak * 0.35) * smoothstep(CLEAR + 0.1, CLEAR + 0.5, out_from_middle);
	col = mix(col, ROT, rot * bled * drain * 0.72);
	// Its front: low sick fire licking in, torn by the brush, up with each gulp.
	float lick = textureLod(stroke_sheet, a * 0.3 + vec2(0.13, TIME * -0.05), 0.0).r;
	float tear = textureLod(stroke_sheet, a * 0.09 + vec2(TIME * 0.012, 0.47), 0.0).r;
	float front = out_from_middle - reach - (lick - 0.5) * 0.42;
	float flame = exp(-front * front * 70.0) * smoothstep(0.52, 0.66, lick) * smoothstep(0.42, 0.58, tear);
	col += SICK * flame * step(0.001, drain) * smoothstep(CLEAR - 0.02, CLEAR + 0.12, out_from_middle) * (0.12 + gulp * 0.3) * clamp(drain * 2.0, 0.0, 1.0) * (1.0 - release);

	// What is being drawn out of you: out of your chest, into each hand that has you.
	for (int i = 0; i < 3; i++) {
		if (threads[i].z > 0.01) {
			vec2 to = vec2((threads[i].x * 2.0 - 1.0) * aspect, threads[i].y * 2.0 - 1.0);
			float at_it = length(a - to);
			col += SICK * exp(-at_it * at_it * 40.0) * (0.04 + gulp * 0.18) * threads[i].z;
			float out_to = sign(to.x + 0.0001);
			vec2 chest = vec2(out_to * 0.06, 1.08);
			vec2 way = to - chest;
			vec2 mid = (chest + to) * 0.5;
			float seed = float(i) * 2.3;
			drunk_ribbon(col, a, chest + vec2(-0.05, 0.0), mid + vec2(0.05 + out_to * 0.05, 0.16), to, RIBBON_WIDE, LIFE_DEEP, LIFE_LIT, seed, gulp, grain);

			if (magic > 0.01) {
				drunk_ribbon(col, a, chest + vec2(0.05, 0.0), mid + vec2(-0.08 * out_to, 0.03), to + vec2(0.0, 0.015), RIBBON_WIDE * 0.82 * magic, MAGIC_DEEP, MAGIC_LIT, seed + 1.3, max(gulp - 0.1, 0.0) / 0.9, grain);
			}
		}
	}

	// Free: it comes back, and more than it was, for a moment.
	col = mix(col, col * 1.4 + WARM * 0.05 * (0.5 + 0.5 * out_from_middle), release);
	COLOR = vec4(col, 1.0);
}
