// What the floating eye's living parts share: noise in the model's own space, and
// a heart that beats faster as its blood comes up.

instance uniform float rage = 0.0;
instance uniform float hurt = 0.0;
instance uniform float wounds = 0.0;
instance uniform float smoulder = 0.0;

float eye_hash(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float eye_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(eye_hash(i), eye_hash(i + vec3(1.0, 0.0, 0.0)), u.x), mix(eye_hash(i + vec3(0.0, 1.0, 0.0)), eye_hash(i + vec3(1.0, 1.0, 0.0)), u.x), u.y),
		mix(mix(eye_hash(i + vec3(0.0, 0.0, 1.0)), eye_hash(i + vec3(1.0, 0.0, 1.0)), u.x), mix(eye_hash(i + vec3(0.0, 1.0, 1.0)), eye_hash(i + vec3(1.0, 1.0, 1.0)), u.x), u.y), u.z);
}

// Smoked: resin burning on it, an amber rim and embers crawling over it.
vec3 eye_smoulder(vec3 at, vec3 normal, vec3 view, float time) {
	float rim = pow(1.0 - clamp(dot(normal, view), 0.0, 1.0), 2.0);
	float embers = smoothstep(0.66, 0.72, eye_noise(at * 22.0 + vec3(0.0, -time * 1.4, 0.0)));
	return vec3(1.0, 0.5, 0.1) * (rim * 1.6 + embers * 0.9) * smoulder;
}

// Lub-dub, 0..1. Faster with its blood up.
float eye_beat(float time, float blood) {
	float t = fract(time * mix(1.0, 2.6, blood));
	return exp(-t * 16.0) + 0.65 * exp(-max(t - 0.2, 0.0) * 18.0) * step(0.2, t);
}

// A web of thin raised lines, 1 on a vein.
float eye_veins(vec3 p) {
	float a = abs(eye_noise(p) - 0.5);
	float b = abs(eye_noise(p * 2.3 + 7.0) - 0.5);
	return 1.0 - smoothstep(0.0, 0.05, min(a, b * 1.3));
}
