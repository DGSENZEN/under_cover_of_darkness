shader_type canvas_item;
// One option's painted brush swipe in the talk box (draft 28's swipe_mask and
// painted_swipe, .superpowers/talkbox/draft28_reference.py): bristle lines
// run across it, each starting and ending a little apart, frayed with small
// holes only at its outer ends (the left 4%, the right 5%).
//   - Paint: a skin's painting (paint, region: a rect of it in UV), or the
//     plain skin's colours (paint_dark, paint_warm), at `light`; past 1 the
//     chosen swipe is washed toward `wash` by wash_amount.
//   - The chosen swipe carries the marker at its right end (marker_x, in px
//     from its left, marker_width wide): the skin's cursor painting cut to
//     the swipe's height about its tip (cursor_tip of its height), or a
//     painted spike pointing back at the words. It frays with the bristles.
//   - A special option of a school (`school`, 1 + its index in
//     DialogueBook.SCHOOLS) paints itself in that school's look instead
//     (talk_school.gdshaderinc), chosen (`warm`) or not; 0 is the plain paint.
// Everything is in the swipe's pixels at 1080p (swipe_size).
// `reveal` (0..1) paints it in from the left, each bristle at its own pace,
// a darker wet line at each front.

uniform vec2 swipe_size = vec2(400.0, 42.0);
uniform float seed = 20.0;
uniform float light = 0.5;
uniform float alpha_scale = 0.9;
uniform vec3 paint_dark = vec3(0.55, 0.42, 0.52);
uniform vec3 paint_warm = vec3(0.62, 0.48, 0.26);
uniform bool warm = false;
uniform bool use_paint = false;
uniform sampler2D paint : filter_linear_mipmap, repeat_disable;
uniform vec4 region = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec3 wash = vec3(0.8706, 0.7294, 0.4627);
uniform float wash_amount = 0.78;
uniform float marker_x = -1.0;
uniform float marker_width = 150.0;
uniform bool use_cursor = false;
uniform sampler2D cursor : filter_linear_mipmap, repeat_disable;
uniform float cursor_tip = 0.685;
uniform float cursor_aspect = 1.0;
// The cursor's colour, as draft 28 has it: its saturation, then its grey
// times cursor_tint mixed in by cursor_tint_amount (the librarian's red).
uniform float cursor_saturation = 1.0;
uniform vec3 cursor_tint = vec3(1.0);
uniform float cursor_tint_amount = 0.0;
uniform float reveal = 1.0;
uniform int school = 0;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21) + seed * 0.173);
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// One bristle (a row about 1.4 px high): how much paint it lays at x.
// The brush's bristle lines, as draft 28's swipe_mask draws them: h * 2.2
// lines laid across the middle 76% of its height, each from a start in the
// first 10% to an end in the last 16%, a little off level (up to 2 px over
// its length), 1, 2 or 3 px wide, of its own strength (150..255); where they
// cross, the one laid last shows. Here each line is one of a stack spread
// evenly down the band (jittered), and "laid last" is a random rank.
const float LINES_PER_PX = 2.2;
const float BAND_TOP = 0.12;
const float BAND_BOTTOM = 0.88;

float mask(vec2 p) {
	float w = swipe_size.x;
	float h = swipe_size.y;
	float spacing = (BAND_BOTTOM - BAND_TOP) / LINES_PER_PX;
	float first = floor((p.y - 3.5 - BAND_TOP * h) / spacing) - 2.0;
	float cover = 0.0;
	float value = 0.0;
	float rank = -1.0;

	for (int i = 0; i < 28; i++) {
		float k = first + float(i);

		if (k < 0.0) {
			continue;
		}

		if (k >= floor(h * LINES_PER_PX)) {
			break;
		}

		float x0 = hash(vec2(k, 1.0)) * 0.10 * w;
		float x1 = (0.84 + 0.16 * hash(vec2(k, 2.0))) * w;
		float t = clamp((p.x - x0) / max(x1 - x0, 1.0), 0.0, 1.0);
		float y = BAND_TOP * h + (k + (hash(vec2(k, 3.0)) - 0.5) * 2.4) * spacing + (hash(vec2(k, 4.0)) - 0.5) * 4.0 * t;
		float pick = hash(vec2(k, 5.0));
		float thick = pick < 0.25 ? 1.0 : (pick < 0.75 ? 2.0 : 3.0);
		// Soft by about the reference's 0.8 px blur.
		float across = 1.0 - smoothstep(thick * 0.5 - 0.6, thick * 0.5 + 0.6, abs(p.y - y));
		float along = smoothstep(x0 - 0.6, x0 + 0.6, p.x) * (1.0 - smoothstep(x1 - 0.6, x1 + 0.6, p.x));
		float c = across * along;

		if (c <= 0.0) {
			continue;
		}

		float order = hash(vec2(k, 6.0));
		float v = mix(150.0, 255.0, hash(vec2(k, 7.0))) / 255.0;

		// The last laid shows; a softer edge under it lets the one below through.
		if (order > rank) {
			value = mix(value, v, c);
			rank = c > 0.5 ? order : rank;
		}

		cover = max(cover, c);
	}

	float m = value * smoothstep(0.0, 1.0, cover * 1.6);
	// The dry ends: a few small holes (the reference's w * 0.12 ellipses,
	// 0.6-1.6 px across) in the outer 4% and 5%.
	float ends = max(1.0 - step(0.04 * w, p.x), step(0.95 * w, p.x));
	float holes = smoothstep(0.80, 0.88, vnoise(p / vec2(1.4, 0.7) + 13.0));
	return m * (1.0 - ends * holes);
}

