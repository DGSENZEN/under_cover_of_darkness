// Opaque night water: rippled light columns, Fresnel sky, moon glitter, and optional SSR.
// The shared surface include adds flow/rain rings and edge scum/duckweed.
shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;
#include "water_surface.gdshaderinc"
