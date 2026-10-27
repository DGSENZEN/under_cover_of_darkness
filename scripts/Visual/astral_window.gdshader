// A window onto the void (scripts/Visual/AstralPassage.gd): where the astral passage's walls, ceiling and floor were,
// and round each ward-gate's circle. Near black, it marks the stencil (1) where it is seen and keeps the depth of its
// plane, so nothing of the map beyond shows; the void draws only where it marked. With a `hole` (m), a circle that
// round its middle is cut out of it (`size` its quad's, m), so a gate's circle shows what is beyond the gap.
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
stencil_mode write, compare_always, 1;

uniform vec3 ink : source_color = vec3(0.008, 0.006, 0.014);
uniform float hole = 0.0;
uniform vec2 size = vec2(1.0, 1.0);

void fragment() {
	if (length((UV - 0.5) * size) < hole) {
		discard;
	}
	ALBEDO = ink;
}
