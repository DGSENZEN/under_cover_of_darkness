// The warp of crossing an astral passage's threshold (scripts/Visual/AstralPassage.gd): for a moment the whole view
// swirls about its middle, its colours parting, its edges drawn into ink. `strength` 0 is nothing.
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float strength = 0.0;
uniform vec3 ink : source_color = vec3(0.02, 0.012, 0.04);

void fragment() {
	vec2 c = SCREEN_UV - 0.5;
	float r = length(c);
	float a = strength * 1.4 * (1.0 - smoothstep(0.0, 0.75, r));
	vec2 turned = vec2(c.x * cos(a) - c.y * sin(a), c.x * sin(a) + c.y * cos(a)) + 0.5;
	vec2 apart = c * 0.012 * strength;
	vec3 col = vec3(texture(screen, turned + apart).r, texture(screen, turned).g, texture(screen, turned - apart).b);
	col = mix(col, ink, smoothstep(0.35, 0.75, r) * strength * 0.85);
	COLOR = vec4(col, 1.0);
}
