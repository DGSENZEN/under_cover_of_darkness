shader_type spatial;
// Smoke from the old town's chimneys (Distance.gd): a ribbon up from each
// stack, turned about its upright to face the eye, leaning downwind the
// higher it goes, widening and thinning as it rises, ragged (value noise
// carried up it); warm at its foot from the fire under it. Its quad's foot at
// the stack's top; INSTANCE_CUSTOM.x its seed. The scene's fog hazes it.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, skip_vertex_transform;

uniform vec3 smoke : source_color = vec3(0.26, 0.27, 0.31);
uniform vec3 ember : source_color = vec3(0.32, 0.17, 0.08);
uniform float density = 0.85;
uniform vec3 wind = vec3(1.0, 0.0, 0.0);
uniform float lean = 0.9;
uniform float near_fade = 40.0;

varying float far;
varying float seed;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	vec3 foot = MODEL_MATRIX[3].xyz;
	float width = length(MODEL_MATRIX[0].xyz);
	float height = length(MODEL_MATRIX[1].xyz);
	float up = VERTEX.y + 0.5;
	vec3 to_eye = INV_VIEW_MATRIX[3].xyz - foot;
	to_eye.y = 0.0;
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), normalize(to_eye + vec3(0.0001, 0.0, 0.0))));
	vec3 drift = vec3(wind.x, 0.0, wind.z) * lean * height * 0.12 * pow(up, 1.6);
	vec4 view = VIEW_MATRIX * vec4(foot + right * VERTEX.x * width + vec3(0.0, up * height, 0.0) + drift, 1.0);
	VERTEX = view.xyz;
	far = -view.z;
	seed = INSTANCE_CUSTOM.x;
}

void fragment() {
	float up = 1.0 - UV.y;
	float across = (UV.x * 2.0 - 1.0) / (0.22 + 0.7 * up);
	float n = noise(vec2(UV.x * 4.0 + seed * 9.1, up * 5.0 - TIME * 0.35 + seed * 3.3)) * 0.65
		+ noise(vec2(UV.x * 9.0 + seed, up * 11.0 - TIME * 0.6)) * 0.35;
	float plume = exp(-across * across * 3.0) * smoothstep(0.0, 0.06, up) * pow(1.0 - up, 1.2);
	ALBEDO = mix(ember, smoke, smoothstep(0.0, 0.25, up));
	ALPHA = density * plume * smoothstep(0.15, 0.6, n) * smoothstep(near_fade * 0.5, near_fade, far);
}
