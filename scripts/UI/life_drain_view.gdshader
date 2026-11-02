shader_type canvas_item;
// Your willpower and your life being drunk (LifeLeech.gd), on the screen. Colour bleeds
// out of the world from the edges in, toward a cold grey, deeper with each one on you,
// the brush's grain on its edge; the middle stays clear, so you can still fight. Wisps
// of your own warmth are drawn from your sight toward whatever has hold of you, so you
// can see where to turn. Thrown off, colour floods back past where it
// was (`release`). Painted, as evil_eye_view is, and drawn under it.

uniform float drain = 0.0;
uniform float release = 0.0;
// Each one holding you: where it is on the screen, 0..1 (off it if out of sight), and
// how much of a thread to show.
uniform vec3 threads[3];
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D stroke_sheet : repeat_enable, filter_linear_mipmap;

const vec3 COLD = vec3(0.62, 0.66, 0.72);
const vec3 WARM = vec3(1.0, 0.58, 0.28);
const float CLEAR = 0.42;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 a = vec2(p.x * aspect, p.y);
	float out_from_middle = length(p);
	vec3 col = texture(screen_tex, SCREEN_UV).rgb;
	float grain = textureLod(stroke_sheet, a * 0.28 + vec2(TIME * 0.008, 0.0), 0.0).r;

	// Bled out from the edges in. Never over the middle.
	float reach = mix(1.5, CLEAR, drain);
	float bled = smoothstep(reach - 0.14, reach + 0.2, out_from_middle + (grain - 0.5) * 0.3);
	bled *= smoothstep(CLEAR - 0.1, CLEAR + 0.12, out_from_middle);
	float value = dot(col, vec3(0.3, 0.55, 0.15));
	col = mix(col, value * COLD * 0.9, bled * clamp(drain * 1.4, 0.0, 0.95));

	// What is being drawn out of you, to what has hold of you: wisps of your own warmth,
	// thick and thin as the brush went, bowing and wavering, drawn off in slow pulses.
	for (int i = 0; i < 3; i++) {
		if (threads[i].z > 0.01) {
			vec2 to = vec2((threads[i].x * 2.0 - 1.0) * aspect, threads[i].y * 2.0 - 1.0);
			vec2 from = normalize(to + vec2(0.0001)) * CLEAR * 1.05;
			vec2 along = to - from;
			float length_of = max(length(along), 0.001);
			vec2 way = along / length_of;
			float t = dot(a - from, way) / length_of;

			if (t > 0.0 && t < 1.0) {
				vec2 side = vec2(-way.y, way.x);
				float across = dot(a - from, side);
				float arc = sin(t * 3.1416);

				for (int k = 0; k < 3; k++) {
					float seed = float(k) * 1.7 + float(i) * 3.1;
					float bow = (hash(vec2(seed, 1.0)) - 0.5) * 0.5 * arc;
					float brush = textureLod(stroke_sheet, vec2(t * 1.2 + seed * 0.3 - TIME * 0.09, seed * 0.17), 0.0).r;
					float wander = (brush - 0.5) * 0.14 * arc + sin(t * 7.0 - TIME * 1.6 + seed) * 0.022 * arc;
					float off = across - bow - wander;
					float wide = (0.004 + brush * 0.016) * smoothstep(0.0, 0.25, t) * mix(1.0, 0.25, t);
					float wisp = 1.0 - smoothstep(wide * 0.35, wide, abs(off));
					float pulse = smoothstep(0.0, 0.6, sin(t * 7.0 - TIME * 2.4 + seed * 2.0) * 0.5 + 0.5);
					float fades = smoothstep(0.0, 0.1, t) * smoothstep(0.75, 0.3, t);
					vec3 warmth = mix(WARM, WARM * vec3(0.55, 0.22, 0.2), t);
					col = mix(col, warmth, wisp * mix(0.08, 0.42, pulse) * fades * threads[i].z);
				}
			}
		}
	}

	// Free: it comes back, and more than it was, for a moment.
	col = mix(col, col * 1.22 + WARM * 0.025, release);
	COLOR = vec4(col, 1.0);
}
