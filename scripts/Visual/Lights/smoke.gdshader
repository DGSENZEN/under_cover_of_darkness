// Smoke/steam from the four-puff sheet (assets/vfx/smoke.png).
// MultiMesh custom data selects puff/visibility; COLOR supplies underside fire light that fades with height.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D puffs : source_color, filter_nearest, repeat_disable;
// The smoke itself; COLOR is the fire's light on its underside.
uniform vec4 body : source_color = vec4(0.16, 0.15, 0.14, 1.0);

varying float v_puff;
varying float v_alpha;
varying float v_lit;

void vertex() {
	v_puff = INSTANCE_CUSTOM.x;
	v_alpha = INSTANCE_CUSTOM.y;
	v_lit = INSTANCE_CUSTOM.z;
}

void fragment() {
	vec4 texel = texture(puffs, vec2((floor(v_puff + 0.5) + clamp(UV.x, 0.01, 0.99)) * 0.25, UV.y));
	float under = clamp(UV.y * 1.4 - 0.2, 0.0, 1.0) * v_lit;
	ALBEDO = mix(body.rgb, COLOR.rgb, under);
	ALPHA = texel.a * v_alpha;
}
