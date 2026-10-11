// A ward sigil on a sigil disc (Occult.gd): our sigil_strokes sheet (red: the
// order its strokes are drawn in, alpha: where it is drawn), written on by a
// threshold (`drawn` 0..1, the stroke's tip hottest), glowing the wards'
// cyan-white (`glow`, with the hum). A placeholder: the real glyphs are the
// user's to paint.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

uniform sampler2D sheet : filter_nearest, repeat_disable;
uniform vec4 colour : source_color = vec4(0.812, 0.91, 0.941, 1.0);
instance uniform float drawn = 1.0;
instance uniform float glow = 1.0;

void fragment() {
	vec4 s = texture(sheet, UV);
	float written = step(s.r, drawn) * step(0.5, s.a);
	// The stroke being drawn now burns brightest.
	float tip = 1.0 - smoothstep(0.0, 0.06, drawn - s.r);
	ALBEDO = colour.rgb * (1.0 + 2.0 * tip * step(drawn, 0.999));
	ALPHA = written * glow;
}
