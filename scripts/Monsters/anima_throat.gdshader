// What it swallows, showing a long way down its throat: a low sick light behind the teeth,
// coming up with each gulp (`flare`), out when it isn't drinking. Drawn into the black of
// its mouth, in the world and in your view.
shader_type spatial;
render_mode unshaded, depth_draw_never, blend_add, shadows_disabled, cull_back;

uniform vec4 glow : source_color = vec4(0.26, 0.34, 0.08, 1.0);
uniform float z_clip = 1.0;
uniform float fov_override = 0.0;
instance uniform float flare = 0.0;

void vertex() {
	Z_CLIP_SCALE = z_clip;

	if (fov_override > 0.0) {
		float f = 1.0 / tan(radians(fov_override) * 0.5);
		float aspect = abs(PROJECTION_MATRIX[1][1] / PROJECTION_MATRIX[0][0]);
		PROJECTION_MATRIX[1][1] = f * sign(PROJECTION_MATRIX[1][1]);
		PROJECTION_MATRIX[0][0] = f / aspect * sign(PROJECTION_MATRIX[0][0]);
	}
}

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float flicker = 0.85 + 0.15 * sin(TIME * 23.0) * sin(TIME * 7.0);
	ALBEDO = glow.rgb * facing * facing * facing * facing * flare * flicker;
}
