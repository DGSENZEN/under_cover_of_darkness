// The schools' looks for a special option's swipe (talk_swipe.gdshader;
// the spec's "Magic options get their school's shader"): `school` is 1 + its
// index in DialogueBook.SCHOOLS (0: none, the plain paint). Each one paints
// the swipe's colour itself, over the same bristle mask and reveal, and moves
// by TIME alone, so the box sets nothing every frame. `warm` is the chosen
// option: each school's own chosen treatment, never the gold wash.
//   1 obsidian  black volcanic glass with depth, fine fracture lines, a cold
//               narrow glint sliding across every 2.5 s (a second, quicker one
//               and a thin cold rim while chosen)
//   2 copal     resin smoke drifting through amber-grey
//   3 seance    a pale ghost-light pulsing from the middle
//   4 nahual    three claw strokes raked through dark hide
//   5 lumen     a blue-white arc flickering along it
//   6 relic     gilt leaf laid in flakes, a slow sheen over them
// Needs hash, vnoise, swipe_size, seed and warm from the shader including it.

vec2 school_hash2(vec2 p) {
	return vec2(hash(p), hash(p + vec2(17.31, 5.17)));
}

// Distance (in cells) to the nearest Voronoi edge round `x`, and that cell.
vec3 school_voronoi(vec2 x) {
	vec2 n = floor(x);
	vec2 f = fract(x);
	vec2 near_r = vec2(0.0);
	vec2 near_g = vec2(0.0);
	float best = 8.0;

	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 r = g + school_hash2(n + g) - f;
			float d = dot(r, r);

			if (d < best) {
				best = d;
				near_r = r;
				near_g = g;
			}
		}
	}

	float edge = 8.0;

	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = near_g + vec2(float(i), float(j));
			vec2 r = g + school_hash2(n + g) - f;

			if (dot(near_r - r, near_r - r) > 0.00001) {
				edge = min(edge, dot(0.5 * (near_r + r), normalize(r - near_r)));
			}
		}
	}

	return vec3(edge, n + near_g);
}

float school_fbm(vec2 p) {
	return 0.55 * vnoise(p) + 0.3 * vnoise(p * 2.03 + 7.1) + 0.15 * vnoise(p * 4.1 + 2.9);
}

// A narrow band slanted across the swipe, crossing it in the first half of
// every `period` s and resting the other half; `offset` shifts its phase.
float school_glint(vec2 p, float period, float offset, float width) {
	float s = (p.x + (swipe_size.y * 0.5 - p.y) * 0.9) / max(swipe_size.x, 1.0);
	float t = fract(TIME / period + offset);
	float d = (s - (-0.15 + 2.6 * t)) / width;
	return 0.55 * exp(-d * d) + 0.45 * exp(-d * d * 9.0);
}

// How near p is to the top of the bristle band (a lit lip of the stroke).
float school_lip(vec2 p) {
	float d = (p.y - (BAND_TOP * swipe_size.y + 1.6)) / 1.1;
	return exp(-d * d);
}

