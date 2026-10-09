shader_type spatial;
// The painterly look unlit, for tests/painterly_pixels.tscn: its colours as
// computed, with no light on them.

render_mode cull_back, unshaded;

#define PAINTERLY_UNSHADED
#include "res://scripts/Visual/painterly.gdshaderinc"
