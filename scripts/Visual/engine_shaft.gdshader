shader_type spatial;
// The Company's engine's light leaving a window (maps/metro_station_engine_fx.gd, Nov 1 2026): a soft shaft in the
// hall's haze, faked on a frustum's sides. Added to what is behind it; brightest at the window, gone by its end; its
// sides seen edge-on fade (so it reads as light in the air, not a cone); softened where it touches what it falls on;
// a slow drift of the air's own grain through it. Its strength breathes on the engine's beat (set each frame).
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D depth : hint_depth_texture, filter_nearest;
uniform vec4 tint : source_color = vec4(0.353, 0.706, 1.0, 1.0);
uniform float strength = 0.3;
uniform float soft_depth = 0.4;
uniform float drift = 0.12;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	// (UV.y along it, 0 at the window; UV.x round its sides.)
	float along = pow(1.0 - UV.y, 1.8) * smoothstep(0.0, 0.15, UV.y);
	float facing = pow(abs(dot(normalize(NORMAL), normalize(VIEW))), 1.5);
	// (Dark along its corners, where two sides meet: no pane's edge, only light thickest down its middle.)
	float side = sin(3.14159 * fract(UV.x * 4.0));
	facing *= side * side;
	float air = 0.65 + 0.35 * noise(vec2(UV.x * 9.0, UV.y * 3.0 - TIME * drift));
	float behind = texture(depth, SCREEN_UV).r;
	vec4 back = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, behind, 1.0);
	float gap = -back.z / back.w + VERTEX.z;
	float soft = clamp(gap / soft_depth, 0.0, 1.0) * smoothstep(0.3, 1.2, length(VERTEX));
	ALBEDO = tint.rgb * strength * along * facing * air * soft;
}
