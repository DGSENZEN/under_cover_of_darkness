// An eye opening in the astral void (scripts/Visual/AstralPassage.gd), far off, turned to whoever looks: an almond of
// ink, its iris marigold and glowing, its pupil a slit; its lids closing and opening on its own slow clock. Seen only
// through the passage's windows.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, fog_disabled, blend_mix;
stencil_mode read, compare_equal, 1;

uniform float seed = 0.0;
uniform vec3 white : source_color = vec3(0.86, 0.84, 0.76);
uniform vec3 iris : source_color = vec3(1.0, 0.58, 0.14);
uniform vec3 ink : source_color = vec3(0.02, 0.015, 0.03);

void vertex() {
	// (Turned to the eye that looks at it.)
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	// Its lids: open most of the time, closing slowly now and then.
	float cycle = fract(TIME * 0.07 + seed);
	float open = 1.0 - smoothstep(0.82, 0.9, cycle) * (1.0 - smoothstep(0.92, 1.0, cycle));
	float lid = (1.0 - p.x * p.x) * 0.55 * open;
	float almond = step(abs(p.y), lid);
	float rim = step(abs(p.y), lid + 0.06) - almond;
	// Its iris and its slit, looking a little about.
	vec2 look = vec2(sin(TIME * 0.21 + seed * 9.0) * 0.18, 0.0);
	float d = length((p - look) * vec2(1.0, 1.0));
	float in_iris = step(d, 0.42);
	float slit = step(abs(p.x - look.x), 0.06 * open + 0.01) * in_iris;
	vec3 col = mix(white * 0.35, iris * (1.3 - d), in_iris);
	col = mix(col, ink, slit);
	ALBEDO = mix(ink, col, almond);
	ALPHA = max(almond, rim * 0.9);
}
