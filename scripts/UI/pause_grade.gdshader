shader_type canvas_item;
// The paused game under the pause painting: drained toward the painting's
// blue-violet and darkened, so where the painting melts away the two meet.
uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float level = 1.0;

void fragment() {
	vec3 c = textureLod(screen, SCREEN_UV, 1.0).rgb;
	float grey = dot(c, vec3(0.3, 0.59, 0.11));
	vec3 graded = mix(c, grey * vec3(0.72, 0.78, 1.0), 0.6) * 0.72;
	COLOR = vec4(mix(c, graded, level), 1.0);
}
