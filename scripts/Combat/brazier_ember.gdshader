shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
// A hot ember: a point with a soft edge, turned to face you, cooling through its colours.

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	float r = length((UV - 0.5) * 2.0);
	ALBEDO = COLOR.rgb;
	ALPHA = smoothstep(1.0, 0.25, r) * COLOR.a;
}
