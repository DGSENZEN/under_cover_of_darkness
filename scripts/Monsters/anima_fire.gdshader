// A burning ánima's fire: the game's own simulated fire (assets/vfx/fire.png, as the braziers
// burn it, vfx_flame.gdshader), turned to face you and standing up in the world, bent by two
// climbing noises, narrowing to its tips, cut into hard bands of heat. Added to what is behind it,
// because fire is light: solid, this green reads as leaves. Its palest band only where it is
// hottest. One MultiMesh of quads, each scaled by its instance (AnimaBurn.gd).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled, world_vertex_coords;

#include "res://scripts/Visual/vfx_common.gdshaderinc"

uniform sampler2D sheet : source_color, filter_linear, repeat_disable;
uniform sampler2D noise : filter_linear, repeat_enable;
uniform vec4 cool : source_color = vec4(0.05, 0.1, 0.012, 1.0);
uniform vec4 warm : source_color = vec4(0.2, 0.34, 0.035, 1.0);
uniform vec4 hot : source_color = vec4(0.62, 0.8, 0.2, 1.0);
uniform float fps = 13.0;

varying float phase;

void vertex() {
	phase = INSTANCE_CUSTOM.x;
	vec3 root = MODEL_MATRIX[3].xyz;
	float wide = length(MODEL_MATRIX[0].xyz);
	float tall = length(MODEL_MATRIX[1].xyz);
	vec3 to_eye = normalize(CAMERA_POSITION_WORLD - root);
	vec3 across = normalize(cross(vec3(0.0, 1.0, 0.0), to_eye));
	VERTEX = root + across * (UV.x - 0.5) * wide + vec3(0.0, (1.0 - UV.y) * tall, 0.0);
}

void fragment() {
	float up = 1.0 - UV.y;
	float n = texture(noise, vec2(UV.x * 1.3 + phase * 5.0, UV.y * 0.8 + TIME * 1.1)).r;
	float m = texture(noise, vec2(UV.x * 2.6 + 0.37 + phase * 3.0, UV.y * 1.6 + TIME * 2.0)).r;
	vec2 uv = vec2(UV.x + (n - 0.5) * 0.3 * up, UV.y);
	vec4 f = texture(sheet, flipbook_uv(uv, fract(TIME * fps / 16.0 + phase), ivec2(4, 4)));
	float heat = dot(f.rgb, vec3(0.3, 0.59, 0.11)) * f.a;
	heat *= 0.45 + multiply_noise(n, m) * 0.9;
	heat *= smoothstep(1.0, 0.5, up) * smoothstep(0.0, 0.1, up);
	float half_width = mix(0.46, 0.05, pow(up, 0.55));
	heat *= 1.0 - smoothstep(half_width * 0.55, half_width, abs(UV.x - 0.5 + (n - 0.5) * 0.18 * up));
	float banded = bands(heat * 1.4, 4.0);
	vec3 colour = mix(cool.rgb, warm.rgb, step(0.4, banded));
	colour = mix(colour, hot.rgb, step(0.7, banded));
	ALBEDO = colour * step(0.15, banded);
}