vec3 school_obsidian(vec2 p, vec2 uv) {
	float h = swipe_size.y;
	// The glass: near black, a violet-blue depth below, faint flow banding
	// (obsidian's frozen streaks) and a soft sheen on its upper curve.
	vec3 deep = vec3(0.012, 0.012, 0.022);
	vec3 face = vec3(0.045, 0.05, 0.068);
	float curve = smoothstep(0.95, 0.12, uv.y);
	vec3 colour = mix(deep, face, curve * 0.8);
	float flow = sin(p.y * 0.55 + school_fbm(p / vec2(90.0, 9.0) + seed) * 7.0);
	colour += vec3(0.018, 0.02, 0.03) * smoothstep(0.6, 1.0, flow);
	colour += vec3(0.05, 0.06, 0.08) * exp(-pow((uv.y - 0.3) / 0.12, 2.0)) * (0.6 + 0.4 * vnoise(p / vec2(60.0, 4.0)));

	// Fine fracture lines: Voronoi edges in long cells, sparse, hair-thin.
	vec2 cell = vec2(26.0, 13.0);
	vec3 v = school_voronoi(p / cell + seed * 3.1);
	float edge_px = v.x * min(cell.x, cell.y);
	float crack = (1.0 - smoothstep(0.25, 0.85, edge_px)) * smoothstep(0.42, 0.62, vnoise(p / vec2(55.0, 16.0) + 4.0));
	// Each facet tilts a little, so some face the light more than others.
	colour += vec3(0.012, 0.014, 0.02) * hash(v.yz);

	// The glint: a cold narrow band every 2.5 s, a second quicker one while
	// chosen, flaring the fracture lines it crosses.
	float offset = fract(seed * 0.37);
	float g = school_glint(p, 2.5, offset, 0.03);

	if (warm) {
		g = max(g, school_glint(p, 1.25, offset + 0.5, 0.022));
	}

	vec3 cold = vec3(0.72, 0.84, 1.0);
	colour += vec3(0.3, 0.36, 0.46) * crack * (0.35 + 1.6 * g);
	colour += cold * g * (warm ? 0.5 : 0.28);

	// Chosen: the glass lifts, and a thin cold rim lights the stroke's lip.
	if (warm) {
		colour += vec3(0.02, 0.026, 0.04);
		colour += cold * school_lip(p) * (0.5 + 0.5 * g);
		colour += cold * 0.18 * exp(-pow((p.y - (BAND_BOTTOM * h - 1.4)) / 1.0, 2.0));
	}

	return colour;
}

vec3 school_copal(vec2 p, vec2 uv) {
	vec3 colour = vec3(0.13, 0.1, 0.075) * (0.85 + 0.3 * vnoise(p / vec2(40.0, 3.0)));
	float speed = warm ? 1.7 : 1.0;
	vec2 drift = vec2(-TIME * 14.0, TIME * 2.5) * speed;
	float smoke = school_fbm((p + drift) / vec2(46.0, 12.0) + seed);
	smoke = smoothstep(0.35, 0.8, smoke);
	colour += vec3(0.62, 0.42, 0.2) * smoke * (warm ? 0.55 : 0.32);
	colour += vec3(0.2, 0.18, 0.16) * school_fbm((p - drift * 0.6) / vec2(80.0, 20.0)) * 0.35;

	if (warm) {
		colour += vec3(0.9, 0.6, 0.28) * school_lip(p) * 0.45;
	}

	return colour;
}

vec3 school_seance(vec2 p, vec2 uv) {
	vec3 colour = vec3(0.06, 0.07, 0.075);
	float pulse = 0.5 + 0.5 * sin(TIME * (warm ? 3.4 : 2.0) + seed * 1.7);
	float middle = exp(-pow((uv.y - 0.5) / 0.28, 2.0)) * exp(-pow((uv.x - 0.45) / 0.5, 2.0));
	float wisp = school_fbm(p / vec2(70.0, 10.0) + vec2(TIME * 0.15, 0.0));
	colour += vec3(0.62, 0.74, 0.7) * middle * (0.12 + 0.3 * pulse) * (0.6 + 0.6 * wisp);

	if (warm) {
		colour += vec3(0.75, 0.88, 0.84) * school_lip(p) * (0.25 + 0.3 * pulse);
	}

	return colour;
}

