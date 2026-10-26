shader_type canvas_item;
// The chosen archetype takes the whole screen on its way into the game, in
// its own paint and its own story, held in steps like the cards' effects,
// and ends in the dark.
// Derivé strikes: the screen cracks from his card, shockwaves race out,
// sparks fly, the blast floods red, and soot closes in with ember edges.
// Thaumaturge's eye shuts: violet smoke closes like lids onto his card, its
// gold lid line rayed like his emblem, glyphs and gold dust adrift in it.
// Factotum's drafting table: a grid, rules, a protractor and compass circles
// draw in, ink blots bleed and spatter, then the page turns over into the dark.
uniform sampler2D noise : filter_linear, repeat_enable;
uniform int kind = 0;
uniform float progress = 0.0;
uniform float fps = 9.0;
// The chosen card's centre (screen UV) and the screen's width over height.
uniform vec2 origin = vec2(0.5);
uniform float aspect = 1.7778;

const vec3 DARK = vec3(0.02, 0.035, 0.047);

float hash(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

float tex(vec2 p) {
	return texture(noise, p).r;
}

// Coverage of d < 0, with a torn, bristled edge.
float paint(float d, vec2 m, vec2 dir, vec2 boil, float rough) {
	vec2 along = vec2(dot(m, dir), dot(m, vec2(-dir.y, dir.x)));
	float streak = tex(vec2(along.x * 0.5, along.y * 10.0) + boil);
	float e = d + (tex(m * 1.8 + boil) - 0.5) * rough + (streak - 0.5) * rough * 0.5;
	return 1.0 - smoothstep(-0.004, 0.004, e);
}

// A thin inked or painted line along d = 0.
float stroke(float d, float width, vec2 m, vec2 boil) {
	float wob = (tex(m * 7.0 + boil) - 0.5) * width * 0.8;
	return 1.0 - smoothstep(width * 0.6, width * 1.2, abs(d) + wob);
}

// Oil laid in strokes along `dir`: two pigments, the bristles' streaks, and
// each stroke's own light.
vec3 strokes(vec3 a, vec3 b, vec2 m, vec2 dir, vec2 boil) {
	vec2 along = vec2(dot(m, dir), dot(m, vec2(-dir.y, dir.x)));
	float body = tex(vec2(along.x * 0.8, along.y * 4.0) + boil * 0.2);
	float streak = tex(vec2(along.x * 0.4, along.y * 22.0) + boil * 0.4);
	vec3 c = mix(a, b, smoothstep(0.3, 0.7, body));
	return c * (0.8 + streak * 0.4);
}

void over(inout vec4 acc, vec3 c, float a) {
	acc.rgb = c * a + acc.rgb * (1.0 - a);
	acc.a = a + acc.a * (1.0 - a);
}

float segment(vec2 p, vec2 a, vec2 b) {
	vec2 ab = b - a;
	float h = clamp(dot(p - a, ab) / dot(ab, ab), 0.0, 1.0);
	return length(p - a - ab * h);
}

void derive(inout vec4 acc, vec2 m, vec2 r, float rad, float ang, vec2 dir, float p, vec2 boil) {
	vec3 oxblood = vec3(0.43, 0.12, 0.1);
	vec3 vermilion = vec3(0.86, 0.27, 0.12);
	vec3 orange = vec3(0.95, 0.52, 0.2);
	vec3 ochre = vec3(0.98, 0.8, 0.45);
	// The screen cracks from the hit: jagged spokes and a web between them.
	float web = 1e3;
	float reach = smoothstep(0.0, 0.14, p) * 1.6;
	for (int i = 0; i < 11; i++) {
		float fi = float(i);
		float a = (fi + hash(fi) * 0.6) / 11.0 * TAU;
		vec2 d = vec2(cos(a), sin(a));
		float along = dot(r, d);
		float side = dot(r, vec2(-d.y, d.x)) + (tex(vec2(along * 0.9, fi * 0.37)) - 0.5) * 0.09 * along;
		web = min(web, along > 0.0 && along < reach ? abs(side) : 1e3);
	}
	for (int i = 0; i < 3; i++) {
		float ring_r = 0.12 + float(i) * 0.15 + hash(float(i) + 4.0) * 0.04;
		float jag = (tex(vec2(ang * 9.0, float(i) * 0.3)) - 0.5) * 0.04;
		web = min(web, rad < reach ? abs(rad - ring_r + jag) : 1e3);
	}
	over(acc, DARK, (1.0 - smoothstep(0.004, 0.009, web)) * 0.85);
	over(acc, oxblood, (1.0 - smoothstep(0.009, 0.02, web)) * 0.45);
	over(acc, orange, 1.0 - smoothstep(0.0015, 0.0035, web));
	// The blast: radial strokes from the hit, the gaps closing as it floods.
	float spokes = 26.0;
	float k = floor(ang * spokes);
	float len = (0.4 + 1.6 * hash(k)) * smoothstep(0.08, 0.3, p);
	float across = (fract(ang * spokes) - 0.5) / spokes * TAU * rad;
	float width = mix(0.012, 0.6, smoothstep(0.2, 0.62, p)) * (0.4 + rad);
	float d_blast = max(abs(across) - width * (1.0 - clamp(rad / max(len, 0.001), 0.0, 1.0)) - 0.006, rad - len);
	vec3 blast = mix(strokes(vermilion, orange, m, dir, boil), strokes(oxblood, vermilion, m, dir, boil), smoothstep(0.1, 0.9, rad));
	over(acc, blast, paint(d_blast, m, dir, boil, 0.03));
	// Shockwaves: three painted rings racing out, ochre, oxblood, orange.
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		float ring_r = smoothstep(0.03 + fi * 0.07, 0.55 + fi * 0.1, p) * 2.0;
		float band = 0.03 * (1.0 - p) + 0.006;
		float d_ring = abs(rad - ring_r) - band;
		vec3 col = i == 1 ? oxblood : (i == 0 ? ochre : orange);
		over(acc, col, paint(d_ring, m, vec2(-dir.y, dir.x), boil, 0.015) * (1.0 - smoothstep(0.5, 0.85, p)) * step(0.01, ring_r));
	}
	// One white-hot frame at the hit.
	float spikes = pow(abs(sin(ang * TAU * 6.0 + 0.4)), 6.0) * 0.6 + pow(abs(sin(ang * TAU * 4.0)), 10.0) * 0.4;
	over(acc, ochre, (p > 0.04 && p < 0.1) ? paint(rad - (0.05 + 0.22 * spikes), m, dir, boil, 0.02) : 0.0);
	// Sparks flung out along the spokes, streaked by their speed.
	float lanes = 64.0;
	float lane = floor(ang * lanes);
	float lane_mid = (fract(ang * lanes) - 0.5) / lanes * TAU * rad;
	float at = (0.15 + hash(lane * 1.7)) * smoothstep(0.03, 0.7, p) * 2.0;
	float spark = max(abs(lane_mid) - 0.003, abs(rad - at) - 0.045 * (0.5 + hash(lane)));
	over(acc, mix(ochre, orange, hash(lane + 2.0)), paint(spark, m, dir, boil, 0.004) * step(0.5, hash(lane + 9.0)) * (1.0 - smoothstep(0.6, 0.8, p)));
	// Soot closes in from the edges, onto his card, its front still smouldering.
	float front = mix(2.2, -0.2, smoothstep(0.55, 1.0, p)) - rad + (tex(m * 1.3 + boil * 0.1) - 0.5) * 0.15;
	over(acc, orange, (1.0 - smoothstep(0.0, 0.03, abs(front))) * step(0.56, p) * 0.9);
	over(acc, DARK, paint(front, m, dir, boil, 0.06));
}

