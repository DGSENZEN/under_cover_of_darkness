// What is left of a ravenous ánima's fire: the Metro's spirit-fire outline (anima_aura), its
// shape pushed out and drawn from behind, but nearly out: broken into licks here and
// there along the bones, dirty, low, coming up a little as it drinks (`flare`). The
// viewmodel's hands take it too, with its depth and field of view.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, blend_add, shadows_disabled;

uniform vec4 glow : source_color = vec4(0.46, 0.64, 0.14, 1.0);
uniform float energy = 0.42;
uniform float thickness = 0.016;
uniform sampler2D noise : filter_linear_mipmap, repeat_enable;
uniform float z_clip = 1.0;
uniform float fov_override = 0.0;
instance uniform float flare = 0.0;

varying vec3 local;

void vertex() {
	local = VERTEX;
	float lick = texture(noise, vec2(VERTEX.x * 3.0 + VERTEX.z, VERTEX.y * 2.4 - TIME * 1.1)).r;
	VERTEX += NORMAL * thickness * (0.5 + 1.1 * lick + flare * 0.5);
	Z_CLIP_SCALE = z_clip;

	if (fov_override > 0.0) {
		float f = 1.0 / tan(radians(fov_override) * 0.5);
		float aspect = abs(PROJECTION_MATRIX[1][1] / PROJECTION_MATRIX[0][0]);
		PROJECTION_MATRIX[1][1] = f * sign(PROJECTION_MATRIX[1][1]);
		PROJECTION_MATRIX[0][0] = f / aspect * sign(PROJECTION_MATRIX[0][0]);
	}
}

void fragment() {
	vec2 at = vec2(local.x * 2.2 + local.z * 1.6, local.y * 1.8 - TIME * 0.7);
	float n = texture(noise, at).r;

	// Broken up and soft at its edges: more of it alight the more it has drunk.
	float from_edge = mix(0.56, 0.42, flare);

	if (n < from_edge) {
		discard;
	}

	float alight = smoothstep(from_edge, from_edge + 0.2, n);
	ALBEDO = glow.rgb * energy * alight * (0.7 + flare * 1.5) * (0.8 + 0.2 * sin(TIME * 5.0 + local.y * 6.0));
}
