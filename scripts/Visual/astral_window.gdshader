// A window onto the deep (scripts/Visual/AstralPassage.gd): where the astral passage's walls, ceiling and floor were.
// It shows the deep's own picture (its world drawn by an eye matched to the camera: `deep`) where it is seen, and
// keeps the depth of its plane, so nothing of the map beyond shows. (Round its gates and past its gaps:
// astral_mark.gdshader.)
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;

uniform sampler2D deep : filter_linear, repeat_disable;

void fragment() {
	ALBEDO = texture(deep, SCREEN_UV).rgb;
}
