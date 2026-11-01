shader_type canvas_item;
// The evil eye on you: lids of ink closing in from above and below, dragged
// along by a dry brush, a bruised rim where the paint pools. `amount` 0..1.

uniform float amount = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	// Bristle streaks run along the lid, slowly crawling.
	float streak = noise(vec2(p.x * 2.5 + TIME * 0.05, p.y * 26.0)) * 0.6 + noise(vec2(p.x * 7.0 - TIME * 0.03, p.y * 9.0)) * 0.4;
	float open = mix(1.3, 0.84, amount) * (1.0 - p.x * p.x * 0.55) + sin(TIME * 0.7) * 0.015;
	float past = abs(p.y) - open + (streak - 0.5) * 0.2;
	float lid = smoothstep(-0.03, 0.07, past);
	float rim = smoothstep(-0.05, 0.02, past) * (1.0 - smoothstep(0.02, 0.2, past));
	vec3 ink = mix(vec3(0.035, 0.022, 0.024), vec3(0.2, 0.05, 0.05), rim);
	COLOR = vec4(ink, max(lid * 0.8, rim * 0.5) * smoothstep(0.0, 0.3, amount));
}
