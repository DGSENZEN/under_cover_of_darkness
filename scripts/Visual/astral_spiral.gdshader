// The motes spiralling into a ward-gate's vortex (scripts/Visual/AstralPassage.gd): each born near its rim at its
// own angle and depth, going round faster as it is drawn in, fading out at its eye. In the gate's own frame (its
// GPUParticles3D local_coords), the gate's face its x-y.
shader_type particles;
render_mode disable_force, disable_velocity;

// The rim's radius (m), how many turns a second out at the rim, how deep they spread (m), their colour.
uniform float radius = 1.4;
uniform float turns = 0.12;
uniform float depth = 0.3;
uniform vec4 tint : source_color = vec4(0.812, 0.91, 0.941, 1.0);

float hash(uint x) {
	x = ((x >> 16u) ^ x) * 0x45d9f3bu;
	x = ((x >> 16u) ^ x) * 0x45d9f3bu;
	x = (x >> 16u) ^ x;
	return float(x) / 4294967295.0;
}

void start() {
	uint key = NUMBER * 3u + RANDOM_SEED;
	CUSTOM = vec4(hash(key) * 6.2831853, 0.0, 0.75 + 0.3 * hash(key + 1u), hash(key + 2u));
	TRANSFORM = mat4(1.0);
	TRANSFORM[3].xyz = vec3(cos(CUSTOM.x), sin(CUSTOM.x), 0.0) * radius * CUSTOM.z;
	COLOR = vec4(tint.rgb, 0.0);
}

void process() {
	CUSTOM.y += DELTA;
	float t = clamp(CUSTOM.y / LIFETIME, 0.0, 1.0);
	float r = radius * CUSTOM.z * pow(1.0 - t, 0.85) + 0.02;
	// (Faster as it is drawn in: as water round a drain.)
	CUSTOM.x += DELTA * turns * 6.2831853 * min(radius / r, 6.0);
	TRANSFORM = mat4(1.0);
	TRANSFORM[3].xyz = vec3(cos(CUSTOM.x) * r, sin(CUSTOM.x) * r, (CUSTOM.w - 0.5) * depth * (1.0 - t));
	COLOR = vec4(tint.rgb, tint.a * smoothstep(0.0, 0.15, t) * smoothstep(1.0, 0.75, t));
}
