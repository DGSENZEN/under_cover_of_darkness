// A flame's hot heart: only its hottest heat, solid, and brighter than white
// so it crosses the glow threshold and blooms.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_disabled, fog_disabled, shadows_disabled;

#include "res://scripts/Visual/Lights/flame.gdshaderinc"

uniform float core_cut = 0.8;
uniform float brightness = 2.5;

void fragment() {
	float h = flame_heat(UV);

	if (h < core_cut) {
		discard;
	}

	ALBEDO = flame_colour(UV).rgb * brightness;
}
