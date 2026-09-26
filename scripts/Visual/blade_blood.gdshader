shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, shadows_disabled;
// Blood on a blade, laid over the steel (GeometryInstance3D.material_overlay):
// streaks from the tip back toward the hilt, further the more it has cut,
// wet and red at first, dark and dull once it has dried. Only on the blade:
// the line from `blade_base` to `blade_tip`, in the model's own space.

uniform vec3 blade_base = vec3(0.0, 0.1, 0.0);
uniform vec3 blade_tip = vec3(0.0, 0.84, 0.0);
// 0 clean .. 1 blood to the hilt.
uniform float amount : hint_range(0.0, 1.0) = 0.0;
// 1 fresh .. 0 dry.
uniform float wet : hint_range(0.0, 1.0) = 1.0;
// So that no two blades bleed alike.
uniform float seed = 0.0;
// The viewmodel's depth squeeze (BaseMaterial3D.z_clip_scale): 1 in the world.
uniform float z_clip = 1.0;

varying vec3 model_position;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	return noise(p) * 0.6 + noise(p * 2.3 + 17.0) * 0.3 + noise(p * 5.1 + 3.0) * 0.1;
}

void vertex() {
	model_position = VERTEX;
	// A hair proud of the steel, so it never fights with it for the pixel.
	VERTEX += NORMAL * 0.0006;
	Z_CLIP_SCALE = z_clip;
}

void fragment() {
	vec3 axis = blade_tip - blade_base;
	float length_sq = max(dot(axis, axis), 1e-6);
	vec3 from_base = model_position - blade_base;
	// 0 at the hilt end of the blade, 1 at the tip.
	float along = dot(from_base, axis) / length_sq;
	// Across the blade's face: any direction square to it will do.
	vec3 dir = axis * inversesqrt(length_sq);
	vec3 across_dir = normalize(cross(dir, abs(dir.y) < 0.9 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0)));
	float across = dot(from_base, across_dir);
	float other = dot(from_base, cross(dir, across_dir));

	vec2 p = vec2(along * 16.0, (across + other) * 70.0) + vec2(seed * 3.1, seed * 7.7);
	float streaks = fbm(vec2(p.x * 0.45, p.y));
	float blotches = fbm(p * 1.3 + 11.0);

	// How far down from the tip it has run, ragged at its edge.
	float reach = amount * 1.1;
	float run = smoothstep(1.0 - reach - 0.08, 1.0 - reach + 0.12, along + (streaks - 0.5) * 0.45);
	// Thicker where there is more: splotches first, streaks at the last, and
	// always some steel showing through.
	float cover = smoothstep(0.6 - amount * 0.2, 0.68 - amount * 0.2, blotches * 0.6 + streaks * 0.4);
	float on_blade = step(0.0, along) * step(along, 1.03);
	float mask = run * cover * on_blade * step(0.001, amount);

	vec3 fresh = vec3(0.42, 0.018, 0.012);
	vec3 dried = vec3(0.15, 0.035, 0.02);
	ALBEDO = mix(dried, fresh, wet);
	ROUGHNESS = mix(0.85, 0.15, wet);
	SPECULAR = mix(0.2, 0.6, wet);
	// A little light of its own: steel in the dark is black, and blood on it
	// would be too, where it should still read as blood.
	EMISSION = mix(vec3(0.025, 0.004, 0.002), vec3(0.09, 0.004, 0.002), wet);
	ALPHA = mask * mix(0.82, 0.95, wet);
}
