shader_type spatial;
render_mode depth_draw_never, cull_back;
// What's got you, on your hands: from the knuckles out, the skin goes the drowned's grey, torn by the brush, with the seep's thin lines running in it. Laid over the arms as they are, and only as far as `reach` from each hand.

uniform sampler2D stroke_sheet : filter_linear_mipmap, repeat_enable;
uniform float seep = 0.0;
uniform float reach = 0.0;
uniform vec3 right_hand = vec3(0.0);
uniform vec3 left_hand = vec3(0.0);
// The viewmodel's depth squeeze, and field of view (HandSlot's others).
uniform float z_clip = 1.0;
uniform float fov_override = 0.0;

const vec3 DROWNED = vec3(0.11, 0.14, 0.135);
const vec3 SEEP = vec3(0.5, 0.83, 0.42);

varying vec3 world_at;
varying vec2 skin_at;

void vertex() {
	world_at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	skin_at = UV;
	Z_CLIP_SCALE = z_clip;

	if (fov_override > 0.0) {
		float f = 1.0 / tan(radians(fov_override) * 0.5);
		float aspect = abs(PROJECTION_MATRIX[1][1] / PROJECTION_MATRIX[0][0]);
		PROJECTION_MATRIX[1][1] = f * sign(PROJECTION_MATRIX[1][1]);
		PROJECTION_MATRIX[0][0] = f / aspect * sign(PROJECTION_MATRIX[0][0]);
	}
}

void fragment() {
	float brush = texture(stroke_sheet, skin_at * 3.1).r;
	float fine = texture(stroke_sheet, skin_at * 8.7 + vec2(0.0, TIME * 0.015)).r;
	float near = min(length(world_at - right_hand), length(world_at - left_hand));
	float in_it = 1.0 - smoothstep(reach * 0.6, reach, near + (brush - 0.5) * reach * 0.7);
	// (A few thin lines of it, under the skin: never a pattern over it.)
	float vein = 1.0 - abs(texture(stroke_sheet, skin_at * 2.3 - vec2(TIME * 0.008, 0.0)).r * 2.0 - 1.0);
	float line = smoothstep(0.972, 0.996, vein) * smoothstep(0.5, 0.66, fine);
	ALBEDO = mix(DROWNED, DROWNED * 0.45, smoothstep(0.42, 0.62, brush) * 0.7) + SEEP * line * 0.12;
	ROUGHNESS = 0.6;
	EMISSION = SEEP * line * in_it * seep * 0.32;
	ALPHA = clamp(in_it * seep * 0.72, 0.0, 1.0);
}
