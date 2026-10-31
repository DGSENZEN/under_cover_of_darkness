shader_type spatial;
// The Light Company's ward light behind a lamp's frosted glass (the station's Company lamps, Oct 31 2026): a cold
// light that churns as it burns, wisps rising through it, brighter where the eye glances across the glass (the frost
// catching it) than where it looks straight through. `pulse` is the lamp's breath, set by CompanyLamp with its light.
render_mode unshaded, cull_back, shadows_disabled;

uniform vec4 colour : source_color = vec4(0.353, 0.706, 1.0, 1.0);
uniform float energy = 3.0;
uniform float pulse = 1.0;
// Its own place in the churn, so no two lamps move alike.
uniform float phase = 0.0;
// How fast the wisps rise (per s), how fine they are (per m), how much they move the light.
uniform float rise = 0.18;
uniform float grain = 9.0;
uniform float churn = 0.45;
// How white its heart runs; how much brighter the frost at a glance.
uniform float core_white = 0.5;
uniform float frost = 0.6;

varying vec3 local;

void vertex() {
	local = VERTEX;
}

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y),
		f.z);
}

void fragment() {
	float t = TIME + phase * 17.0;
	vec3 p = local * grain + vec3(phase * 3.1, -t * rise * grain, phase * 1.7);
	// Two octaves, the finer one twisting against the first: wisps, not blotches.
	float wisp = noise(p) * 0.65 + noise(p * 2.3 + vec3(t * 0.4, 0.0, -t * 0.3)) * 0.35;
	wisp = smoothstep(0.3, 0.85, wisp);
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float glance = 1.0 - facing;
	vec3 hot = mix(colour.rgb, vec3(1.0), core_white * facing * wisp);
	float bright = (1.0 - churn) + churn * wisp + frost * glance * glance;
	ALBEDO = hot * energy * bright * pulse;
}