void thaumaturge(inout vec4 acc, vec2 m, vec2 r, float p, vec2 boil, float step_n) {
	vec3 deep = vec3(0.15, 0.07, 0.28);
	vec3 violet = vec3(0.42, 0.22, 0.72);
	vec3 lilac = vec3(0.7, 0.54, 0.92);
	vec3 gold = vec3(0.88, 0.74, 0.46);
	vec3 pale_gold = vec3(0.98, 0.9, 0.68);
	// The eye: an almond around his card whose lids close.
	float shut = smoothstep(0.0, 0.88, p);
	float half_w = mix(1.7, 0.55, shut);
	float open_h = mix(0.85, 0.0, shut);
	vec2 warp = vec2(tex(m * 0.35 + boil * 0.05), tex(m * 0.35 + 0.5 + boil * 0.05)) - 0.5;
	float lid = open_h * max(1.0 - (r.x * r.x) / (half_w * half_w), 0.0);
	float outside = abs(r.y + warp.y * 0.12) - lid;
	// Smoke beyond the lids, flowing along them, darker the further out.
	vec2 flow = normalize(vec2(1.0, -r.y * r.x * 0.6) + 1e-4);
	vec3 smoke = mix(deep, violet, smoothstep(0.3, 0.75, tex(m * 0.5 + warp * 0.3)));
	smoke *= 0.85 + tex(vec2(dot(m, flow) * 0.6, dot(m, vec2(-flow.y, flow.x)) * 7.0) + boil * 0.3) * 0.3;
	smoke = mix(smoke, lilac, smoothstep(0.66, 0.9, tex(m * 0.8 + warp * 0.5)) * 0.35);
	smoke = mix(smoke, DARK, smoothstep(0.15, 0.7, outside));
	over(acc, smoke, paint(-outside, m + warp * 0.2, flow, boil, 0.08));
	// Glyphs adrift in the smoke, turning in held steps.
	vec2 cell = floor(m / 0.11);
	vec2 local = (fract(m / 0.11) - 0.5) * 0.11 - (vec2(hash(cell.x * 1.3 + cell.y * 9.1), hash(cell.x * 4.7 + cell.y * 2.3)) - 0.5) * 0.06;
	float pick = floor(hash(cell.x * 7.0 + cell.y * 13.0) * 6.0);
	float spin = step_n * 0.15 + hash(cell.x + cell.y * 3.0) * 6.0;
	local = vec2(local.x * cos(spin) - local.y * sin(spin), local.x * sin(spin) + local.y * cos(spin));
	float glyph = 1e3;
	if (pick < 1.0) {
		glyph = abs(length(local) - 0.014) - 0.002;
	} else if (pick < 2.0) {
		glyph = min(max(abs(local.x) - 0.002, abs(local.y) - 0.016), max(abs(local.y) - 0.002, abs(local.x) - 0.01));
	} else if (pick < 3.0) {
		glyph = max(length(local) - 0.015, -(length(local - vec2(0.006, 0.0)) - 0.012));
	}
	float in_smoke = smoothstep(0.02, 0.12, outside) * (1.0 - smoothstep(0.4, 0.7, outside));
	over(acc, gold, (1.0 - smoothstep(0.0, 0.002, glyph)) * in_smoke * 0.75);
	// Gold dust.
	vec2 dust_cell = floor(m * 60.0);
	float dust = step(0.985, hash(dust_cell.x * 3.1 + dust_cell.y * 7.7 + floor(step_n / 3.0))) * (1.0 - smoothstep(0.2, 0.42, length(fract(m * 60.0) - 0.5)));
	over(acc, pale_gold, dust * in_smoke * 0.8);
	// The lid line, painted gold, with rays like his emblem's.
	over(acc, gold, stroke(outside, 0.005, m, boil) * step(abs(r.x), half_w) * (1.0 - smoothstep(0.9, 1.0, p)));
	float rays = 1.0 - smoothstep(0.0025, 0.005, abs(fract(r.x / 0.06 + 0.5) - 0.5) * 0.06);
	float ray_band = step(0.0, outside) * (1.0 - smoothstep(0.0, 0.035 + 0.02 * hash(floor(r.x / 0.06)), outside));
	over(acc, gold, rays * ray_band * step(abs(r.x), half_w * 0.9) * (1.0 - shut * 0.6));
	// Shut: a gold slit, then nothing.
	float slit = 1.0 - smoothstep(0.002, 0.006, abs(r.y));
	over(acc, pale_gold, slit * step(abs(r.x), half_w) * smoothstep(0.84, 0.9, p) * (1.0 - smoothstep(0.92, 0.98, p)));
}

