// A flame's corona, as Thief: Deadly Shadows drew them: a soft halo the same
// size on screen however far the flame is, drawn over the fog, added onto
// the scene. Walls and men hide it by ray (Corona.gd), not by depth, so it
// is drawn without the depth test and fades rather than being cut.
shader_type spatial;
render_mode unshaded, blend_add, depth_test_disabled, depth_draw_never, fog_disabled, cull_disabled, shadows_disabled;

uniform sampler2D falloff : filter_nearest, repeat_disable;
// Sizes are measured on this many lines (the Retro screen's grid).
uniform float grid_lines = 360.0;
// How bright the halo is at its heart: a haze round the flame, never over it.
uniform float intensity = 0.4;

instance uniform float size_px = 48.0;
instance uniform float amount = 0.0;
instance uniform vec4 tint : source_color = vec4(1.0);

void vertex() {
	vec4 centre = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(NODE_POSITION_WORLD, 1.0));
	float across = size_px / grid_lines * 2.0;
	vec2 aspect = vec2(VIEWPORT_SIZE.y / max(VIEWPORT_SIZE.x, 1.0), 1.0);
	POSITION = centre + vec4(VERTEX.xy * across * aspect * centre.w, 0.0, 0.0);
}

void fragment() {
	float f = texture(falloff, UV).r;
	ALBEDO = tint.rgb;
	ALPHA = f * amount * intensity;
}
