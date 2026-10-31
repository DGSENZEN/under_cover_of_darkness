shader_type spatial;
// The indicator lamps along the head of each gauge board on the Company's engine (Oct 31 2026): a chase of amber
// light running along each row, round the engine, as it runs.
render_mode unshaded, cull_back, shadows_disabled;

uniform vec4 colour : source_color = vec4(1.0, 0.62, 0.25, 1.0);
uniform float energy = 3.0;
uniform float chase = 2.6;
uniform float spacing = 30.0;

varying vec3 local;

void vertex() {
	local = VERTEX;
}

void fragment() {
	float around = atan(local.z, local.x);
	float on = 0.5 + 0.5 * sin(TIME * chase - around * spacing);
	ALBEDO = colour.rgb * energy * (0.15 + 0.85 * on * on);
}
