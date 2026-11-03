shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled;
// A smear of black water behind a revenant's blow, with the seep at its leading edge: painted shapes, breaking up as they fade.

const vec3 SEEP = vec3(0.5, 0.83, 0.42);
const vec3 BLACK = vec3(0.006, 0.01, 0.009);

float bump(vec2 p) {
	return fract(sin(dot(floor(p), vec2(12.9898, 78.233))) * 43758.5453);
}

float soft_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(bump(i), bump(i + vec2(1.0, 0.0)), f.x), mix(bump(i + vec2(0.0, 1.0)), bump(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	float along = UV.x;
	float across = UV.y;
	float fades = COLOR.g;
	float n = soft_noise(vec2(along * 9.0, across * 3.0)) * 0.6 + soft_noise(vec2(along * 23.0, across * 7.0)) * 0.4;
	// Its body goes before its leading edge does; thin out toward the elbow.
	float body = smoothstep(0.0, 0.5, along) * (1.0 - smoothstep(0.55, 1.0, across + (n - 0.5) * 0.5));
	float there = step(1.0 - fades, n * 0.9 + along * 0.25);
	float lip = smoothstep(0.86, 0.97, along) * (1.0 - across * 0.6);
	ALBEDO = BLACK + SEEP * lip * 0.7 * fades;
	ALPHA = clamp(body * there * 0.82 + lip * fades * 0.8, 0.0, 1.0);
}
