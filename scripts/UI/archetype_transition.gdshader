shader_type canvas_item;
// The chosen archetype takes the screen on its way into the game by acting
// on the painting itself, in muted oils with a canvas grain, held in steps
// like the cards' effects, and ends in the dark.
// Derivé, instinct: three heartbeats, each sooner, as the world narrows
// onto his card (the edges blur toward him, drain and redden, and veins creep
// in from the borders, throbbing with the beats); then one blow: the painting
// smears and caves, dark cracks spider out along it, a few drops of blood
// follow, and the pieces fall away into the dark.
// Thaumaturge, the glamour: the city twists around his card and drains to
// violet; ritual circles, script and sigils are etched around him as smoke
// lids close, and inky, foreign eyes open and blink in the smoke, watching him.
// Factotum, the study: the painting is printed as a cyanotype, a plan of
// itself, ruled by a few construction lines; then indigo watercolour floods
// it into the dark.
uniform sampler2D screen : hint_screen_texture, repeat_disable, filter_linear_mipmap;
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

vec2 hash2(vec2 p) {
	return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}

float tex(vec2 p) {
	return texture(noise, p).r;
}

float luma(vec3 c) {
	return dot(c, vec3(0.3, 0.59, 0.11));
}

// The painting beneath, at a point given in aspect space.
vec3 under(vec2 m) {
	return textureLod(screen, clamp(vec2(m.x / aspect, m.y), vec2(0.001), vec2(0.999)), 0.0).rgb;
}

// Oil laid in strokes along `dir`: the bristles' streaks and their light.
float streaks(vec2 m, vec2 dir, vec2 boil) {
	vec2 along = vec2(dot(m, dir), dot(m, vec2(-dir.y, dir.x)));
	return tex(vec2(along.x * 0.5, along.y * 18.0) + boil * 0.4);
}

// A ragged painted edge: coverage of d < 0.
float edge(float d, vec2 m, vec2 boil, float rough) {
	float e = d + (tex(m * 1.6 + boil) - 0.5) * rough + (tex(m * 7.0 + boil * 2.0) - 0.5) * rough * 0.35;
	return 1.0 - smoothstep(-0.006, 0.006, e);
}

vec2 turn2(vec2 v, float a) {
	return vec2(v.x * cos(a) - v.y * sin(a), v.x * sin(a) + v.y * cos(a));
}

