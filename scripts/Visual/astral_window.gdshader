// A window onto the void (scripts/Visual/AstralPassage.gd): where the astral passage's walls, ceiling and floor were.
// Near black, it marks the stencil (1) where it is seen and keeps the depth of its plane, so nothing of the map beyond
// shows; the void draws only where it marked.
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
stencil_mode write, compare_always, 1;

uniform vec3 ink : source_color = vec3(0.008, 0.006, 0.014);

void fragment() {
	ALBEDO = ink;
}
