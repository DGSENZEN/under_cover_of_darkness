// A stain on the ground (soot, trodden dirt: the garrison's floor stains):
// a card laid on the floor that multiplies what is drawn under it, as a
// PS2 laid its blob shadows, so it darkens the stones whatever light is on
// them (a decal only swaps the colour the light falls on, and a dark one
// all but vanished under the fire's light and the wet sheen). Its painting
// mixed in by its alpha and `strength` (it darkens the light before the
// tonemap, so it is laid on thick); `curve` under 1 lifts its colour toward
// white (trodden dirt tints the stones brown and darkens them a little,
// soot blackens them).
shader_type spatial;
render_mode blend_mul, unshaded, cull_back, depth_draw_never, shadows_disabled, fog_disabled;

uniform sampler2D stain : source_color, filter_nearest_mipmap, repeat_disable;
uniform float strength = 1.0;
uniform float curve = 1.0;

void fragment() {
	vec4 paint = texture(stain, UV);
	ALBEDO = mix(vec3(1.0), pow(paint.rgb, vec3(curve)), clamp(paint.a * strength, 0.0, 1.0));
}