vec3 derive(vec2 m, vec2 o, float p, vec2 boil, float step_n) {
	vec3 blood = vec3(0.26, 0.03, 0.03);
	vec3 vein_dark = vec3(0.3, 0.035, 0.04);
	vec3 vein_lit = vec3(0.72, 0.1, 0.08);
	vec3 plaster = vec3(0.5, 0.46, 0.42);
	vec2 light = normalize(vec2(-0.6, -0.8));
	// Instinct first: three heartbeats, each sooner than the last.
	float beat = exp(-pow((p - 0.04) / 0.022, 2.0)) + 0.9 * exp(-pow((p - 0.17) / 0.02, 2.0)) + 0.8 * exp(-pow((p - 0.27) / 0.018, 2.0));
	// Tunnel vision: the world narrows onto his card. Beyond the focus it
	// blurs toward him, drains, darkens and reddens; each beat squeezes it.
	float focus = mix(1.5, 0.32, smoothstep(0.0, 0.42, p)) - beat * 0.06;
	// Then one blow, a hook thrown from his card across the screen.
	float hit = step(0.42, p);
	float pp = clamp((p - 0.42) / 0.58, 0.0, 1.0);
	vec2 blow = normalize(vec2(o.x < aspect * 0.5 ? 1.0 : -1.0, -0.18));
	vec2 side = vec2(-blow.y, blow.x);
	vec2 shake = vec2(sin(TIME * 61.0), cos(TIME * 47.0)) * 0.011 * hit * (1.0 - smoothstep(0.0, 0.16, pp));
	vec2 q = o + (m - o) / (1.0 + 0.025 * beat + 0.03 * hit * exp(-pp * 10.0)) + shake;
	// The canvas gives under it: a dent pulled toward the hit.
	float dent_r = 0.38;
	vec2 dr = q - o;
	float u = clamp(length(dr) / dent_r, 0.0, 1.0);
	vec2 ddir = normalize(dr + 1e-4);
	float depth = hit * smoothstep(0.0, 0.05, pp) * 0.05;
	q -= ddir * depth * (1.0 - u) * (1.0 - u) * 0.9;
	// Plaster shards: dark cracks spider out along the blow; the pieces fall.
	vec2 cell_scale = vec2(5.5);
	vec2 g = floor(q * cell_scale);
	vec2 f = fract(q * cell_scale);
	float near = 8.0;
	float second = 8.0;
	vec2 id = vec2(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 c = vec2(float(x), float(y));
			vec2 pt = c + hash2(g + c) * 0.9;
			float d = length(pt - f);
			if (d < near) {
				second = near;
				near = d;
				id = g + c;
			} else if (d < second) {
				second = d;
			}
		}
	}
	vec2 centre = (id + hash2(id) * 0.9) / cell_scale;
	vec2 rel = centre - o;
	float reach = smoothstep(0.0, 0.25, pp) * 2.4 * hit;
	float broken = step(length(vec2(dot(rel, blow) * 0.6, dot(rel, side))), reach);
	float seam = second - near;
	float crack = 1.0 - smoothstep(0.012, 0.04, seam);
	vec2 away = normalize(mix(normalize(rel + 1e-4), blow, 0.6));
	float loose = broken * smoothstep(0.03, 0.25, pp);
	float drop_at = 0.4 + hash(id.x * 7.1 + id.y * 3.3) * 0.35;
	float fall = pow(max(pp - drop_at, 0.0), 2.0) * 9.0;
	float spin = fall * (hash(id.y * 5.3 + id.x) - 0.5) * 4.0 * broken;
	vec2 moved = centre + turn2(q - centre, spin) - away * 0.012 * loose - vec2(0.0, fall) * broken;
	// Beyond the focus the eye stops looking: the painting smears toward him.
	vec2 r = m - o;
	float rad = length(r);
	float outer = smoothstep(focus * 0.75, focus + 0.25, rad);
	float smear = hit * (1.0 - smoothstep(0.0, 0.25, pp));
	vec3 col = vec3(0.0);
	float weight = 0.0;
	for (int k = 0; k < 6; k++) {
		float w = 1.0 / (1.0 + float(k));
		vec2 at = moved - blow * float(k) * 0.01 * smear;
		at = o + (at - o) * (1.0 - float(k) * 0.012 * outer);
		col += under(at) * w;
		weight += w;
	}
	col /= weight;
	float gone = broken * smoothstep(0.0, 0.08, fall - 0.25);
	col = mix(col, vec3(luma(col)) * vec3(1.1, 0.72, 0.66), outer * 0.75);
	col *= 1.0 - outer * (0.35 + beat * 0.25);
	// The dent's light, kept low: its far wall lit, its near wall in shadow.
	float slope = depth * 2.0 * (1.0 - u) / dent_r;
	col *= 1.0 + clamp(-dot(ddir, light) * slope * 6.0, -0.4, 0.3);
	// The shards have thickness, but no shine: edges dark, each a shade apart.
	vec2 within = normalize(f - (hash2(id) * 0.9 + (id - g)) + 1e-4);
	col *= 1.0 + (1.0 - smoothstep(0.0, 0.06, seam)) * loose * 0.4 * dot(within, light);
	col *= mix(1.0, 0.85 + 0.25 * hash(id.x * 1.9 + id.y * 6.1), loose);
	col = mix(col, DARK, crack * broken * 0.92);
	// A little plaster dust where it broke.
	float dusty = (1.0 - smoothstep(0.0, 0.18, seam)) * broken * smoothstep(0.05, 0.2, pp) * (1.0 - smoothstep(0.45, 0.8, pp));
	col = mix(col, plaster, dusty * smoothstep(0.55, 0.85, tex(m * 2.4 + vec2(TIME * 0.02, -pp * 0.3))) * 0.4);
	// A few drops of blood follow the blow.
	vec2 along = vec2(dot(r, blow), dot(r, side));
	vec2 cell = floor(along / 0.026);
	vec2 local = (fract(along / 0.026) - 0.5) * 0.026 - vec2(pp * 0.015, 0.0);
	float stretch = 1.0 + 2.5 * hash(cell.x * 3.7 + cell.y * 1.3);
	float drop = 1.0 - smoothstep(0.0, 0.002, length(vec2(local.x / stretch, local.y)) - 0.0032 * (0.6 + hash(cell.x + cell.y * 5.1)));
	float cone = step(0.0, along.x) * step(abs(along.y), 0.04 + along.x * 0.16) * step(along.x, 1.3 * smoothstep(0.0, 0.12, pp));
	col = mix(col, blood, drop * cone * step(0.9, hash(cell.x * 2.3 + cell.y * 7.9)) * hit * 0.85);
	// Veins creep in from the borders as the world narrows, tapering as they
	// reach in, branching finer, throbbing with each beat.
	vec2 rv = m - vec2(aspect * 0.5, 0.5);
	float edge_d = min(min(m.x, aspect - m.x), min(m.y, 1.0 - m.y));
	float creep = mix(0.02, 0.3, smoothstep(0.02, 0.42, p)) + beat * 0.025;
	float va = atan(rv.y, rv.x) / TAU;
	float veins = 0.0;
	for (int k = 0; k < 2; k++) {
		// One vessel per lane, wavering along its own length as it reaches in.
		float count = k == 0 ? 22.0 : 58.0;
		float lane_v = va * count + float(k) * 0.37;
		float li = floor(lane_v);
		float waver = (tex(vec2(edge_d * 1.6, li * 0.173 + float(k) * 0.5)) - 0.5) * 0.7;
		float apart = abs(fract(lane_v) - 0.5 - waver * 0.5) / count * TAU * length(rv);
		float reach_v = creep * (k == 0 ? 0.55 + 0.45 * hash(li) : 0.2 + 0.35 * hash(li + 40.0));
		float taper = clamp(1.0 - edge_d / max(reach_v, 1e-3), 0.0, 1.0);
		float width = (k == 0 ? 0.0065 : 0.0035) * pow(taper, 0.7);
		veins = max(veins, (1.0 - smoothstep(width * 0.5, width + 0.0004, apart)) * step(0.001, taper) * (k == 0 ? 1.0 : 0.75));
	}
	col = mix(col, mix(vein_dark, vein_lit, beat * 0.8), veins * 0.9);
	// Each beat pushes a faint red tide in from the edges.
	float edge_near = 1.0 - smoothstep(0.0, creep + 0.12, edge_d);
	col = mix(col, col * vec3(1.25, 0.55, 0.5), edge_near * (0.25 + beat * 0.4));
	// The beats close the dark in around the edges, and the end takes the rest.
	col *= 1.0 - beat * 0.3 * smoothstep(0.4, 1.4, rad);
	return mix(col, DARK, gone);
}

