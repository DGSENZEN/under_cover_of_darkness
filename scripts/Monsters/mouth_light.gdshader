// The light in those pressing out of the mouth (AnimaMouth.gd): white-hot where you look straight into it, going
// sick and dim round its edge, so it sits back in a socket instead of lying on the face like a disc.
shader_type spatial;
render_mode unshaded, shadows_disabled;

uniform vec3 core : source_color = vec3(1.0, 0.98, 0.72);
uniform vec3 edge : source_color = vec3(0.2, 0.3, 0.05);
uniform float z_clip = 1.0;
uniform float fov_override = 0.0;

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
	float into = pow(clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.6);
	ALBEDO = mix(edge, core, into);
}
