shader_type spatial;
// A neon tube (the Metro Underground's signs): unshaded, its colour burning
// to near white at the core the eye looks straight through, softer at the
// glass's edges. `flicker` (0-1) is the sign's pattern, set by NeonSign.
render_mode unshaded, cull_back, shadows_disabled;

uniform vec4 colour : source_color = vec4(1.0, 0.3, 0.6, 1.0);
uniform float energy = 4.0;
uniform float flicker = 1.0;
// How white the core runs, and how sharply the glow falls to the edges.
uniform float core_white = 0.55;
uniform float falloff = 1.6;

void fragment() {
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float core = pow(facing, falloff);
	vec3 hot = mix(colour.rgb, vec3(1.0), core * core_white);
	// A cold tube still shows its glass: a dim shade of its colour.
	vec3 cold = colour.rgb * 0.08;
	ALBEDO = mix(cold, hot * energy * (0.35 + 0.65 * core), flicker);
}
