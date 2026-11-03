shader_type canvas_item;
// What a revenant has done to your sight. Not shown, felt. Soaked (`soaked`): lake water, cold and wet at the edges of your sight, running up
// it against all sense. Its touch (`touch`), for as long as it's on you: the dark of the water at your corners, with the thin light of the
// seep at its front, slow, like something breathing. The middle third is never touched. Painted, as the others are, and not them: it is cold.

uniform float soaked = 0.0;
uniform float touch = 0.0;
uniform sampler2D stroke_sheet : filter_linear_mipmap, repeat_enable;

const vec3 COLD = vec3(0.035, 0.07, 0.075);
const vec3 BLACK_WATER = vec3(0.004, 0.009, 0.008);
const vec3 SEEP = vec3(0.5, 0.83, 0.42);

void fragment() {
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 p = (UV - 0.5) * 2.0;
	// Squarish: it comes in from the edges, most at the corners; 0 at the middle third's edge, 1 at the screen's.
	float out_x = abs(p.x);
	float out_y = abs(p.y);
	float edge = smoothstep(0.34, 1.05, max(out_x, out_y) * 0.55 + length(p) * 0.4);
	vec2 at = vec2(UV.x * aspect, UV.y);
	float stroke = texture(stroke_sheet, at * 0.9 + vec2(0.0, TIME * 0.006)).r;
	float fine = texture(stroke_sheet, at * 2.3 - vec2(TIME * 0.004, 0.0)).r;
	// Soaked: streaks, running up.
	float run = texture(stroke_sheet, vec2(at.x * 3.4, at.y * 0.4 + TIME * 0.05)).r;
	float wet = smoothstep(0.32, 0.72, edge * 1.1 + (stroke - 0.5) * 0.3);
	float rivulets = smoothstep(0.58, 0.66, run) * smoothstep(0.1, 0.6, edge);
	float wet_shown = soaked * clamp(wet * 0.62 + rivulets * 0.5, 0.0, 0.8);
	// Its touch: closing in, ragged, and lit at its front.
	float line = edge + (stroke - 0.5) * 0.26 + (fine - 0.5) * 0.1;
	float breath = 0.5 + 0.5 * sin(TIME * 1.15);
	float reach = mix(0.74, 0.62, breath);
	float dark = smoothstep(reach, reach + 0.05, line) * touch;
	float front = smoothstep(reach - 0.012, reach + 0.004, line) * (1.0 - smoothstep(reach + 0.004, reach + 0.03, line));
	vec3 colour = mix(COLD, BLACK_WATER, clamp(dark * 2.0, 0.0, 1.0));
	colour += SEEP * front * touch * (0.3 + breath * 0.45);
	COLOR = vec4(colour, clamp(max(wet_shown, dark * 0.92) + front * touch * 0.8, 0.0, 1.0));
}
