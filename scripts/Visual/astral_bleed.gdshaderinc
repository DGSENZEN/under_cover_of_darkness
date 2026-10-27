// Where the astral passage's void bleeds out past a gap (scripts/Visual/AstralPassage.gd): shared by the bleed's mark
// (astral_mark.gdshader) and its burning edge (astral_tear.gdshader), so the edge burns exactly where the void ends.
// Needs `noise` (sampler3D) and the varying `world_pos`.

// How far it reaches (m), about: only ragged tongues of it, reaching out from the edge `seg_a` to `seg_b` (the gap's
// edge it bleeds from).
uniform float bleed = 0.0;
uniform vec3 seg_a;
uniform vec3 seg_b;

// How far it reaches here (m), its ragged line slowly working.
float torn_to(vec3 at, float reach) {
	float big = texture(noise, at * 0.45 + vec3(0.0, TIME * 0.01, 0.0)).r;
	float fine = texture(noise, at * 2.2 + vec3(TIME * 0.02)).r;
	return reach * clamp(0.15 + 1.1 * big + 0.35 * (fine - 0.5), 0.0, 1.4);
}

// How far inside the void `at` is (m; under 0 the world).
float inside_by(vec3 at) {
	vec3 ab = seg_b - seg_a;
	vec3 nearest = seg_a + ab * clamp(dot(at - seg_a, ab) / max(dot(ab, ab), 0.0001), 0.0, 1.0);
	return torn_to(at, bleed) - distance(at, nearest);
}
