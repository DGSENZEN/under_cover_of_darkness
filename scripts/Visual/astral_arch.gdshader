// A stone of a ward-gate's arch (scripts/Visual/AstralPassage.gd): a carved block of the city's dark stone floating
// with its fellows round the gate's circle, in the deep's own world (seen through the gate's frame). Lit from the gate's fire
// on its inner face, a cold rim from the deep; on its faces toward either side one glyph of the ward-tongue, the old
// carved language its ward is written in (docs/superpowers/specs/2026-10-29-ward-tongue.md; never the portal's burning
// script): a frame for what kind of word it is, a root at its heart, its marks. A groove in the stone, its lip
// catching the fire, a little ward light deep in it pulsing round the arch in turn (marigold in the keystone's, the
// seal). Seen only where the void is.
shader_type spatial;
render_mode unshaded, cull_back, fog_disabled;

uniform sampler3D noise : filter_linear, repeat_enable;
// Where the gate's middle is, and this stone's place round its arch (0..1; the keystone 0.5) and whether it is the
// keystone.
uniform vec3 gate_at;
uniform float place = 0.0;
uniform bool keystone = false;
// Its glyph (AstralPassage.WARD): its frame (0 round: a power or a name, 1 stepped: an act, 2 cut-cornered: a place),
// its root (0 the dead, 1 the living, 2 the deep, 3 fire, 4 water, 5 stone, 6 sight, 7 passage, 8 binding, 9 the
// eclipse), its dots (how much), its bar (not), its hook (toward).
uniform int ward_frame = 0;
uniform int ward_root = 5;
uniform int ward_dots = 0;
uniform bool ward_bar = false;
uniform bool ward_hook = false;
// Whether it carries its carving (an arch's stone), or the Pasaje's chequer on its top (an echo of a way stone); how
// much of it is there (a glimpse: below 1 it dissolves).
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
// The world's up in its face (x-y): its glyph is cut upright, wherever it sits round the arch.
varying vec2 face_up;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	local = VERTEX;
	local_n = NORMAL;
	vec2 up = (inverse(mat3(MODEL_MATRIX)) * vec3(0.0, 1.0, 0.0)).xy;
	face_up = length(up) > 0.001 ? normalize(up) : vec2(0.0, 1.0);
}

