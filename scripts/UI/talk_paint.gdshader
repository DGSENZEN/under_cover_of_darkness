shader_type canvas_item;
// A picture of the talk box (its panel, its portrait) that frays out from its
// own paint, as draft 28's painted_edge (.superpowers/talkbox/draft28_reference.py):
//   - its border is eaten inward by streaky noise running along each edge (a
//     dry brush), slower noise biting deeper here and there, soft corners;
//   - pigment pools in a thin darker rim just inside the fray;
//   - a few thin dry strokes drag the edge's own colours out past it.
// No blurred copy behind it, no tabs, no grain laid over it.
//
// The rect it is drawn on is the picture plus `pad` all round (the strokes
// need the room). Everything is measured in the picture's pixels at 1080p
// (picture_size, pad), so the fray looks the same at any screen size. The
// picture is TEXTURE (a painting, a live render), or, with `procedural`, the
// plain skin's backdrop painted here from noise. A backdrop gets a dark
// reading pool (pool, pool_strength) under the words.
//
// `reveal` (0..1) paints it in, and back out the same way: a few big
// splotches bloom outward from where they land, while bristle strokes sweep
// across from the left with a ragged, streaky front; a pixel is down once
// either has reached it. A darker pigment line rides the wet front, so it
// reads as paint laid, not a fade. `reveal_seed` changes every opening.

uniform vec2 picture_size = vec2(1000.0, 583.0);
uniform float pad = 40.0;
// The frayed edge's soft rim (px at 1080p): the paint is whole inside it.
uniform float fray_soft = 5.0;
uniform float seed = 11.0;
uniform bool procedural = false;
// The pool's ellipse, as its box in fractions of the picture (x0, y0, x1, y1).
uniform vec4 pool = vec4(0.06, -0.25, 0.94, 0.92);
uniform float pool_strength = 0.0;
uniform float reveal = 1.0;
uniform float reveal_seed = 0.0;
// The part of TEXTURE shown (x, y, w, h in its UV): a skin's backdrop is the
// whole painting, its frame cropped away here.
uniform vec4 crop = vec4(0.0, 0.0, 1.0, 1.0);

// The living painting (a painted skin's; TalkSkin.animate drives it), all
// off by default:
//   - breathe: the spectral faces (rects in fractions of the picture) swell
//     and settle, very slightly, through a soft masked warp;
//   - eyes: their eyes glow in the shade's colour (eye_glow, eye_colour), and
//     gutter with it (eye_flicker);
//   - dust: faint motes drift up across it;
//   - shift: the painting slides a few px inside its frame (the mouse);
//   - warmth, grey, flicker: the portrait warms on flare, greys on dim,
//     flickers on gutter.
uniform bool living = false;
uniform vec4 breathe[4];
uniform int breathe_count = 0;
uniform vec4 eyes[6];
uniform int eye_count = 0;
uniform vec3 eye_colour = vec3(1.0, 0.62, 0.22);
uniform float eye_glow = 0.0;
uniform float eye_flicker = 0.0;
uniform float dust = 0.0;
uniform vec2 shift = vec2(0.0);
uniform float warmth = 0.0;
uniform float grey = 0.0;
uniform float flicker = 0.0;

const vec3 POOL_INK = vec3(4.0, 4.0, 6.0) / 255.0;
// The reading pool's softness: draft 28 blurs it with a Gaussian of this
// sigma (px of the 1000 px panel).
const float POOL_SIGMA = 70.0;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21) + seed * 0.137);
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

// Value noise, smoothly joined (the reference resizes random grids bicubically).
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;

	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + 17.0;
		a *= 0.5;
	}

	return v;
}

// How much paint the plain backdrop wants here (0..1): its flanks, its foot,
// a little its head, unevenly.
float paint_wanted(vec2 q) {
	vec2 uv = q / picture_size;
	float flank = 1.0 - smoothstep(0.02, 0.13, min(uv.x, 1.0 - uv.x));
	float foot = 1.0 - smoothstep(0.0, 0.2, 1.0 - uv.y);
	float head = 1.0 - smoothstep(0.0, 0.07, uv.y);
	return clamp(max(max(flank, foot * 0.7), head * 0.45) * (0.7 + 0.6 * vnoise(q / 120.0 + 5.0)), 0.0, 1.0);
}

