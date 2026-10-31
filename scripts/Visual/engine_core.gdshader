shader_type spatial;
// The Company's engine's dynamo core behind its iron ribs (maps/metro_station_machinery.gd, Oct 31 2026): the
// Company's blue, streaks of hotter light climbing it, a band of current sweeping up it every few seconds, its heart
// running white where the eye meets it square.
render_mode unshaded, cull_back, shadows_disabled;

uniform vec4 colour : source_color = vec4(0.353, 0.706, 1.0, 1.0);
uniform float energy = 2.4;
// The streaks: how many round it, how fast they climb (m/s); the sweep: how often (per s), how wide (m).
uniform float streaks = 40.0;
uniform float climb = 0.45;
uniform float sweep_rate = 0.35;
uniform float sweep_width = 0.12;
uniform float span = 0.72;

varying vec3 local;

void vertex() {
	local = VERTEX;
}

float hash(float n) {
	return fract(sin(n * 91.345) * 47453.5453);
}

void fragment() {
	float around = atan(local.z, local.x) / 6.2831853 + 0.5;
	float lane = floor(around * streaks);
	float speed = climb * (0.6 + 0.8 * hash(lane));
	float along = fract(local.y / span * 2.0 - TIME * speed + hash(lane + 7.0));
	// (Each streak a bright head fading down its tail.)
	float streak = smoothstep(0.0, 0.15, along) * (1.0 - along) * (0.4 + 0.6 * hash(lane + 3.0));
	float sweep = fract(TIME * sweep_rate);
	float band = exp(-pow((fract(local.y / span) - sweep) / sweep_width * span, 2.0));
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	vec3 hot = mix(colour.rgb, vec3(1.0), 0.45 * facing * facing + 0.35 * band);
	ALBEDO = hot * energy * (0.55 + 0.6 * streak + 0.7 * band);
}
