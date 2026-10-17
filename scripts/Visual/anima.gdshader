// An ánima: a small flat flame, Mignola's way: a hard-edged pale shape with a darker core,
// standing upright and turned to the eye, its tip licking; no soft glow (its light on what is
// round it is a lamp's, Animas.gd).
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;

uniform vec4 colour : source_color = vec4(0.66, 0.92, 0.62, 1.0);
uniform vec4 core : source_color = vec4(0.16, 0.36, 0.26, 1.0);
uniform float presence = 1.0;
uniform float seed = 0.0;

void vertex() {
	// Turned to the eye about the vertical only, so the flame stays upright.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
		vec4(0.0, 1.0, 0.0, 0.0),
		vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
		MODEL_MATRIX[3]);
}

// How far outside a teardrop the point is: round below its belly, drawn out to a tip above.
float teardrop(vec2 p, float scale, float drop) {
	p /= scale;
	p.y += drop;
	float below = step(p.y, -0.35);
	float reach = mix(1.3, 0.55, below);
	float along = clamp((p.y + 0.35) / reach, -1.0, 1.0);
	float half_width = 0.55 * sqrt(max(0.0, 1.0 - along * along));
	return (abs(p.x) - half_width) * scale;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	p.y = -p.y;
	float t = TIME * 5.0 + seed * 13.0;
	// The tip licks side to side, more the higher up.
	p.x += 0.14 * sin(p.y * 3.0 + t) * clamp((p.y + 1.0) * 0.5, 0.0, 1.0);
	float edge = 0.025;
	float shape = 1.0 - smoothstep(-edge, edge, teardrop(p, 1.0, 0.0));
	float inner = 1.0 - smoothstep(-edge, edge, teardrop(p, 0.42, -0.55));
	ALBEDO = mix(colour.rgb, core.rgb, inner);
	ALPHA = shape * presence;
}
