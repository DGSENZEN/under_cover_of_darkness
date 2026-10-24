// The edge of the view coloured by magic (MagicView.gd): Blink's cold flash,
// Empower's beast pulse, a soft vignette strongest in the corners; and
// Blink's rush, the picture smeared in toward the middle, most at the edges.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(0.87, 0.9, 0.95, 1.0);
uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform float rush : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 from_middle = (UV - 0.5) * vec2(1.25, 1.0);
	float edge = smoothstep(0.32, 0.78, length(from_middle));
	float tinted = tint.a * edge * amount;

	if (rush > 0.001) {
		vec2 to_middle = vec2(0.5) - SCREEN_UV;
		vec3 smeared = vec3(0.0);

		for (int i = 0; i < 10; i++) {
			smeared += texture(screen_tex, SCREEN_UV + to_middle * rush * 0.09 * float(i) / 9.0).rgb;
		}

		smeared /= 10.0;
		vec3 here = texture(screen_tex, SCREEN_UV).rgb;
		vec3 picture = mix(here, smeared, smoothstep(0.15, 0.6, length(from_middle)));
		COLOR = vec4(mix(picture, tint.rgb, tinted), 1.0);
	} else {
		COLOR = vec4(tint.rgb, tinted);
	}
}
