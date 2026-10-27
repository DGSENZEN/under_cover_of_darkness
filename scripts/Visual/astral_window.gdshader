// A window onto the void (scripts/Visual/AstralPassage.gd): where the astral passage's walls, ceiling and floor were,
// round each ward-gate's circle, and bleeding out past its gaps over the world's own surfaces. Near black, it marks
// the stencil (1) where it is seen and keeps the depth of its plane, so nothing of the map beyond shows; the void
// draws only where it marked.
// - `hole` (m): a circle that round its middle cut out of it (`size` its quad's, m): a gate's circle.
// - `bleed` (m): only ragged tongues of it, slowly working, reaching about that far out from the edge `seg_a` to
//   `seg_b` (the gap's edge it bleeds from).
// (astral_tear.gdshader burns along the same edges: its torn_to and inside_by must stay this one's.)
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
stencil_mode write, compare_always, 1;

uniform sampler3D noise : filter_linear, repeat_enable;
uniform vec3 ink : source_color = vec3(0.008, 0.006, 0.014);
uniform float hole = 0.0;
uniform vec2 size = vec2(1.0, 1.0);
uniform float bleed = 0.0;
uniform vec3 seg_a;
uniform vec3 seg_b;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// How far it reaches here (m), its ragged line slowly working.
float torn_to(vec3 at, float reach) {
	float big = texture(noise, at * 0.45 + vec3(0.0, TIME * 0.01, 0.0)).r;
	float fine = texture(noise, at * 2.2 + vec3(TIME * 0.02)).r;
	return reach * clamp(0.15 + 1.1 * big + 0.35 * (fine - 0.5), 0.0, 1.4);
}

// How far inside the void this is (m; under 0 the world).
float inside_by() {
	if (bleed <= 0.0) {
		return 1.0;
	}
	vec3 ab = seg_b - seg_a;
	vec3 nearest = seg_a + ab * clamp(dot(world_pos - seg_a, ab) / max(dot(ab, ab), 0.0001), 0.0, 1.0);
	return torn_to(world_pos, bleed) - distance(world_pos, nearest);
}

void fragment() {
	if (length((UV - 0.5) * size) < hole || inside_by() < 0.0) {
		discard;
	}
	ALBEDO = ink;
}
