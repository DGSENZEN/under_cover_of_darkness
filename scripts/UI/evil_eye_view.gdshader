shader_type canvas_item;
// The evil eye, on the screen: the monster's own flesh growing in over your sight,
// painted as it is painted (hard stepped light, a wet dab, an ink line, no fog).
//   - stared: being looked at, before any curse. Veins reach in from the edge, and
//     a patch of meat swells where each watcher is (gazers: x, y in the screen's
//     0..1, z how open), an eye tearing open in it.
//   - curse: the curse itself. The meat closes in, beating, the edges of your view
//     double (your aim strays) and bruise, and six eyes sunk in it (ring, how open)
//     stare at your aim, weeping blood, shutting one by one as it runs out.
//   - leaving: running out by itself, it fades as `curse` falls: quiet.
//   - gather: using the egg, 0..1. The eyes turn to it; then the flesh tears away in
//     twisting ribbons with the eyes riding on them, hauled into the egg one by one.
//   - dispel: the egg is spent, 0..1. What was left goes in, and the egg bursts.
//   - relief: after it, 0..1: your sight a little brighter.
//   - egg_at: where the egg is on the screen, 0..1.
uniform float stared = 0.0;
uniform float curse = 0.0;
uniform float gather = 0.0;
uniform float dispel = 0.0;
uniform float relief = 0.0;
uniform vec2 egg_at = vec2(0.3, 0.7);
uniform float leaving = 0.0;
uniform float cleansed = 0.0;
uniform vec3 gazers[4];
uniform float ring[6];
// The eye's own painting (the model's ball).
uniform sampler2D eye_paint : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap, repeat_disable;
// The look's brush: the same strokes as the world's paint.
uniform sampler2D stroke_sheet : filter_linear_mipmap, repeat_enable;

const vec3 INK = vec3(0.012, 0.007, 0.008);
// Oxblood and liver, as the crown's stone and the meat behind it.
const vec3 LIVER = vec3(0.05, 0.012, 0.014);
const vec3 MEAT = vec3(0.155, 0.03, 0.024);
const vec3 WET = vec3(0.27, 0.06, 0.04);
const vec3 DAB = vec3(0.52, 0.34, 0.27);
const vec3 VIOLET = vec3(0.05, 0.016, 0.045);
const vec3 ARTERY = vec3(0.2, 0.018, 0.016);
const vec3 BLOOD = vec3(0.13, 0.008, 0.008);
const vec3 WARD = vec3(0.72, 0.8, 0.82);
// The ribbons, on the clock of the egg's use: when the first sets off, how long
// after it each next one does, how long one takes to reach the egg, and how long its
// tail lags its head. (Loadout.gd lands them on the same clock.)
const float PULL_FROM = 0.14;
const float PULL_STAGGER = 0.06;
const float PULL_TAKES = 0.55;
const float TAIL_LAG = 0.14;
const vec3 PALE = vec3(0.86, 0.8, 0.66);
const vec2 LIGHT_DIR = vec2(-0.45, -0.89);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Lub-dub, 0..1.
float beat(float time) {
	float t = fract(time);
	return exp(-t * 14.0) + 0.6 * exp(-max(t - 0.22, 0.0) * 16.0) * step(0.22, t);
}

// How the meat stands: rounded swells and folds running round the view.
float swell_at(vec2 a, float time) {
	vec2 p = vec2(atan(a.y, a.x) * 2.2, length(a) * 3.4 - time * 0.03);
	float big = noise(p * 1.1);
	float fold = 1.0 - abs(noise(p * vec2(2.3, 3.4) + 4.0) * 2.0 - 1.0);
	return big * 0.65 + fold * fold * 0.35;
}

// Thin lines where noise crosses its middle, stretched to reach toward the aim.
float reaching(vec2 a, float width) {
	vec2 grown = vec2(atan(a.y, a.x) * 5.0, length(a) * 1.1);
	float line = min(abs(noise(grown) - 0.5), abs(noise(grown * 2.3 + 5.0) - 0.5) * 1.4);
	return 1.0 - smoothstep(width * 0.4, width, line);
}

// The brush's value here, 0..1.
float strokes(vec2 at) {
	return texture(stroke_sheet, at).r;
}

