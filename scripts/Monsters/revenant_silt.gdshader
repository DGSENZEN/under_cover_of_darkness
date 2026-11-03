shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled;
// Silt coming up from where it treads, and hanging, as it would in still water: a soft dark bloom in the brush's shapes.

uniform sampler2D stroke_sheet : filter_linear_mipmap, repeat_enable;
uniform vec3 seep : source_color = vec3(0.5, 0.83, 0.42);

varying float age;
varying float phase;

void vertex() {
	age = INSTANCE_CUSTOM.x;
	phase = INSTANCE_CUSTOM.y;
	// (Its transform's scale, turned to face you.)
	vec3 root = MODEL_MATRIX[3].xyz;
	float wide = length(MODEL_MATRIX[0].xyz);
	float tall = length(MODEL_MATRIX[1].xyz);
	vec3 to_eye = normalize(CAMERA_POSITION_WORLD - root);
	vec3 across = normalize(cross(vec3(0.0, 1.0, 0.0), to_eye));
	vec3 up = normalize(cross(to_eye, across));
	VERTEX = (inverse(MODEL_MATRIX) * vec4(root + across * VERTEX.x * wide + up * VERTEX.y * tall, 1.0)).xyz;
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float brush = texture(stroke_sheet, UV * 0.7 + vec2(phase, age * 0.12)).r;
	// (A cloud, not an orb: it has no edge of its own.)
	float soft = smoothstep(1.0, 0.1, r + (brush - 0.5) * 1.3);
	float comes = smoothstep(0.0, 0.2, age) * (1.0 - smoothstep(0.3, 1.0, age));
	ALBEDO = mix(vec3(0.006, 0.008, 0.007), vec3(0.016, 0.02, 0.016), brush);
	ALPHA = soft * soft * comes * 0.5;
}
