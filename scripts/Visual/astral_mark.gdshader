// The deep shown round each ward-gate's circle and bleeding out past the astral passage's gaps over the world's own
// surfaces (scripts/Visual/AstralPassage.gd). It shows the deep's own picture (`deep`) and keeps the depth of its
// plane, as the passage's windows do (astral_window.gdshader); what lies in its plane over it (a gate's vortex and
// rings, a bleed's burning edge) leans toward the eye (their `lean`), so nothing fights it.
// - `hole` (m): a circle that round its middle cut out of it (`size` its quad's, m): a gate's circle.
// - `bleed` (m, astral_bleed.gdshaderinc): only ragged tongues of it, slowly working, out from a gap's edge.
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;

uniform sampler2D deep : filter_linear, repeat_disable;
uniform sampler3D noise : filter_linear, repeat_enable;
uniform float hole = 0.0;
uniform vec2 size = vec2(1.0, 1.0);

varying vec3 world_pos;

#include "res://scripts/Visual/astral_bleed.gdshaderinc"

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (length((UV - 0.5) * size) < hole || (bleed > 0.0 && inside_by(world_pos) < 0.0)) {
		discard;
	}
	ALBEDO = texture(deep, SCREEN_UV).rgb;
}
