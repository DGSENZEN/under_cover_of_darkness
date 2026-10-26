shader_type canvas_item;
// An archetype's effects, behind its portrait and spilling past it: bold
// graphic shapes painted in oils. Every shape has a dry brush's ragged edge
// that boils in held steps, and moves in held frames like a hand-drawn
// flipbook, never smoothly. Nothing here is drawn over the painting.
uniform sampler2D noise : filter_linear, repeat_enable;
// 0 Derivé, 1 Thaumaturge, 2 Factotum.
uniform int kind = 0;
// 0..1: woken (the card is chosen).
uniform float level = 0.0;
// 0..1: the confirm's surge.
uniform float surge = 0.0;
// 0..1: Factotum's construction lines drawn in.
uniform float drawn = 0.0;
uniform float fps = 9.0;
// This rect's size (px) and the portrait's rect inside it (UV: x, y, w, h).
uniform vec2 px = vec2(800.0, 900.0);
uniform vec4 card = vec4(0.3, 0.2, 0.4, 0.6);

float hash(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

float tex(vec2 p) {
	return texture(noise, p).r;
}

// A brush's coverage of a shape (d < 0 inside, in card heights): the edge is
// torn by noise, bristle streaks run along `dir`, and the edge is dry.
float brush(float d, vec2 m, vec2 dir, vec2 boil, float rough) {
	vec2 along = vec2(dot(m, dir), dot(m, vec2(-dir.y, dir.x)));
	float streak = tex(vec2(along.x * 0.6, along.y * 14.0) + boil);
	float torn = (tex(m * 2.2 + boil) - 0.5) * rough + (streak - 0.5) * rough * 0.5;
	float e = d + torn;
	float cover = 1.0 - smoothstep(-0.004, 0.004, e);
	// Dry bristles near the edge: holes where the streak is thin.
	float dry = smoothstep(0.25, 0.5, streak + clamp(-e * 18.0, 0.0, 1.0));
	return cover * dry;
}

// Oil paint between two pigments, with the stroke's own light and a darker
// pile-up at its edge.
vec3 oil(vec3 a, vec3 b, vec2 m, vec2 boil, float d, vec2 dir) {
	float mixn = tex(m * 0.9 + boil * 0.3);
	vec3 c = mix(a, b, smoothstep(0.3, 0.7, mixn));
	// The stroke's own light runs along it, like the brush that laid it.
	vec2 along = vec2(dot(m, dir), dot(m, vec2(-dir.y, dir.x)));
	float sheen = tex(vec2(along.x * 1.2, along.y * 9.0) + boil * 0.5);
	c *= 0.86 + sheen * 0.3;
	return c * mix(0.7, 1.0, smoothstep(0.0, 0.02, -d));
}

void over(inout vec4 acc, vec3 c, float a) {
	acc.rgb = c * a + acc.rgb * (1.0 - a);
	acc.a = a + acc.a * (1.0 - a);
}

// --- Derivé: fire licks, a burst behind the fists, embers, cracks ---------
void derive(inout vec4 acc, vec2 m, vec2 c, float aspect, float t, vec2 boil, float step_n) {
	vec3 oxblood = vec3(0.42, 0.08, 0.05);
	vec3 vermilion = vec3(0.85, 0.27, 0.12);
	vec3 orange = vec3(0.94, 0.54, 0.22);
	vec3 ochre = vec3(0.97, 0.78, 0.42);
	// The burst: radial strokes flaring out behind the fists on a punch rhythm.
	float beat = fract(t / 1.6);
	float grow = beat < 0.2 ? min(beat / 0.12, 1.0) : 1.0 - smoothstep(0.2, 1.0, beat) * 0.55;
	grow = max(grow, surge) * (1.0 + surge * 0.6);
	vec2 hub = vec2(0.5 * aspect, 0.34);
	vec2 r = m - hub;
	float ang = atan(r.y, r.x) / TAU + 0.5;
	float spokes = 22.0;
	float k = floor(ang * spokes);
	float cycle = floor(t / 1.6);
	float len = (0.42 + 0.5 * hash(k + cycle * 7.0)) * grow;
	float within = (fract(ang * spokes) - 0.5) / spokes * TAU * length(r);
	float rad = length(r);
	float hw = 0.03 * (1.0 - clamp(rad / max(len, 0.001), 0.0, 1.0)) + 0.002;
	float d_burst = max(abs(within) - hw, rad - len);
	d_burst = max(d_burst, 0.12 - rad);
	vec2 dir = normalize(r + 1e-4);
	float a_burst = brush(d_burst, m, dir, boil, 0.02);
	over(acc, oil(vermilion, orange, m, boil, d_burst, dir), a_burst * 0.9);
	// Fire licks rooted under the portrait's foot, tallest at its sides:
	// pointed tongues that curl, each with a brighter core.
	for (int i = 0; i < 9; i++) {
		float fi = float(i);
		float cx = mix(-0.24, aspect + 0.24, (fi + 0.5) / 9.0);
		float side = abs(cx - 0.5 * aspect) / (0.5 * aspect + 0.24);
		float h = (0.2 + 0.45 * side) * (0.8 + 0.3 * hash(fi + step_n * 3.1)) * (1.0 + surge * 0.5);
		float y = (1.06 - c.y) / h;
		float curl = sin(y * 3.5 + t * 2.6 + fi * 1.7) * 0.07 * y * y;
		float x = m.x - cx - curl;
		float wide = 0.05 + 0.02 * hash(fi);
		for (int layer = 0; layer < 2; layer++) {
			float k = layer == 0 ? 1.0 : 0.5;
			float yy = layer == 0 ? y : y / 0.75;
			float half_w = wide * k * pow(clamp(1.0 - yy, 0.0, 1.0), 1.3) * smoothstep(-0.05, 0.18, yy);
			float d = yy < 0.0 || yy > 1.0 ? 1.0 : abs(x) - half_w;
			float a = brush(d, m, vec2(0.0, 1.0), boil, 0.012);
			vec3 col = layer == 0
				? mix(oil(oxblood, vermilion, m, boil, d, vec2(0.0, 1.0)), vermilion, smoothstep(0.5, 1.0, yy))
				: mix(orange, ochre, smoothstep(0.2, 0.9, yy));
			over(acc, col, a);
		}
	}
	// Cracks in the ground under him, glowing, flickering in steps.
	// (Only to his sides: his name and line sit under him.)
	float band = smoothstep(0.94, 0.99, c.y) * (1.0 - smoothstep(1.06, 1.12, c.y)) * smoothstep(0.16, 0.34, abs(m.x - 0.5 * aspect));
	float v = tex(vec2(m.x * 0.7, c.y * 0.35) + vec2(0.31, 0.17));
	float crack = 1.0 - smoothstep(0.004, 0.012, abs(v - 0.5));
	float flicker = 0.7 + 0.3 * hash(step_n);
	over(acc, mix(orange, ochre, 0.5), crack * band * flicker);
	// Ember daubs rising past him.
	for (int i = 0; i < 14; i++) {
		float fi = float(i);
		float ph = fract(t * (0.22 + 0.12 * hash(fi + 3.0)) + hash(fi));
		float ex = mix(-0.25, aspect + 0.25, hash(fi + 9.0)) + sin(ph * 7.0 + fi) * 0.05;
		vec2 e = vec2(ex, 1.12 - ph * 1.35);
		float d = length((m - e) * vec2(1.0, 0.7)) - 0.011 * (1.0 - ph * 0.6);
		over(acc, ochre, brush(d, m, vec2(0.0, 1.0), boil, 0.006) * (1.0 - ph) * step(0.0, abs(m.x - 0.5 * aspect) - 0.22 * step(0.98, e.y)));
	}
}

// --- Thaumaturge: violet smoke, a gold sigil ring, a ring against it ------
void thaumaturge(inout vec4 acc, vec2 m, vec2 c, float aspect, float t, vec2 boil, float step_n) {
	vec3 deep = vec3(0.2, 0.1, 0.38);
	vec3 violet = vec3(0.42, 0.22, 0.72);
	vec3 lilac = vec3(0.68, 0.5, 0.9);
	vec3 gold = vec3(0.85, 0.7, 0.42);
	vec3 pale_gold = vec3(0.95, 0.86, 0.63);
	// Smoke: a halo behind his head and shoulders...
	vec2 warp = vec2(tex(m * 0.7 + vec2(t * 0.03, 0.0)), tex(m * 0.7 + vec2(0.0, t * 0.03) + 0.5)) - 0.5;
	vec2 q = m + warp * 0.3;
	vec2 head = vec2(0.5 * aspect, 0.24);
	float halo = length((q - head) / vec2(0.46 + surge * 0.1, 0.34 + surge * 0.08)) - 1.0;
	float d_halo = halo * 0.22 + (tex(q * 1.4 - vec2(0.0, t * 0.05)) - 0.5) * 0.09;
	vec2 swirl = normalize(vec2(-(q - head).y, (q - head).x) + 1e-4);
	over(acc, oil(deep, violet, q, boil, d_halo, swirl), brush(d_halo, q, swirl, boil, 0.02) * 0.8);
	// ...and tendrils rising past his shoulders, curling as they go.
	for (int i = 0; i < 6; i++) {
		float fi = float(i);
		float side = i < 3 ? -1.0 : 1.0;
		float lane = mod(fi, 3.0);
		float x0 = 0.5 * aspect + side * (0.24 + 0.05 * lane);
		float top = -0.08 - 0.14 * hash(fi + 4.0) - surge * 0.1;
		float span = clamp((0.85 - c.y) / (0.85 - top), 0.0, 1.0);
		// Wisps curl harder as they rise, and taper to a point.
		float coil = sin(span * 7.0 + t * 1.4 + fi * 2.1) * 0.09 + sin(span * 13.0 - t * 2.0 + fi) * 0.03;
		float cx = x0 + side * span * 0.06 + coil * span;
		float w = 0.022 * pow(1.0 - span, 0.8) * (1.0 + 0.3 * hash(fi)) * smoothstep(0.0, 0.08, span);
		float d = c.y > 0.85 || c.y < top ? 1.0 : abs(m.x - cx) - w;
		vec3 col = mix(violet, lilac, span * 0.8);
		over(acc, oil(col * 0.8, col, m, boil, d, vec2(0.0, 1.0)), brush(d, m, vec2(0.0, 1.0), boil, 0.008) * 0.8);
	}
	// The sigil ring, painted in gold, turning slowly in steps.
	vec2 hub = vec2(0.5 * aspect, 0.3);
	vec2 r = m - hub;
	float rad = length(r);
	float ring_r = 0.37 + surge * 0.06;
	float turn = step_n * 0.006;
	float ang = atan(r.y, r.x) + turn;
	float d_ring = abs(rad - ring_r) - 0.009;
	over(acc, oil(gold, pale_gold, m, boil, d_ring, normalize(vec2(-r.y, r.x) + 1e-4)), brush(d_ring, m, normalize(vec2(-r.y, r.x) + 1e-4), boil, 0.008));
	// Glyphs on an outer band: a mark per sector, each its own shape.
	float sectors = 12.0;
	float s = floor((ang / TAU + 0.5) * sectors);
	float sa = (s + 0.5) / sectors * TAU - PI - turn;
	vec2 gc = hub + vec2(cos(sa), sin(sa)) * (ring_r + 0.045);
	vec2 tangent = vec2(-sin(sa), cos(sa));
	vec2 g = vec2(dot(m - gc, tangent), dot(m - gc, vec2(cos(sa), sin(sa))));
	float pick = floor(hash(s * 3.7) * 4.0);
	float d_glyph;
	if (pick < 1.0) {
		d_glyph = abs(length(g) - 0.013) - 0.0035;
	} else if (pick < 2.0) {
		d_glyph = min(max(abs(g.x) - 0.0035, abs(g.y) - 0.016), max(abs(g.y) - 0.0035, abs(g.x) - 0.011));
	} else if (pick < 3.0) {
		d_glyph = min(max(abs(g.x) - 0.0035, abs(g.y) - 0.017), length(g - vec2(0.0, 0.026)) - 0.005);
	} else {
		d_glyph = max(length(g) - 0.015, -(length(g - vec2(0.007, 0.0)) - 0.012));
	}
	over(acc, pale_gold, brush(d_glyph, m, tangent, boil, 0.004));
	// A dashed inner ring of lilac turning the other way.
	float d_inner = abs(rad - (0.28 + surge * 0.04)) - 0.005;
	float dash = step(0.45, fract((atan(r.y, r.x) - turn * 1.6) / TAU * 40.0));
	over(acc, lilac, brush(d_inner, m, normalize(vec2(-r.y, r.x) + 1e-4), boil, 0.006) * dash * 0.9);
}

// --- Factotum: ink washes, construction lines, a compass arc, pages -------
float segment(vec2 p, vec2 a, vec2 b, float upto) {
	vec2 ab = b - a;
	float h = clamp(dot(p - a, ab) / dot(ab, ab), 0.0, upto);
	return length(p - a - ab * h);
}

void factotum(inout vec4 acc, vec2 m, vec2 c, float aspect, float t, vec2 boil, float step_n) {
	vec3 night = vec3(0.07, 0.15, 0.32);
	vec3 ink = vec3(0.12, 0.3, 0.6);
	vec3 blue = vec3(0.23, 0.47, 0.8);
	vec3 pale = vec3(0.74, 0.84, 1.0);
	vec3 paper = vec3(0.9, 0.86, 0.77);
	// Ink blots bleeding out from behind him, darker where the pigment pooled.
	for (int i = 0; i < 4; i++) {
		float fi = float(i);
		vec2 at = i == 0 ? vec2(-0.06, 0.3) : i == 1 ? vec2(aspect + 0.08, 0.62) : i == 2 ? vec2(aspect - 0.02, 0.0) : vec2(0.02, 0.92);
		float r = (0.17 + 0.05 * hash(fi + 1.0)) * (0.85 + drawn * 0.15 + surge * 0.3);
		float d = (length(m - at) - r) * 0.5 + (tex(m * 1.3 + fi * 0.37 + boil * 0.1) - 0.5) * 0.1;
		vec3 col = oil(night, ink, m, boil, d, vec2(0.7, 0.7));
		col = mix(col, blue, smoothstep(0.55, 0.85, tex(m * 2.0 + fi)) * 0.5);
		over(acc, col, brush(d, m, vec2(0.7, 0.7), boil, 0.03) * 0.8);
	}
	// Construction lines inked in, one after another.
	float lines = 1e3;
	float x0 = -0.07;
	float x1 = aspect + 0.07;
	lines = min(lines, segment(m, vec2(-0.32, 0.1), vec2(aspect + 0.32, 0.1), clamp(drawn * 1.6, 0.0, 1.0)));
	lines = min(lines, segment(m, vec2(aspect + 0.32, 0.88), vec2(-0.32, 0.88), clamp(drawn * 1.6 - 0.15, 0.0, 1.0)));
	lines = min(lines, segment(m, vec2(x0, -0.16), vec2(x0, 1.16), clamp(drawn * 1.6 - 0.25, 0.0, 1.0)));
	lines = min(lines, segment(m, vec2(x1, 1.16), vec2(x1, -0.16), clamp(drawn * 1.6 - 0.35, 0.0, 1.0)));
	lines = min(lines, segment(m, vec2(-0.3, 0.62), vec2(aspect + 0.3, -0.12), clamp(drawn * 1.6 - 0.5, 0.0, 1.0)));
	// Ticks along the top line, a rule's measure.
	float tick_x = fract(m.x / 0.04);
	float ticks = abs(m.y - 0.085) < 0.016 && m.x < -0.32 + (aspect + 0.64) * clamp(drawn * 1.6, 0.0, 1.0) && m.x > -0.32 ? abs(tick_x - 0.5) * 0.04 : 1e3;
	lines = min(lines, ticks);
	float wob = (tex(m * 6.0 + boil) - 0.5) * 0.004;
	float d_lines = lines - 0.0022 + wob;
	over(acc, pale, brush(d_lines, m, vec2(1.0, 0.0), boil, 0.002) * 0.85);
	// A compass arc swung from the top corner, with its pivot.
	vec2 pivot = vec2(aspect + 0.07, 0.1);
	vec2 rp = m - pivot;
	float arc_ang = atan(rp.y, rp.x);
	float upto = mix(1.6, 3.4, clamp(drawn * 1.4 - 0.4, 0.0, 1.0));
	float d_arc = abs(length(rp) - 0.3) - 0.0024 + wob;
	d_arc = (arc_ang > 1.6 && arc_ang < upto) ? d_arc : 1.0;
	over(acc, pale, brush(d_arc, m, vec2(0.0, 1.0), boil, 0.002) * 0.85);
	over(acc, pale, brush(length(rp) - 0.008, m, vec2(1.0, 0.0), boil, 0.002));
	// Pages lifting away from the ground, turning in held frames.
	for (int i = 0; i < 4; i++) {
		float fi = float(i);
		float ph = fract(t * 0.09 + fi * 0.27 + hash(fi) * 0.1);
		vec2 at = vec2(mix(-0.2, aspect + 0.15, hash(fi + 2.0)) + ph * 0.22, 1.12 - ph * 0.95);
		float rot = ph * 2.4 + fi;
		vec2 pp = m - at;
		pp = vec2(pp.x * cos(rot) - pp.y * sin(rot), pp.x * sin(rot) + pp.y * cos(rot));
		vec2 size = vec2(0.035, 0.048) * vec2(abs(cos(ph * 5.0 + fi)) * 0.7 + 0.3, 1.0);
		float d_page = max(abs(pp.x) - size.x, abs(pp.y) - size.y);
		float fade = (1.0 - smoothstep(0.7, 1.0, ph)) * smoothstep(0.0, 0.08, ph);
		vec3 sheet = oil(paper, paper * 0.85, m, boil, d_page, vec2(1.0, 0.0));
		sheet = mix(sheet, ink, step(0.7, fract(pp.y / 0.012)) * step(abs(pp.x), size.x * 0.7) * 0.5);
		over(acc, sheet, brush(d_page, m, vec2(1.0, 0.0), boil, 0.003) * fade);
	}
}

void fragment() {
	float step_n = floor(TIME * fps);
	float t = step_n / fps;
	vec2 boil = vec2(hash(step_n), hash(step_n + 17.0)) * 0.5;
	// Card space: the portrait spans 0..1; m is in card heights, so circles are round.
	vec2 c = (UV - card.xy) / card.zw;
	float aspect = (px.x * card.z) / (px.y * card.w);
	vec2 m = vec2(c.x * aspect, c.y);
	vec4 acc = vec4(0.0);
	if (kind == 0) {
		derive(acc, m, c, aspect, t, boil, step_n);
	} else if (kind == 1) {
		thaumaturge(acc, m, c, aspect, t, boil, step_n);
	} else {
		factotum(acc, m, c, aspect, t, boil, step_n);
	}
	// The spill fades out at this rect's own edges, raggedly.
	vec2 e = min(UV, 1.0 - UV);
	float rim = smoothstep(0.0, 0.12, min(e.x, e.y) + (tex(UV * 3.0 + boil) - 0.5) * 0.05);
	vec3 rgb = acc.a > 0.0001 ? acc.rgb / acc.a : vec3(0.0);
	COLOR = vec4(rgb, acc.a * level * rim);
}
