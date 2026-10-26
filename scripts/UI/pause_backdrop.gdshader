shader_type canvas_item;
// The pause painting melting into the paused game: whole behind the words at
// the left, thinning toward the right and the foot in a dry brush's torn
// edge, so the frozen game shows through; a trace of the room stays over it.
// Only the edge moves, in held steps (a hand-drawn boil).
uniform sampler2D noise : filter_linear, repeat_enable;
// 0..1: how far it has bloomed in.
uniform float level = 1.0;
uniform float fps = 9.0;

float hash(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

void fragment() {
	vec4 paint = texture(TEXTURE, UV);
	float step_n = floor(TIME * fps);
	vec2 boil = vec2(hash(step_n), hash(step_n + 17.0)) * 0.5;
	vec2 s = SCREEN_UV;
	float n = texture(noise, s * vec2(1.6, 0.9) + boil).r;
	float fine = texture(noise, s * vec2(6.0, 3.0) + boil * 1.7).r;
	// Whole at the left; melting from the middle out to the right edge.
	float melt = 1.0 - smoothstep(0.4, 1.05, s.x + (n - 0.5) * 0.3 + (fine - 0.5) * 0.08);
	// The foot thins too.
	float foot = 1.0 - smoothstep(0.75, 1.1, s.y + (n - 0.5) * 0.22 + (fine - 0.5) * 0.06);
	float keep = max(melt * mix(1.0, foot, 0.6), 0.2);
	// Blooming in, the torn edge sweeps out from the words.
	keep *= smoothstep(0.0, 0.25, level * 1.25 - s.x * 0.25 + (n - 0.5) * 0.1);
	COLOR = vec4(paint.rgb, paint.a * keep);
}
