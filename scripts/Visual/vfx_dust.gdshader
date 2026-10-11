// Dust motes under a lamp (Vfx.gd's "dust"): specks that show only inside
// their lamp's cone of light (`lamp`, set where the effect is placed;
// `cone_axis`, `cone_angle`), dark outside it.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 tint : source_color = vec4(1.0, 0.92, 0.75, 0.6);
uniform vec3 lamp = vec3(0.0, 10000.0, 0.0);
uniform vec3 cone_axis = vec3(0.0, -1.0, 0.0);
uniform float cone_angle = 0.6;

varying float inside;

void vertex() {
	// Facing the camera, the particle's scale kept.
	mat4 world = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * world * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	vec3 to = MODEL_MATRIX[3].xyz - lamp;
	float angle = acos(clamp(dot(normalize(to), normalize(cone_axis)), -1.0, 1.0));
	inside = 1.0 - smoothstep(cone_angle * 0.75, cone_angle, angle);
}

void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	ALBEDO = tint.rgb * COLOR.rgb;
	ALPHA = tint.a * COLOR.a * (1.0 - smoothstep(0.5, 1.0, length(c))) * inside;
}
