// A veil of the wards' light hung across the astral passage (scripts/Visual/AstralPassage.gd): a few soft ribbons of
// cyan-white swaying as silk, one now and then with a marigold thread down it, a soft breath of light behind them,
// frayed at its edges and foot; it parts round whoever walks through (`walker`), the hole wider the nearer.
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
	// A few soft ribbons hung down it, each swaying as silk in a slow draught, brighter at their folds.
	float light = 0.0;
	float marigold_thread = 0.0;
	for (int i = 0; i < 5; i++) {
		float k = float(i);
		float hash = fract(sin(k * 12.9898 + 4.1) * 43758.5453);
		float at = (k + 0.5) / 5.0 + (hash - 0.5) * 0.12;
		float sway = 0.035 * sin(UV.y * (4.0 + 3.0 * hash) + TIME * (0.25 + 0.2 * hash) + k * 2.0)
			+ 0.015 * sin(UV.y * 11.0 - TIME * 0.6 + k);
		float w = 0.01 + 0.012 * hash;
		float d = abs(UV.x - at - sway);
		float ribbon = smoothstep(w, 0.0, d);
		float fold = 0.6 + 0.4 * sin(UV.y * 9.0 + TIME * 0.5 + k * 3.0);
		light += ribbon * ribbon * fold * (0.5 + 0.5 * hash);
		marigold_thread += step(0.82, hash) * smoothstep(0.004, 0.0, d);
	}
	// A soft breath of light behind them.
	float breath = texture(noise, vec3(UV.x * 1.2, UV.y * 0.5 - TIME * 0.01, 0.7)).r;
	light += smoothstep(0.4, 0.8, breath) * 0.08;
	// Frayed at its sides and its foot, thinning up toward the ceiling.
	float fray = texture(noise, vec3(UV.x * 6.0, UV.y * 2.0, 1.5)).r;
	float edge = smoothstep(0.0, 0.15, UV.x) * smoothstep(1.0, 0.85, UV.x);
	float foot = smoothstep(1.0, 0.72, UV.y + 0.15 * (fray - 0.5));
	float top = smoothstep(0.0, 0.3, UV.y);
	// Parted round the walker: a hole where they are, opening as they near.
	float apart = smoothstep(0.35, 1.4, distance(world_pos, walker + vec3(0.0, 0.9, 0.0)));
	// A thread of marigold now and then through it (the city's own colour, as through every ward).
	ALBEDO = (colour * light + warm * marigold_thread * 0.6) * edge * foot * top * apart * strength * 0.22;
}
