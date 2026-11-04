shader_type spatial;
render_mode cull_back;
// What's in it: coals, black with their cracks burning, the heat moving slowly through them and leaping when they're fanned.

instance uniform float fanned = 0.0;

varying vec3 at;

float bump(vec3 p) {
	return fract(sin(dot(floor(p), vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

float soft_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float low = mix(mix(bump(i), bump(i + vec3(1, 0, 0)), f.x), mix(bump(i + vec3(0, 1, 0)), bump(i + vec3(1, 1, 0)), f.x), f.y);
	float high = mix(mix(bump(i + vec3(0, 0, 1)), bump(i + vec3(1, 0, 1)), f.x), mix(bump(i + vec3(0, 1, 1)), bump(i + vec3(1, 1, 1)), f.x), f.y);
	return mix(low, high, f.z);
}

void vertex() {
	at = VERTEX;
}

void fragment() {
	float slow = soft_noise(at * 34.0 + vec3(0.0, TIME * 0.3, 0.0));
	float fine = soft_noise(at * 110.0 - vec3(TIME * 0.15, 0.0, TIME * 0.1));
	float crack = smoothstep(0.42, 0.72, slow * 0.6 + fine * 0.4 + fanned * 0.16);
	ALBEDO = vec3(0.012, 0.01, 0.009);
	ROUGHNESS = 0.9;
	vec3 deep = vec3(0.7, 0.09, 0.015);
	vec3 bright = vec3(2.4, 0.95, 0.2);
	EMISSION = mix(deep * 0.55, bright, crack) * (0.75 + fanned * 1.4);
}
