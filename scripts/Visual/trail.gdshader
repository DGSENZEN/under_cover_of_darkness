shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;
// The smear a blade leaves in the air (SwingTrail.gd): light off the steel,
// brightest in a thin line along the path of the edge, thinning back toward
// the hilt, gone within a tenth of a second or so. Added to what is behind
// it, so it reads as light, not as a sheet of paper.
//
// UV.x: how old this part of the ribbon is, 0 new to 1 about to go.
// UV.y: across the ribbon, 0 toward the hilt to 1 the edge's own path.

uniform vec4 tint : source_color = vec4(0.88, 0.92, 1.0, 1.0);
// How bright at its brightest.
uniform float strength = 0.5;
// The viewmodel's depth squeeze (BaseMaterial3D.z_clip_scale): 1 in the
// world, small for the trail of your own blade.
uniform float z_clip = 1.0;

void vertex() {
	Z_CLIP_SCALE = z_clip;
}

void fragment() {
	float age = clamp(UV.x, 0.0, 1.0);
	float across = clamp(UV.y, 0.0, 1.0);
	// Fades fastest at first, as a smear in the eye does.
	float life = pow(1.0 - age, 1.7);
	// The body of the smear: faint, and only out toward the edge.
	float body = pow(across, 3.0);
	// The line the edge itself drew, and a hot core just behind the blade.
	float line = exp(-pow((1.0 - across) / 0.07, 2.0));
	float fresh = exp(-age * 10.0);
	float light = (body * 0.16 + line * (0.6 + 0.7 * fresh)) * life * strength;
	ALBEDO = tint.rgb;
	ALPHA = clamp(light, 0.0, 1.0);
}
