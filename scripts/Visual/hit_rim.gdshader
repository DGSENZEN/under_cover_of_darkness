shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, fog_disabled, shadows_disabled;
// Struck: light flares round the edges of him for an instant (GuardRig.gd,
// as the body's material_overlay), so you see the blow land without him
// being painted red.

uniform vec4 tint : source_color = vec4(1.0, 0.84, 0.7, 1.0);
// 0..1, dying away in a few frames after the blow.
uniform float amount = 0.0;

void fragment() {
	// Either way round: a skinned mesh's faces may be wound either way.
	float facing = clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	// Only his outline: in the dark, light laid over the whole of him reads as
	// a ghost.
	float rim = pow(1.0 - facing, 3.5);
	ALBEDO = tint.rgb;
	ALPHA = clamp(amount * rim * 0.45, 0.0, 1.0);
}