// One layer of brush dabs: short, fat strokes a little off level, each its
// own colour from the palette, bristle-streaked along its length, laid where
// paint_wanted (times `amount`) asks for it at the dab's middle, whole or
// not at all. (rgb, coverage)
vec4 dabs(vec2 q, float amount, float layer) {
	// (Every dab stays within a cell of its own, so the eight round each
	// pixel are all that can reach it: no dab is ever cut off.)
	vec2 cell = vec2(140.0, 40.0);
	vec2 g = (q + vec2(layer * 61.0, layer * 23.0)) / cell;
	vec2 id = floor(g);
	vec2 f = fract(g);
	vec4 laid = vec4(0.0);

	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 n = id + vec2(float(i), float(j));
			vec2 centre = vec2(float(i), float(j)) + 0.5 + (vec2(hash(n + 1.3), hash(n + 2.7)) - 0.5) * 0.3;
			vec2 middle = (id + centre) * cell - vec2(layer * 61.0, layer * 23.0);

			if (hash(n + layer * 7.0) > paint_wanted(middle) * amount * 1.3) {
				continue;
			}

			vec2 d = (f - centre) * cell;
			float turn = (hash(n + 3.1) - 0.5) * 0.2 + (layer - 0.5) * 0.1;
			d = vec2(cos(turn) * d.x + sin(turn) * d.y, -sin(turn) * d.x + cos(turn) * d.y);
			float len = mix(100.0, 196.0, hash(n + 4.2));
			float wid = mix(26.0, 48.0, hash(n + 5.3));
			float bristle = vnoise(vec2(d.x / 40.0, d.y / 1.6) + n * 3.1) * 0.7 + vnoise(vec2(d.x / 90.0, d.y / 5.0) + n) * 0.3;
			float e = length(d / vec2(len * 0.5, wid * 0.5)) + (bristle - 0.5) * 0.5;
			float a = (1.0 - smoothstep(0.6, 1.0, e)) * (0.35 + 0.65 * bristle);
			float pick = hash(n + 6.1);
			vec3 colour = pick < 0.3 ? vec3(0.40, 0.31, 0.47)
				: pick < 0.5 ? vec3(0.54, 0.37, 0.45)
				: pick < 0.7 ? vec3(0.60, 0.49, 0.29)
				: pick < 0.82 ? vec3(0.74, 0.67, 0.54)
				: vec3(0.17, 0.21, 0.19);
			colour *= 0.75 + 0.4 * bristle;
			laid.rgb = mix(laid.rgb, colour, a);
			laid.a = max(laid.a, a);
		}
	}

	return laid;
}

// The plain skin's backdrop: a green-black ground, and muted purple, mauve
// and gold dabs worked in toward the flanks, the foot and a little the head.
vec3 backdrop(vec2 q) {
	vec2 uv = q / picture_size;
	vec3 ground = mix(vec3(0.028, 0.038, 0.033), vec3(0.075, 0.09, 0.075), fbm(q / 150.0));
	float grain = vnoise(q / vec2(3.5, 60.0)) * 0.6 + vnoise(q / vec2(9.0, 140.0)) * 0.4;
	ground *= 0.8 + 0.4 * grain;
	vec4 under = dabs(q, 1.0, 0.0);
	vec4 over = dabs(q, 0.8, 1.0);
	vec3 colour = mix(ground, under.rgb, under.a * 0.7);
	return mix(colour, over.rgb, over.a * 0.6);
}

// The dark reading pool: an ellipse, softened about 70 px.
float pool_mask(vec2 q) {
	vec2 a = pool.xy * picture_size;
	vec2 b = pool.zw * picture_size;
	vec2 centre = (a + b) * 0.5;
	vec2 radii = max((b - a) * 0.5, vec2(1.0));
	float out_px = (length((q - centre) / radii) - 1.0) * min(radii.x, radii.y);
	// A Gaussian-blurred edge (the normal CDF, by its logistic likeness).
	return 1.0 / (1.0 + exp(1.702 * out_px / POOL_SIGMA));
}

