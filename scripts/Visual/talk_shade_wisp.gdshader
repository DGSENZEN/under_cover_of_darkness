// A puff of a shade's smoke (Shade.gd): one puff of the project's own smoke
// sheet (assets/vfx/smoke.png, four puffs), turned to face the camera and
// turning slowly about itself as it rises, its edge worn soft by noise. It
// fades in and out with the particle (its COLOR), and burns, cools and
// gutters with the body (talk_shade.gdshader's uniforms).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform sampler2D puffs : source_color, filter_linear, repeat_disable;
uniform vec4 wisp_colour : source_color = vec4(1.0, 0.62, 0.22, 1.0);
uniform float glow = 1.0;
uniform float opacity = 0.55;
uniform float flicker = 0.0;
uniform float seed = 0.0;

varying float v_age;
varying float v_seed;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(hash13(i), hash13(i + vec3(1.0, 0.0, 0.0)), f.x);
	float b = mix(hash13(i + vec3(0.0, 1.0, 0.0)), hash13(i + vec3(1.0, 1.0, 0.0)), f.x);
	float c = mix(hash13(i + vec3(0.0, 0.0, 1.0)), hash13(i + vec3(1.0, 0.0, 1.0)), f.x);
	float d = mix(hash13(i + vec3(0.0, 1.0, 1.0)), hash13(i + vec3(1.0, 1.0, 1.0)), f.x);
	return mix(mix(a, b, f.y), mix(c, d, f.y), f.z);
}

void vertex() {
	// Facing the camera, turned about the view by the particle's angle.
	mat4 world = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
	float turn = INSTANCE_CUSTOM.x;
	world = world * mat4(vec4(cos(turn), -sin(turn), 0.0, 0.0), vec4(sin(turn), cos(turn), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	float size = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * world * mat4(vec4(size, 0.0, 0.0, 0.0), vec4(0.0, size, 0.0, 0.0), vec4(0.0, 0.0, size, 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	v_age = INSTANCE_CUSTOM.y;
	v_seed = INSTANCE_CUSTOM.z * 17.0 + float(INSTANCE_ID) * 0.37;
}

void fragment() {
	// One of the sheet's four puffs.
	float puff = floor(fract(v_seed) * 3.999);
	vec2 uv = clamp(UV, 0.02, 0.98);
	float body = texture(puffs, vec2((puff + uv.x) * 0.25, uv.y)).a;
	// Worn by a slow noise that thins it as it ages: wisps, not a ball.
	float wear = vnoise(vec3(UV * 3.5 + vec2(0.0, TIME * 0.15), v_seed));
	body *= smoothstep(0.1 + 0.3 * v_age, 0.9, wear * 0.7 + body * 0.6);

	// The body's own gutter (talk_shade.gdshader), so they flicker as one.
	float t = TIME;
	float waver = vnoise(vec3(t * 7.0, seed, 0.0)) * 0.45 + vnoise(vec3(t * 19.0, seed + 3.0, 0.0)) * 0.25;
	float gasp = smoothstep(0.62, 0.8, vnoise(vec3(t * 2.3, seed + 7.0, 0.0))) * 0.5;
	float gutter = clamp(1.0 - flicker * (waver + gasp), 0.12, 1.0);
	// And its cooling when dim.
	float cool = clamp((1.0 - glow) / 0.65, 0.0, 1.0);
	vec3 hue = wisp_colour.rgb;
	float lum = dot(hue, vec3(0.3, 0.59, 0.11));
	hue = mix(hue, mix(vec3(lum), vec3(0.42, 0.52, 0.72) * lum * 1.4, 0.6), cool * 0.75);

	// Dark smoke in her colour, lit faintly from within.
	ALBEDO = hue * (0.08 + 0.12 * glow) * gutter;
	ALPHA = clamp(body * COLOR.a * clamp(opacity * 1.3, 0.25, 0.9), 0.0, 1.0);
}
