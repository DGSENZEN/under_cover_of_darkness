// A ring the world bends through, swelling: the Shard's release at the palm
// (MagicFx.release_burst). A flat ring (MagicFx._ring_mesh: v 0 inside, 1
// outside) pushes the screen behind it out from its middle, most at its
// middle line, with a thin cold rim; drawn as the arms are.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float strength = 0.025;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform vec4 rim_tint : source_color = vec4(0.9, 0.933, 0.96, 1.0);
uniform float z_clip = 1.0;
uniform float fov_override = 0.0;

varying vec2 out_dir;

void vertex() {
	Z_CLIP_SCALE = z_clip;

	if (fov_override > 0.0) {
		float f = 1.0 / tan(radians(fov_override) * 0.5);
		float aspect = abs(PROJECTION_MATRIX[1][1] / PROJECTION_MATRIX[0][0]);
		PROJECTION_MATRIX[1][1] = f * sign(PROJECTION_MATRIX[1][1]);
		PROJECTION_MATRIX[0][0] = f / aspect * sign(PROJECTION_MATRIX[0][0]);
	}

	// Out from its middle, as the view sees it.
	out_dir = normalize((MODELVIEW_MATRIX * vec4(VERTEX, 0.0)).xy + vec2(0.0001));
}

void fragment() {
	float across = 1.0 - abs(UV.y * 2.0 - 1.0);
	vec2 bend = out_dir * strength * across * fade;
	vec3 behind = texture(screen_tex, SCREEN_UV - bend * vec2(1.0, -1.0)).rgb;
	float rim = step(0.82, across);
	ALBEDO = mix(behind, rim_tint.rgb * 1.4, rim * 0.35);
	ALPHA = clamp(across * 1.5, 0.0, 1.0) * fade;
}