// Where in TEXTURE the picture's `q` (px of the picture) is: its crop's part.
// (TEXTURE itself can be read only in fragment(), so the sampling is there:
// four bilinear taps spread over the pixel's footprint, from the mip level
// half that footprint, a 2x2 supersample sharper than a mipmap's own blur and
// never aliasing; a pixel no bigger than a texel takes one.)
vec2 picture_uv(vec2 q) {
	return crop.xy + (q + 0.5) / picture_size * crop.zw;
}

// The mip level for the strokes past the edge: the picture's colour well
// blurred, about an eighth of its size (as the reference's dry strokes take
// theirs). `texels`: TEXTURE's width.
float blurred_lod(float texels) {
	return log2(max(texels * crop.z / picture_size.x, 1.0) * 8.0);
}

// Where to take the paint from: shifted with the mouse, and each spectral
// face breathing (a slow swell about its middle, eased out at its edge).
vec2 living_at(vec2 q) {
	q -= shift;

	for (int i = 0; i < 4; i++) {
		if (i >= breathe_count) {
			break;
		}

		vec4 face = breathe[i];
		vec2 middle = (face.xy + face.zw * 0.5) * picture_size;
		vec2 half_size = max(face.zw * 0.5 * picture_size, vec2(1.0));
		float inside = 1.0 - smoothstep(0.45, 1.0, length((q - middle) / half_size));
		float swell = 0.011 * sin(TIME * 6.2832 / 5.5 + float(i) * 1.9) + 0.004 * sin(TIME * 6.2832 / 2.3 + float(i));
		q = middle + (q - middle) / (1.0 + swell * inside);
	}

	return q;
}

// How much the eyes glow here (0..), their light gathered soft about each.
float eye_light(vec2 q) {
	float light = 0.0;

	for (int i = 0; i < 6; i++) {
		if (i >= eye_count) {
			break;
		}

		vec4 eye = eyes[i];
		vec2 middle = (eye.xy + eye.zw * 0.5) * picture_size;
		vec2 radius = max(eye.zw * 0.5 * picture_size, vec2(1.0));
		vec2 d = (q - middle) / radius;
		// A bright core in the eye, a wide faint halo round it.
		light += exp(-dot(d, d) * 2.2) + 0.25 * exp(-dot(d, d) * 0.35);
	}

	// A candle's gutter: it sinks and catches, unevenly.
	float gutter = vnoise(vec2(TIME * 7.0, 3.7)) * 0.7 + vnoise(vec2(TIME * 17.0, 9.1)) * 0.3;
	return light * eye_glow * (1.0 - eye_flicker * 0.75 * smoothstep(0.35, 0.8, gutter));
}

// Faint dust drifting up through the panel: a few soft motes, twinkling.
float motes(vec2 q) {
	float m = 0.0;

	for (int layer = 0; layer < 2; layer++) {
		float l = float(layer);
		vec2 cell = vec2(70.0 + 40.0 * l);
		vec2 at = q + vec2(sin(TIME * 0.13 + l * 2.0) * 24.0, TIME * (7.0 + 5.0 * l));
		vec2 id = floor(at / cell);
		vec2 f = fract(at / cell);
		float h = hash(id + l * 13.0);

		if (h < 0.4) {
			vec2 c = vec2(hash(id + 1.7), hash(id + 2.9)) * 0.8 + 0.1;
			float r = length((f - c) * cell);
			float twinkle = 0.55 + 0.45 * sin(TIME * (0.9 + h * 2.0) + h * 40.0);
			m += (1.0 - smoothstep(0.3, 1.4 + l * 0.6, r)) * twinkle;
		}
	}

	return m;
}

