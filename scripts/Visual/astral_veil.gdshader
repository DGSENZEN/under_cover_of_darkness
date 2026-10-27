// A veil of the wards' light hung across the astral passage (scripts/Visual/AstralPassage.gd): fine threads of
// cyan-white falling slowly, a soft breath of light behind them, frayed at its edges and foot; it parts round whoever
// walks through (`walker`), the hole wider the nearer.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;

uniform sampler3D noise : filter_linear, repeat_enable;
uniform vec3 walker = vec3(0.0, -1000.0, 0.0);
uniform float strength = 1.0;
uniform vec3 colour : source_color = vec3(0.812, 0.91, 0.941);
uniform vec3 warm : source_color = vec3(1.0, 0.62, 0.16);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Fine threads falling down it, each its own brightness.
	float across = UV.x * 18.0;
	float lane = floor(across);
	float hash = fract(sin(lane * 12.9898) * 43758.5453);
	float thread = smoothstep(0.5, 0.0, abs(fract(across) - 0.5 - (hash - 0.5) * 0.5));
	thread = pow(thread, 14.0);
	float run = texture(noise, vec3(lane * 0.37, UV.y * 0.6 - TIME * (0.02 + 0.03 * hash), hash * 4.0)).r;
	// (Only some lanes carry a thread at a time.)
	float light = thread * smoothstep(0.5, 0.8, run) * step(0.35, hash) * (0.4 + 0.6 * hash);
	// A soft breath of light behind them.
	float breath = texture(noise, vec3(UV.x * 1.2, UV.y * 0.5 - TIME * 0.01, 0.7)).r;
	light += smoothstep(0.4, 0.8, breath) * 0.1;
	// Frayed at its sides and its foot, thinning up toward the ceiling.
	float fray = texture(noise, vec3(UV.x * 6.0, UV.y * 2.0, 1.5)).r;
	float edge = smoothstep(0.0, 0.15, UV.x) * smoothstep(1.0, 0.85, UV.x);
	float foot = smoothstep(1.0, 0.72, UV.y + 0.15 * (fray - 0.5));
	float top = smoothstep(0.0, 0.3, UV.y);
	// Parted round the walker: a hole where they are, opening as they near.
	float apart = smoothstep(0.35, 1.4, distance(world_pos, walker + vec3(0.0, 0.9, 0.0)));
	// A thread of marigold now and then through it (the city's own colour, as through every ward).
	vec3 tint = mix(colour, warm, step(0.93, hash) * 0.7);
	ALBEDO = tint * light * edge * foot * top * apart * strength * 0.2;
}
