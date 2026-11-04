shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled;
// The smoke it trails, what a censer is for: thin, in the brush's shapes, and turned to face you.

uniform sampler2D stroke_sheet : filter_linear_mipmap, repeat_enable;
// How far the brush tears it up: enough, and it's rags of vapour, never a ball.
uniform float torn = 0.0;

varying float phase;
varying float not_in_your_face;

void vertex() {
	phase = fract(MODEL_MATRIX[3].x * 0.37 + float(INSTANCE_ID) * 0.13);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	// (A hand from your eye, it would be a blot on your eye, not smoke.)
	not_in_your_face = smoothstep(0.8, 2.2, -MODELVIEW_MATRIX[3].z);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float brush = texture(stroke_sheet, UV * 0.5 + vec2(phase, TIME * 0.02)).r;
	float soft = smoothstep(1.0, 0.1, length(p) + (brush - 0.5) * 1.1);
	ALBEDO = COLOR.rgb;
	float rags = mix(1.0, smoothstep(0.42, 0.68, texture(stroke_sheet, vec2(UV.x * 0.28 + phase, UV.y * 0.9 - TIME * 0.05)).r), torn);
	ALPHA = soft * soft * COLOR.a * rags * not_in_your_face;
}