// How far inside the frayed line this is (px; below 0 the brush has eaten
// it): the line itself is ragged, bitten deeper here and there.
float fray_depth(vec2 p) {
	vec2 size = picture_size;

	if (p.x < 0.0 || p.y < 0.0 || p.x > size.x - 1.0 || p.y > size.y - 1.0) {
		return -1000.0;
	}

	float dx = min(p.x, size.x - 1.0 - p.x);
	float dy = min(p.y, size.y - 1.0 - p.y);
	float r = pad * 1.6;
	float cx = max(r - dx, 0.0);
	float cy = max(r - dy, 0.0);
	float dist = (cx > 0.0 && cy > 0.0) ? r - length(vec2(cx, cy)) : min(dx, dy);
	// Streaks along each edge: the top and foot's run across, the sides' down.
	float along_x = vnoise(p / vec2(60.0, 3.0)) * 0.6 + vnoise(p / vec2(14.0, 2.0) + 31.0) * 0.4;
	float along_y = vnoise(p / vec2(3.0, 60.0) + 53.0) * 0.6 + vnoise(p / vec2(2.0, 14.0) + 71.0) * 0.4;
	float bites = vnoise(p / 160.0 + 91.0);
	float streak = dx < dy ? along_y : along_x;
	float reach = pad * (0.3 + 0.9 * streak + 0.9 * bites * bites);
	return dist - reach * 0.55;
}

// The dry strokes along one edge: `along` runs the edge, `beyond` is how far
// past it (+ outward). Thin lines in loose clusters, tapering away.
float strokes_along(float along, float beyond, float side) {
	float row = floor(beyond * 0.9);
	float lift = fract(beyond * 0.9);
	float cell = floor((along + hash(vec2(row, side)) * 500.0) / 75.0);
	float h = hash(vec2(cell, row + side * 31.0));
	float cluster = hash(vec2(cell, side + 7.0));
	float band = pad * 0.3 * (0.4 + 0.6 * cluster);

	if (h < 0.5 || abs(beyond) > band) {
		return 0.0;
	}

	float start = cell * 75.0 - hash(vec2(row, side)) * 500.0 + hash(vec2(cell, row + 3.0)) * 20.0;
	float len = mix(30.0, 110.0, hash(vec2(row, cell + 5.0)));
	float t = (along - start) / len;

	if (t < 0.0 || t > 1.0) {
		return 0.0;
	}

	float thin = 1.0 - abs(lift - 0.5) * 1.6;
	return mix(0.24, 0.59, h) * (1.0 - t * t) * clamp(thin, 0.0, 1.0);
}

// When this spot is painted, 0..1 of the way through the reveal.
float paint_time(vec2 p, vec2 uv) {
	vec2 o = vec2(reveal_seed * 37.1, reveal_seed * 91.7);
	// Splotches: where slow blobby noise is high, paint lands first and
	// spreads out over the lower ground around it.
	float blob = vnoise((p + o) / 260.0) * 0.75 + vnoise((p + o) / 80.0 + 9.0) * 0.25;
	float bloom = clamp((0.72 - blob) * 2.4, 0.0, 1.0);
	// Strokes: long bristle streaks running across, the sweep from the left
	// ragged by them.
	float streak = vnoise((p + o) / vec2(110.0, 2.6)) * 0.65 + vnoise((p + o) / vec2(40.0, 1.6)) * 0.35;
	float sweep = clamp(uv.x * 0.7 + (1.0 - streak) * 0.3, 0.0, 1.0);
	float t = min(bloom, sweep);
	// The front dragged along the bristles, never a clean line.
	t += (vnoise((p + o) / vec2(26.0, 1.4)) - 0.5) * 0.08;
	return clamp(t, 0.0, 1.0) * 0.92;
}

