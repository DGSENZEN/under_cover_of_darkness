shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
// What burns in a revenant's socket, seen from anywhere: a thin line of light on a soft one, breathing. Its colour is the seeped's.

uniform vec3 colour : source_color = vec3(0.5, 0.83, 0.42);
instance uniform float hot = 0.0;
instance uniform float phase = 0.0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float breath = 0.82 + 0.18 * sin(TIME * 2.3 + phase) * sin(TIME * 3.7 + phase * 2.0);
	float soft = pow(max(1.0 - r, 0.0), 2.6);
	// Long and thin across, as an eye is.
	float across = pow(max(1.0 - abs(p.y) * 9.0, 0.0), 2.0) * pow(max(1.0 - abs(p.x), 0.0), 1.2);
	float core = smoothstep(0.2, 0.1, r);
	ALBEDO = (colour * (soft * 0.5 + across * 0.7) + vec3(1.0, 1.1, 0.85) * core * 1.4) * breath * (1.0 + hot * 1.2);
}
