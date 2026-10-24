// The Shard's trail (ShardTrail.gd): a dark smear of bent light behind it,
// a thin cold line down its middle. u runs across the ribbon (0..1), v is
// each point's age as a share of the trail's life (0 new, 1 gone), so it
// thins and fades from its tail.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float strength = 0.012;
uniform float darken = 0.65;
uniform vec4 line_tint : source_color = vec4(0.9, 0.933, 0.96, 1.0);
uniform float line_energy = 1.6;

void fragment() {
	float age = clamp(UV.y, 0.0, 1.0);
	float from_middle = abs(UV.x * 2.0 - 1.0);
	// Narrower as it ages: what is left of its width.
	float width = 1.0 - age;
	if (from_middle > width) {
		discard;
	}
	float across = from_middle / max(width, 0.001);
	vec2 bend = vec2(UV.x * 2.0 - 1.0, 0.0) * strength * (1.0 - across);
	vec3 behind = texture(screen_tex, SCREEN_UV + bend).rgb;
	float line = 1.0 - step(0.22, across);
	ALBEDO = mix(behind * (1.0 - darken * (1.0 - across)), line_tint.rgb * line_energy, line * (1.0 - age));
	ALPHA = (1.0 - age) * mix(0.9, 1.0, line);
}
