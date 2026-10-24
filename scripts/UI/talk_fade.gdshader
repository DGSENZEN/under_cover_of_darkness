shader_type canvas_item;
// The talk box's options fade (TalkBox._build_fade), over the list's edge
// where more options are hidden beyond it: dark paint deepening toward its
// outer edge (down: the bottom) in dry bristle streaks, three small marigold
// dabs at its middle.

uniform bool down = true;
uniform float seed = 0.0;
uniform vec3 paint = vec3(0.1);
uniform vec3 dab = vec3(0.95, 0.69, 0.2);

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21) + seed * 0.173);
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	float out_v = down ? UV.y : 1.0 - UV.y;
	float row = floor(UV.y * 14.0);
	float streak = 0.75 + 0.25 * hash(vec2(row, floor(UV.x * 40.0)));
	float ends = smoothstep(0.0, 0.08, UV.x) * smoothstep(1.0, 0.9, UV.x);
	float a = smoothstep(0.0, 1.0, out_v) * 0.85 * streak * ends;
	// The dabs, in the fade's own pixels.
	vec2 size = 1.0 / max(fwidth(UV), vec2(0.0001));
	vec2 px = UV * size;
	float d = 9.0;

	for (int i = -1; i <= 1; i++) {
		d = min(d, length(px - vec2(size.x * 0.5 + float(i) * 9.0, size.y * 0.55)));
	}

	float dot_a = (1.0 - smoothstep(1.4, 2.4, d)) * 0.8;
	COLOR = vec4(mix(paint, dab, dot_a), max(a, dot_a) * COLOR.a);
}
