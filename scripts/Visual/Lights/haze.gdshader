// Heat haze over a fire: what is behind it, nudged a pixel of the 360-line
// screen by ripples running upward, fading out to its edges. Big fires only
// (braziers, campfires, hearths); drawn upright, always facing you.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

uniform sampler2D screen : hint_screen_texture, filter_nearest;
// How far it nudges: one pixel of the 360-line screen.
uniform float reach = 0.0028;

void vertex() {
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz));
	vec3 forward = normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0)));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(right, 0.0), vec4(0.0, 1.0, 0.0, 0.0), vec4(forward, 0.0), MODEL_MATRIX[3]);
}

void fragment() {
	float edge = smoothstep(0.0, 0.3, UV.x) * smoothstep(1.0, 0.7, UV.x) * smoothstep(1.0, 0.6, UV.y) * smoothstep(0.0, 0.25, UV.y);
	vec2 ripple = vec2(sin(UV.y * 31.0 + TIME * 7.0 + UV.x * 5.0), cos(UV.x * 23.0 - TIME * 5.0 + UV.y * 13.0));
	ALBEDO = texture(screen, SCREEN_UV + ripple * reach * edge).rgb;
	ALPHA = edge;
}
