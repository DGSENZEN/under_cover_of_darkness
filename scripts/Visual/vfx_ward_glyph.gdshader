// A glyph of the Ward's written circle (Ward.gd, and the ring round the
// copal circle in your hand: HandSlot.gd), in the invented script: one quad,
// its glyph read from the distance-field atlas cell its instance names
// (after scripts/Visual/Library/library_glyph.gdshader on metro-standard),
// so its edge stays sharp at any distance. A bright core in the ward colour,
// a dark rim round it so it reads on any floor, a faint halo beyond. Each
// instance's `glyph`: its cell (x, y), how written in it is (z), a seed (w)
// for its flicker. In your view it is drawn as the arms are.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;

uniform sampler2D atlas : filter_linear_mipmap, repeat_disable;
uniform vec2 grid = vec2(8.0, 6.0);
uniform vec4 core : source_color = vec4(0.81, 0.91, 0.94, 1.0);
uniform vec4 rim : source_color = vec4(0.04, 0.06, 0.08, 1.0);
uniform float energy = 1.6;
uniform float z_clip = 1.0;
uniform float fov_override = 0.0;
instance uniform vec4 glyph = vec4(0.0, 0.0, 1.0, 0.0);

void vertex() {
	Z_CLIP_SCALE = z_clip;

	if (fov_override > 0.0) {
		float f = 1.0 / tan(radians(fov_override) * 0.5);
		float aspect = abs(PROJECTION_MATRIX[1][1] / PROJECTION_MATRIX[0][0]);
		PROJECTION_MATRIX[1][1] = f * sign(PROJECTION_MATRIX[1][1]);
		PROJECTION_MATRIX[0][0] = f / aspect * sign(PROJECTION_MATRIX[0][0]);
	}
}

void fragment() {
	// (Inset so a neighbour's cell never bleeds in at a distance.)
	vec2 at = (glyph.xy + clamp(UV, vec2(0.02), vec2(0.98))) / grid;
	float d = texture(atlas, at).r;
	float w = max(fwidth(d) * 0.75, 0.015);
	float ink = smoothstep(0.5 - w, 0.5 + w, d);
	float inner = smoothstep(0.58 - w, 0.58 + w, d);
	float halo = smoothstep(0.3, 0.5, d) * 0.3;
	float flicker = 0.85 + 0.15 * sin(TIME * 3.0 + glyph.w * 6.283);
	ALBEDO = mix(core.rgb * energy * 0.6, mix(rim.rgb, core.rgb * energy * flicker, inner), ink);
	ALPHA = clamp(max(ink, halo), 0.0, 1.0) * glyph.z;
	if (ALPHA < 0.01) {
		discard;
	}
}