void fragment() {
	vec2 full = picture_size + 2.0 * pad;
	vec2 p = UV * full - pad;
	vec2 q = clamp(p, vec2(0.0), picture_size - 1.0);
	vec3 colour;
	vec3 edge_paint = vec3(0.0);

	if (procedural) {
		colour = backdrop(q);
	} else {
		vec2 uv = picture_uv(living ? living_at(q) : q);
		vec2 size = vec2(textureSize(TEXTURE, 0));
		vec2 ex = dFdx(uv);
		vec2 ey = dFdy(uv);
		float foot = max(length(ex * size), length(ey * size));
		float lod = max(0.0, log2(max(foot, 1.0)) - 1.0);
		float spread = foot > 1.01 ? 1.0 : 0.0;
		colour = textureLod(TEXTURE, uv + (-ex * 0.125 - ey * 0.375) * spread, lod).rgb;
		colour += textureLod(TEXTURE, uv + (ex * 0.375 - ey * 0.125) * spread, lod).rgb;
		colour += textureLod(TEXTURE, uv + (ex * 0.125 + ey * 0.375) * spread, lod).rgb;
		colour += textureLod(TEXTURE, uv + (-ex * 0.375 + ey * 0.125) * spread, lod).rgb;
		colour *= 0.25;
		edge_paint = textureLod(TEXTURE, picture_uv(q), blurred_lod(size.x)).rgb;
	}

	colour = mix(colour, POOL_INK, pool_mask(q) * pool_strength);

	if (living) {
		// The eyes' light over the pool (it glimmers through the dark),
		// screened in; the dust; the portrait's mood.
		vec3 light = eye_colour * eye_light(q);
		colour = 1.0 - (1.0 - colour) * (1.0 - clamp(light, 0.0, 1.0));
		colour += vec3(0.86, 0.80, 0.68) * motes(q) * dust * 0.06;
		colour = mix(colour, colour * vec3(1.10, 0.97, 0.80) + vec3(0.025, 0.012, 0.0), warmth * 0.6);
		float l = dot(colour, vec3(0.299, 0.587, 0.114));
		colour = mix(colour, vec3(l) * 0.85, grey * 0.55);
		float sink = vnoise(vec2(TIME * 9.0, 1.3)) * 0.65 + vnoise(vec2(TIME * 23.0, 5.2)) * 0.35;
		colour *= 1.0 - flicker * 0.3 * smoothstep(0.3, 0.85, sink);
	}

	// Whole paint inside the ragged line, soft only over fray_soft px: no
	// see-through band (the reference faded over up to a third of the reach).
	float depth = fray_depth(p);
	float a = pow(clamp(depth / fray_soft, 0.0, 1.0), 1.25);
	// Pigment pools where the brush lifts.
	float rim = exp(-pow((depth - fray_soft * 1.4) / (fray_soft * 1.1), 2.0)) * 0.28 * step(0.0, depth);
	colour *= 1.0 - rim;

	// The dry strokes, under the body: their colour is the edge's own.
	float s = 0.0;

	if (p.x > pad * 2.0 && p.x < picture_size.x - pad * 2.0) {
		s = max(s, strokes_along(p.x, -p.y, 0.0));
		s = max(s, strokes_along(p.x, p.y - (picture_size.y - 1.0), 1.0));
	}

	if (p.y > pad * 2.0 && p.y < picture_size.y - pad * 2.0) {
		s = max(s, strokes_along(p.y, -p.x, 2.0));
		s = max(s, strokes_along(p.y, p.x - (picture_size.x - 1.0), 3.0));
	}

	vec3 edge_colour = mix(procedural ? colour : edge_paint, POOL_INK, pool_mask(q) * pool_strength);
	float alpha = a + s * (1.0 - a);
	vec3 rgb = alpha > 0.0 ? (colour * a + edge_colour * s * (1.0 - a)) / alpha : colour;

	// Painted in (and out): down where the reveal has passed its time,
	// with a darker wet line at the front.
	if (reveal < 1.0) {
		float when = paint_time(p, clamp(p / picture_size, 0.0, 1.0));
		float ahead = reveal * 1.04 - when;
		alpha *= smoothstep(-0.006, 0.006, ahead);
		rgb *= 1.0 - 0.45 * (1.0 - smoothstep(0.0, 0.035, ahead));
	}

	COLOR = vec4(rgb, alpha * COLOR.a);
}
