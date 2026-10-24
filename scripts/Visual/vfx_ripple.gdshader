// Blink's arrival: a shell of glass the world bends through, strongest at
// its rim, fading out (MagicFx.ripple).
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float strength = 0.04;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform vec4 rim_tint : source_color = vec4(0.9, 0.93, 0.96, 1.0);

void fragment() {
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float rim = pow(1.0 - facing, 2.5);
	vec2 bend = NORMAL.xy * strength * rim * fade;
	vec3 behind = texture(screen_tex, SCREEN_UV - bend).rgb;
	ALBEDO = mix(behind, rim_tint.rgb, rim * 0.25 * fade);
	ALPHA = clamp(rim * 1.6, 0.0, 1.0) * fade;
}
