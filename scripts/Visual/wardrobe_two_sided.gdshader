// A guard's cloth strips (skirts, tabards, capes), seen from both sides: see
// wardrobe.gdshaderinc. The back of a strip is lit as its own side.
shader_type spatial;
render_mode diffuse_lambert_wrap, specular_disabled, cull_disabled;

#include "res://scripts/Visual/wardrobe.gdshaderinc"

void fragment() {
	ALBEDO = wardrobe_colour(UV);
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	NORMAL = FRONT_FACING ? NORMAL : -NORMAL;
}
