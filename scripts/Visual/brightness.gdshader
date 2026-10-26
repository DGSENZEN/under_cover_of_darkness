shader_type canvas_item;
// The player's brightness: a lift (or a lowering) of the picture's middle
// tones, a gamma, leaving black black and white white.
uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform float brightness = 1.0;

void fragment() {
	vec3 c = texture(screen, SCREEN_UV).rgb;
	COLOR = vec4(pow(max(c, vec3(0.0)), vec3(1.0 / max(brightness, 0.01))), 1.0);
}
