shader_type spatial;
// Mist lying in the low places far off (Distance.gd): cards turned about their
// upright to face the eye, thick at their foot and thinning up, ragged
// (drifting value noise), soft where they meet the ground behind them and gone
// when you come near (they are only for the distance). INSTANCE_CUSTOM.x: a
// card's seed. The scene's fog hazes it as it hazes the land.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, skip_vertex_transform;

uniform vec3 colour : source_color = vec3(0.22, 0.25, 0.32);
uniform float density = 0.5;
uniform float near_fade = 60.0;
uniform float soft = 14.0;
uniform sampler2D depth_texture : hint_depth_texture, filter_linear;

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

float field(vec2 p) {
	return noise(p) * 0.55 + noise(p * 2.1 + 3.7) * 0.3 + noise(p * 4.3 + 9.1) * 0.15;
}

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
	seed = INSTANCE_CUSTOM.x;
}

void fragment() {
	float up = 1.0 - UV.y;
	float n = field(vec2(UV.x * 3.0 + seed * 7.3 + TIME * 0.012, up * 1.6 + seed * 2.1 + TIME * 0.004));
	float sides = smoothstep(0.0, 0.28, UV.x) * smoothstep(1.0, 0.72, UV.x);
	float rises = smoothstep(0.0, 0.12, up) * pow(1.0 - up, 1.3);
	float scene = texture(depth_texture, SCREEN_UV).r;
	vec4 behind = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, scene, 1.0);
	float gap = -behind.z / behind.w - far;
	ALBEDO = colour;
	ALPHA = density * sides * rises * smoothstep(0.3, 0.72, n) * clamp(gap / soft, 0.0, 1.0) * smoothstep(near_fade * 0.5, near_fade, far);
}