float box_from(vec2 p, vec2 half_size) {
	vec2 d = abs(p) - half_size;
	return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

float segment_from(vec2 p, vec2 a, vec2 b) {
	vec2 ab = b - a;
	return length(p - a - ab * clamp(dot(p - a, ab) / dot(ab, ab), 0.0, 1.0));
}

// How far `p` is from its frame's groove (the face from -1 to 1 across).
float frame_from(vec2 p, int f) {
	if (f == 0) {
		return abs(length(p) - 0.86) - 0.045;
	} else if (f == 1) {
		// (Each corner cut in two steps.)
		float d = min(min(box_from(p, vec2(0.86, 0.56)), box_from(p, vec2(0.56, 0.86))), box_from(p, vec2(0.71, 0.71)));
		return abs(d) - 0.045;
	}
	// (Each corner cut off straight.)
	return abs(max(box_from(p, vec2(0.86)), (abs(p.x) + abs(p.y)) * 0.7071 - 0.9)) - 0.045;
}

// How far `q` is from its root's groove (its own square from -1 to 1).
float root_from(vec2 q, int root) {
	float r = length(q);
	float a = atan(q.y, q.x);
	if (root == 0) {
		// The dead: an eye closed, its lid shut along it, three lashes hanging from it (sight's own eye, shut).
		float almond = max(length(q - vec2(0.0, -0.95)) - 1.4, length(q - vec2(0.0, 0.95)) - 1.4);
		float d = min(abs(almond) - 0.08, max(abs(q.y) - 0.07, abs(q.x) - 0.9));
		for (int i = -1; i <= 1; i++) {
			d = min(d, segment_from(q, vec2(float(i) * 0.32, -0.1), vec2(float(i) * 0.4, -0.62)) - 0.06);
		}
		return d;
	} else if (root == 1) {
		// The living: a breath scroll leaving the mouth, its tail trailing down.
		float s = r / 0.3 - a / 6.2831853;
		float d = max(max(abs(fract(s) - 0.5) * 0.3 - 0.06, r - 0.78), 0.12 - r);
		return min(d, segment_from(q, vec2(0.7, -0.1), vec2(0.3, -0.9)) - 0.08);
	} else if (root == 2) {
		// The deep: three arcs opening downward, a well with no floor.
		vec2 w = q - vec2(0.0, -0.55);
		float d = min(min(abs(length(w) - 0.4), abs(length(w) - 0.8)), abs(length(w) - 1.2)) - 0.08;
		return max(d, max(-w.y, abs(q.x) - 0.98));
	} else if (root == 3) {
		// Fire: three tongues rising, the middle one tallest.
		float d = 1.0;
		for (int i = -1; i <= 1; i++) {
			float x = float(i) * 0.55;
			float top = i == 0 ? 0.9 : 0.55;
			float rise = clamp((q.y + 0.8) / (top + 0.8), 0.0, 1.0);
			d = min(d, segment_from(q, vec2(x - 0.08, -0.8), vec2(x + 0.14, top)) - 0.15 * (1.0 - 0.8 * rise));
		}
		return d;
	} else if (root == 4) {
		// Water: two waves.
		float d = min(abs(q.y - 0.35 - 0.16 * sin(q.x * 5.0)), abs(q.y + 0.3 - 0.16 * sin(q.x * 5.0 + 1.6))) - 0.08;
		return max(d, abs(q.x) - 0.95);
	} else if (root == 5) {
		// Stone: a block and its core.
		return min(abs(box_from(q, vec2(0.72))) - 0.08, box_from(q, vec2(0.2)));
	} else if (root == 6) {
		// Sight: an open eye, its pupil.
		float almond = max(length(q - vec2(0.0, -0.95)) - 1.4, length(q - vec2(0.0, 0.95)) - 1.4);
		return min(abs(almond) - 0.08, r - 0.24);
	} else if (root == 7) {
		// Passage: two footprints, one ahead of the other.
		float d = 1.0;
		for (int i = 0; i < 2; i++) {
			vec2 at = i == 0 ? vec2(-0.38, -0.42) : vec2(0.38, 0.32);
			vec2 f = q - at;
			d = min(d, length(vec2(f.x * 1.9, f.y + 0.06)) - 0.36);
			for (int t = 0; t < 3; t++) {
				d = min(d, length(f - vec2(-0.13 + float(t) * 0.13, 0.42 - abs(float(t) - 1.0) * 0.05)) - 0.06);
			}
		}
		return d;
	} else if (root == 8) {
		// Binding: two bands crossed, knotted where they cross.
		float band = max(min(abs(q.x - q.y), abs(q.x + q.y)) * 0.7071 - 0.1, max(abs(q.x), abs(q.y)) - 0.85);
		return min(max(band, 0.32 - r), abs(r - 0.24) - 0.07);
	}
	// The eclipse: the eaten sun, its dark disc, its ring, eight rays.
	float ray = abs(fract(a / 0.785398 + 0.5) - 0.5) * 0.785398 * r;
	float rays = max(max(ray - 0.12 * (1.0 - smoothstep(0.55, 0.98, r)), 0.6 - r), r - 0.98);
	return min(min(abs(r - 0.42) - 0.07, rays), r - 0.17);
}

// How far `p` is from its glyph's groove, about: its frame, its root (in the middle of it), its marks.
float glyph_from(vec2 p) {
	float d = frame_from(p, ward_frame);
	d = min(d, root_from(p / 0.52, ward_root) * 0.52);
	// Its dots along its foot.
	for (int i = 0; i < ward_dots; i++) {
		float x = (float(i) - float(ward_dots - 1) * 0.5) * 0.22;
		d = min(d, length(p - vec2(x, -0.7)) - 0.06);
	}
	// Its bar across its root: not.
	if (ward_bar) {
		d = min(d, max(abs(p.y) - 0.055, abs(p.x) - 0.66));
	}
	// Its hook at its right: toward.
	if (ward_hook) {
		float hook = min(segment_from(p, vec2(0.56, 0.22), vec2(0.74, 0.22)),
			max(abs(length(p - vec2(0.74, 0.06)) - 0.16), -(p.x - 0.74)));
		d = min(d, hook - 0.04);
	}
	return d;
}

// How much of `p` its glyph's groove covers (filtered by what a pixel spans: no shimmer).
float carving(vec2 p, float aa) {
	return 1.0 - smoothstep(-aa, aa, glyph_from(p));
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
	// (Only its face toward the gate's fire takes a little of it.)
	col += mix(oxblood, marigold, 0.35) * pow(to_fire, 3.0) * 0.12;
	// Its carving, on its faces toward either side of the gate (its local z).
	float groove = 0.0;
	float lip = 0.0;
	if (chequer && local_n.y > 0.85) {
		// The Pasaje's chequer on its top, dim, in its grout.
		vec2 cell = floor(local.xz / 0.3);
		vec2 f = fract(local.xz / 0.3);
		float line = 1.0 - smoothstep(0.03, 0.07, min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y)));
		vec3 tiles = mix(vec3(0.8, 0.72, 0.56), vec3(0.6, 0.3, 0.2), mod(cell.x + cell.y, 2.0));
		col = mix(tiles * 0.3 * (0.8 + 0.4 * grain), ink, line);
	}
	if (glyphs && abs(local_n.z) > 0.9) {
		// (Its face from -1 to 1 across, the same way up from either side; the keystone larger.)
		vec2 p = local.xy / (0.17 * (keystone ? 1.35 : 1.0));
		p = vec2(dot(p, vec2(face_up.y, -face_up.x)), dot(p, face_up));
		p.x *= sign(local_n.z);
		float aa = max(fwidth(p.x) + fwidth(p.y), 0.004);
		groove = carving(p, aa);
		// (The groove's far wall, toward the fire below it, catching it: the lip.)
		lip = clamp(groove - carving(p + vec2(0.0, 0.07), aa), 0.0, 1.0);
	}
	float pulse = pow(0.5 + 0.5 * sin(TIME * 1.1 - place * 12.0), 6.0);
	vec3 glow = keystone ? marigold : ward;
	// (Cut in: a dark groove, its lip lit by the fire, a little light deep in it.)
	col = mix(col, ink * 0.45, groove * 0.85);
	col += mix(oxblood, marigold, 0.5) * lip * 0.22;
	col += glow * groove * ((keystone ? 0.14 : 0.04) + (keystone ? 0.4 : 0.16) * pulse);
	// A cold rim from the deep.
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	col += ward * rim * 0.2;
	ALBEDO = col;
}
