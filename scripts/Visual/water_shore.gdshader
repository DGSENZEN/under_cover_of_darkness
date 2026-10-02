// Only the shallow shoreline: deep water keeps its original opaque SSR pass.
shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx, depth_draw_never;
#define WATER_SHORE
#include "water_surface.gdshaderinc"
