shader_type canvas_item;
// A page's painting at full colour and brushwork, standing in the city behind
// the page's text: torn all round, melting longest to the left. Outside the
// painting the city simply shows. Only the edges move, in steps.
uniform sampler2D atlas : source_color, filter_linear_mipmap;
uniform sampler2D noise : filter_linear, repeat_enable;
// The painting's window in the atlas, and where it sits in the page (UV box).
uniform vec4 rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 box = vec4(0.2, 0.1, 0.7, 0.7);
uniform float boil_fps = 9.0;
uniform vec2 px = vec2(1070.0, 900.0);

float hash(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

void fragment() {
	vec2 p = (UV - box.xy) / box.zw;
	vec4 paint = texture(atlas, rect.xy + clamp(p, vec2(0.0), vec2(1.0)) * rect.zw);
	float step_n = floor(TIME * boil_fps);
	vec2 boil = vec2(hash(step_n), hash(step_n + 17.0)) * 0.5;
	vec2 at = p * box.zw * px;
	float n = texture(noise, at / vec2(600.0, 300.0) + boil).r;
	float fine = texture(noise, at / vec2(150.0, 60.0) + boil * 1.7).r;
	float ragged = (n - 0.5) * 0.18 + (fine - 0.5) * 0.06;
	float left = smoothstep(0.0, 0.5, p.x + ragged);
	float right = 1.0 - smoothstep(0.78, 1.0, p.x + ragged);
	float top = smoothstep(0.0, 0.2, p.y + ragged);
	float bottom = 1.0 - smoothstep(0.8, 1.0, p.y + ragged);
	float inside = step(0.0, p.x) * step(p.x, 1.0) * step(0.0, p.y) * step(p.y, 1.0);
	COLOR = vec4(paint.rgb, paint.a * left * right * top * bottom * inside * 0.92);
}
