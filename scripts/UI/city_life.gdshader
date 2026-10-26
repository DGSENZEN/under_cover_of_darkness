shader_type canvas_item;
// The menu's city: the painting itself never moves. Only things that would
// move there do — wisps of cloud, lights and fire, haze over the lake, the
// lake's reflections, the moon's glow — and the score's layers stir them.
uniform sampler2D masks : filter_linear;
uniform sampler2D noise : filter_linear, repeat_enable;
uniform float base = 0.0;
uniform float low = 0.0;
uniform float high = 0.0;
uniform float fx = 0.0;
uniform float dim = 1.0;
const vec2 MOON = vec2(0.075, 0.129);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	vec4 m = texture(masks, uv);
	vec3 col = texture(TEXTURE, uv).rgb;

	// Reflections: a slight horizontal shiver, only on the open water.
	float ripple = sin(uv.y * 900.0 + TIME * 1.6) * 0.001 + sin(uv.y * 370.0 - TIME * 1.1) * 0.0005;
	col = mix(col, texture(TEXTURE, uv + vec2(ripple, 0.0)).rgb, m.b);

	// Lights: each little patch of the city steps to a new brightness 3-9
	// times a second, out of step with its neighbours. Fire (G 0.4) gently.
	vec2 cell = floor(uv * 512.0);
	float phase = hash(cell);
	float rate = 3.0 + 6.0 * hash(cell + 3.1);
	float flick = hash(vec2(floor(TIME * rate + phase * 10.0), phase)) - 0.5;
	float amp = 0.15 + 0.15 * low;
	col *= 1.0 + m.g * flick * 2.0 * amp;

	// Clouds: wisps drifting across the sky only, stepped like paint, not smoke.
	float wisp = texture(noise, uv * vec2(1.6, 4.2) + vec2(TIME * 0.004, 0.0)).r;
	wisp = floor(smoothstep(0.52, 0.86, wisp) * 4.0) / 4.0;
	col = mix(col, col * 1.35 + vec3(0.03, 0.035, 0.05), wisp * 0.22 * m.r);

	// Haze: low over the lake, behind the near buildings (A); the occult
	// layer thickens and cools it.
	float band = m.a;
	float drift = texture(noise, uv * vec2(1.2, 7.0) + vec2(TIME * 0.002, 0.3)).r;
	vec3 haze = mix(vec3(0.55, 0.5, 0.47), vec3(0.38, 0.47, 0.62), fx);
	col = mix(col, haze, band * smoothstep(0.35, 0.8, drift) * (0.12 + 0.12 * fx));

	// The moon's glow breathes, slowly.
	vec2 d = (uv - MOON) * vec2(1.79, 1.0);
	float glow = exp(-dot(d, d) / 0.0035);
	col += vec3(1.0, 0.95, 0.85) * glow * 0.08 * sin(TIME * 6.2831853 * 0.08) * (1.0 + base * 0.5);

	COLOR = vec4(col * dim, 1.0);
}
