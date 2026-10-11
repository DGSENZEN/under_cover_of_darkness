// The seeped mist (Vfx.gd's "mist"): a fog volume round a seeped booth or
// machine, its noise flowing away from the source along the ground (two
// phases of it, flow-mapped), thick low down and near, gone by its edges,
// glowing the seeped's phosphor green and pulsing (`pulse`: the god's
// breath, later).
shader_type fog;

uniform sampler3D noise : repeat_enable;
uniform vec4 colour : source_color = vec4(0.498, 0.827, 0.416, 1.0);
uniform float density = 1.6;
uniform float pulse = 1.0;

void fog() {
	vec3 local = WORLD_POSITION - OBJECT_POSITION;
	float dist = length(local.xz);
	vec2 away = local.xz / max(dist, 0.001);
	float t0 = fract(TIME * 0.12);
	float t1 = fract(TIME * 0.12 + 0.5);
	vec3 flow = vec3(away.x, 0.0, away.y) * 1.4;
	float a = texture(noise, (WORLD_POSITION - flow * t0) * 0.45).r;
	float b = texture(noise, (WORLD_POSITION - flow * t1) * 0.45 + 0.5).r;
	float n = mix(a, b, abs(t0 * 2.0 - 1.0));
	float fine = texture(noise, WORLD_POSITION * 1.3 + vec3(0.0, TIME * 0.05, 0.0)).r;
	float low = 1.0 - smoothstep(0.0, 0.85, UVW.y);
	float near = 1.0 - smoothstep(0.8, 2.8, dist);
	float body = clamp(n * fine * 2.4, 0.0, 1.0) * low * near;
	float glow = pulse * (0.85 + 0.15 * sin(TIME * 1.7));
	DENSITY = density * body * glow;
	ALBEDO = colour.rgb;
	EMISSION = colour.rgb * 2.2 * body * glow;
}
