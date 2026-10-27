// A veil of pale light hung across the astral passage (scripts/Visual/AstralPassage.gd): streaks of it falling
// slowly, frayed at its edges and foot; it parts round whoever walks through (`walker`), the hole wider the nearer.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;

uniform sampler3D noise : filter_linear, repeat_enable;
uniform vec3 walker = vec3(0.0, -1000.0, 0.0);
uniform float strength = 1.0;
uniform vec3 colour : source_color = vec3(0.6, 0.72, 1.0);
uniform vec3 warm : source_color = vec3(1.0, 0.72, 0.36);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Streaks falling down it.
	float streak = texture(noise, vec3(UV.x * 3.0, UV.y * 0.35 - TIME * 0.03, TIME * 0.01)).r;
	streak = smoothstep(0.45, 0.85, streak);
	float fine = texture(noise, vec3(UV.x * 11.0, UV.y * 1.5 - TIME * 0.06, 0.5)).r;
	float light = streak * (0.6 + 0.6 * fine);
	// Frayed at its sides and its foot, thinning up toward the ceiling.
	float edge = smoothstep(0.0, 0.12, UV.x) * smoothstep(1.0, 0.88, UV.x);
	float foot = smoothstep(1.0, 0.7, UV.y + 0.15 * (fine - 0.5));
	float top = smoothstep(0.0, 0.25, UV.y);
	// Parted round the walker: a hole where they are, opening as they near.
	float apart = smoothstep(0.35, 1.4, distance(world_pos, walker + vec3(0.0, 0.9, 0.0)));
	// A thread of marigold now and then through it (the city's own colour, as through every ward).
	vec3 tint = mix(colour, warm, smoothstep(0.8, 0.95, fine) * 0.6);
	ALBEDO = tint * light * edge * foot * top * apart * strength * 0.33;
}
