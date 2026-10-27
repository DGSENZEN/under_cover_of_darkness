// The void's sky (scripts/Visual/AstralPassage.gd), seen only through the astral passage's windows: the deep in the
// city's own colours (the effects' rule: phosphor green the seeped, oxblood the gods, cyan-white the wards, marigold
// the dead). Ink, deeper below; its clouds the seeped dark's green in soft, slow gradients with oxblood in their depths,
// their edges only a little broken by the user's brush sheets, as paint is; an aurora hung high through it, a curtain
// with a bright lower hem and soft rays fading up, green going to ward-white, slowly folding; a few cold stars.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, fog_disabled, blend_mix;
stencil_mode read, compare_equal, 1;

uniform sampler3D noise : filter_linear, repeat_enable;
uniform sampler2D brush : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform vec3 centre;
uniform vec3 ink : source_color = vec3(0.01, 0.009, 0.014);
uniform vec3 seeped : source_color = vec3(0.498, 0.827, 0.416);
uniform vec3 oxblood : source_color = vec3(0.431, 0.122, 0.102);
uniform vec3 ward : source_color = vec3(0.812, 0.91, 0.941);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

// An aurora's curtain whose hem wanders round the sky at `height`, `seed` its own.
float curtain(vec3 d, float height, float seed, float t) {
	vec2 round_dir = normalize(d.xz + 0.0001);
	float wander = texture(noise, vec3(round_dir * 1.1, seed + t * 0.006)).r;
	float hem = height + (wander - 0.5) * 0.12;
	float above = d.y - hem;
	// A bright lower hem, fading softly up.
	float hang = smoothstep(-0.008, 0.006, above) * exp(-max(above, 0.0) / 0.1);
	// Its rays: drawn from round the sky only (not its height), so they stand straight; folding slowly, shimmering.
	float rays = texture(noise, vec3(round_dir * 4.0, seed * 2.0 + t * 0.015)).r;
	float fine = texture(noise, vec3(round_dir * 14.0, seed * 3.0 + t * 0.05)).r;
	// Hung only in some quarters of the sky, not round all of it.
	float here = smoothstep(0.45, 0.68, texture(noise, vec3(round_dir * 0.7, seed * 7.0 + t * 0.002)).r);
	return hang * here * smoothstep(0.3, 0.8, rays) * (0.6 + 0.8 * smoothstep(0.4, 0.8, fine));
}

void fragment() {
	vec3 d = normalize(world_pos - centre);
	float t = TIME;
	// (The brush sheet laid round the sphere, only to break the clouds' edges.)
	vec2 round_uv = vec2(atan(d.z, d.x) / 6.2831853 + 0.5, asin(clamp(d.y, -1.0, 1.0)) / 3.1415927 + 0.5);
	float stroke = texture(brush, round_uv * vec2(2.0, 1.2) + vec2(t * 0.001, 0.0)).r;
	float broad = texture(noise, d * 0.75 + vec3(t * 0.002, 0.0, t * 0.001)).r;
	float detail = texture(noise, d * 1.9 + vec3(0.0, t * 0.003, 0.4)).r;
	float cloud = broad * 0.72 + detail * 0.28 + (stroke - 0.5) * 0.08;
	float deep = texture(noise, d * 0.5 + vec3(0.37, t * 0.0015, 0.0)).r;
	float body = smoothstep(0.42, 0.8, cloud);
	// Ink, deeper below, a breath of the seeped dark's green high up.
	vec3 col = ink * (0.7 + 0.3 * smoothstep(-0.8, 0.4, d.y));
	col += seeped * 0.012 * smoothstep(-0.1, 0.8, d.y);
	// The clouds: the seeped dark's green, soft; oxblood where they gather deepest, and below.
	vec3 cloud_col = mix(seeped * 0.075, oxblood * 0.22, smoothstep(0.45, 0.75, deep) * 0.8 + smoothstep(0.1, -0.6, d.y) * 0.4);
	col = mix(col, cloud_col, body * 0.85);
	// Their lit crests, faint.
	col += mix(seeped, ward, 0.3) * 0.025 * smoothstep(0.7, 0.9, cloud);
	// The aurora: two curtains, green at the hem going to ward-white above.
	for (int i = 0; i < 2; i++) {
		float height = i == 0 ? 0.32 : 0.55;
		float hang = curtain(d, height, float(i) * 5.3, t);
		float above = clamp((d.y - height) / 0.3, 0.0, 1.0);
		col += mix(seeped, ward, above * 0.8 + 0.15) * hang * (i == 0 ? 0.14 : 0.08);
	}
	// A few cold stars where the cloud is thin.
	vec3 cell = floor(d * 170.0);
	float h = hash3(cell);
	float twinkle = 0.55 + 0.45 * sin(t * (0.6 + h * 2.0) + h * 30.0);
	col += ward * step(0.992, h) * smoothstep(0.45, 0.0, length(fract(d * 170.0) - 0.5)) * twinkle * (1.0 - body);
	ALBEDO = col;
}
