// The deep's sky (scripts/Visual/AstralPassage.gd: the sky of the deep's own world, seen through the passage's
// windows): the deep in the city's own colours (the effects' rule: phosphor green the seeped, oxblood the gods,
// cyan-white the wards, marigold the dead). Ink, deeper below; its clouds the seeped dark's green in soft, slow
// gradients with oxblood in their depths, their edges only a little broken by the user's brush sheets, as paint is; an
// aurora hung high through it, a curtain with a bright lower hem and soft rays fading up, green going to ward-white,
// slowly folding; a few cold stars. At no distance, behind all of the deep.
shader_type sky;

uniform sampler3D noise : filter_linear, repeat_enable;
uniform sampler2D brush : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform vec3 ink : source_color = vec3(0.01, 0.009, 0.014);
uniform vec3 seeped : source_color = vec3(0.498, 0.827, 0.416);
uniform vec3 oxblood : source_color = vec3(0.431, 0.122, 0.102);
uniform vec3 ward : source_color = vec3(0.812, 0.91, 0.941);

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

// An aurora's curtain whose hem wanders round the sky at `height`, `seed` its own: x its light, y how far up it
// (0 its hem, 1 its top).
vec2 curtain(vec3 d, float height, float seed, float t) {
	vec2 round_dir = normalize(d.xz + 0.0001);
	// (Its folds: the hem's line bent by two scales of noise, the finer drifting along it.)
	float fold = texture(noise, vec3(round_dir * 1.1, seed + t * 0.006)).r - 0.5;
	float ripple = texture(noise, vec3(round_dir * 4.5 + vec2(t * 0.01, 0.0), seed + 1.7)).r - 0.5;
	float hem = height + fold * 0.14 + ripple * 0.012;
	float above = d.y - hem;
	float up = clamp(above / 0.22, 0.0, 1.0);
	// A soft hem, fading slowly up.
	float hang = smoothstep(-0.05, 0.02, above) * exp(-max(above, 0.0) / 0.13);
	// Its rays: drawn from round the sky only, so they stand straight; shimmering along it as light runs through.
	float rays = texture(noise, vec3(round_dir * 4.0, seed * 2.0 + t * 0.015)).r;
	float shimmer = texture(noise, vec3(round_dir * 16.0 + vec2(t * 0.04, 0.0), seed * 3.0 + t * 0.03)).r;
	// Hung only in some quarters of the sky, not round all of it.
	float here = smoothstep(0.45, 0.68, texture(noise, vec3(round_dir * 0.7, seed * 7.0 + t * 0.002)).r);
	return vec2(hang * here * (0.25 + 0.75 * smoothstep(0.3, 0.75, rays)) * (0.7 + 0.6 * shimmer), up);
}

void sky() {
	vec3 d = EYEDIR;
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
	// The clouds: the seeped dark's green high up, greyed into the ink; oxblood where they gather deepest, and the
	// lower the more.
	vec3 green = mix(seeped, vec3(dot(seeped, vec3(0.333))), 0.35) * 0.06;
	float red = clamp(smoothstep(0.45, 0.75, deep) * 0.7 + smoothstep(0.3, -0.5, d.y) * 0.6, 0.0, 1.0);
	vec3 cloud_col = mix(green, oxblood * 0.24, red);
	col = mix(col, cloud_col, body * 0.85);
	// Their lit crests, faint.
	col += mix(seeped, ward, 0.4) * 0.02 * smoothstep(0.7, 0.9, cloud);
	// The aurora: two curtains, ward-white at the hem, the seeped dark's green through it, an oxblood fringe at its
	// top.
	for (int i = 0; i < 2; i++) {
		vec2 hang = curtain(d, i == 0 ? 0.32 : 0.55, float(i) * 5.3, t);
		vec3 tint = mix(mix(mix(ward, seeped, 0.5), seeped, smoothstep(0.0, 0.2, hang.y)), oxblood * 2.0,
			smoothstep(0.35, 0.85, hang.y));
		col += tint * hang.x * (i == 0 ? 0.16 : 0.09);
	}
	// A few cold stars where the cloud is thin.
	vec3 cell = floor(d * 170.0);
	float h = hash3(cell);
	float twinkle = 0.55 + 0.45 * sin(t * (0.6 + h * 2.0) + h * 30.0);
	col += ward * step(0.992, h) * smoothstep(0.45, 0.0, length(fract(d * 170.0) - 0.5)) * twinkle * (1.0 - body);
	COLOR = col;
}
