// The eclipse in the astral deep (scripts/Visual/AstralPassage.gd): the city's eclipse seen from the other side. A black
// sun, its rim a thin burning line, its corona oxblood and marigold in streamers that climb slowly off it, the whole
// breathing; turned to whoever looks, seen only through the passage's windows.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, fog_disabled, blend_mix;
stencil_mode read, compare_equal, 1;

uniform sampler3D noise : filter_linear, repeat_enable;
uniform vec3 ink : source_color = vec3(0.004, 0.003, 0.006);
uniform vec3 oxblood : source_color = vec3(0.431, 0.122, 0.102);
uniform vec3 marigold : source_color = vec3(1.0, 0.62, 0.16);
uniform vec3 pale : source_color = vec3(1.0, 0.9, 0.72);

void vertex() {
	// (Turned to the eye that looks at it.)
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	// Its breath.
	float breath = 0.85 + 0.15 * sin(TIME * 0.22);
	float disc = 0.34;
	// The corona's streamers: noise drawn out along the radius, climbing slowly off the rim.
	float streams = texture(noise, vec3(cos(a) * 1.2, sin(a) * 1.2, r * 1.4 - TIME * 0.03)).r;
	float fine = texture(noise, vec3(cos(a) * 3.0, sin(a) * 3.0, r * 3.0 - TIME * 0.05)).r;
	float reach = disc + (0.18 + 0.5 * smoothstep(0.4, 0.85, streams)) * breath;
	float corona = smoothstep(reach, disc, r) * smoothstep(disc - 0.01, disc + 0.02, r);
	corona *= 0.6 + 0.6 * fine;
	vec3 col = mix(oxblood, marigold, smoothstep(0.0, 0.8, corona) * smoothstep(disc + 0.25, disc, r));
	col = mix(col, pale, smoothstep(0.85, 1.0, corona) * smoothstep(disc + 0.06, disc, r));
	// Its rim, a thin burning line.
	float rim = smoothstep(0.018, 0.0, abs(r - disc));
	col += pale * rim * breath;
	// A glow far round it.
	float glow = smoothstep(1.0, disc, r) * 0.25;
	float lit = max(max(corona, rim), glow);
	ALBEDO = r < disc ? ink : col;
	ALPHA = r < disc ? 1.0 : clamp(lit, 0.0, 1.0);
}
