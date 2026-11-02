shader_type canvas_item;
// Your willpower and your life being drunk (LifeLeech.gd), on the screen: the grave coming
// up in you. From the edges in your sight goes corpse-green, thin and cold, rot blotching
// through it in long brush-marked strokes, with the low sick fire of what has hold of you
// licking along its front, deeper with each one on you. The middle stays clear, so you can
// still fight. It comes in gulps: each pulses it inward, and a bead of your warmth is drawn
// along each wisp, going green as it goes, to whatever has hold of you, which glows there
// with what it has taken. Thrown off, colour floods back past where it was (`release`).
// Painted, as evil_eye_view is, and drawn under it.

uniform float drain = 0.0;
uniform float release = 0.0;
// The last gulp: 1 as it lands, down to 0.
uniform float gulp = 0.0;
// Each one holding you: where it is on the screen, 0..1 (off it if out of sight), and
// how much of a thread to show.
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
	vec3 col = texture(screen_tex, SCREEN_UV).rgb;
	vec2 way_out = a / max(length(a), 0.001);
	float grain = textureLod(stroke_sheet, a * 0.28 + vec2(TIME * 0.008, 0.0), 0.0).r;

	// Bled out from the edges in, pulsed further in by each gulp. Never over the middle.
	float reach = mix(1.5, CLEAR, drain) - gulp * 0.16 * step(0.001, drain);
	float bled = smoothstep(reach - 0.14, reach + 0.2, out_from_middle + (grain - 0.5) * 0.34);
	bled *= smoothstep(CLEAR - 0.08, CLEAR + 0.1, out_from_middle);
	float value = dot(col, vec3(0.3, 0.55, 0.15));
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

	// What is being drawn out of you, to what has hold of you: wisps of your own warmth,
	// wavering, with a bead going down each with every gulp; and where it is going, a
	// glow of what it has taken.
	for (int i = 0; i < 3; i++) {
		if (threads[i].z > 0.01) {
			vec2 to = vec2((threads[i].x * 2.0 - 1.0) * aspect, threads[i].y * 2.0 - 1.0);
			float at_it = length(a - to);
			col += SICK * exp(-at_it * at_it * 9.0) * (0.05 + gulp * 0.2) * threads[i].z;
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
					float wide = (0.003 + brush * 0.011) * smoothstep(0.0, 0.25, t) * mix(1.0, 0.3, t);
					float wisp = 1.0 - smoothstep(wide * 0.35, wide, abs(off));
					float fades = smoothstep(0.0, 0.1, t) * smoothstep(1.0, 0.45, t);
					vec3 warmth = mix(WARM, SICK, smoothstep(0.1, 0.75, t));
					col = mix(col, warmth, wisp * 0.2 * fades * threads[i].z);
					// The bead: where this gulp has got to.
					if (k == 0) {
						float bead_at = (1.0 - gulp) * 1.1;
						float along_bead = (t - bead_at) * length_of;
						float bead = exp(-along_bead * along_bead * 900.0 - off * off * 5200.0);
						col += mix(WARM, SICK, smoothstep(0.1, 0.75, t)) * bead * 0.55 * step(0.001, gulp) * threads[i].z;
					}
				}
			}
		}
	}

	// Free: it comes back, and more than it was, for a moment.
	col = mix(col, col * 1.4 + WARM * 0.05 * (0.5 + 0.5 * out_from_middle), release);
	COLOR = vec4(col, 1.0);
}
