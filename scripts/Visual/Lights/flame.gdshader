// A flame layer: added onto whatever is behind it, as the PS2 drew fire.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

#include "res://scripts/Visual/Lights/flame.gdshaderinc"

void fragment() {
	vec4 colour = flame_colour(UV);

	if (colour.a < 0.5) {
		discard;
	}

	ALBEDO = colour.rgb;
	ALPHA = 1.0;
}