void factotum(inout vec4 acc, vec2 m, vec2 o, vec2 r, float rad, float p, vec2 boil) {
	vec3 night = vec3(0.06, 0.13, 0.28);
	vec3 ink = vec3(0.12, 0.3, 0.6);
	vec3 wash = vec3(0.3, 0.52, 0.82);
	vec3 pale = vec3(0.76, 0.86, 1.0);
	vec3 paper = vec3(0.9, 0.86, 0.76);
	// A drafting grid comes up, faint, over the whole screen.
	vec2 g = abs(fract(m / 0.06) - 0.5) * 0.06;
	float grid = 1.0 - smoothstep(0.0006, 0.0016, min(g.x, g.y));
	over(acc, pale, grid * smoothstep(0.0, 0.2, p) * 0.18);
	// Rules across the screen, drawn in quick succession.
	float lines = 1e3;
	for (int i = 0; i < 7; i++) {
		float fi = float(i);
		float drawn = clamp(p * 4.0 - fi * 0.25, 0.0, 1.0);
		if (i % 2 == 0) {
			float y = 0.12 + 0.76 * hash(fi + 3.0);
			lines = m.x < drawn * aspect ? min(lines, abs(m.y - y)) : lines;
		} else {
			float x = (0.1 + 0.8 * hash(fi + 7.0)) * aspect;
			lines = m.y < drawn ? min(lines, abs(m.x - x)) : lines;
		}
	}
	// Compass circles swung about his card, with the compass's arm.
	float swing = smoothstep(0.05, 0.35, p);
	float ang = atan(r.y, r.x);
	float round_way = ang / TAU + 0.5;
	lines = min(lines, round_way < swing ? abs(rad - 0.32) : 1e3);
	lines = min(lines, round_way < swing * 0.8 ? abs(rad - 0.48) : 1e3);
	lines = min(lines, segment(m, o, o + vec2(cos(swing * TAU - PI), sin(swing * TAU - PI)) * 0.48));
	// A protractor over him: its arc and its degrees, every fifth one longer.
	float over_him = step(r.y, 0.0) * step(-ang / PI, swing);
	float tenth = -ang / PI * 36.0;
	float tick = abs(fract(tenth) - 0.5) / 36.0 * PI * rad;
	float tick_len = abs(fract(tenth / 5.0 + 0.1) - 0.5) < 0.1 ? 0.06 : 0.035;
	lines = min(lines, over_him * step(0.62 - tick_len, rad) * step(rad, 0.62) > 0.5 ? tick : 1e3);
	lines = min(lines, over_him > 0.5 ? abs(rad - 0.62) : 1e3);
	over(acc, pale, stroke(lines, 0.0022, m, boil) * (1.0 - smoothstep(0.62, 0.8, p)));
	// Ink blots bleed out and merge: watercolour edges, darker where the
	// pigment pooled, lighter at their hearts, with spatter thrown ahead.
	float blot = 1e3;
	vec2 flow = vec2(0.7, 0.7);
	float spatter = 0.0;
	for (int i = 0; i < 6; i++) {
		float fi = float(i);
		vec2 at = i == 0 ? o : vec2(hash(fi * 3.1) * aspect, hash(fi * 5.7));
		float grow = smoothstep(0.12 + fi * 0.06, 0.95, p) * (0.95 + hash(fi) * 0.35);
		float d_i = length(m - at) - grow;
		if (d_i < blot) {
			blot = d_i;
			flow = normalize(m - at + 1e-4);
		}
		vec2 dc = floor((m - at) / 0.035);
		vec2 dl = (fract((m - at) / 0.035) - 0.5) * 0.035;
		float drop_r = 0.004 + 0.006 * hash(dc.x * 5.3 + dc.y * 1.9 + fi);
		float lucky = step(0.93, hash(dc.x * 2.7 + dc.y * 8.1 + fi * 3.0));
		float ahead = step(0.0, d_i) * (1.0 - smoothstep(0.0, 0.18, d_i)) * step(0.01, grow);
		spatter = max(spatter, lucky * ahead * (1.0 - smoothstep(drop_r - 0.002, drop_r, length(dl))));
	}
	float d = blot * 0.6 + (tex(m * 1.2 + boil * 0.1) - 0.5) * 0.12;
	float depth = clamp(-d / 0.12, 0.0, 1.0);
	// Watercolour: pigment pooling unevenly, granulating, its tide-line dark.
	vec3 col = mix(ink, wash, smoothstep(0.35, 0.8, tex(m * 0.6 + boil * 0.05)) * 0.6);
	col = mix(col, night, smoothstep(0.4, 0.9, tex(m * 1.7 + 0.3)) * 0.55);
	col *= 0.88 + step(0.62, tex(m * 9.0 + boil * 0.2)) * 0.12 - step(0.7, tex(m * 13.0 + 0.5)) * 0.18;
	col = mix(night * 0.55, col, smoothstep(0.0, 0.1, depth));
	over(acc, col, paint(d, m, flow, boil, 0.04));
	over(acc, night, spatter);
	// The page turns over, right to left, onto the dark beneath it.
	float turn = smoothstep(0.5, 0.97, p);
	float fold = mix(aspect + 0.35, -0.6, turn) + (m.y - 0.5) * 0.25;
	float past = m.x - fold;
	float flap_w = min(0.3, (aspect + 0.35 - fold) * 0.5);
	over(acc, DARK, step(0.0, past));
	// Its back: cream paper, ruled, shaded toward the fold, casting a shadow.
	float on_flap = step(-flap_w, past) * step(past, 0.0);
	vec3 back = paper * mix(0.62, 1.0, smoothstep(0.0, -flap_w, past));
	back = mix(back, ink, (1.0 - smoothstep(0.0008, 0.002, abs(fract(m.y / 0.035) - 0.5) * 0.035)) * 0.25);
	float shade = (1.0 - smoothstep(0.0, 0.06, -flap_w - past)) * step(past, -flap_w) * 0.5;
	over(acc, vec3(0.0), shade * step(0.001, turn));
	over(acc, back, on_flap * step(0.001, turn));
}

void fragment() {
	float step_n = floor(TIME * fps);
	vec2 boil = vec2(hash(step_n), hash(step_n + 17.0)) * 0.5;
	// Held frames: the transition itself advances in the same steps.
	float p = floor(progress * 14.0) / 14.0;
	vec2 m = vec2(UV.x * aspect, UV.y);
	vec2 o = vec2(origin.x * aspect, origin.y);
	vec2 r = m - o;
	float rad = length(r);
	vec2 dir = normalize(r + 1e-4);
	float ang = atan(r.y, r.x) / TAU + 0.5;
	vec4 acc = vec4(0.0);
	if (kind == 0) {
		derive(acc, m, r, rad, ang, dir, p, boil);
	} else if (kind == 1) {
		thaumaturge(acc, m, r, p, boil, step_n);
	} else {
		factotum(acc, m, o, r, rad, p, boil);
	}
	vec3 rgb = acc.a > 0.0001 ? acc.rgb / acc.a : vec3(0.0);
	// The very end is the dark everywhere, so the loading cover follows cleanly.
	float a = max(acc.a, smoothstep(0.92, 1.0, progress));
	rgb = mix(rgb, DARK, smoothstep(0.92, 1.0, progress));
	COLOR = vec4(rgb, a);
}
