shader_type canvas_item;
// AdrenalineView combat pass below Retro: heartbeat rim, impact jolt/chromatic split,
// directional red hurt flood, and low-health desaturation. The central fight view stays clear.

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
// 0..1: how much of the adrenaline to show (full adrenaline, faded in).
uniform float ready = 0.0;
// 0..1: the heartbeat's thump right now.
uniform float beat = 0.0;
// 0..1: a power blow is being wound up with adrenaline to spend.
uniform float primed = 0.0;
// 0..1.5: a blow just landed, dying away in a moment.
uniform float impact = 0.0;
// 0..1: you were just cut; `hurt_side` where from (-1 left, 0 ahead, 1 right).
uniform float hurt = 0.0;
uniform float hurt_side = 0.0;
// 0..1: how near death you are.
uniform float wounded = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 from_middle = uv - 0.5;
	// Round, not stretched with the screen.
	vec2 round_off = from_middle * vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	float r = length(round_off) * 1.55;
	vec2 away = normalize(from_middle + vec2(1e-5));

	float strength = ready * (0.5 + 0.35 * beat + 0.45 * primed);
	float rim = smoothstep(0.42 - 0.08 * beat - 0.1 * primed, 1.05, r) * strength;

	// The jolt: a short smear in toward the middle, stronger at the edges,
	// and the colours pulled apart there.
	float jolt = impact * smoothstep(0.1, 1.0, r);
	vec2 pull = -from_middle * impact * 0.014;
	float spread = rim * (0.0025 + 0.004 * beat) + jolt * 0.007;
	vec3 colour = vec3(0.0);

	for (int i = 0; i < 3; i++) {
		vec2 at = uv + pull * float(i);
		colour += vec3(
			texture(screen, at - away * spread).r,
			texture(screen, at).g,
			texture(screen, at + away * spread).b);
	}

	colour /= 3.0;
	float grey = dot(colour, vec3(0.299, 0.587, 0.114));

	// Blood in the eyes: warmer, greyer, darker toward the rim.
	vec3 warm = vec3(grey) * vec3(1.35, 0.62, 0.45);
	colour = mix(colour, warm, rim * 0.7);
	colour *= 1.0 - rim * 0.42;
	colour += vec3(0.22, 0.015, 0.0) * rim * rim * beat;

	// Near death: the colour drains away, and the edges close in.
	colour = mix(colour, vec3(grey) * vec3(1.02, 0.94, 0.9), wounded * 0.6);
	colour *= 1.0 - smoothstep(0.55, 1.2, r) * wounded * 0.35;

	// Cut: red from the side it came from.
	float toward = clamp(0.65 + hurt_side * from_middle.x * 2.4, 0.2, 1.7);
	float flood = smoothstep(0.2, 1.05, r * toward) * hurt;
	vec3 red = vec3(grey * 0.55 + 0.16, grey * 0.06, grey * 0.05);
	colour = mix(colour, red, flood * 0.8);

	// The very instant of a blow: a hair brighter.
	colour *= 1.0 + impact * 0.05;
	COLOR = vec4(colour, 1.0);
}
