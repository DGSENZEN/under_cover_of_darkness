// Heat haze over a fire (Vfx.gd): what is behind it wavers, by a climbing
// noise, never more than a hair; facing the camera about its upright.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D noise : filter_linear, repeat_enable;
uniform float strength = 0.008;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
		vec4(0.0, 1.0, 0.0, 0.0), vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0), MODEL_MATRIX[3]);
}

void fragment() {
	float n = texture(noise, UV * vec2(1.0, 0.6) + vec2(0.0, -TIME * 0.8)).r - 0.5;
	float fade = sin(UV.x * PI) * smoothstep(0.0, 0.5, UV.y) * smoothstep(1.0, 0.7, UV.y);
	ALBEDO = texture(screen, SCREEN_UV + vec2(n, n * 0.5) * strength * fade).rgb;
	ALPHA = clamp(fade * 3.0, 0.0, 1.0);
}
