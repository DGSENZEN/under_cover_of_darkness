shader_type canvas_item;
// The selection band: a torn, dry-brushed swath across the city carrying one
// illustration, glazed toward the night. Only the band's EDGES move, and in
// steps (a hand-drawn boil); the illustration itself is never displaced.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D atlas : source_color, filter_linear_mipmap;
uniform sampler2D noise : filter_linear, repeat_enable;
// Atlas UV windows (x, y, w, h) and where each sits inside the band (UV box).
uniform vec4 rect_a = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 rect_b = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 box_a = vec4(0.4, 0.0, 0.42, 1.0);
uniform vec4 box_b = vec4(0.4, 0.0, 0.42, 1.0);
uniform float mix_ab = 1.0;
uniform vec4 glaze_a : source_color = vec4(1.0);
uniform vec4 glaze_b : source_color = vec4(1.0);
uniform float glaze_amount = 0.28;
uniform float page = 0.0;
uniform float pulse = 0.0;
uniform float boil_fps = 9.0;
// Band size in design px, so noise keeps its grain whatever the band's shape.
uniform vec2 band_px = vec2(1440.0, 360.0);

float hash(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

float lum(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

// A torn edge: distance d from the edge, ragged by noise that re-rolls in steps.
float torn(float d, vec2 at, vec2 boil, float depth) {
	float n = texture(noise, at + boil).r;
	float fine = texture(noise, at * 4.0 + boil * 1.7).r;
	return smoothstep(0.0, depth, d + (n - 0.5) * depth * 1.3 + (fine - 0.5) * depth * 0.35);
}

vec4 art(vec2 uv, vec4 rect, vec4 box, vec2 boil, float t, float as_page) {
	vec2 p = (uv - box.xy) / box.zw;
	// Slow drift inside the band: 18 s each way, scale 1.04-1.08, pan +-1.2%.
	float s = 0.5 + 0.5 * sin(t * 6.2831853 / 36.0);
	float scale = 1.04 + 0.04 * s;
	vec2 q = (p - 0.5) / scale + 0.5 + vec2((s - 0.5) * 0.024, 0.0);
	vec4 c = texture(atlas, rect.xy + clamp(q, vec2(0.0), vec2(1.0)) * rect.zw);
	// The picture has no box edges of its own: the band's torn top and bottom
	// cut it, and it bleeds sideways into the dark word end and the city.
	float bleed = min(p.x / 0.3, (1.0 - p.x) / 0.26);
	float n = texture(noise, vec2(p.x * 0.8, p.y * 2.2) + boil).r;
	float a = smoothstep(0.0, 1.0, bleed + (n - 0.5) * 0.5) * step(0.0, p.x) * step(p.x, 1.0) * step(0.0, p.y) * step(p.y, 1.0);
	// On a page there is no band edge above and below it, so it tears there too.
	float rise = smoothstep(0.0, 1.0, min(p.y, 1.0 - p.y) / 0.24 + (n - 0.5) * 0.5);
	a *= mix(1.0, rise, as_page);
	return vec4(c.rgb, c.a * a);
}

void fragment() {
	vec2 uv = UV;
	float step_n = floor(TIME * boil_fps);
	vec2 boil = vec2(hash(step_n), hash(step_n + 17.0)) * 0.5;
	vec2 px = uv * band_px;

	// Choice mode: torn top and bottom, a soft start at the screen edge, and
	// bristle streaks running out toward the far end.
	float vertical = min(px.y, band_px.y - px.y) / 70.0;
	float choice_mask = torn(vertical, vec2(px.x / 900.0, px.y / 260.0), boil, 1.0);
	choice_mask *= smoothstep(0.0, 0.03, uv.x);
	// Streaks only past the picture, never across it.
	float far = smoothstep(0.84, 1.0, uv.x);
	float bristle = smoothstep(0.25, 0.75, texture(noise, vec2(px.x / 1600.0, px.y / 90.0) + boil * 0.2).r);
	choice_mask *= mix(1.0, bristle, far) * (1.0 - smoothstep(0.84, 1.0, uv.x + (bristle - 0.5) * 0.1));
	// Page mode: the band fills the right two-thirds; only its left side is torn.
	float page_mask = torn(px.x / 80.0, vec2(px.x / 300.0, px.y / 700.0), boil, 1.0);
	float mask = mix(choice_mask, page_mask, page);

	// What is behind: the city, softened and darkened, glazed in the choice's colour.
	vec3 behind = textureLod(screen_tex, SCREEN_UV, 2.5).rgb * 0.62;
	// Each picture keeps its own glaze; the city behind blends between them.
	vec3 glaze = mix(glaze_a.rgb, glaze_b.rgb, mix_ab);
	vec3 tint = glaze / max(lum(glaze), 0.05);
	behind = mix(behind, lum(behind) * tint, glaze_amount * 1.4);

	vec4 a = art(uv, rect_a, box_a, boil, TIME, page);
	vec4 b = art(uv, rect_b, box_b, boil, TIME, page);
	vec4 pic = mix(a, b, mix_ab);
	// Glazed into the night: a little desaturated and darker, washed in the
	// choice's colour, with firelight bleeding through on the right.
	vec3 col = mix(vec3(lum(pic.rgb)), pic.rgb, 0.7) * 0.9;
	col = mix(col, lum(col) * tint, glaze_amount);
	float glow = 1.0 - smoothstep(0.0, 0.55, length((uv - vec2(0.7, 0.5)) * vec2(1.0, 0.6)));
	col += vec3(1.0, 0.55, 0.27) * 0.18 * glow * (1.0 - page * 0.5);
	col = mix(behind, col, pic.a);

	// Dark by the word so it stays readable, opening into the painting.
	float word_end = 0.85 * (1.0 - smoothstep(0.02, 0.4, uv.x)) * (1.0 - page);
	col = mix(col, vec3(0.008, 0.024, 0.031), word_end);
	col *= 1.0 + pulse * 0.25;
	COLOR = vec4(col, mask);
}
