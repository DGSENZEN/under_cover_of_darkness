// A brazier's flame tongues (Vfx.gd): our fire sheet's frames, bent by two
// multiplied noises that climb, narrowing to their tips, cut hard into three
// heat bands (graphic, the Mignola way), coloured by a warm ramp, their
// height and glow pulsing with the brazier's flicker (shared with its light).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

#include "res://scripts/Visual/vfx_common.gdshaderinc"

uniform sampler2D sheet : source_color, filter_linear, repeat_disable;
uniform sampler2D noise : filter_linear, repeat_enable;
uniform sampler2D ramp : source_color, filter_nearest, repeat_disable;
uniform float flicker = 1.0;
uniform float fps = 10.0;
uniform float phase = 0.0;
uniform float height = 1.0;

void vertex() {
	// Taller and shorter with the flicker (the tips, not the base).
	VERTEX.y *= mix(1.0, 0.75 + 0.45 * flicker, clamp(VERTEX.y / height, 0.0, 1.0));
}

void fragment() {
	float up = 1.0 - UV.y;
	float n = texture(noise, vec2(UV.x * 1.3 + phase, UV.y * 0.8 + TIME * 0.9)).r;
	float m = texture(noise, vec2(UV.x * 2.6 + 0.37 + phase, UV.y * 1.6 + TIME * 1.7)).r;
	vec2 uv = vec2(UV.x + (n - 0.5) * 0.22 * up, UV.y);
	vec4 f = texture(sheet, flipbook_uv(uv, fract(TIME * fps / 16.0 + phase), ivec2(4, 4)));
	float heat = dot(f.rgb, vec3(0.3, 0.59, 0.11)) * f.a;
	heat *= 0.45 + multiply_noise(n, m) * 0.9;
	heat *= smoothstep(1.0, 0.55, up) * smoothstep(0.0, 0.12, up) * (0.8 + 0.3 * flicker);
	// Narrowing to the tips, the outline wobbling with the noise (the
	// sheet's bed fills its frame: drawn edge to edge it stood in a box).
	float half_width = mix(0.5, 0.08, pow(up, 0.5));
	heat *= 1.0 - smoothstep(half_width * 0.6, half_width, abs(UV.x - 0.5 + (n - 0.5) * 0.14 * up));
	float banded = bands(heat * 1.25, 3.0);
	ALBEDO = texture(ramp, vec2(clamp(banded, 0.0, 0.999), 0.5)).rgb;
	EMISSION = ALBEDO * (1.2 + flicker);
	ALPHA = step(0.2, banded);
}
