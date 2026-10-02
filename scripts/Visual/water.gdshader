// Still dark water at night (WaterVolume's surface): the lamps and torches
// by it stand in it as columns of light broken by its ripples (the old way:
// each light's mirror image under the surface, drawn out toward the eye),
// the sky in it at a glancing look (fresnel), the moon's glitter from the
// light itself; opaque, so the night's screen reflections may land on it
// too. It flows; rain rings it; a scum line where it laps the walls and a
// skin of duckweed in the still water near them.
shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;
#include "water_surface.gdshaderinc"
