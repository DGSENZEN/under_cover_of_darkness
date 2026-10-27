// A cut-out seen far off in the astral void (scripts/Visual/AstralPassage.gd): the shades walking a way of their own
// across it, the giant hand drifting past; one cell of a sheet, inked, a cold rim of light round its outline, seen
// only through the passage's windows. Its uniforms are the shade cut-out's (shade_cutout.gdshader), so a Silhouette
// shows its cells and walks its loop on it.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, fog_disabled, blend_mix;
stencil_mode read, compare_equal, 1;

uniform sampler2D sheet : filter_linear, repeat_disable;
uniform vec2 cell_scale = vec2(0.25, 0.5);
uniform vec2 cell_offset = vec2(0.0, 0.0);
uniform sampler3D noise : filter_linear, repeat_enable;
uniform float presence = 1.0;
uniform vec3 ink : source_color = vec3(0.02, 0.016, 0.03);
uniform vec3 rim : source_color = vec3(0.34, 0.78, 0.9);

varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float shape(vec2 uv) {
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		return 0.0;
	}
	return texture(sheet, cell_offset + uv * cell_scale).a;
}

void fragment() {
	float here = shape(UV);
	float r = 0.012;
	float around = (shape(UV + vec2(r, 0.0)) + shape(UV - vec2(r, 0.0)) + shape(UV + vec2(0.0, r))
		+ shape(UV - vec2(0.0, r))) / 4.0;
	// Its outline lit, its body ink, the whole frayed a little at its edge.
	float n = texture(noise, world * 2.0 + vec3(0.0, -TIME * 0.2, 0.0)).r;
	float body = smoothstep(0.35, 0.6, here + (n - 0.5) * 0.3 * (1.0 - around));
	float edge = clamp(here - around * 0.98, 0.0, 1.0) + clamp(around - here, 0.0, 1.0) * 0.6;
	ALBEDO = ink + rim * smoothstep(0.05, 0.4, edge) * 1.2;
	ALPHA = max(body, smoothstep(0.05, 0.4, edge)) * presence;
}
