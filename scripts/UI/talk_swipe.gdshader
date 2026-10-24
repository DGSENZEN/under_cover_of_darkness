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
uniform float reveal = 1.0;

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
float bristle(float row, float x) {
	float w = swipe_size.x;
	float x0 = hash(vec2(row, 1.0)) * 0.10 * w;
	float x1 = (0.84 + 0.16 * hash(vec2(row, 2.0))) * w;
	float v = mix(150.0, 255.0, hash(vec2(row, 3.0))) / 255.0;
	float on = smoothstep(x0, x0 + 3.0, x) * (1.0 - smoothstep(x1 - 3.0, x1, x));
	// Here and there a thin one: the paint runs out between them.
	float thin = hash(vec2(row, 4.0)) < 0.16 ? 0.5 : 1.0;
	return v * on * thin;
}

float mask(vec2 p) {
	float h = swipe_size.y;
	float y = p.y / 1.4;
	float row = floor(y);
	float m = mix(bristle(row, p.x), bristle(row + 1.0, p.x), smoothstep(0.2, 0.8, fract(y)));
	m *= smoothstep(0.10 * h, 0.15 * h, p.y) * (1.0 - smoothstep(0.85 * h, 0.90 * h, p.y));
	// The dry ends: small holes in the outer 4% and 5%.
	float w = swipe_size.x;
	float ends = max(1.0 - smoothstep(0.0, 0.04 * w, p.x), smoothstep(0.95 * w, w, p.x));
	float holes = smoothstep(0.5, 0.62, vnoise(p / vec2(1.6, 0.8) + 13.0));
	return m * (1.0 - ends * holes);
}

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

vec4 cursor_cut(vec2 p) {
	float t = (p.x - marker_x) / marker_width;

	if (t < 0.0 || t > 1.0) {
		return vec4(0.0);
	}

	float tall = marker_width / max(cursor_aspect, 0.01);
	float v = cursor_tip + (p.y - swipe_size.y * 0.5) / tall;
	vec4 c = texture(cursor, vec2(t, v));
	// Its rim softened, as the reference's blurred box.
	c.a *= smoothstep(0.0, 0.03, t) * smoothstep(0.0, 2.0, p.y) * smoothstep(0.0, 2.0, swipe_size.y - p.y);
	c.rgb = mix(c.rgb, wash, 0.08);
	return c;
}

void fragment() {
	vec2 p = UV * swipe_size;
	float m = mask(p);
	vec3 colour;

	if (use_paint) {
		colour = texture(paint, region.xy + UV * region.zw).rgb;
	} else {
		colour = (warm ? paint_warm : paint_dark) * (0.82 + 0.36 * vnoise(p / vec2(38.0, 2.0)));
	}

	colour *= light;

	if (light > 1.0) {
		colour = mix(colour, wash, wash_amount);
	}

	float alpha = m * alpha_scale;

	if (marker_x >= 0.0) {
		vec4 mark = use_cursor ? cursor_cut(p) : spike(p);
		mark.a *= min(1.0, m * 1.4);
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
