// A wisp off a shade (Shade.gd): one thin ribbon of its smoke, standing
// upright and turned to the camera, curling as it rises and thinning to
// threads before it is gone. Its soft ends are a puff of the project's own
// smoke sheet (assets/vfx/smoke.png, four puffs); the rest is noise. It
// burns, cools and gutters with the body (shade.gdshader's uniforms).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

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
	// Upright, turned about the vertical toward the camera: smoke rises.
	vec3 right = INV_VIEW_MATRIX[0].xyz;
	right = normalize(vec3(right.x, 0.0, right.z) + vec3(1e-4, 0.0, 0.0));
	vec3 up = vec3(0.0, 1.0, 0.0);
	vec3 back = cross(right, up);
	float size = length(MODEL_MATRIX[0].xyz);
	mat4 world = mat4(vec4(right * size, 0.0), vec4(up * size, 0.0), vec4(back * size, 0.0), MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * world;
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	v_age = INSTANCE_CUSTOM.y;
	v_seed = INSTANCE_CUSTOM.z * 17.0 + float(INSTANCE_ID) * 0.37;
}

void fragment() {
	// A thin ribbon down the middle, swaying side to side as it climbs.
	float sway = (vnoise(vec3(UV.y * 2.5 - TIME * 0.6, v_seed, 0.0)) - 0.5) * 0.55;
	float across = abs(UV.x - 0.5 - sway * (1.0 - UV.y));
	float width = mix(0.3, 0.12, v_age) * (0.6 + 0.8 * vnoise(vec3(UV.y * 4.0, v_seed + 5.0, 0.0)));
	float ribbon = smoothstep(width, 0.0, across);
	// Torn into threads as it ages.
	float threads = vnoise(vec3(UV.x * 18.0, UV.y * 3.0 - TIME * 0.8 + v_seed, 0.0));
	ribbon *= smoothstep(v_age * 0.5, v_age * 0.5 + 0.5, threads);
	// One of the sheet's puffs keeps its ends soft.
	float puff = floor(fract(v_seed) * 3.999);
	float soft = texture(puffs, vec2((puff + clamp(UV.x * 0.6 + 0.2, 0.01, 0.99)) * 0.25, UV.y)).a;

	// The body's own gutter (shade.gdshader), so they flicker as one.
	float t = TIME;
	float waver = vnoise(vec3(t * 7.0, seed, 0.0)) * 0.45 + vnoise(vec3(t * 19.0, seed + 3.0, 0.0)) * 0.25;
	float gasp = smoothstep(0.62, 0.8, vnoise(vec3(t * 2.3, seed + 7.0, 0.0))) * 0.5;
	float gutter = clamp(1.0 - flicker * (waver + gasp), 0.12, 1.0);
	// And its cooling when dim.
	float cool = clamp((1.0 - glow) / 0.65, 0.0, 1.0);
	vec3 hue = wisp_colour.rgb;
	float lum = dot(hue, vec3(0.3, 0.59, 0.11));
	hue = mix(hue, mix(vec3(lum), vec3(0.42, 0.52, 0.72) * lum * 1.4, 0.6), cool * 0.75);

	// Smoke, not flame: paler than the body, and faint where it leaves her.
	hue = mix(hue, vec3(dot(hue, vec3(0.3, 0.59, 0.11))) * 1.2, 0.35);
	float rise = smoothstep(1.0, 0.65, UV.y);
	float a = ribbon * soft * rise * COLOR.a * clamp(opacity * 1.4, 0.2, 1.0);
	ALBEDO = hue * glow * gutter * a * 0.7;
	ALPHA = 1.0;
}