// A clean line of half-width `w` along d = 0, anti-aliased to the pixel.
float aa_line(float d, float w) {
	float f = max(fwidth(d), 1e-5);
	return 1.0 - smoothstep(w - f, w + f, d);
}

// A ritual circle's linework: two rings and a star of `points` joined every
// `skip`, drawn round as `reveal` goes 0..1. Distance to the nearest line.
float ritual(vec2 r, float radius, float rot, float reveal, int points, int skip) {
	float round_way = fract((atan(r.y, r.x) - rot) / TAU);
	float d = 1e3;
	if (round_way < reveal) {
		d = min(d, abs(length(r) - radius));
		d = min(d, abs(length(r) - radius * 0.84));
	}
	for (int k = 0; k < 9; k++) {
		if (k >= points) {
			break;
		}
		if (float(k) / float(points) < reveal) {
			float a0 = rot + float(k) * TAU / float(points);
			float a1 = rot + float(k + skip) * TAU / float(points);
			vec2 v0 = vec2(cos(a0), sin(a0)) * radius * 0.84;
			vec2 v1 = vec2(cos(a1), sin(a1)) * radius * 0.84;
			vec2 ab = v1 - v0;
			d = min(d, length(r - v0 - ab * clamp(dot(r - v0, ab) / dot(ab, ab), 0.0, 1.0)));
		}
	}
	return d;
}

// Sigils etched in a band at `radius`: one of six marks per sector, each a
// small composite glyph. Returns the distance (in glyph units) and the sector.
float sigils(vec2 r, float radius, float rot, float sectors, float size, out float sector) {
	float a = atan(r.y, r.x) - rot;
	float s = floor(fract(a / TAU) * sectors);
	sector = s;
	float mid = (s + 0.5) / sectors * TAU + rot;
	vec2 c = vec2(cos(mid), sin(mid)) * radius;
	vec2 t = vec2(-sin(mid), cos(mid));
	vec2 g = vec2(dot(r - c, t), dot(r - c, vec2(cos(mid), sin(mid)))) / size;
	float pick = floor(hash(s * 3.7 + radius * 11.0) * 6.0);
	float stem = max(abs(g.x) - 0.1, abs(g.y) - 0.85);
	if (pick < 1.0) {
		return min(abs(length(g) - 0.6) - 0.1, length(g) - 0.16);
	} else if (pick < 2.0) {
		return min(min(stem, max(abs(g.y - 0.3) - 0.1, abs(g.x) - 0.5)), max(abs(g.y + 0.4) - 0.1, abs(g.x) - 0.3));
	} else if (pick < 3.0) {
		return min(stem, abs(length(g - vec2(0.0, 1.1)) - 0.25) - 0.08);
	} else if (pick < 4.0) {
		return min(max(length(g) - 0.7, -(length(g - vec2(0.3, 0.0)) - 0.55)), length(g + vec2(0.45, 0.0)) - 0.12);
	} else if (pick < 5.0) {
		vec2 k = abs(g);
		return min(abs(k.x + k.y - 0.7) - 0.09, stem * 1.0 + 0.4);
	}
	return min(max(abs(g.x - 0.35 * sign(g.y)) - 0.1, abs(g.y) - 0.8), abs(g.y) - 0.1 + step(0.55, abs(g.x)) * 10.0);
}

