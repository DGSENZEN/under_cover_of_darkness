shader_type spatial;
// The heat over the Company's engine's drum (maps/metro_station_engine_fx.gd, Nov 1 2026): a card turned to the eye
// about its upright that bends what is seen through it, a slow wobble climbing it, strongest low over the drum and
// gone at its edges, softened where it meets what is behind it and faded out near the eye (on the deck walk, in it).
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never, blend_mix;

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth : hint_depth_texture, filter_nearest;
// How far the screen is bent (a share of the screen), how fast the wobble climbs (per s), how big its shapes.
uniform float strength = 0.006;
uniform float climb = 0.9;
uniform vec2 grain = vec2(5.0, 3.5);
// It fades out within this of the eye (m), and over this much of what is behind it (m).
uniform float near_fade = 1.5;
uniform float soft_depth = 0.6;
// Its breath on the engine's beat (EngineBeat.swell): a little more heat as it swells.
uniform float swell = 0.5;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	// (Turned to the eye about its upright, as a billboard on Y.)
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
		vec4(0.0, 1.0, 0.0, 0.0), vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0), MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 at = UV * grain - vec2(0.0, TIME * climb);
	vec2 bend = vec2(noise(at) - 0.5, noise(at + vec2(17.3, 5.1)) - 0.5);
	// (Strongest low, over the drum; nothing at its sides or its top.)
	float mask = smoothstep(0.0, 0.25, UV.x) * smoothstep(1.0, 0.75, UV.x) * smoothstep(0.0, 0.5, UV.y) * smoothstep(1.0, 0.85, UV.y);
	float behind = texture(depth, SCREEN_UV).r;
	vec4 back = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, behind, 1.0);
	float gap = -back.z / back.w + VERTEX.z;
	float fade = mask * clamp(gap / soft_depth, 0.0, 1.0) * smoothstep(near_fade * 0.6, near_fade, length(VERTEX));
	ALBEDO = texture(screen, SCREEN_UV + bend * strength * mix(0.7, 1.3, swell) * fade).rgb;
	ALPHA = fade;
}