#include "res://scripts/UI/talk_school.gdshaderinc"

// The plain skin's marker: a dark spike, its tip at the left pointing back at
// the words, widening to a pale head at its right end.
vec4 spike(vec2 p) {
	float t = (p.x - marker_x) / marker_width;

	if (t < 0.0 || t > 1.0) {
		return vec4(0.0);
	}

	float h = swipe_size.y;
	float mid = h * 0.5;
	float half_width = h * 0.21 * smoothstep(0.02, 0.7, t);
	float across = abs(p.y - mid);
	float blade = 1.0 - smoothstep(half_width - 1.0, half_width + 0.6, across);
	vec2 head_centre = vec2(marker_x + marker_width * 0.84, mid);
	float head = 1.0 - smoothstep(0.85, 1.05, length((p - head_centre) / vec2(marker_width * 0.13, h * 0.34)));
	float grain = 0.8 + 0.35 * vnoise(p / vec2(9.0, 1.4));
	// Pale steel, lit along its top, streaked dark along its length.
	vec3 steel = mix(vec3(0.42, 0.42, 0.45), vec3(0.86, 0.85, 0.82), smoothstep(-0.6, 0.8, (mid - p.y) / max(half_width, 0.5)));
	steel *= 0.7 + 0.45 * vnoise(p / vec2(14.0, 0.9) + 3.0);
	vec3 bone = vec3(0.36, 0.34, 0.33) * grain;
	vec3 colour = mix(steel * grain, bone, head);
	return vec4(colour, max(blade, head));
}

// The skin's paint for the swipe at `uv`: its region of the painting
// squeezed into the swipe, far more down than across (as the reference's
// resize): taps along the squeezed way, from the level the other way needs.
vec3 paint_at(vec2 uv) {
	vec2 at = region.xy + uv * region.zw;
	vec2 size = vec2(textureSize(paint, 0));
	vec2 ex = dFdx(at);
	vec2 ey = dFdy(at);
	float lx = length(ex * size);
	float ly = length(ey * size);
	vec2 major = lx > ly ? ex : ey;
	float minor = min(lx, ly);
	float lod = max(0.0, log2(max(minor, 0.0001)));
	int taps = clamp(int(ceil(max(lx, ly) / max(minor, 1.0))), 1, 8);
	vec3 sum = vec3(0.0);

	for (int i = 0; i < 8; i++) {
		if (i >= taps) {
			break;
		}

		sum += textureLod(paint, at + major * ((float(i) + 0.5) / float(taps) - 0.5), lod).rgb;
	}

	return sum / float(taps);
}

vec4 cursor_cut(vec2 p) {
	float t = (p.x - marker_x) / marker_width;

	if (t < 0.0 || t > 1.0) {
		return vec4(0.0);
	}

	float tall = marker_width / max(cursor_aspect, 0.01);
	float v = cursor_tip + (p.y - swipe_size.y * 0.5) / tall;
	vec4 c = texture(cursor, vec2(t, v));
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	c.rgb = mix(vec3(l), c.rgb, cursor_saturation);
	l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	c.rgb = mix(c.rgb, vec3(l) * cursor_tint, cursor_tint_amount);
	// Its rim softened, as the reference's blurred box.
	c.a *= smoothstep(0.0, 0.03, t) * smoothstep(0.0, 2.0, p.y) * smoothstep(0.0, 2.0, swipe_size.y - p.y);
	c.rgb = mix(c.rgb, wash, 0.08);
	return c;
}

void fragment() {
	vec2 p = UV * swipe_size;
	float m = mask(p);
	vec3 colour;

	if (school > 0) {
		colour = school_paint(school, p, UV);
	} else {
		if (use_paint) {
			colour = paint_at(UV);
		} else {
			colour = (warm ? paint_warm : paint_dark) * (0.82 + 0.36 * vnoise(p / vec2(38.0, 2.0)));
		}

		colour *= light;

		if (light > 1.0) {
			colour = mix(colour, wash, wash_amount);
		}
	}

	float alpha = m * alpha_scale;

	if (marker_x >= 0.0) {
		vec4 mark = use_cursor ? cursor_cut(p) : spike(p);
		mark.a *= min(1.0, m * alpha_scale * 1.4);
		colour = mix(colour, mark.rgb, mark.a);
		alpha = max(alpha, mark.a);
	}

	// Laid from the left along its bristles, each its own pace.
	if (reveal < 1.0) {
		float row = floor(p.y / 1.4);
		float front = reveal * 1.2 - hash(vec2(row, 9.0)) * 0.2;
		float ahead = front - UV.x;
		alpha *= smoothstep(-0.004, 0.004, ahead);
		colour *= 1.0 - 0.4 * (1.0 - smoothstep(0.0, 0.03, ahead));
	}

	COLOR = vec4(colour, alpha * COLOR.a);
}
