// Empower's beast sign on the arm: a faint umber pelt-shadow, fur-like
// strands drifting along the forearm and hand, on the gun arm only (the side
// HandSlot names: the arm always in view), over the arm's own look
// (material_overlay).
// Drawn as the arms are: at their own field of view and depth squeeze.
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled;

uniform vec4 pelt : source_color = vec4(0.29, 0.2, 0.14, 1.0);
uniform vec4 sheen : source_color = vec4(0.85, 0.78, 0.64, 1.0);
uniform sampler2D noise : filter_linear_mipmap, repeat_enable;
uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform float most = 0.35;
// Which side of the arms' space is the left arm (+1 or -1), and where it
// begins across the middle (m).
uniform float side_sign = 1.0;
uniform float side_from = 0.06;
uniform float z_clip = 1.0;
uniform float fov_override = 0.0;

varying float on_left;
varying vec3 model_at;

void vertex() {
	Z_CLIP_SCALE = z_clip;

	if (fov_override > 0.0) {
		float f = 1.0 / tan(radians(fov_override) * 0.5);
		float aspect = abs(PROJECTION_MATRIX[1][1] / PROJECTION_MATRIX[0][0]);
		PROJECTION_MATRIX[1][1] = f * sign(PROJECTION_MATRIX[1][1]);
		PROJECTION_MATRIX[0][0] = f / aspect * sign(PROJECTION_MATRIX[0][0]);
	}

	model_at = VERTEX;
	on_left = smoothstep(side_from, side_from + 0.1, VERTEX.x * side_sign);
}

void fragment() {
	// Strands: the noise stretched along the arm, drifting slowly.
	vec2 at = vec2(model_at.x * 9.0 + model_at.z * 9.0, model_at.y * 2.5 - TIME * 0.08);
	float strands = smoothstep(0.45, 0.75, texture(noise, at).r);
	ALBEDO = mix(pelt.rgb, sheen.rgb, strands * 0.25);
	ALPHA = amount * most * on_left * mix(0.4, 1.0, strands);
}
