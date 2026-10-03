shader_type spatial;
// A far light's glow (Distance.gd): a quad turned to the eye, bright in its
// middle and soft to its edge, never fewer than min_pixels across however far
// it is; a flame's flicker, a corpse-light's slow breathing (INSTANCE_CUSTOM:
// x its seed, y how it lives: 0 a flame, 1 a corpse-light; z how much of it
// shows). It is added to what is behind it, so the haze is its own: the same
// depth haze as the city's (city.gd HAZE_*), dimming it with distance.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled, skip_vertex_transform;

uniform float min_pixels = 2.5;
uniform float haze_from = 90.0;
uniform float haze_to = 1600.0;
uniform float haze_curve = 1.6;
uniform float haze = 0.8;

varying float seed;
varying float life;
varying float shows;
varying float far;

void vertex() {
	vec4 centre = MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0);
	float size = length(MODEL_MATRIX[0].xyz);
	far = -centre.z;
	// (A pixel's width at its distance: it is never smaller than a few.)
	float pixel = 2.0 * far / (PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y);
	size = max(size, pixel * min_pixels);
	VERTEX = centre.xyz + vec3(VERTEX.xy * size, 0.0);
	seed = INSTANCE_CUSTOM.x;
	life = INSTANCE_CUSTOM.y;
	shows = INSTANCE_CUSTOM.z;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float core = exp(-r * r * 10.0);
	float halo = exp(-r * 3.4) * 0.3;
	float flame = 0.8 + 0.12 * sin(TIME * 9.0 + seed * 17.0) + 0.08 * sin(TIME * 23.0 + seed * 5.0);
	float breath = 0.55 + 0.45 * sin(TIME * 0.7 + seed * 6.0) * sin(TIME * 0.23 + seed * 2.0);
	float lived = mix(flame, breath, life);
	float hazed = haze * pow(clamp((far - haze_from) / (haze_to - haze_from), 0.0, 1.0), haze_curve);
	ALBEDO = COLOR.rgb * (core + halo) * lived * shows * (1.0 - hazed) * smoothstep(1.0, 0.75, r);
}
