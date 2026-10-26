shader_type canvas_item;
// An archetype's portrait, cut from the sheet: the painting itself, never
// tinted or glazed. Its edges are a dry brush's, boiling in steps, and they
// sink into the dark at the very rim (a longer fall at the foot) so no pale
// paint is left floating over the city. Asleep, it is dimmed and greyed.
uniform sampler2D sheet : source_color, filter_linear_mipmap;
uniform sampler2D noise : filter_linear, repeat_enable;
// The panel's window in the sheet (x, y, w, h in sheet UV).
uniform vec4 rect = vec4(0.0, 0.0, 1.0, 1.0);
// 0 asleep .. 1 chosen.
uniform float wake = 0.0;
uniform float alpha = 1.0;
uniform float fps = 9.0;
uniform vec2 px = vec2(281.0, 480.0);

float hash(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

void fragment() {
	vec4 paint = texture(sheet, rect.xy + UV * rect.zw);
	float step_n = floor(TIME * fps);
	vec2 boil = vec2(hash(step_n), hash(step_n + 17.0)) * 0.5;
	vec2 p = UV * px;
	float n = texture(noise, p / vec2(200.0, 260.0) + boil).r;
	float fine = texture(noise, p / vec2(60.0, 18.0) + boil * 1.7).r;
	float sides = min(p.x, px.x - p.x) / 22.0;
	float top = p.y / 22.0;
	float foot = (px.y - p.y) / 70.0;
	float edge = min(min(sides, top), foot) + (n - 0.5) * 0.9 + (fine - 0.5) * 0.35;
	float cover = smoothstep(0.0, 1.0, edge);
	// The outermost band sinks into the dark before it goes, so the paint's
	// pale passages never leave a grey rim.
	float sink = smoothstep(0.0, 2.6, edge);
	float grey = dot(paint.rgb, vec3(0.3, 0.59, 0.11));
	vec3 asleep = mix(vec3(grey), paint.rgb, 0.5) * 0.42;
	vec3 rgb = mix(asleep, paint.rgb, wake) * mix(0.12, 1.0, sink);
	COLOR = vec4(rgb, cover * alpha);
}
