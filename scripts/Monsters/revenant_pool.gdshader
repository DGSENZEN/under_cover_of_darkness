shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled;
// The dark where it stands: black water under its feet that isn't on the floor. Its edge creeps.

uniform vec3 seep : source_color = vec3(0.5, 0.83, 0.42);
uniform sampler2D stroke_sheet : filter_linear_mipmap, repeat_enable;

float bump(vec2 p) {
	return sin(p.x * 3.1 + sin(p.y * 2.3)) * 0.5 + sin(p.y * 4.3 + sin(p.x * 1.7)) * 0.5;
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float reach = 0.6 + bump(p * 1.7 + vec2(TIME * 0.05, 0.0)) * 0.07 + (texture(stroke_sheet, UV * 1.6).r - 0.5) * 0.3;
	ALBEDO = vec3(0.004, 0.006, 0.006);
	ALPHA = smoothstep(reach + 0.015, reach - 0.015, r) * 0.96;
}
