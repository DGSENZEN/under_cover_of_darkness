// The astral passage's skin (scripts/Visual/AstralPassage.gd): where the Metro's unwarded dark wears thin, the
// corridor's walls and ceiling give way to deep space. Stars lie at depths behind the surface (sampled along the
// eye's ray past it, so they shift as the walker goes, as stars far off would), a slow nebula of cold violet and teal
// deeper still. It grows from nothing at the passage's far end to its fullest, and eases at the market's mouth.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;

uniform sampler3D noise : filter_linear, repeat_enable;
// The passage: the market's mouth (world), the way from it to the far end, its length (m), how strong at its fullest.
uniform vec3 mouth;
uniform vec3 away = vec3(0.0, 0.0, 1.0);
uniform float span = 20.0;
uniform float strength = 1.0;
uniform vec3 star_colour : source_color = vec3(0.86, 0.9, 1.0);
uniform vec3 violet : source_color = vec3(0.32, 0.14, 0.52);
uniform vec3 teal : source_color = vec3(0.08, 0.36, 0.44);

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

// One layer of stars: a star in a few cells of a grid `scale` per metre, twinkling.
float stars(vec3 p, float scale, float time) {
	vec3 c = floor(p * scale);
	vec3 f = fract(p * scale);
	float h = hash3(c);
	if (h < 0.93) {
		return 0.0;
	}
	vec3 at = vec3(hash3(c + 1.3), hash3(c + 2.7), hash3(c + 4.1)) * 0.6 + 0.2;
	float d = length(f - at);
	float twinkle = 0.55 + 0.45 * sin(time * (0.8 + h * 2.5) + h * 40.0);
	return smoothstep(0.1, 0.0, d) * twinkle * (0.4 + 3.0 * (h - 0.93) / 0.07);
}

void fragment() {
	vec3 eye = normalize(world_pos - CAMERA_POSITION_WORLD);
	// (How squarely the eye meets the surface: the depths behind it measured along the eye's ray.)
	float facing = max(abs(dot(eye, world_normal)), 0.2);
	vec3 light = vec3(0.0);
	for (int i = 0; i < 4; i++) {
		float depth = 2.0 + float(i) * 4.5;
		vec3 p = world_pos + eye * depth / facing;
		light += star_colour * stars(p, 1.4 - float(i) * 0.24, TIME) * (1.0 - float(i) * 0.17);
	}
	// The nebula, deepest.
	vec3 q = world_pos + eye * 14.0 / facing;
	float cloud = texture(noise, q * 0.035 + vec3(0.0, 0.0, TIME * 0.004)).r;
	float hue = texture(noise, q * 0.017 + vec3(0.37, TIME * 0.002, 0.0)).r;
	light += mix(violet, teal, smoothstep(0.35, 0.65, hue)) * smoothstep(0.42, 0.8, cloud) * 0.55;
	// Strongest in the passage's middle, easing at the market's mouth, gone toward the far end.
	float t = clamp(dot(world_pos - mouth, away) / span, 0.0, 1.0);
	float grown = smoothstep(1.0, 0.55, t) * (0.45 + 0.55 * smoothstep(0.0, 0.18, t));
	ALBEDO = light * grown * strength;
}
