// A flame drawn solid: its main layer (every pixel inside the flame, a little
// brighter than its ramp so it holds its shape over a lit wall) or its hot
// heart (only its hottest heat, brighter than white, so it blooms).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_disabled, fog_disabled, shadows_disabled;

#include "res://scripts/Visual/Lights/flame.gdshaderinc"

// Heat below this is cut; 0 cuts where the ramp starts.
uniform float core_cut = 0.0;
uniform float brightness = 1.3;

void fragment() {
	vec4 colour = flame_colour(UV);

	if (colour.a < 0.5 || flame_heat(UV) < core_cut) {
		discard;
	}

	ALBEDO = colour.rgb * brightness;
}