// Paints the meat at `a`, `body` being how far in it stands: big flat shapes, half
// of it solid black, a few paints laid on with the brush, near each other.
vec3 meat_at(vec2 a, float body, float time, float pulse) {
	float h = swell_at(a, time);
	float e = 0.012;
	vec2 slope = vec2(swell_at(a + vec2(e, 0.0), time) - h, swell_at(a + vec2(0.0, e), time) - h) / e;
	float facing = dot(normalize(slope * 0.16 + LIGHT_DIR * 0.2), LIGHT_DIR);
	float brush = strokes(a * 0.7 + vec2(0.0, time * 0.002));
	// The shadow's edge broken by the brush.
	float f = facing + (brush - 0.5) * 0.3;
	vec3 c = mix(INK, LIVER, smoothstep(-0.28, -0.2, f));
	c = mix(c, MEAT, smoothstep(0.12, 0.2, f));
	c = mix(c, WET, smoothstep(0.62, 0.7, f) * smoothstep(0.5, 0.6, h));
	// Second and third paints: hue and value, not dirt.
	c *= mix(vec3(0.72, 0.68, 0.74), vec3(1.2, 1.08, 0.98), smoothstep(0.35, 0.65, strokes(a * 1.9 + 2.0)));
	// Veins on it: dark, flushing only a little with each beat.
	c = mix(c, mix(VIOLET, ARTERY, pulse), reaching(a * 1.6 + 3.0, 0.018) * 0.8 * smoothstep(-0.2, 0.1, f));
	// The wet dab: small, hard, muted, only here and there.
	float dab = smoothstep(0.93, 0.95, facing) * smoothstep(0.66, 0.72, h) * step(0.55, noise(a * 3.0));
	c = mix(c, DAB, dab * 0.8);
	return c * (0.85 + body * 0.15);
}

// One eye sunk in the meat at `c`, `size` half-wide: the swollen lids, the painted
// ball looking along `look`, its lash line, its dab. Alpha 0 outside the socket.
vec4 sunk_eye(vec2 a, vec2 c, float size, float open, vec2 look, float seed, float time) {
	vec2 q = (a - c) / size;
	// Its lids are not quite true: each eye its own.
	q.y += sin(q.x * 3.0 + seed * 7.0) * 0.05;
	float wide = 1.0 - q.x * q.x;

	if (wide <= -0.28 || abs(q.y) > 1.1) {
		return vec4(0.0);
	}

	float lid = open * 0.58 * max(wide, 0.0);
	float d = abs(q.y) - lid + (noise(q * 6.0 + seed * 13.0) - 0.5) * 0.05;
	// The swollen rim of the lid round the almond.
	float socket = 1.0 - smoothstep(0.26, 0.31, d + max(-wide, 0.0) * 0.8);
	vec2 around = vec2(q.x, sign(q.y) * d);
	float roll = smoothstep(0.0, 0.26, d);
	float lit = smoothstep(-0.05, 0.1, -q.y * sign(q.y) * 0.0 + (q.y < 0.0 ? 0.26 - d : d - 0.1));
	vec3 col = mix(LIVER, MEAT, lit);
	col = mix(col, WET, smoothstep(0.1, 0.14, d) * (1.0 - smoothstep(0.17, 0.22, d)) * step(q.y, 0.0));
	col *= 0.85 + strokes(a * 2.1 + seed) * 0.3;
	// A heavy lash line, and a heavy line round the lid.
	col = mix(col, INK, 1.0 - smoothstep(0.03, 0.08, d));
	col = mix(col, INK, smoothstep(0.235, 0.26, d + max(-wide, 0.0) * 0.8));

	if (d < 0.0 && open > 0.02) {
		// The ball, in the middle of the painting, turned to look.
		vec2 on_ball = q - look * 0.3;
		float r = length(on_ball);
		vec2 uv = vec2(0.5) + vec2(on_ball.x, -on_ball.y) * 0.42;
		// A dirty, tired white, so the amber is the one bright note.
		vec3 ball = texture(eye_paint, clamp(uv, vec2(0.0), vec2(1.0))).rgb;
		float white_of_it = smoothstep(0.34, 0.42, r);
		ball *= mix(vec3(1.0), vec3(0.52, 0.46, 0.4), white_of_it);
		ball *= 0.85 + strokes(a * 3.0 + seed) * 0.3 * white_of_it;
		// Its pupil, breathing.
		float pupil = 0.2 + 0.03 * sin(time * 2.1 + seed * 9.0);
		ball = mix(ball, INK, 1.0 - smoothstep(pupil - 0.012, pupil + 0.012, r));
		// In shadow under the upper lid, and a hard wet dab.
		ball *= 0.55 + 0.45 * smoothstep(-lid, -lid * 0.2, q.y);
		ball = mix(ball, DAB * 1.3, 1.0 - smoothstep(0.035, 0.05, length(on_ball - vec2(-0.14, -0.14))));
		col = ball;
	}

	return vec4(col, socket);
}

