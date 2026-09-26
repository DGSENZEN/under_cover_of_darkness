// A guard's closed parts (body, garments, boots): see wardrobe.gdshaderinc.
shader_type spatial;
render_mode diffuse_lambert_wrap, specular_disabled;

#include "res://scripts/Visual/wardrobe.gdshaderinc"

void fragment() {
	ALBEDO = wardrobe_colour(UV);
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
}