vec3 school_nahual(vec2 p, vec2 uv) {
	float w = swipe_size.x;
	float h = swipe_size.y;
	vec3 colour = vec3(0.09, 0.06, 0.045) * (0.8 + 0.4 * vnoise(p / vec2(12.0, 2.0)));
	float claws = 0.0;
	float wet = 0.0;

	// Three strokes raked down-right across the middle, tapering at both ends;
	// a brightness runs along them every 3 s (quicker while chosen).
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		float x0 = w * (0.3 + 0.07 * fi + 0.05 * hash(vec2(fi, 31.0)));
		float x1 = x0 + w * 0.2;
		float t = clamp((p.x - x0) / (x1 - x0), 0.0, 1.0);
		float y = mix(h * 0.18, h * 0.84, t) + fi * 1.2;
		float taper = sin(t * 3.14159) * step(x0, p.x) * step(p.x, x1);
		float line = (1.0 - smoothstep(0.3, 1.2 * taper + 0.3, abs(p.y - y))) * taper;
		claws = max(claws, line);
		float run = fract(TIME / (warm ? 1.4 : 3.0) + fi * 0.12);
		wet = max(wet, line * exp(-pow((t - run * 1.4 + 0.2) / 0.12, 2.0)));
	}

	colour = mix(colour, vec3(0.62, 0.5, 0.38), claws * 0.8);
	colour += vec3(0.55, 0.16, 0.1) * wet * 0.8;

	if (warm) {
		colour += vec3(0.8, 0.55, 0.38) * school_lip(p) * 0.35;
	}

	return colour;
}

vec3 school_lumen(vec2 p, vec2 uv) {
	float h = swipe_size.y;
	vec3 colour = vec3(0.025, 0.04, 0.08);
	// The arc jumps to a new path a dozen times a second and is lit only
	// about half of those, brighter and steadier while chosen.
	float tick = floor(TIME * (warm ? 18.0 : 11.0));
	float lit = step(warm ? 0.25 : 0.5, hash(vec2(tick, 41.0)));
	float y = h * 0.5 + (school_fbm(vec2(p.x / 22.0, tick * 1.37)) - 0.5) * h * 0.6;
	float d = abs(p.y - y);
	float arc = exp(-d * d / 0.8) + 0.35 * exp(-d * d / 18.0);
	colour += vec3(0.68, 0.82, 1.0) * arc * lit * (warm ? 0.9 : 0.6);
	colour += vec3(0.1, 0.16, 0.3) * lit * 0.25;

	if (warm) {
		colour += vec3(0.7, 0.84, 1.0) * school_lip(p) * 0.35;
	}

	return colour;
}

vec3 school_relic(vec2 p, vec2 uv) {
	vec3 colour = vec3(0.085, 0.062, 0.035) * (0.85 + 0.3 * vnoise(p / vec2(30.0, 3.0)));
	// Gilt leaf in flakes: some Voronoi cells laid, their edges torn dark.
	vec3 v = school_voronoi(p / vec2(16.0, 9.0) + seed * 2.3);
	float laid = step(0.45, hash(v.yz)) * smoothstep(0.04, 0.12, v.x);
	vec3 gilt = vec3(0.78, 0.6, 0.28) * (0.65 + 0.45 * vnoise(p / vec2(8.0, 3.0) + 9.0));
	float s = (p.x + (swipe_size.y * 0.5 - p.y) * 1.4) / max(swipe_size.x, 1.0);
	float sheen = exp(-pow((s - fract(TIME / (warm ? 2.2 : 4.0) + seed * 0.21) * 1.6 + 0.3) / 0.12, 2.0));
	colour = mix(colour, gilt * (0.8 + 0.7 * sheen), laid * (warm ? 0.95 : 0.7));

	if (warm) {
		colour += vec3(1.0, 0.82, 0.45) * school_lip(p) * 0.35;
	}

	return colour;
}

vec3 school_paint(int which, vec2 p, vec2 uv) {
	if (which == 1) {
		return school_obsidian(p, uv);
	} else if (which == 2) {
		return school_copal(p, uv);
	} else if (which == 3) {
		return school_seance(p, uv);
	} else if (which == 4) {
		return school_nahual(p, uv);
	} else if (which == 5) {
		return school_lumen(p, uv);
	}

	return school_relic(p, uv);
}
