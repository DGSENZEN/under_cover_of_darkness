// A window onto the deep (scripts/Visual/AstralPassage.gd): where the astral passage's walls, ceiling and floor were.
// It shows the deep's own picture (its world drawn by an eye matched to the camera: `deep`) where it is seen, and
// keeps the depth of its plane, so nothing of the map beyond shows. (Round its gates and past its gaps:
// astral_mark.gdshader.) One-sided, facing into the passage: where a neighbouring space's own wall stands in its plane
// (the market stairs' end, the cistern lane's), that wall is what is seen from outside, never the two fighting.
shader_type spatial;
render_mode unshaded, cull_back, fog_disabled;

uniform sampler2D deep : filter_linear, repeat_disable;

void fragment() {
	ALBEDO = texture(deep, SCREEN_UV).rgb;
}
