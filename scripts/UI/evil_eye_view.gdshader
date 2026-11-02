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
//   - dispel: the egg, 0..1. A status being lifted: a soft pale pulse goes out from
//     the middle, the eyes snap shut, and all of it dissolves away.
//   - cleansed: a dry broken line of ward colour at the frame's edge, for as long as
//     no gaze can stick.

uniform float stared = 0.0;
uniform float curse = 0.0;
uniform float dispel = 0.0;
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

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 a = vec2(p.x * aspect, p.y);
	float out_from_middle = length(p);
	float edges = smoothstep(0.5, 1.2, out_from_middle);
	float time = TIME;
	float heart = beat(time * mix(1.0, 1.7, curse));

	// The edges of your view double, and sway: your aim is not your own.
	float strength = curse * (1.0 - dispel);
	vec2 slip = vec2(sin(time * 0.9), cos(time * 0.63)) * 0.014 * strength * edges;
	vec3 sharp = texture(screen_tex, SCREEN_UV).rgb;
	vec3 doubled = (texture(screen_tex, SCREEN_UV + slip).rgb + texture(screen_tex, SCREEN_UV - slip * 0.7).rgb) * 0.5;
	vec3 col = mix(sharp, doubled, edges * strength * 0.85);
	col = mix(col, col * vec3(1.05, 0.6, 0.6), edges * strength * 0.8);

	// Veins reaching in ahead of the flesh, as the stare builds.
	float reach = max(stared * 0.62, curse * 0.9) * (1.0 - dispel) * (1.0 - leaving * (1.0 - curse));

	if (reach > 0.001) {
		float vein = reaching(a, 0.009 + reach * 0.004) * smoothstep(0.3, 0.6, strokes(a * 1.2));
		float limit = smoothstep(1.5 - reach * 0.8, 1.68 - reach * 0.8, out_from_middle);
		col = mix(col, ARTERY * (0.75 + heart * 0.3), vein * limit * 0.7);
	}

	// How much of it remains here: all of it, or dissolved by the dispel, unevenly,
	// by the brush, or thinning as it leaves by itself.
	float dissolve = 0.0;
	float dissolve_edge = 0.0;

	if (dispel > 0.001) {
		float grain = strokes(a * 0.8) * 0.55 + noise(a * 5.0) * 0.45;
		float line = dispel * 1.3 - 0.15;
		dissolve = smoothstep(grain - 0.05, grain + 0.05, line);
		dissolve_edge = (1.0 - smoothstep(0.0, 0.016, abs(grain - line))) * (1.0 - smoothstep(0.6, 0.9, dispel));
	}

	float remains = (1.0 - dissolve) * (1.0 - leaving * (1.0 - curse));

	// The flesh, closing in from above and below.
	float closing = max(curse, stared * 0.28);

	if (closing > 0.001) {
		float bristle = strokes(vec2(p.x * 1.7 + 0.3, p.y * 0.25)) * 0.6 + strokes(vec2(p.x * 4.3, p.y * 0.5 + 0.7)) * 0.4;
		float past = flesh_past(p, closing, time, heart, bristle);

		// Its shadow on your sight, cast down and in: it lies on top of the view.
		float shadow_past = flesh_past(p - vec2(0.012, -sign(p.y) * 0.05 + 0.01), closing, time, heart, bristle);
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
			// Where it is going, a thin pale edge as it lifts away.
			col = mix(col, PALE, dissolve_edge * body * 0.45);
		}
	}

	// The six sunk in it, staring at your aim, and what they weep.
	float blink_clock = time * 0.31;

	for (int i = 0; i < 6; i++) {
		if (ring[i] > 0.01) {
			float across = (float(i % 3) - 1.0) * 0.72;
			float side = i < 3 ? -1.0 : 1.0;
			float rest = mix(1.42, 0.84, curse) * (1.0 - across * across * 0.5);
			float seed = float(i) * 0.37 + 0.11;
			vec2 at = vec2((across + (side > 0.0 ? 0.12 : -0.12)) * aspect, side * min(rest + 0.11, 0.84));
			// Blinking when it likes, not together.
			float blink = 1.0 - smoothstep(0.965, 0.99, noise(vec2(blink_clock * 9.0, seed * 31.0)));
			float size = 0.12 + hash(vec2(seed, 5.0)) * 0.035;
			float presence = smoothstep(0.1, 0.4, curse);
			// The egg takes it: it snaps shut first of all.
			float snapped = 1.0 - smoothstep(0.0, 0.3, dispel);
			vec2 twitch = vec2(noise(vec2(time * 1.7, seed * 11.0)), noise(vec2(time * 1.7, seed * 17.0))) * 0.2 - 0.1;
			float shed = tears_from(a, at, size, seed, time) * ring[i];
			col = mix(col, BLOOD, shed * presence * 0.95 * remains);
			// Set deep: the meat dark around it.
			float pit = 1.0 - smoothstep(0.9, 1.5, length((a - at) / vec2(size * 1.35, size * 0.95)));
			col *= 1.0 - pit * 0.55 * presence * remains;
			vec4 eye = sunk_eye(a, at, size, ring[i] * blink * snapped, -normalize(at) + twitch, seed, time);
			col = mix(col, eye.rgb, eye.a * presence * remains * (1.0 - smoothstep(0.22, 0.4, dispel)));
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

	// The egg: one soft pale pulse, out from the middle and gone.
	if (dispel > 0.001) {
		float front = dispel * 1.9;
		float pulse = 1.0 - smoothstep(0.0, 0.34, abs(out_from_middle - front));
		col = mix(col, PALE, pulse * pulse * (1.0 - dispel) * 0.34);
	}

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