vec3 thaumaturge(vec2 m, vec2 o, float p, vec2 boil, float step_n) {
	vec3 violet = vec3(0.34, 0.24, 0.58);
	vec3 deep = vec3(0.07, 0.04, 0.12);
	vec3 gold = vec3(0.8, 0.67, 0.42);
	vec3 pale_gold = vec3(0.98, 0.9, 0.66);
	vec3 lilac = vec3(0.72, 0.62, 0.95);
	vec2 r = m - o;
	float rad = length(r);
	// The ritual runs smoothly in real time; only the smoke keeps its boil.
	float t = TIME;
	// The glamour: the painting twists around his card and is drawn in.
	float twist = pow(smoothstep(0.0, 1.0, p), 1.4) * 3.2 * exp(-rad * 1.1);
	float pull = 1.0 + 0.45 * smoothstep(0.0, 1.0, p) * exp(-rad * 0.8);
	float a = atan(r.y, r.x) + twist;
	vec3 col = under(o + vec2(cos(a), sin(a)) * rad * pull);
	// Its colours drain to a violet monochrome.
	col = mix(col, luma(col) * vec3(0.62, 0.52, 0.9) * 1.15, smoothstep(0.05, 0.6, p));
	// Smoke lids close over it, soft, darker the further out.
	float shut = smoothstep(0.08, 0.9, p);
	float half_w = mix(1.9, 0.5, shut);
	float open_h = mix(1.0, 0.0, shut);
	vec2 warp = vec2(tex(m * 0.4 + boil * 0.05), tex(m * 0.4 + 0.5 + boil * 0.05)) - 0.5;
	float lid = open_h * max(1.0 - (r.x * r.x) / (half_w * half_w), 0.0);
	float outside = abs(r.y + warp.y * 0.1) - lid;
	vec2 flow = normalize(vec2(1.0, -r.y * r.x * 0.6) + 1e-4);
	float body = smoothstep(0.2, 0.8, tex(m * 0.6 + warp * 0.4 + vec2(step_n * 0.004, 0.0)));
	vec3 smoke = mix(deep, violet, body * 0.7) * (0.8 + streaks(m + warp * 0.3, flow, boil) * 0.3);
	smoke = mix(smoke, col * 0.35, 0.3);
	smoke = mix(smoke, DARK, smoothstep(0.1, 0.55, outside));
	float in_smoke = 1.0 - smoothstep(-0.03, 0.05, -outside + (tex(m * 2.5 + boil) - 0.5) * 0.06);
	col = mix(col, smoke, in_smoke);
	col += vec3(0.55, 0.45, 0.8) * (1.0 - smoothstep(0.0, 0.03, abs(outside))) * 0.18 * (1.0 - shut);
	// Ritual circles, etched as they are drawn: the great circle closing with
	// the lids (a seven-pointed star, an outer band of sigils, an inner band of
	// runes turning against it, a ring of studs), five lesser circles orbiting
	// it, turning against it, a faint outer ring of ticks, and a seal at the heart.
	float fade = 1.0 - smoothstep(0.78, 0.9, p);
	float great = mix(0.55, 0.2, shut);
	float turn = t * 0.27;
	float reveal = smoothstep(0.03, 0.3, p);
	float lines = ritual(r, great, turn, reveal, 7, 3);
	float sector_out;
	float marks = sigils(r, great * 0.92, turn, 26.0, great * 0.035, sector_out) * great * 0.035;
	float sector_in;
	float runes = sigils(r, great * 0.62, -turn * 1.7, 18.0, great * 0.026, sector_in) * great * 0.026;
	runes = max(runes, -(abs(length(r) - great * 0.62) - great * 0.06));
	float studs = length(vec2(fract((atan(r.y, r.x) + turn) / TAU * 42.0) - 0.5, 0.0) * TAU * rad / 42.0 + vec2(0.0, rad - great * 0.72)) - great * 0.008;
	float seal = min(abs(rad - great * 0.14), ritual(r, great * 0.12, -turn * 3.0, reveal, 3, 1));
	float outer_ticks = abs(length(r) - great * 1.9);
	outer_ticks = min(outer_ticks, max(abs(fract((atan(r.y, r.x) + turn * 0.5) / TAU * 72.0) - 0.5) * 0.02, abs(length(r) - great * 1.86) - great * 0.03));
	float lesser = 1e3;
	for (int i = 0; i < 5; i++) {
		float fi = float(i);
		float at = fi / 5.0 * TAU - turn * 0.6;
		vec2 c = vec2(cos(at), sin(at)) * great * 1.45;
		float spin_in = -turn * 1.5 + fi;
		lesser = min(lesser, ritual(r - c, great * 0.3, spin_in, smoothstep(0.08 + fi * 0.04, 0.32 + fi * 0.04, p), i % 2 == 0 ? 3 : 4, 1));
		lesser = min(lesser, abs(length(r - c) - great * 0.06));
	}
	// The sigils wake one after another round the band, and the runes pulse
	// against them; sparks run round the great ring; gold motes orbit it.
	float wake_out = 1.0 - smoothstep(0.0, 0.12, fract(t * 0.7 - sector_out / 26.0));
	float wake_in = 0.5 + 0.5 * sin(t * 5.0 + sector_in * 1.3);
	float shimmer = 0.88 + 0.12 * sin(t * 7.0 + sector_out * 1.7);
	vec3 glow = vec3(0.0);
	col = mix(col, gold, aa_line(lines, 0.0014) * 0.8 * fade);
	glow += gold * exp(-max(lines, 0.0) / 0.006) * 0.12;
	float mark = aa_line(marks, 0.0);
	col = mix(col, mix(gold, pale_gold, wake_out), mark * reveal * (0.55 + 0.4 * wake_out) * shimmer * fade);
	glow += pale_gold * exp(-max(marks, 0.0) / 0.008) * wake_out * 0.35 * reveal;
	col = mix(col, lilac, aa_line(runes, 0.0) * reveal * (0.35 + 0.4 * wake_in) * fade);
	col = mix(col, gold, aa_line(studs, 0.0) * reveal * 0.6 * fade);
	col = mix(col, pale_gold, aa_line(seal, 0.0012) * reveal * 0.7 * fade);
	col = mix(col, lilac, aa_line(lesser, 0.0011) * 0.6 * fade);
	glow += lilac * exp(-max(lesser, 0.0) / 0.006) * 0.08;
	col = mix(col, lilac, aa_line(outer_ticks, 0.0009) * reveal * 0.3 * fade);
	for (int k = 0; k < 3; k++) {
		float spark_a = t * (1.6 + float(k) * 0.4) * (k == 1 ? -1.0 : 1.0) + float(k) * 2.1;
		vec2 spark = vec2(cos(spark_a), sin(spark_a)) * (k == 1 ? great * 0.84 : great);
		float sd = length(r - spark);
		glow += pale_gold * (exp(-sd / 0.006) * 0.9 + exp(-sd / 0.03) * 0.2) * reveal;
	}
	vec2 orbit = turn2(r, -t * 0.25);
	vec2 mote_cell = floor(orbit * 40.0);
	float mote = step(0.97, hash(mote_cell.x * 3.1 + mote_cell.y * 7.7)) * (1.0 - smoothstep(0.15, 0.35, length(fract(orbit * 40.0) - 0.5)));
	mote *= (1.0 - smoothstep(0.0, great * 0.4, abs(rad - great * 1.2))) * (0.5 + 0.5 * sin(t * 6.0 + mote_cell.x));
	glow += pale_gold * mote * 0.7 * reveal;
	// Finer work: a medallion at each star point, a band of crawling script
	// ruled above and below, a dotted orbit, and spokes out to the lesser
	// circles, a diamond on each and a glyph turning in each circle.
	float medal = 1e3;
	for (int k = 0; k < 7; k++) {
		float va = turn + float(k) * TAU / 7.0;
		vec2 vd = vec2(cos(va), sin(va));
		vec2 vp = r - vd * great * 0.84;
		medal = min(medal, abs(length(vp) - great * 0.06));
		medal = min(medal, max(abs(dot(vp, vd)) - great * 0.035, abs(dot(vp, vec2(-vd.y, vd.x))) - great * 0.004));
	}
	col = mix(col, pale_gold, aa_line(medal, 0.0012) * reveal * (0.75 + 0.15 * sin(t * 5.0)) * fade);
	float sa = fract((atan(r.y, r.x) - turn * 0.4 + t * 0.05) / TAU) * 160.0;
	float sc = floor(sa);
	float sx = (fract(sa) - 0.5) / 160.0 * TAU * rad;
	float script = max(abs(sx) - great * 0.0022, abs(rad - great * 1.03 - (hash(sc * 3.1) - 0.5) * great * 0.012) - great * (0.008 + 0.018 * hash(sc * 1.7)));
	script = min(script, length(vec2(sx, rad - great * 1.062)) - great * 0.004 + step(0.6, hash(sc * 5.3)) * 10.0);
	col = mix(col, gold, aa_line(script, 0.0) * step(sc / 160.0, reveal) * 0.6 * fade);
	col = mix(col, gold, aa_line(min(abs(rad - great * 0.995), abs(rad - great * 1.075)), 0.0007) * reveal * 0.5 * fade);
	float orbit_a = fract((atan(r.y, r.x) + t * 0.3) / TAU * 90.0) - 0.5;
	float dots = length(vec2(orbit_a / 90.0 * TAU * rad, rad - great * 1.22)) - great * 0.006;
	col = mix(col, lilac, aa_line(dots, 0.0) * reveal * 0.6 * fade);
	float spokes = 1e3;
	float inner_glyphs = 1e3;
	for (int i = 0; i < 5; i++) {
		float fi = float(i);
		float at = fi / 5.0 * TAU - turn * 0.6;
		vec2 dirc = vec2(cos(at), sin(at));
		vec2 perp = vec2(-dirc.y, dirc.x);
		float out_d = dot(r, dirc);
		spokes = min(spokes, max(abs(dot(r, perp)) - 0.0006, max(great * 1.08 - out_d, out_d - great * 1.15)));
		vec2 mid = r - dirc * great * 1.115;
		spokes = min(spokes, abs(abs(dot(mid, dirc)) + abs(dot(mid, perp)) - great * 0.022));
		float sector_l;
		inner_glyphs = min(inner_glyphs, sigils(r - dirc * great * 1.45, 0.0001, -turn * 2.0 + fi * 1.3, 1.0, great * 0.05, sector_l) * great * 0.05);
	}
	col = mix(col, gold, aa_line(spokes, 0.0007) * reveal * 0.55 * fade);
	col = mix(col, pale_gold, aa_line(inner_glyphs, 0.0) * reveal * (0.6 + 0.3 * wake_in) * fade);
	col += glow * fade;
	// Eyes open in the smoke, sixteen of them and no two alike. Each sits in
	// a blot of ink that bleeds slowly and drips; its lids are a true almond,
	// the upper one shadowing the eye and the lower one wet. The eye is a
	// glossy ball of dark ink, the iris fibrous bone-lilac, darker at its rim
	// with a lighter collarette, the pupil foreign (a slit, a goat's bar,
	// twins, or rings) and widening as it opens, with a window's highlight.
	// Some open upright; shut, each stays an ink slash; open, they look at him.
	for (int i = 0; i < 16; i++) {
		float fi = float(i);
		float ang = fi / 16.0 * TAU + hash(fi) * 0.7;
		float far = 0.36 + hash(fi + 3.0) * 0.55;
		vec2 c = o + vec2(cos(ang) * far * 1.55, sin(ang) * far * 0.62);
		float size = 0.04 + pow(hash(fi + 5.0), 1.5) * 0.09;
		vec2 lq = (m - c) / size;
		vec2 toward = normalize(o - c);
		if (hash(fi + 11.0) > 0.7) {
			lq = vec2(lq.y, -lq.x);
			toward = vec2(toward.y, -toward.x);
		}
		if (abs(lq.x) < 2.8 && lq.y > -2.0 && lq.y < 4.0) {
			float ph = fract(t * (0.3 + hash(fi + 7.0) * 0.45) + hash(fi + 9.0));
			float there = smoothstep(0.08 + fi * 0.022, 0.2 + fi * 0.022, p) * fade;
			float open = smoothstep(0.0, 0.2, ph) * (1.0 - smoothstep(0.62, 0.8, ph));
			open = open * open * (3.0 - 2.0 * open) * there;
			float bleed = (tex(lq * 0.2 + fi * 0.37 + vec2(t * 0.03, 0.0)) - 0.5) * 0.1;
			// The ink, backlit by a sickly lilac so it reads against the smoke.
			float back = 1.0 - smoothstep(0.0, 0.9, length(lq * vec2(0.65, 1.0)) - 0.6 + bleed);
			col = mix(col, vec3(0.5, 0.42, 0.62), back * 0.45 * there);
			float halo = 1.0 - smoothstep(0.0, 0.4, length(lq * vec2(0.72, 1.0)) - 0.95 + bleed);
			float lane = floor(lq.x * 1.7 + hash(fi));
			float drip_w = 1.0 - smoothstep(0.03, 0.08, abs(fract(lq.x * 1.7 + hash(fi)) - 0.5));
			float drip = step(0.0, lq.y) * drip_w * (1.0 - smoothstep(0.0, 0.6 + 2.4 * hash(lane + fi * 3.0) * there, lq.y)) * step(abs(lq.x), 0.8);
			col = mix(col, vec3(0.015, 0.01, 0.02), max(halo * 0.8, drip * 0.9) * there);
			// The lids: an almond, the upper arched higher.
			float shape = max(1.0 - lq.x * lq.x, 0.0);
			float upper = max(open, 0.05) * 0.6 * shape;
			float lower = max(open, 0.05) * 0.42 * shape;
			float d_lid = (lq.y < 0.0 ? -lq.y - upper : lq.y - lower) + bleed * 0.4;
			float fw = max(fwidth(d_lid), 1e-4) * 1.2;
			float inside = (1.0 - smoothstep(-fw, fw, d_lid)) * step(abs(lq.x), 1.0);
			col = mix(col, vec3(0.012, 0.008, 0.016), inside * there);
			float seen = inside * smoothstep(0.03, 0.12, open);
			// The ball, shaded round, darkened under the upper lid.
			vec2 ir = lq - toward * 0.22 * vec2(1.0, 0.5) * open;
			float il = length(ir);
			float lid_shadow = smoothstep(-upper, -upper + 0.3, lq.y);
			vec3 eye = mix(vec3(0.02, 0.015, 0.03), vec3(0.17, 0.12, 0.22), 1.0 - smoothstep(0.0, 1.0, length(lq * vec2(0.9, 1.5))));
			// The iris: fibres at two scales, a dark limbal rim, a pale collarette.
			float fwi = max(fwidth(il), 1e-4) * 1.2;
			float iris = 1.0 - smoothstep(0.4 - fwi, 0.4 + fwi, il);
			float ang_i = atan(ir.y, ir.x);
			// Fibres run outward from the pupil, so they are long round and short across.
			float fibres = mix(tex(vec2(ang_i * 2.4 + fi, il * 0.5)), tex(vec2(ang_i * 7.0 + fi * 0.43, il * 1.1)), 0.45);
			vec3 iris_col = mix(vec3(0.34, 0.29, 0.42), vec3(0.9, 0.86, 0.94), smoothstep(0.38, 0.72, fibres));
			iris_col *= mix(1.0, 0.4, smoothstep(0.27, 0.4, il));
			iris_col += vec3(0.22, 0.2, 0.28) * (1.0 - smoothstep(0.0, 0.04, abs(il - 0.17)));
			eye = mix(eye, iris_col, iris);
			eye *= mix(0.3, 1.0, lid_shadow);
			// The pupil, foreign and black, widening as it opens, its edge faintly lit.
			float pick = floor(hash(fi + 13.0) * 4.0);
			float dilate = mix(0.7, 1.15, open);
			float d_pupil;
			if (pick < 1.0) {
				d_pupil = abs(ir.x) - 0.05 * dilate * max(1.0 - pow(ir.y / 0.34, 2.0), 0.0) + max(abs(ir.y) - 0.34, 0.0);
			} else if (pick < 2.0) {
				d_pupil = length(max(abs(ir) - vec2(0.16, 0.03) * dilate, 0.0)) - 0.02;
			} else if (pick < 3.0) {
				d_pupil = min(length(ir - vec2(0.11, 0.0)) - 0.075 * dilate, length(ir + vec2(0.11, 0.02)) - 0.06 * dilate);
			} else {
				d_pupil = min(length(ir) - 0.07 * dilate, abs(il - 0.25) - 0.012);
			}
			float fwp = max(fwidth(d_pupil), 1e-4) * 1.2;
			float pupil = (1.0 - smoothstep(-fwp, fwp, d_pupil)) * iris;
			eye = mix(eye, vec3(0.0), pupil);
			eye += vec3(0.5, 0.45, 0.6) * (1.0 - smoothstep(0.0, 0.03, abs(d_pupil))) * iris * 0.25 * lid_shadow;
			// Highlights: a window, and a small second glint.
			float window = 1.0 - smoothstep(0.0, 0.02, length(max(abs(ir - vec2(-0.15, -0.16)) - vec2(0.05, 0.032), 0.0)) - 0.008);
			float glint = 1.0 - smoothstep(0.0, 0.02, length(ir - vec2(0.13, 0.1)) - 0.01);
			eye += vec3(1.0, 0.97, 0.95) * (window * 0.8 + glint * 0.35) * lid_shadow;
			col = mix(col, eye, seen);
			col += vec3(0.85, 0.8, 0.95) * 0.1 * exp(-il * 3.5) * open * inside;
			// The lower lid's wet line, and the upper lid's heavier ink.
			float wet = (1.0 - smoothstep(0.0, 0.05, abs(lq.y - lower))) * step(0.0, lq.y) * step(abs(lq.x), 0.9);
			col = mix(col, vec3(0.62, 0.56, 0.74), wet * smoothstep(0.03, 0.12, open) * 0.5 * there);
			float upper_rim = (1.0 - smoothstep(0.0, 0.09, abs(-lq.y - upper))) * step(lq.y, 0.0) * step(abs(lq.x), 0.98);
			col = mix(col, vec3(0.01, 0.006, 0.012), upper_rim * there * 0.9);
		}
	}
	// Shut: a gold glint along the slit, then nothing.
	float slit = (1.0 - smoothstep(0.0015, 0.005, abs(r.y))) * step(abs(r.x), half_w * 0.8);
	col = mix(col, gold * 1.2, slit * smoothstep(0.84, 0.88, p) * (1.0 - smoothstep(0.9, 0.96, p)));
	return col;
}

