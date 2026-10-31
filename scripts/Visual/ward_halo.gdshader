shader_type spatial;
// The glow a Company lamp throws into the haze round it (the station's Company lamps, Oct 31 2026): a soft disc always
// facing the eye, added to what is behind it, fading out before it meets the wall it hangs on (it never shows the
// line where it would cut it), and never fogged: fog added over its whole quad would draw the square where the glow
// is gone. `pulse` breathes with the lamp.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 colour : source_color = vec4(0.353, 0.706, 1.0, 1.0);
uniform float strength = 0.35;
uniform float pulse = 1.0;
// How far before a surface behind it the glow is gone (m).
uniform float soft = 0.5;
uniform sampler2D depth : hint_depth_texture, filter_nearest;

void vertex() {
	// (Turned to face the eye where it hangs, its size kept.)
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz),
		INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz), INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz), MODEL_MATRIX[3]);
}

void fragment() {
	float r = length(UV - vec2(0.5)) * 2.0;
	float glow = exp(-r * r * 4.0) * (1.0 - smoothstep(0.85, 1.0, r));
	float behind = texture(depth, SCREEN_UV).r;
	vec4 world = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, behind, 1.0);
	float gap = -world.z / world.w - (-VERTEX.z);
	glow *= clamp(gap / soft, 0.0, 1.0);
	ALBEDO = colour.rgb * strength * glow * pulse;
}
