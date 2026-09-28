// A bat (Wildlife): our painting's two frames (wings down, wings up) beaten
// at its own pace, always turned to the eye, a black shape against the sky
// (unfogged: the sky it is seen against is not fogged either).
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;

uniform sampler2D frames : source_color, filter_nearest, repeat_disable;
uniform float beats = 9.0;
instance uniform float phase = 0.0;

void vertex() {
	// Turned to the eye (a billboard), its own size kept.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz), INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz),
		INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz), MODEL_MATRIX[3]);
}

void fragment() {
	float frame = floor(fract(TIME * beats / 2.0 + phase) * 2.0);
	vec4 paint = texture(frames, vec2((UV.x + frame) * 0.5, UV.y));
	ALBEDO = paint.rgb;
	ALPHA = paint.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
