shader_type canvas_item;
// A word's painting, at full colour and brushwork, washed in around the word:
// torn at top and bottom, soft on every side, melting away to the left into
// the city. Only the edges move, in steps (a hand-drawn boil).
uniform sampler2D atlas : source_color, filter_linear_mipmap;
uniform sampler2D noise : filter_linear, repeat_enable;
// The painting's window in the atlas (x, y, w, h in atlas UV).
uniform vec4 rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform float alpha = 0.0;
uniform float boil_fps = 9.0;
uniform vec2 px = vec2(440.0, 170.0);

float hash(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

void fragment() {
	vec4 paint = texture(atlas, rect.xy + UV * rect.zw);
	float step_n = floor(TIME * boil_fps);
	vec2 boil = vec2(hash(step_n), hash(step_n + 17.0)) * 0.5;
	vec2 p = UV * px;
	float n = texture(noise, vec2(p.x / 520.0, p.y / 160.0) + boil).r;
	float fine = texture(noise, vec2(p.x / 140.0, p.y / 40.0) + boil * 1.7).r;
	// Torn top and bottom: a dry brush's ragged edge.
	float edge = min(p.y, px.y - p.y) / 30.0 + (n - 0.5) * 1.1 + (fine - 0.5) * 0.35;
	float torn = smoothstep(0.0, 1.0, edge);
	// Long melt to the left, a shorter fray to the right.
	float left = smoothstep(0.0, 0.62, UV.x + (n - 0.5) * 0.12);
	float right = 1.0 - smoothstep(0.66, 1.0, UV.x + (n - 0.5) * 0.14 + (fine - 0.5) * 0.06);
	COLOR = vec4(paint.rgb, paint.a * torn * left * right * alpha * 0.92);
}
