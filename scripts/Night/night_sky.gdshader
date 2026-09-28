shader_type sky;
// The night sky (NightSky.gd, fed by Night.gd): a gradient, pixel stars, the
// moon where the moonlight comes from (LIGHT0) with its halo, the clouds of
// Night's cloud field (the same projection and constants as Night.gd, so the
// cloud that crosses the moon is the one that dims its light), a veil for a
// scripted cloud, the skyline's silhouettes round the horizon, the fog's haze
// and a lightning flash.

uniform sampler2D cloud_field : repeat_enable, filter_linear;
uniform sampler2D skyline : source_color, repeat_enable, filter_nearest;
uniform vec2 cloud_offset = vec2(0.0);
uniform float cloud_cover = 0.15;
uniform vec2 veil_center = vec2(10.0);
uniform float veil_on = 0.0;
uniform float flash = 0.0;
uniform float fog = 0.0;
// The night's clock (s), for the stars' twinkle (not the engine's clock: a
// sky reading that re-filters its radiance map every frame).
uniform float clock = 0.0;

uniform vec3 zenith_color : source_color = vec3(0.006, 0.009, 0.024);
uniform vec3 horizon_color : source_color = vec3(0.055, 0.07, 0.115);
uniform vec3 cloud_color : source_color = vec3(0.05, 0.058, 0.08);
uniform vec3 moon_color : source_color = vec3(0.88, 0.92, 1.0);
uniform vec3 haze_color : source_color = vec3(0.09, 0.1, 0.13);
// The moon's radius (rad): 1 degree, the moon 2 degrees across.
uniform float moon_radius = 0.01745;
uniform float moon_brightness = 2.2;

const float CLOUD_CURVE = 0.25;
const float CLOUD_SCALE = 0.35;
const float CLOUD_SOFT = 0.12;
const float VEIL_RADIUS = 0.22;
const float VEIL_EDGE = 0.18;
// The skyline strip spans these elevations (rad): 28 degrees up to 2 down.
const float SKYLINE_TOP = 0.488692;
const float SKYLINE_BOTTOM = -0.034907;
// A star's cell (rad) and how few cells hold one.
const float STAR_CELL = 0.0026;
const float STAR_RARITY = 0.9968;

vec2 sky_uv(vec3 d) {
	float h = max(d.y, 0.02) + CLOUD_CURVE;
	return d.xz / h * CLOUD_SCALE + cloud_offset;
}

float clouds(vec3 d) {
	vec2 uv = sky_uv(d);
	float n = texture(cloud_field, uv).r;
	float field = smoothstep(1.0 - cloud_cover - CLOUD_SOFT, 1.0 - cloud_cover + CLOUD_SOFT, n);
	float veil = veil_on * (1.0 - smoothstep(VEIL_RADIUS, VEIL_RADIUS + VEIL_EDGE, distance(uv, veil_center)));
	return max(field, veil);
}

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void sky() {
	vec3 d = normalize(EYEDIR);
	vec3 m = LIGHT0_ENABLED ? normalize(LIGHT0_DIRECTION) : normalize(vec3(-0.6, 0.5, -0.6));
	float up = clamp(d.y, 0.0, 1.0);
	vec2 flat_d = normalize(d.xz + vec2(0.0001));
	vec2 flat_m = normalize(m.xz + vec2(0.0001));
	float moonward = max(dot(flat_d, flat_m), 0.0);

	// The gradient: black-blue overhead, a haze at the horizon, brighter on
	// the moon's side.
	vec3 col = mix(horizon_color * (1.0 + 0.7 * moonward * moonward), zenith_color, pow(up, 0.45));

	if (AT_CUBEMAP_PASS) {
		COLOR = col;
	} else {
		float angle = acos(clamp(dot(d, m), -1.0, 1.0));

		// Stars: one in a few hundred cells, twinkling a little, gone near the
		// moon, in the haze and in fog.
		vec2 sph = vec2(atan(d.x, d.z), asin(clamp(d.y, -1.0, 1.0)));
		vec2 cell = floor(sph / STAR_CELL);
		float star = step(STAR_RARITY, hash(cell));
		star *= 0.55 + 0.45 * sin(clock * (1.0 + 3.0 * hash(cell + 7.0)) + hash(cell + 3.0) * 6.28);
		star *= smoothstep(0.03, 0.25, d.y) * (1.0 - fog) * smoothstep(0.2, 0.5, angle);
		vec3 behind = col + vec3(0.75, 0.8, 1.0) * star * 0.45;

		// The moon: a full disc 2 degrees across, its face shaded (maria), and
		// its halo.
		vec3 t1 = normalize(cross(m, vec3(0.0, 1.0, 0.0)));
		vec3 t2 = cross(t1, m);
		vec2 face = vec2(dot(d, t1), dot(d, t2)) / moon_radius;
		float disc = 1.0 - smoothstep(moon_radius * 0.92, moon_radius, angle);
		float maria = 0.58 + 0.42 * texture(cloud_field, face * 0.18 + vec2(0.37, 0.61)).r;
		float halo = exp(-angle / 0.02) * 0.25 + exp(-angle / 0.08) * 0.05;
		behind += moon_color * (disc * maria * moon_brightness + halo);

		// The clouds: lit from the moon's side, silver at the edge near it;
		// thinning into the haze.
		float c = d.y > 0.0 ? clouds(d) : 0.0;
		c *= smoothstep(0.0, 0.1, d.y);
		float near_moon = exp(-angle / 0.07);
		float edge = c * (1.0 - c) * 4.0;
		vec3 lit = cloud_color * (1.0 + 0.8 * moonward) + moon_color * (edge * near_moon * 0.2 + near_moon * 0.1);
		col = mix(behind, lit, c) + moon_color * halo * 0.25 * c;

		// The fog's haze.
		col = mix(col, haze_color, fog * (1.0 - 0.6 * up));

		// The skyline: silhouettes and a few lit windows round the horizon, lit
		// by the moon's side a little, paled by the fog, shown by lightning.
		float v = (asin(clamp(d.y, -1.0, 1.0)) - SKYLINE_TOP) / (SKYLINE_BOTTOM - SKYLINE_TOP);

		if (v >= 0.0) {
			vec4 s = v <= 1.0 ? texture(skyline, vec2(atan(d.x, d.z) / 6.2831853 + 0.5, v)) : vec4(0.01, 0.012, 0.016, 1.0);
			vec3 silhouette = s.rgb * (0.7 + 0.3 * moonward);
			silhouette = mix(silhouette, haze_color, fog * 0.6);
			col = mix(col, silhouette, s.a);
		}

		// Lightning.
		col += flash * vec3(0.55, 0.6, 0.75) * (0.35 + 0.9 * c + 0.3 * up);
		COLOR = col;
	}
}
