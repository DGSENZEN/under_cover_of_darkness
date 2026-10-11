// The thread of copal smoke above a censer or an offering (Vfx.gd): crossed
// planes, a thread narrow at its foot wavering wider as it climbs into the
// billows, lumped by two climbing, multiplied noises sampled in metres (in
// the quad's UVs a tall quad stretched them into drips), lit in hard bands.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_lambert, specular_disabled;

#include "res://scripts/Visual/vfx_common.gdshaderinc"

uniform sampler2D noise : filter_linear, repeat_enable;
uniform vec4 tint : source_color = vec4(0.925, 0.902, 0.855, 1.0);
uniform float opacity = 0.55;
// The planes' width and height (m).
uniform vec2 size = vec2(0.5, 1.0);

void fragment() {
	float up = 1.0 - UV.y;
	vec2 at = UV * size;
	float n = texture(noise, vec2(at.x * 1.6, at.y * 1.6 + TIME * 0.35)).r;
	float m = texture(noise, vec2(at.x * 3.4 + 0.41, at.y * 3.4 + TIME * 0.6)).r;
	// The thread wavers side to side as it climbs, more the higher it is.
	float sway = (texture(noise, vec2(0.3, at.y * 0.8 + TIME * 0.25)).r - 0.5) * 0.6 * up;
	float width = mix(0.06, 0.38, up);
	float across = 1.0 - smoothstep(width * 0.35, width, abs(UV.x - 0.5 - sway));
	float body = across * (0.5 + multiply_noise(n, m));
	float alpha = erode(body, 0.3 + 0.35 * up, 0.12) * smoothstep(0.0, 0.06, up) * (1.0 - smoothstep(0.7, 1.0, up));
	ALBEDO = tint.rgb;
	ALPHA = alpha * opacity;
}

void light() {
	DIFFUSE_LIGHT += bands(dot(NORMAL, LIGHT) * 0.5 + 0.5, 3.0) * ATTENUATION * LIGHT_COLOR / PI;
}
