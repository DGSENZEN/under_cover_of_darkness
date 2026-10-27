// The void's sky (scripts/Visual/AstralPassage.gd), seen only through the astral passage's windows: the painterly
// occult deep. Ink, with clouds of violet and teal laid in flat painted steps and inked at their edges, ribbons of
// aurora hanging through it, threads of marigold (the city's own colour, as through every ward), a few stars.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, fog_disabled, blend_mix;
stencil_mode read, compare_equal, 1;

uniform sampler3D noise : filter_linear, repeat_enable;
uniform vec3 centre;
uniform vec3 ink : source_color = vec3(0.012, 0.008, 0.022);
uniform vec3 violet : source_color = vec3(0.3, 0.1, 0.46);
uniform vec3 teal : source_color = vec3(0.05, 0.34, 0.4);
uniform vec3 marigold : source_color = vec3(1.0, 0.62, 0.16);
uniform vec3 star : source_color = vec3(0.86, 0.9, 1.0);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void fragment() {
	vec3 d = normalize(world_pos - centre);
	float t = TIME;
	// The clouds, laid in painted steps, their edges inked.
	float cloud = texture(noise, d * 1.6 + vec3(t * 0.004, 0.0, t * 0.002)).r;
	float hue = texture(noise, d * 0.9 + vec3(0.31, t * 0.003, 0.0)).r;
	float stepped = floor(smoothstep(0.38, 0.82, cloud) * 4.0) / 4.0;
	float edge = 1.0 - smoothstep(0.0, 0.02, abs(fract(smoothstep(0.38, 0.82, cloud) * 4.0) - 0.5) - 0.46);
	vec3 col = mix(ink, mix(violet, teal, smoothstep(0.4, 0.62, hue)), stepped * 0.85);
	col = mix(col, ink * 0.5, edge * step(0.01, stepped) * 0.7);
	// Ribbons of aurora hanging through it: bands along a wandering line, streaked downward.
	float wander = texture(noise, vec3(d.x * 0.8, 0.2, d.z * 0.8) + vec3(t * 0.006)).r;
	float band = abs(d.y - 0.15 - (wander - 0.5) * 0.9);
	float streak = texture(noise, vec3(d.x * 6.0, d.y * 0.6 - t * 0.02, d.z * 6.0)).r;
	float ribbon = smoothstep(0.16, 0.0, band) * smoothstep(0.4, 0.75, streak);
	col += mix(teal, violet, smoothstep(0.0, 0.16, band)) * ribbon * 1.1;
	// Threads of marigold where the clouds' noise crosses its middle.
	float thread = 1.0 - smoothstep(0.0, 0.006, abs(texture(noise, d * 2.4 + vec3(5.0, t * 0.003, 1.0)).r - 0.5));
	col += marigold * thread * smoothstep(0.45, 0.7, cloud) * 0.8;
	// A few stars.
	vec3 cell = floor(d * 160.0);
	float h = hash3(cell);
	float twinkle = 0.6 + 0.4 * sin(t * (0.7 + h * 2.0) + h * 30.0);
	col += star * step(0.993, h) * smoothstep(0.42, 0.0, length(fract(d * 160.0) - 0.5)) * twinkle * (1.0 - stepped);
	ALBEDO = col;
}
