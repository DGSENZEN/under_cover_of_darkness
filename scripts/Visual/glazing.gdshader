// Window glass (Materials "glazing", tools/level/kit_glazing): crown glass the
// moon goes through. Alpha-blended with no depth prepass, so it stays out of
// the shadow pass; clear in the middle, grimier toward its edges (its
// painting); a sheen of the night sky at grazing angles, so it reads as glass
// and not as a hole.
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque;

uniform sampler2D grime : filter_nearest_mipmap, repeat_disable;
uniform vec3 tint : source_color = vec3(0.55, 0.62, 0.56);
uniform float clear = 0.12;
uniform float grimy = 0.35;
uniform vec3 sky : source_color = vec3(0.16, 0.2, 0.3);
uniform float sheen = 0.5;

void fragment() {
	float g = texture(grime, UV).r;
	float facing = clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0);
	float fresnel = pow(1.0 - facing, 4.0);
	ALBEDO = mix(tint, sky, fresnel) * mix(1.0, 0.7, g);
	ALPHA = clamp(mix(clear, grimy, g) + fresnel * sheen, 0.0, 0.9);
	ROUGHNESS = mix(0.08, 0.5, g);
	SPECULAR = 0.6;
	METALLIC = 0.0;
}
