shader_type spatial;
// The painterly look, lit (painterly.gdshaderinc).

render_mode cull_back, diffuse_lambert, specular_schlick_ggx;

#include "res://scripts/Visual/painterly.gdshaderinc"
