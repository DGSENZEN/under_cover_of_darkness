shader_type canvas_item;
// Your magic and your life being drunk (LifeLeech.gd): not shown, felt, in your sight. As
// your magic goes the colour goes out of everything; as your life goes the dark closes in.
// Round it, from the edges, it goes corpse-green and thin, rot blotching through it, the low
// sick fire of what has hold of you at its front, deeper with each one on you. With each
// gulp your sight dims and is dragged toward the hand that has you, and a soft green mist
// streams in to it. The middle stays clear enough to fight. Thrown off, colour floods back
// past where it was (`release`). Painted, as evil_eye_view is, and drawn under it.

uniform float drain = 0.0;
uniform float release = 0.0;
// The last gulp: 1 as it lands, down to 0.
uniform float gulp = 0.0;
// How much magic and life you have left, 0..1.
uniform float magic = 1.0;
uniform float life = 1.0;
// Each hand that has you: where it is on the screen, 0..1, and how much to show.
uniform vec3 threads[3];
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D stroke_sheet : repeat_enable, filter_linear_mipmap;

const vec3 CORPSE = vec3(0.5, 0.68, 0.4);
const vec3 GRAVE = vec3(0.1, 0.2, 0.07);
const vec3 ROT = vec3(0.012, 0.03, 0.012);
const vec3 SICK = vec3(0.56, 0.78, 0.12);
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
	vec2 way_out = a / max(length(a), 0.001);

	// Your sight, dragged toward whatever has hold of you, the more with each gulp.
	vec2 dragged = vec2(0.0);

	for (int i = 0; i < 3; i++) {
		if (threads[i].z > 0.01) {
			vec2 to_it = threads[i].xy - UV;
			// (Nothing at the grip itself: it would pinch into a whirlpool there.)
			dragged += to_it / max(length(to_it), 0.001) * exp(-length(to_it) * 1.4) * smoothstep(0.08, 0.34, length(to_it)) * threads[i].z;
		}
	}

	dragged *= (0.005 * drain + gulp * 0.03) * smoothstep(0.15, 1.1, out_from_middle);
	vec3 col = texture(screen_tex, SCREEN_UV + dragged).rgb;
	float grain = textureLod(stroke_sheet, a * 0.28 + vec2(TIME * 0.008, 0.0), 0.0).r;
	float value = dot(col, vec3(0.3, 0.55, 0.15));

	// Your magic going: the colour leaves all of it, the middle too, and a gulp takes more.
	float held = step(0.001, drain);
	float colourless = clamp((1.0 - magic) * 0.78 + gulp * 0.38, 0.0, 0.92) * held;
	col = mix(col, value * CORPSE * 1.05, colourless);
	// Each gulp dims it.
	col *= 1.0 - gulp * 0.24 * held;

	// Bled out from the edges in, pulsed further in by each gulp. Never over the middle.
	float reach = mix(1.5, CLEAR, drain) - gulp * 0.16 * step(0.001, drain);
	float bled = smoothstep(reach - 0.14, reach + 0.2, out_from_middle + (grain - 0.5) * 0.34);
	bled *= smoothstep(CLEAR - 0.08, CLEAR + 0.1, out_from_middle);
	// Long strokes running in from the edges, so it is a wash of paint and not a fog.
	float streak = textureLod(stroke_sheet, way_out * 0.42 + a * 0.05, 0.0).r;
	bled *= mix(0.45, 1.0, smoothstep(0.3, 0.65, streak));
	// No blood in it: corpse-green and thin, its darks lifted into the grave's colour.
	vec3 thin = value * CORPSE * 0.95 + GRAVE * (0.1 + 0.26 * streak + gulp * 0.16);
	col = mix(col, thin, bled * clamp(drain * 1.3, 0.0, 0.9));
	// Rot blotching through it, dark, in the brush's shapes.
	float blotch = textureLod(stroke_sheet, a * 0.13 + vec2(0.31, TIME * 0.004), 0.0).r;
	float rot = smoothstep(0.5, 0.64, blotch * 0.65 + streak * 0.35) * smoothstep(CLEAR + 0.1, CLEAR + 0.5, out_from_middle);
	col = mix(col, ROT, rot * bled * drain * 0.72);
	// Its front: low sick fire licking in, torn by the brush, up with each gulp.
	float lick = textureLod(stroke_sheet, a * 0.3 + vec2(0.13, TIME * -0.05), 0.0).r;
	float tear = textureLod(stroke_sheet, a * 0.09 + vec2(TIME * 0.012, 0.47), 0.0).r;
	float front = out_from_middle - reach - (lick - 0.5) * 0.42;
	float flame = exp(-front * front * 70.0) * smoothstep(0.52, 0.66, lick) * smoothstep(0.42, 0.58, tear);
	col += SICK * flame * step(0.001, drain) * smoothstep(CLEAR - 0.02, CLEAR + 0.12, out_from_middle) * (0.12 + gulp * 0.3) * clamp(drain * 2.0, 0.0, 1.0) * (1.0 - release);

	// A soft mist of it, streaming in to each hand that has you.
	for (int i = 0; i < 3; i++) {
		if (threads[i].z > 0.01) {
			vec2 to = vec2((threads[i].x * 2.0 - 1.0) * aspect, threads[i].y * 2.0 - 1.0);
			vec2 from_it = a - to;
			float away = length(from_it);
			vec2 way = from_it / max(away, 0.001);
			float smoke = textureLod(stroke_sheet, way * 0.45 + vec2(away * 0.32 + TIME * 0.11 + float(i) * 0.37, float(i)), 0.0).r;
			float mist = smoothstep(0.42, 0.74, smoke) * exp(-away * 1.15) * smoothstep(0.2, 0.55, away);
			col = mix(col, value * CORPSE * 0.6 + GRAVE * 0.75 + SICK * 0.05, mist * (0.28 + gulp * 0.42) * threads[i].z);
		}
	}

	// Your life going: the dark closes in, breathing with each gulp. Never quite to the middle.
	float closing = (1.0 - life) * held;
	float dark = smoothstep(mix(1.7, 0.62, closing) - gulp * 0.1, mix(1.9, 1.05, closing), out_from_middle + (grain - 0.5) * 0.2);
	col = mix(col, ROT * 0.5, dark * clamp(closing * 1.6, 0.0, 0.94));

	// Free: it comes back, and more than it was, for a moment.
	col = mix(col, col * 1.4 + WARM * 0.05 * (0.5 + 0.5 * out_from_middle), release);
	COLOR = vec4(col, 1.0);
}
