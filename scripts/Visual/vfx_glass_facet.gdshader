// A facet of the cracked pane Blink leaves where you stood
// (MagicFx.blink_crack): the world behind it seen a little shifted, each
// facet its own way, like a broken mirror, a cold sheen over it, and a cold
// line along its cracks (the mesh carries barycentric corners in COLOR, set
// so a quad's diagonal is no crack). `fade` takes it away as it falls.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec2 shift = vec2(0.01, 0.0);
uniform float sheen = 0.12;
uniform vec4 glint : source_color = vec4(0.9, 0.933, 0.96, 1.0);
uniform float crack_energy = 1.8;
uniform float crack_width = 0.03;
uniform float fade : hint_range(0.0, 1.0) = 1.0;

varying vec3 corner;

void vertex() {
	corner = COLOR.rgb;
}

void fragment() {
	vec3 behind = texture(screen_tex, SCREEN_UV + shift * fade).rgb;
	float facing = clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0);
	// A mirror's sheen: what is behind, brightened and cooled, not white laid
	// over it (that went milky at night).
	vec3 colour = behind * (1.0 + sheen) + glint.rgb * (sheen * 0.15 + (1.0 - facing) * 0.12);
	float crack = 1.0 - smoothstep(0.0, crack_width, min(corner.x, min(corner.y, corner.z)));
	ALBEDO = mix(colour, glint.rgb * crack_energy, crack);
	ALPHA = fade;
}
