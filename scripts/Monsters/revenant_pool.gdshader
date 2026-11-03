shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled;
// The lake, where it stands: black water under its feet that isn't on the floor, with the seep's rings going out through it.

uniform vec3 seep : source_color = vec3(0.5, 0.83, 0.42);
uniform sampler2D stroke_sheet : filter_linear_mipmap, repeat_enable;

float bump(vec2 p) {
	return sin(p.x * 3.1 + sin(p.y * 2.3)) * 0.5 + sin(p.y * 4.3 + sin(p.x * 1.7)) * 0.5;
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	// Its edge, ragged and creeping.
	float reach = 0.6 + bump(p * 1.7 + vec2(TIME * 0.05, 0.0)) * 0.07 + (texture(stroke_sheet, UV * 1.6).r - 0.5) * 0.3;
	float inside = smoothstep(reach + 0.015, reach - 0.015, r);
	// Rings, going out from it. Thin, hard, breaking up as they go.
	float rings = 0.0;

	for (int i = 0; i < 2; i++) {
		float at = fract(TIME * 0.11 + float(i) / 2.0);
		float line = smoothstep(0.008, 0.0, abs(r - at * reach));
		rings += line * (1.0 - at) * (1.0 - at) * smoothstep(0.42, 0.62, texture(stroke_sheet, UV * 2.4 + float(i) * 0.3).r);
	}

	ALBEDO = vec3(0.004, 0.006, 0.006) + seep * rings * 0.4;
	ALPHA = inside * 0.96;
}
