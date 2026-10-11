// What drifts down (Vfx.gd's "petals" and "leaves", the drift kit's
// meshes): born in a box over the emitter, tumbling on all axes and
// fluttering side to side as they fall (`fall` m/s), carried by the wind
// (the map's attractor: ATTRACTOR_FORCE), never past `limit` m/s; where they
// land (the camera's heightfield) they lie flat and stay, shrinking away in
// their last `fade` seconds.
shader_type particles;

uniform vec3 box = vec3(2.0, 0.6, 2.0);
uniform float offset = 1.8;
uniform float fall = 1.0;
uniform float limit = 3.0;
uniform float flutter = 0.6;
// How fast the air brings it round to its fall and flutter (1/s).
uniform float drag = 1.5;
uniform float spin = 3.0;
uniform float fade = 2.0;
uniform vec2 scale = vec2(0.8, 1.25);

float hash(uint x) {
	x = ((x >> 16u) ^ x) * 0x45d9f3bu;
	x = ((x >> 16u) ^ x) * 0x45d9f3bu;
	x = (x >> 16u) ^ x;
	return float(x) / 4294967295.0;
}

mat3 turn(vec3 axis, float angle) {
	float c = cos(angle);
	float s = sin(angle);
	float k = 1.0 - c;
	return mat3(vec3(c + axis.x * axis.x * k, axis.y * axis.x * k + axis.z * s, axis.z * axis.x * k - axis.y * s),
		vec3(axis.x * axis.y * k - axis.z * s, c + axis.y * axis.y * k, axis.z * axis.y * k + axis.x * s),
		vec3(axis.x * axis.z * k + axis.y * s, axis.y * axis.z * k - axis.x * s, c + axis.z * axis.z * k));
}

void start() {
	uint seed = NUMBER * 7919u + RANDOM_SEED;

	if (RESTART_POSITION) {
		vec3 r = vec3(hash(seed), hash(seed + 1u), hash(seed + 2u)) * 2.0 - 1.0;
		TRANSFORM = mat4(1.0);
		TRANSFORM[3].xyz = (EMISSION_TRANSFORM * vec4(r * box + vec3(0.0, offset, 0.0), 1.0)).xyz;
	}

	if (RESTART_VELOCITY) {
		VELOCITY = vec3(0.0, -fall, 0.0);
	}

	if (RESTART_CUSTOM) {
		// x: its own phase, y: its age (0..1), z: resting, w: its scale.
		CUSTOM = vec4(hash(seed + 3u), 0.0, 0.0, mix(scale.x, scale.y, hash(seed + 4u)));
	}
}

void process() {
	uint seed = NUMBER * 7919u + RANDOM_SEED;
	CUSTOM.y += DELTA / LIFETIME;
	float age = CUSTOM.y * LIFETIME;
	float phase = CUSTOM.x * 6.2832;

	if (CUSTOM.z < 0.5 && COLLIDED) {
		CUSTOM.z = 1.0;
		TRANSFORM[3].xyz += COLLISION_NORMAL * COLLISION_DEPTH;
	}

	mat3 basis;

	if (CUSTOM.z > 0.5) {
		// Lying where it landed, flat, turned its own way.
		VELOCITY = vec3(0.0);
		basis = turn(vec3(0.0, 1.0, 0.0), phase) * turn(vec3(1.0, 0.0, 0.0), 0.08 * sin(phase * 3.0));
	} else {
		// Fluttering side to side, a pendulum's swing, as it falls; the wind
		// carries it; the air brings it round to its fall.
		vec2 swing = vec2(sin(age * 2.2 + phase), cos(age * 1.6 + phase * 1.3)) * flutter;
		vec3 aim = vec3(swing.x, -fall * (0.8 + 0.3 * sin(age * 3.1 + phase)), swing.y);
		// (The wind's push is an acceleration; the drag holds the drift to a
		// pace: the wind's push over the drag, past the flutter.)
		VELOCITY += (ATTRACTOR_FORCE + (aim - VELOCITY) * drag) * DELTA;

		if (length(VELOCITY) > limit) {
			VELOCITY = normalize(VELOCITY) * limit;
		}

		vec3 axis = normalize(vec3(hash(seed + 5u), hash(seed + 6u), hash(seed + 7u)) * 2.0 - 1.0);
		basis = turn(axis, phase + age * spin * (0.6 + 0.8 * hash(seed + 8u)));
	}

	float left = (1.0 - CUSTOM.y) * LIFETIME;
	float size = CUSTOM.w * clamp(left / fade, 0.0, 1.0);
	TRANSFORM[0].xyz = basis[0] * size;
	TRANSFORM[1].xyz = basis[1] * size;
	TRANSFORM[2].xyz = basis[2] * size;
}
