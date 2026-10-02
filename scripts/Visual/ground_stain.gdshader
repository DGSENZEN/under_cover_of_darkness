// Multiplicative floor stain card: darkens the lit scene rather than only swapping decal albedo.
// Texture alpha mixes strength; curve < 1 lifts colour toward white for lighter dirt tint.
// Drawn before tonemapping, so soot remains visible under fire light and wet sheen.
shader_type spatial;
render_mode blend_mul, unshaded, cull_back, depth_draw_never, shadows_disabled, fog_disabled;

uniform sampler2D stain : source_color, filter_nearest_mipmap, repeat_disable;
uniform float strength = 1.0;
uniform float curve = 1.0;

void fragment() {
	vec4 paint = texture(stain, UV);
	ALBEDO = mix(vec3(1.0), pow(paint.rgb, vec3(curve)), clamp(paint.a * strength, 0.0, 1.0));
}