// Blood run down from an eye: a few thin lines, each with its own slow drop.
float tears_from(vec2 a, vec2 c, float size, float seed, float time) {
	float wept = 0.0;

	for (int i = 0; i < 3; i++) {
		float f = float(i) + seed * 3.0;
		float x = c.x + (hash(vec2(f, 1.0)) - 0.5) * size * 1.1;
		float wander = sin(a.y * 12.0 + f) * 0.004;
		float start = c.y + size * 0.3;
		float run = size * (0.8 + hash(vec2(f, 2.0)) * 2.4) * (0.55 + 0.45 * fract(time * 0.07 + f * 0.37));
		float across = abs(a.x - x - wander);
		float below = (a.y - start) / max(run, 0.001);
		float width = 0.0035 + 0.0035 * smoothstep(0.75, 1.0, below);
		wept = max(wept, (1.0 - smoothstep(width * 0.6, width, across)) * step(0.0, below) * (1.0 - smoothstep(0.98, 1.02, below)));
	}

	return wept;
}

// How far past the flesh's edge `p` is: above 0, inside it. `closing` is how far in
// it has come; a dry brush's streaks and a beat move its edge.
float flesh_past(vec2 p, float closing, float time, float heart, float bristle) {
	float edge_noise = noise(vec2(p.x * 3.0 + time * 0.04, 3.0)) * 0.6 + noise(vec2(p.x * 9.0 - time * 0.03, 7.0)) * 0.3 + noise(vec2(p.x * 21.0, p.y * 6.0)) * 0.1;
	float open = mix(1.42, 0.84, closing) * (1.0 - p.x * p.x * 0.5) - heart * 0.012 * closing;
	float past = abs(p.y) - open + (edge_noise - 0.5) * 0.16 + (bristle - 0.5) * 0.1;
	// Its corners come in round the sides too.
	return max(past, abs(p.x) - mix(1.5, 1.02, closing) + (edge_noise - 0.5) * 0.12 + (bristle - 0.5) * 0.08);
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

vec2 curve_at(vec2 from, vec2 bend, vec2 to, float t) {
	return mix(mix(from, bend, t), mix(bend, to, t), t);
}

// The bend of a ribbon's way in: all one way round, so they swirl into the egg.
vec2 curve_bend(vec2 from, vec2 to, float seed) {
	vec2 along = to - from;
	return (from + to) * 0.5 + vec2(-along.y, along.x) * (0.26 + hash(vec2(seed, 3.0)) * 0.22);
}

// A strip of flesh torn loose, from `tail` to `head` of the way along its curve, flat
// and twisting: narrow where it turns edge-on, its back darker, an ink line and a wet
// edge, pinched to a thread where it goes into the egg.
void ribbon(inout vec3 col, vec2 a, vec2 from, vec2 bend, vec2 to, float tail, float head, float wide, float seed, float time, float pulse) {
	if (head <= tail) {
		return;
	}

	vec2 sway = vec2(sin(a.y * 5.0 + time * 3.1 + seed * 9.0), cos(a.x * 4.0 - time * 2.7 + seed * 5.0));
	vec2 at = a + sway * wide * 0.3;
	vec2 near = on_curve(at, from, bend, to);
	float t = near.y;
	float twist = cos(t * 8.0 + seed * 7.0 - time * 4.0);
	// Still rooted, it runs on off your sight at full width; torn free, its tail tapers.
	float tail_taper = tail > 0.001 ? smoothstep(tail, tail + 0.14, t) : 1.0;
	float ends = tail_taper * (1.0 - smoothstep(head - 0.03, head, t)) * step(t, head);
	float half_wide = wide * (0.42 + 0.58 * abs(twist)) * ends * mix(1.0, 0.1, smoothstep(0.82, 1.0, t));

	if (half_wide < 0.001) {
		return;
	}

	float inside = half_wide - near.x;
	// Its shadow on what is behind it.
	col *= 1.0 - 0.55 * smoothstep(-0.035, 0.0, inside);

	if (inside > -0.012) {
		vec2 toward = normalize(2.0 * (1.0 - t) * (bend - from) + 2.0 * t * (to - bend));
		float across = dot(vec2(-toward.y, toward.x), at - curve_at(from, bend, to, t));
		vec3 flesh = meat_at(vec2(across * 4.5 + seed, t * 0.7 + seed * 3.0), 0.9, time, pulse);
		flesh = mix(flesh, flesh * 0.5 + LIVER * 0.1, smoothstep(0.08, -0.08, twist));
		float wet_edge = smoothstep(0.3, 0.62, across / half_wide) * (1.0 - smoothstep(0.62, 0.86, across / half_wide));
		flesh = mix(flesh, WET, wet_edge * 0.6 * step(0.0, twist));
		col = mix(col, INK, smoothstep(-0.012, -0.002, inside));
		col = mix(col, flesh, smoothstep(0.0, 0.006, inside));
	}
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 a = vec2(p.x * aspect, p.y);
	float out_from_middle = length(p);
	float edges = smoothstep(0.5, 1.2, out_from_middle);
	float time = TIME;
	float heart = beat(time * mix(1.0, 1.7, curse) * (1.0 + gather * 1.4));

	// The egg, and how far through being taken the curse is. What is left of the last
	// ribbons goes in as it bursts.
	float taken = dispel > 0.001 ? 1.0 : gather;
	float pull = taken + dispel * 0.5;
	vec2 egg = vec2((egg_at.x * 2.0 - 1.0) * aspect, egg_at.y * 2.0 - 1.0);
	vec2 from_egg = a - egg;
	vec2 way_from_egg = from_egg / max(length(from_egg), 0.001);

	// The edges of your view double, and sway: your aim is not your own.
	float strength = curse * (1.0 - smoothstep(0.1, 0.6, taken));
	vec2 slip = vec2(sin(time * 0.9), cos(time * 0.63)) * 0.014 * strength * edges;
	vec3 sharp = texture(screen_tex, SCREEN_UV).rgb;
	vec3 doubled = (texture(screen_tex, SCREEN_UV + slip).rgb + texture(screen_tex, SCREEN_UV - slip * 0.7).rgb) * 0.5;
	vec3 col = mix(sharp, doubled, edges * strength * 0.85);
	col = mix(col, col * vec3(1.05, 0.6, 0.6), edges * strength * 0.8);

	// Veins reaching in ahead of the flesh, as the stare builds.
	float reach = max(stared * 0.62, curse * 0.9) * (1.0 - smoothstep(0.1, 0.5, taken)) * (1.0 - leaving * (1.0 - curse));

	if (reach > 0.001) {
		float vein = reaching(a, 0.009 + reach * 0.004) * smoothstep(0.3, 0.6, strokes(a * 1.2));
		float limit = smoothstep(1.5 - reach * 0.8, 1.68 - reach * 0.8, out_from_middle);
		col = mix(col, ARTERY * (0.75 + heart * 0.3), vein * limit * 0.7);
	}

	float remains = (1.0 - smoothstep(0.0, 0.2, dispel)) * (1.0 - leaving * (1.0 - curse));

	// The flesh, closing in from above and below, and torn back as the ribbons go.
	float closing = max(curse, stared * 0.28) * (1.0 - smoothstep(0.2, 0.9, pull));

	if (closing > 0.001) {
		float bristle = strokes(vec2(p.x * 1.7 + 0.3, p.y * 0.25)) * 0.6 + strokes(vec2(p.x * 4.3, p.y * 0.5 + 0.7)) * 0.4;
		// Torn back past the edge of your sight, corners and all, as the last ones go.
		float torn_back = smoothstep(0.45, 1.0, pull) * 0.7;
		float past = flesh_past(p, closing, time, heart, bristle) - torn_back;

		// Its shadow on your sight, cast down and in: it lies on top of the view.
		float shadow_past = flesh_past(p - vec2(0.012, -sign(p.y) * 0.05 + 0.01), closing, time, heart, bristle) - torn_back;
		float cast = smoothstep(-0.05, 0.03, shadow_past) * (1.0 - smoothstep(-0.004, 0.012, past));
		col *= 1.0 - cast * 0.62 * smoothstep(0.1, 0.5, closing) * remains;

		if (past > -0.04) {
			vec3 flesh = meat_at(a, smoothstep(0.0, 0.3, past), time, heart * closing);
			float body = smoothstep(0.0, 0.015, past);
			// A wet lit lip just inside its edge, where it folds over.
			float lip = smoothstep(0.012, 0.03, past) * (1.0 - smoothstep(0.03, 0.06 + bristle * 0.03, past));
			flesh = mix(flesh, WET, lip * 0.7);
			// Pigment pools in a line of ink, thick and thin as the brush went.
			float line = smoothstep(-0.03 - bristle * 0.02, -0.012, past) * (1.0 - body);
			col = mix(col, INK, line * remains);
			col = mix(col, flesh, body * remains);
		}
	}

	// Thin strips torn from the rim, going in with the rest.
	if (curse > 0.1 && pull > PULL_FROM) {
		for (int i = 0; i < 7; i++) {
			float seed = float(i) * 0.53 + 0.31;
			float round_about = float(i) * 0.9 + hash(vec2(seed, 2.0)) * 0.7;
			vec2 from = vec2(cos(round_about) * aspect, sin(round_about)) * 1.45;
			float head = pow(clamp((pull - PULL_FROM - float(i) * PULL_STAGGER * 0.8) / PULL_TAKES, 0.0, 1.0), 2.0);
			float tail = pow(clamp((pull - PULL_FROM - float(i) * PULL_STAGGER * 0.8 - TAIL_LAG) / PULL_TAKES, 0.0, 1.0), 2.0);
			ribbon(col, a, from, curve_bend(from, egg, seed), egg, tail, head, 0.024, seed, time, heart);
		}
	}

	// The six sunk in it, staring at your aim, and what they weep. The egg takes them:
	// each turns to look at it, then is hauled in on its own ribbon, one by one, wide
	// open until it is at the egg's mouth.
	float blink_clock = time * 0.31;

	for (int i = 0; i < 6; i++) {
		if (ring[i] > 0.01) {
			float across = (float(i % 3) - 1.0) * 0.72;
			float side = i < 3 ? -1.0 : 1.0;
			float rest = mix(1.42, 0.84, curse) * (1.0 - across * across * 0.5);
			float seed = float(i) * 0.37 + 0.11;
			vec2 at = vec2((across + (side > 0.0 ? 0.12 : -0.12)) * aspect, side * min(rest + 0.11, 0.84));
			float set_off = PULL_FROM + float((i * 5 + 2) % 6) * PULL_STAGGER;
			float head = pow(clamp((pull - set_off) / PULL_TAKES, 0.0, 1.0), 2.2);
			float tail = pow(clamp((pull - set_off - TAIL_LAG) / PULL_TAKES, 0.0, 1.0), 2.4);
			// From out past the edge of your sight, through where the eye sat, to the egg.
			vec2 root = at * 1.5;
			vec2 bend = curve_bend(root, egg, seed);
			float root_part = 0.2;
			float head_along = mix(root_part, 1.0, head);

			if (head > 0.0) {
				ribbon(col, a, root, bend, egg, mix(0.0, 1.0, tail), head_along, 0.1, seed, time, heart);
			}

			// Blinking when it likes, not together; held open once the egg has it.
			float blink = 1.0 - smoothstep(0.965, 0.99, noise(vec2(blink_clock * 9.0, seed * 31.0)));
			blink = mix(blink, 1.0, smoothstep(0.0, 0.2, taken));
			float size = 0.12 + hash(vec2(seed, 5.0)) * 0.035;
			float presence = smoothstep(0.1, 0.4, curse) * max(remains, step(0.0001, head) * step(head, 0.985));
			float loose = smoothstep(0.0, 0.1, head);
			vec2 eye_at = mix(at, curve_at(root, bend, egg, head_along), loose);
			vec2 toward = normalize(2.0 * (1.0 - head_along) * (bend - root) + 2.0 * head_along * (egg - bend));
			float angle = atan(toward.y, toward.x);
			angle = (angle > PI * 0.5 ? angle - PI : (angle < -PI * 0.5 ? angle + PI : angle)) * loose;
			float cos_turn = cos(angle);
			float sin_turn = sin(angle);
			mat2 turned = mat2(vec2(cos_turn, -sin_turn), vec2(sin_turn, cos_turn));
			float shrink = mix(1.0, 0.42, smoothstep(0.45, 1.0, head));
			vec2 eye_here = eye_at + turned * (a - eye_at) / shrink;
			float shut = 1.0 - smoothstep(0.78, 0.97, head);
			vec2 twitch = vec2(noise(vec2(time * 1.7, seed * 11.0)), noise(vec2(time * 1.7, seed * 17.0))) * 0.2 - 0.1;
			vec2 look = turned * mix(-normalize(at) + twitch, normalize(egg - eye_at), smoothstep(0.0, 0.2, taken));
			float shed = tears_from(a, at, size, seed, time) * ring[i] * (1.0 - loose);
			col = mix(col, BLOOD, shed * presence * 0.95);
			// Set deep: the meat dark around it.
			float pit = 1.0 - smoothstep(0.9, 1.5, length((eye_here - eye_at) / vec2(size * 1.35, size * 0.95)));
			col *= 1.0 - pit * 0.55 * presence;
			vec4 eye = sunk_eye(eye_here, eye_at, size, ring[i] * blink * shut, look, seed, time);
			col = mix(col, eye.rgb, eye.a * presence);
		}
	}

	// Whoever is looking at you, from where they are: a patch of meat, an eye in it.
	for (int i = 0; i < 4; i++) {
		if (gazers[i].z > 0.01) {
			vec2 at = vec2((gazers[i].x * 2.0 - 1.0) * aspect, gazers[i].y * 2.0 - 1.0);
			float size = 0.075 + stared * 0.05;
			float seed = float(i) * 0.61 + 0.2;
			float patch_edge = length((a - at) / vec2(size * 1.55, size * 1.1)) + (noise(a * 11.0 + seed) - 0.5) * 0.35;
			float body = 1.0 - smoothstep(0.86, 0.9, patch_edge);
			float line = (1.0 - smoothstep(0.92, 0.97, patch_edge)) * (1.0 - body);
			col = mix(col, INK, line * gazers[i].z);
			col = mix(col, meat_at(a * 2.0, 1.0, time, stared), body * gazers[i].z);
			vec4 eye = sunk_eye(a, at, size, gazers[i].z, -normalize(at + vec2(0.0001)), seed, time);
			col = mix(col, eye.rgb, eye.a * gazers[i].z);
		}
	}

	// The egg bursts: a small splash of what it took, out from the hand and gone, and
	// a sliver or two of its shell.
	if (dispel > 0.001) {
		float from_it = length(from_egg);
		float lobes = noise(way_from_egg * 4.0 + 7.0) * 0.6 + noise(way_from_egg * 11.0 + 3.0) * 0.4;
		float splash_to = (0.04 + lobes * lobes * 0.3) * smoothstep(0.0, 0.5, dispel);
		float hollowed = splash_to * smoothstep(0.25, 0.85, dispel);
		float splash = (1.0 - smoothstep(splash_to - 0.012, splash_to, from_it)) * smoothstep(hollowed - 0.012, hollowed, from_it);
		col = mix(col, mix(INK, LIVER, lobes * 0.5), splash * (1.0 - smoothstep(0.55, 0.95, dispel)));
		col += vec3(1.0, 0.82, 0.55) * exp(-from_it * from_it * 90.0) * pow(max(1.0 - dispel * 4.0, 0.0), 2.0) * 0.5;
		float angle = atan(from_egg.y, from_egg.x);
		float slice = floor((angle + PI) / TAU * 14.0);
		float luck = hash(vec2(slice, 4.0));
		float along = from_it - dispel * (0.14 + luck * 0.34);
		float aside = (fract((angle + PI) / TAU * 14.0) - 0.5) * from_it * 0.44;
		float sliver = 1.0 - smoothstep(0.002, 0.006, length(vec2(along * 0.7, aside)));
		col = mix(col, PALE, sliver * step(0.7, hash(vec2(slice, 8.0))) * (1.0 - smoothstep(0.5, 1.0, dispel)));
	}

	// After: a moment's relief.
	col = mix(col, col * 1.09 + vec3(0.007, 0.005, 0.002), relief);

	// Clean: a dry broken line of ward colour, gone as it runs out.
	if (cleansed > 0.001) {
		float to_frame = 1.0 - max(abs(p.x), abs(p.y));
		float width = 0.004 + noise(a * 9.0 + time * 0.2) * 0.012;
		float band = 1.0 - smoothstep(width, width + 0.006, to_frame);
		float gaps = smoothstep(0.62 - cleansed * 0.4, 0.72 - cleansed * 0.4, noise(a * 3.0 + vec2(time * 0.05, 0.0)));
		col = mix(col, WARD, band * gaps * 0.32);
	}

	COLOR = vec4(col, 1.0);
}
