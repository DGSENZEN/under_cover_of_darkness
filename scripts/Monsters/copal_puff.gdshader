shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled;
// One puff of a copal cloud: pale resin smoke, thick at the middle of the ball
// as you see it and bitten away at its edge by slow climbing noise, with a
// warm stain low down where the resin burns. `fade` thins it in and out.

uniform vec3 pale = vec3(0.46, 0.44, 0.38);
uniform vec3 warm = vec3(0.5, 0.31, 0.13);
uniform float seed = 0.0;
uniform float fade = 1.0;
uniform float opacity = 0.3;

varying vec3 local_at;

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1.0, 0.0, 0.0)), u.x), mix(hash(i + vec3(0.0, 1.0, 0.0)), hash(i + vec3(1.0, 1.0, 0.0)), u.x), u.y),
		mix(mix(hash(i + vec3(0.0, 0.0, 1.0)), hash(i + vec3(1.0, 0.0, 1.0)), u.x), mix(hash(i + vec3(0.0, 1.0, 1.0)), hash(i + vec3(1.0, 1.0, 1.0)), u.x), u.y), u.z);
}

void vertex() {
	local_at = VERTEX;
}

void fragment() {
	vec3 p = local_at * 2.2 + vec3(seed, seed * 0.7 - TIME * 0.12, seed * 1.3);
	float bite = noise(p) * 0.62 + noise(p * 2.3) * 0.38;
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float body = smoothstep(0.05, 0.95, facing * 0.8 + (bite - 0.5) * 1.1);
	ALBEDO = mix(pale, warm, smoothstep(0.1, -0.7, local_at.y) * 0.55) * mix(0.72, 1.0, bite);
	ALPHA = body * opacity * fade;
}
