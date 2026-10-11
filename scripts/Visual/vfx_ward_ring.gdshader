// The wards' ring (Occult.gd): close to a ward-cage lamp, the air round its
// lenses bends, a ring of the screen pushed outward (at most 0.006 of the
// screen), shimmering with the hum, faint cyan at its crest; `strength`
// fades it with the player's distance.
shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float strength = 0.0;
uniform float hum = 0.0;
uniform vec4 colour : source_color = vec4(0.812, 0.91, 0.941, 1.0);

void vertex() {
	// Facing the camera.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	float r = length(c);
	float ring = smoothstep(0.55, 0.78, r) * (1.0 - smoothstep(0.78, 1.0, r));
	vec2 push = (r > 0.001 ? c / r : vec2(0.0)) * 0.006 * strength * ring * (0.8 + 0.2 * sin(hum));
	ALBEDO = texture(screen, SCREEN_UV - push).rgb + colour.rgb * ring * strength * 0.05;
	ALPHA = step(0.001, ring * strength);
}
