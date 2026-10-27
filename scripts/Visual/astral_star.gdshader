// A glyph constellation's star or thread in the astral deep (scripts/Visual/AstralPassage.gd): ward cyan-white, its
// glow growing as its constellation is lit (`lit`), a thread only a faint line until then; seen only through the
// passage's windows. A star turns to whoever looks (`star`); a thread lies as it was laid.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, fog_disabled, blend_add;
stencil_mode read, compare_equal, 1;

uniform vec3 ward : source_color = vec3(0.812, 0.91, 0.941);
uniform vec3 marigold : source_color = vec3(1.0, 0.62, 0.16);
uniform float lit = 0.0;
uniform bool star = true;
instance uniform float seed = 0.0;

void vertex() {
	if (star) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	}
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float twinkle = 0.75 + 0.25 * sin(TIME * (1.0 + seed) + seed * 17.0);
	if (star) {
		float r = length(p);
		float core = exp(-r * r * 22.0) * 1.6;
		float halo = exp(-r * r * 5.0) * (0.25 + 0.75 * lit);
		// Its four-pointed glint, longer when lit.
		float glint = (exp(-abs(p.x) * 50.0) + exp(-abs(p.y) * 50.0)) * exp(-r * (4.0 - 2.8 * lit)) * (0.3 + lit);
		ALBEDO = mix(ward, marigold, lit * 0.2) * (core + halo + glint) * twinkle * (0.45 + 0.75 * lit);
	} else {
		// A thread: a fine line along its middle, drawn as its constellation lights.
		float line = exp(-p.y * p.y * 40.0);
		float drawn = smoothstep(lit * 1.2, lit * 1.2 - 0.1, UV.x);
		ALBEDO = ward * line * (0.1 + 0.8 * lit * drawn) * twinkle;
	}
}
