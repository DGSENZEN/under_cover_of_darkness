// A glyph constellation's star or thread in the astral deep (scripts/Visual/AstralPassage.gd): ward cyan-white, its
// glow growing as its constellation is lit (`lit`), a thread only a faint line until then; seen only through the
// passage's windows. A star turns to whoever looks (`star`); a thread lies as it was laid.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, fog_disabled, blend_add;
stencil_mode read, compare_equal, 1;

uniform vec3 ward : source_color = vec3(0.812, 0.91, 0.941);
uniform vec3 marigold : source_color = vec3(1.0, 0.62, 0.16);
uniform float lit = 0.0;
// The flare of its lighting (1 as it starts, fading).
uniform float flare = 0.0;
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
		float halo = exp(-r * r * 5.0) * (0.15 + 0.85 * lit + 1.5 * flare);
		// Its four-pointed glint, longer when lit, longest in the flare of its lighting.
		float glint = (exp(-abs(p.x) * 50.0) + exp(-abs(p.y) * 50.0)) * exp(-r * (4.0 - 2.8 * max(lit, flare))) * (0.2 + lit + flare);
		ALBEDO = mix(ward, marigold, lit * 0.2 + flare * 0.3) * (core + halo + glint) * twinkle * (0.3 + 0.9 * lit + flare);
	} else {
		// A thread: a fine line along its middle, drawn in as its constellation lights, its drawing end brightest.
		float line = exp(-p.y * p.y * 40.0) + exp(-p.y * p.y * 6.0) * 0.25 * lit;
		float reach = lit * 1.15;
		float drawn = smoothstep(reach, reach - 0.08, UV.x);
		float tip = exp(-pow((UV.x - reach + 0.04) / 0.05, 2.0)) * (1.0 - lit) * 2.0;
		ALBEDO = ward * line * (0.04 + 0.85 * lit * drawn + tip) * twinkle;
	}
}