vec3 factotum(vec2 m, vec2 o, float p, vec2 boil) {
	vec3 ink = vec3(0.1, 0.13, 0.22);
	vec3 indigo = vec3(0.12, 0.18, 0.34);
	vec3 wash = vec3(0.28, 0.38, 0.56);
	vec2 r = m - o;
	float rad = length(r);
	vec3 col = under(m);
	// The study: the painting printed as a cyanotype, a plan of itself in
	// Prussian blue on paper, sweeping out from his card.
	vec2 uv = vec2(m.x / aspect, m.y);
	float tone = smoothstep(0.02, 0.42, luma(textureLod(screen, uv, 0.5).rgb));
	float grain = tex(m * 9.0 + 0.3);
	vec3 prussian = vec3(0.05, 0.11, 0.24);
	vec3 bleached = vec3(0.74, 0.8, 0.84);
	vec3 drawing = mix(prussian, bleached, pow(tone, 0.85));
	drawing *= 0.9 + grain * 0.14;
	// The print's uneven wash, darker where the solution pooled.
	drawing = mix(drawing, prussian * 0.8, smoothstep(0.55, 0.85, tex(m * 0.7 + 0.4)) * 0.35);
	float sweep = smoothstep(0.0, 0.45, p) * 2.2;
	float drawn = edge(rad - sweep, m, boil, 0.22);
	col = mix(col, drawing, drawn);
	// A few construction lines, ruled and faint.
	float rule = 1e3;
	rule = min(rule, m.x < smoothstep(0.1, 0.4, p) * aspect ? abs(m.y - o.y + 0.27) : 1e3);
	rule = min(rule, m.y < smoothstep(0.15, 0.45, p) ? abs(m.x - o.x - 0.22) : 1e3);
	rule = min(rule, (atan(r.y, r.x) / TAU + 0.5) < smoothstep(0.12, 0.42, p) ? abs(rad - 0.36) : 1e3);
	col = mix(col, bleached * 1.1, (1.0 - smoothstep(0.0008, 0.0022, rule)) * 0.8 * drawn);
	// Indigo watercolour floods in from his card and two more drops,
	// granulating, with dark tide lines, until it is all dark.
	float flood = 1e3;
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		vec2 at = i == 0 ? o : vec2(hash(fi * 3.1 + 1.0) * aspect, hash(fi * 5.7 + 2.0));
		flood = min(flood, length(m - at) - smoothstep(0.35 + fi * 0.06, 0.97, p) * (1.25 + hash(fi) * 0.3));
	}
	float df = flood * 0.6 + (tex(m * 1.1 + boil * 0.08) - 0.5) * 0.12;
	float depth = clamp(-df / 0.15, 0.0, 1.0);
	vec3 water = mix(wash, indigo, smoothstep(0.35, 0.75, tex(m * 0.8 + 0.2)));
	water *= 0.85 + step(0.6, tex(m * 11.0 + boil * 0.2)) * 0.12 - step(0.72, tex(m * 15.0)) * 0.15;
	water = mix(water, DARK, smoothstep(0.1, 1.0, depth));
	water = mix(ink * 0.6, water, smoothstep(0.0, 0.08, depth));
	col = mix(col, water, edge(df, m, boil, 0.05));
	return col;
}

