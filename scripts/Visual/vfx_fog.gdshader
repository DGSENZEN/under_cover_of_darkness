// The canal's night fog (Vfx.gd's "canal_fog"): a long low fog volume over
// the water, two octaves of slow noise drifting, thick at the water and
// thinning up, soft at its ends and sides.
shader_type fog;

uniform sampler3D noise : repeat_enable;
uniform vec4 albedo : source_color = vec4(0.72, 0.76, 0.82, 1.0);
uniform float density = 1.5;
uniform vec3 drift = vec3(0.3, 0.0, 0.1);

void fog() {
	float n = texture(noise, WORLD_POSITION * 0.12 - drift * TIME * 0.12).r;
	float m = texture(noise, WORLD_POSITION * 0.31 - drift * TIME * 0.2 + 0.5).r;
	float low = 1.0 - smoothstep(0.1, 0.9, UVW.y);
	vec3 e = min(UVW, 1.0 - UVW);
	float edge = smoothstep(0.0, 0.15, e.x) * smoothstep(0.0, 0.2, e.z);
	DENSITY = density * smoothstep(0.35, 0.75, n * 0.7 + m * 0.5) * low * edge;
	ALBEDO = albedo.rgb;
}
