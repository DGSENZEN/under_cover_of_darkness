shader_type spatial;
// The balefire's pillar (Distance.gd): a band of cold light standing up from
// the keep into the haze, turned about its upright to face the eye, brightest
// at its foot and fading as it climbs, its light crawling up it and breathing
// slowly. Its quad's foot is at its node, its scale its width and height.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled, skip_vertex_transform;

uniform vec3 colour : source_color = vec3(0.55, 1.0, 0.78);
uniform float strength = 0.035;
uniform float haze_from = 90.0;
uniform float haze_to = 1600.0;
uniform float haze_curve = 1.6;
uniform float haze = 0.8;

varying float far;

void vertex() {
	vec3 foot = MODEL_MATRIX[3].xyz;
	float width = length(MODEL_MATRIX[0].xyz);
	float height = length(MODEL_MATRIX[1].xyz);
	vec3 to_eye = INV_VIEW_MATRIX[3].xyz - foot;
	to_eye.y = 0.0;
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), normalize(to_eye + vec3(0.0001, 0.0, 0.0))));
	vec4 view = VIEW_MATRIX * vec4(foot + right * VERTEX.x * width + vec3(0.0, (VERTEX.y + 0.5) * height, 0.0), 1.0);
	VERTEX = view.xyz;
	far = -view.z;
}

void fragment() {
	float across = UV.x * 2.0 - 1.0;
	float up = 1.0 - UV.y;
	// (Soft across, fading fast as it climbs, broken into slow streaks that
	// crawl up it: a glow in the haze, never a beam.)
	float band = exp(-across * across * 3.2);
	float climb = pow(1.0 - up, 2.4) * smoothstep(0.0, 0.03, up);
	float streaks = 0.55 + 0.45 * sin(across * 7.0 + sin(up * 5.0 + TIME * 0.2) * 1.8);
	float crawl = 0.8 + 0.2 * sin(up * 30.0 - TIME * 0.9 + across * 2.0);
	float breath = 0.75 + 0.25 * sin(TIME * 0.31) * sin(TIME * 0.11 + 1.0);
	float hazed = haze * pow(clamp((far - haze_from) / (haze_to - haze_from), 0.0, 1.0), haze_curve);
	ALBEDO = colour * strength * band * climb * streaks * crawl * breath * (1.0 - hazed);
}