void fragment() {
	float step_n = floor(TIME * fps);
	vec2 boil = vec2(hash(step_n), hash(step_n + 17.0)) * 0.5;
	// Held frames: the transition itself advances in steps.
	float p = floor(progress * 16.0) / 16.0;
	vec2 m = vec2(UV.x * aspect, UV.y);
	vec2 o = vec2(origin.x * aspect, origin.y);
	vec3 col;
	if (kind == 0) {
		col = derive(m, o, progress, boil, step_n);
	} else if (kind == 1) {
		col = thaumaturge(m, o, progress, boil, step_n);
	} else {
		col = factotum(m, o, p, boil);
	}
	// The canvas under every frame of it, and the corners darkening as it goes.
	float canvas = tex(UV * vec2(aspect, 1.0) * 6.0) * 0.6 + tex(UV * vec2(aspect, 1.0) * 23.0) * 0.4;
	col *= 1.0 + (canvas - 0.5) * 0.12 * smoothstep(0.0, 0.2, progress);
	vec2 v = UV - 0.5;
	col *= 1.0 - dot(v, v) * 1.4 * smoothstep(0.0, 0.6, progress);
	// The very end is the dark everywhere, so the loading cover follows cleanly.
	col = mix(col, DARK, smoothstep(0.9, 1.0, progress));
	// Untouched before it starts.
	COLOR = vec4(col, step(0.0001, progress));
}
