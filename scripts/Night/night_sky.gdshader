shader_type sky;
// The night sky (NightSky.gd, fed by Night.gd): a gradient deep overhead and
// hazed at the horizon (brighter toward the moon, warm low over the town),
// the Milky Way's faint band, stars fine and bright, the moon's painted face
// where the moonlight comes from (LIGHT0) with its glow and, in thin cloud, a
// halo ring; the clouds of Night's cloud field (the same projection and
// constants as Night.gd, so the cloud that crosses the moon is the one that
// dims its light), shaded as the moon lights them, their ragged edges silver
// toward it; high thin streaks on a clear night; a veil for a scripted cloud;
// the skyline's silhouettes round the horizon; the fog's haze; lightning
// lighting the clouds from within, its bolt down to the horizon.

uniform sampler2D cloud_field : repeat_enable, filter_linear;
uniform sampler2D skyline : source_color, repeat_enable, filter_nearest;
uniform sampler2D moon_face : source_color, filter_linear, repeat_disable;
uniform vec2 cloud_offset = vec2(0.0);
uniform float cloud_cover = 0.15;
uniform vec2 veil_center = vec2(10.0);
uniform float veil_on = 0.0;
uniform float flash = 0.0;
uniform float fog = 0.0;
// Lightning: where in the sky the flash is, whether its bolt shows, which
// bolt (its shape).
uniform vec3 flash_dir = vec3(0.0, 0.3, -1.0);
uniform float bolt = 0.0;
uniform float bolt_seed = 0.0;
// High thin cloud (0..1).
uniform float cirrus = 0.0;
// The night's clock (s), for the stars' twinkle (not the engine's clock: a
// sky reading that re-filters its radiance map every frame).
uniform float clock = 0.0;

uniform vec3 zenith_color : source_color = vec3(0.004, 0.007, 0.022);
uniform vec3 middle_color : source_color = vec3(0.014, 0.022, 0.052);
uniform vec3 horizon_color : source_color = vec3(0.06, 0.078, 0.12);
uniform vec3 cloud_color : source_color = vec3(0.048, 0.055, 0.075);
uniform vec3 moon_color : source_color = vec3(0.88, 0.92, 1.0);
uniform vec3 haze_color : source_color = vec3(0.11, 0.115, 0.125);
// The town beyond the lanes: its firelight low in the sky that way, and on
// the clouds' bellies over it.
uniform vec3 town_color : source_color = vec3(0.11, 0.06, 0.028);
uniform vec3 town_dir = vec3(0.7, 0.0, -0.7);
// The moon's radius (rad): 1.4 degrees, drawn larger than it is (as the eye
// sees it low over roofs).
uniform float moon_radius = 0.0244;
uniform float moon_brightness = 2.2;

const float CLOUD_CURVE = 0.25;
const float CLOUD_SCALE = 0.35;
const float CLOUD_SOFT = 0.12;
const float VEIL_RADIUS = 0.22;
const float VEIL_EDGE = 0.18;
// The skyline strip spans these elevations (rad): 28 degrees up to 2 down.
const float SKYLINE_TOP = 0.488692;
const float SKYLINE_BOTTOM = -0.034907;
// A star's cell (rad) and how few cells hold one; the bright ones'.
const float STAR_CELL = 0.0026;
const float STAR_RARITY = 0.9968;
const float BRIGHT_CELL = 0.011;
const float BRIGHT_RARITY = 0.992;
// The Milky Way: its pole, how wide its band (rad).
const vec3 GALAXY_POLE = vec3(0.35, 0.55, 0.76);
const float GALAXY_WIDTH = 0.22;
// A moon halo in thin ice cloud, 22 degrees out.
const float HALO_RING = 0.384;

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

// How near `d` is to the bolt: its path down from the flash's cloud to the
// horizon, a jag every few degrees, and one fork (angular distance, rad).
float bolt_distance(vec3 d) {
	float az = atan(d.x, d.z);
	float el = asin(clamp(d.y, -1.0, 1.0));
	float top = asin(clamp(flash_dir.y, -1.0, 1.0));
	float centre = atan(flash_dir.x, flash_dir.z);
	float best = 1.0;
	float x0 = 0.0;
	float fork = 0.0;
	const int STEPS = 10;

	for (int i = 0; i < STEPS; i++) {
		float e0 = top * (1.0 - float(i) / float(STEPS));
		float e1 = top * (1.0 - float(i + 1) / float(STEPS));
		float x1 = x0 + (hash(vec2(bolt_seed, float(i))) - 0.5) * 0.06;
		// The segment from (x0, e0) to (x1, e1) in (azimuth, elevation).
		vec2 a = vec2(centre + x0, e0);
		vec2 b = vec2(centre + x1, e1);
		vec2 p = vec2(az, el);
		vec2 ab = b - a;
		float t = clamp(dot(p - a, ab) / max(dot(ab, ab), 1e-6), 0.0, 1.0);
		best = min(best, length(p - (a + ab * t)));

		// The fork: off the fourth joint, three jags long.
		if (i >= 3 && i < 6) {
			float f1 = fork + (hash(vec2(bolt_seed + 7.0, float(i))) - 0.2) * 0.05;
			vec2 fa = vec2(centre + (i == 3 ? x0 : x0 + fork), e0);
			vec2 fb = vec2(centre + x1 + f1, e1);
			vec2 fab = fb - fa;
			float ft = clamp(dot(p - fa, fab) / max(dot(fab, fab), 1e-6), 0.0, 1.0);
			best = min(best, length(p - (fa + fab * ft)) * 1.6);
			fork = f1;
		}

		x0 = x1;
	}

	return best;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	vec3 m = LIGHT0_ENABLED ? normalize(LIGHT0_DIRECTION) : normalize(vec3(-0.6, 0.5, -0.6));
	float up = clamp(d.y, 0.0, 1.0);
	vec2 flat_d = normalize(d.xz + vec2(0.0001));
	vec2 flat_m = normalize(m.xz + vec2(0.0001));
	vec2 flat_t = normalize(town_dir.xz + vec2(0.0001));
	float moonward = max(dot(flat_d, flat_m), 0.0);
	float townward = max(dot(flat_d, flat_t), 0.0);

	// The gradient: near black overhead, deep blue midway, a haze at the
	// horizon, brighter on the moon's side, the town's firelight low.
	vec3 col = mix(middle_color, zenith_color, smoothstep(0.25, 1.0, up));
	col = mix(horizon_color * (1.0 + 0.8 * moonward * moonward), col, smoothstep(0.0, 0.3, pow(up, 0.8)));
	col += town_color * exp(-up / 0.07) * (0.35 + 0.65 * townward * townward) * (1.0 - fog);

	if (AT_CUBEMAP_PASS) {
		COLOR = col;
	} else {
		float angle = acos(clamp(dot(d, m), -1.0, 1.0));
		vec2 sph = vec2(atan(d.x, d.z), asin(clamp(d.y, -1.0, 1.0)));
		float seen = smoothstep(0.03, 0.25, d.y) * (1.0 - fog) * smoothstep(0.2, 0.5, angle);

		// The Milky Way: a faint band, dark lanes of dust in it, more stars.
		float lat = dot(d, normalize(GALAXY_POLE));
		float band = exp(-(lat * lat) / (GALAXY_WIDTH * GALAXY_WIDTH));
		vec2 along = vec2(atan(d.x - GALAXY_POLE.x * lat, d.z - GALAXY_POLE.z * lat), lat) * vec2(0.9, 2.6);
		float grainy = texture(cloud_field, along * 4.0 + vec2(0.13, 0.41)).r;
		float lanes = smoothstep(0.4, 0.7, texture(cloud_field, along * 1.2 + vec2(0.7, 0.2)).r);
		vec3 behind = col + vec3(0.008, 0.0095, 0.014) * band * (0.75 + 0.5 * grainy) * (1.0 - 0.6 * lanes) * seen;

		// Stars: fine ones in a few hundred cells (more in the band), twinkling a
		// little; a few bright ones, blue-white, gold or red; none near the moon,
		// in the haze or in fog.
		vec2 cell = floor(sph / STAR_CELL);
		float rarity = STAR_RARITY - 0.004 * band;
		float star = step(rarity, hash(cell));
		star *= 0.55 + 0.45 * sin(clock * (1.0 + 3.0 * hash(cell + 7.0)) + hash(cell + 3.0) * 6.28);
		behind += vec3(0.75, 0.8, 1.0) * star * 0.45 * seen;
		vec2 big = floor(sph / BRIGHT_CELL);
		float bright = step(BRIGHT_RARITY, hash(big + 11.0));
		vec2 at = (big + vec2(hash(big + 2.0), hash(big + 5.0)) * 0.6 + 0.2) * BRIGHT_CELL;
		float spot = 1.0 - smoothstep(0.0012, 0.0024, length(sph - at));
		float kind = hash(big + 9.0);
		vec3 hue = kind < 0.6 ? vec3(0.8, 0.88, 1.0) : (kind < 0.85 ? vec3(1.0, 0.9, 0.68) : vec3(1.0, 0.7, 0.55));
		behind += hue * bright * spot * (0.7 + 0.3 * sin(clock * 1.7 + kind * 40.0)) * 0.9 * seen;

		// The moon: its painted face 2.8 degrees across, a glow round it.
		vec3 t1 = normalize(cross(m, vec3(0.0, 1.0, 0.0)));
		vec3 t2 = cross(t1, m);
		vec2 face = vec2(dot(d, t1), -dot(d, t2)) / moon_radius;
		vec4 disc = texture(moon_face, face * 0.5 + 0.5) * step(max(abs(face.x), abs(face.y)), 1.0);
		float glow = exp(-angle / 0.018) * 0.3 + exp(-angle / 0.09) * 0.06 + exp(-angle / 0.35) * 0.02;
		behind += moon_color * (disc.rgb * disc.a * moon_brightness + glow);

		// The clouds: shaded as the moon lights them (thinner toward it, silver
		// at the edges that face it), mottled bellies, ragged edges; thinning
		// into the haze. Under full cover the moon's glow barely comes through.
		float c = d.y > 0.0 ? clouds(d) : 0.0;
		vec2 uv = sky_uv(d);
		float n0 = texture(cloud_field, uv).r;
		float toward = texture(cloud_field, uv + flat_m * 0.035).r;
		float grain = texture(cloud_field, uv * 3.3 + vec2(0.31, 0.77)).r;
		float edge = c * (1.0 - c) * 4.0;
		c *= mix(1.0, smoothstep(0.2, 0.75, grain), 0.55 * edge);
		c *= smoothstep(0.0, 0.1, d.y);
		float near_moon = exp(-angle / 0.09);
		float lit_side = clamp((n0 - toward) * 5.0 + 0.5, 0.0, 1.0);
		float thick = smoothstep(1.0 - cloud_cover, 1.0, n0);
		vec3 belly = cloud_color * (0.8 + 0.5 * moonward) * (1.0 - 0.4 * thick) * (0.8 + 0.45 * grain);
		belly += town_color * 0.9 * townward * exp(-up / 0.35) * (1.0 - fog);
		vec3 silver = moon_color * (edge * lit_side * near_moon * 0.55 + near_moon * 0.08 * (1.0 - thick));
		float through = 1.0 - smoothstep(0.7, 0.95, cloud_cover);
		col = mix(behind, belly + silver, c) + moon_color * glow * 0.3 * c * through;

		// High thin cloud: faint wisps drawn out along the wind, lit by the
		// moon near it.
		vec2 streak_uv = sky_uv(d) * vec2(0.45, 1.3) + vec2(cloud_offset.y, cloud_offset.x) * 0.6;
		streak_uv += (texture(cloud_field, sky_uv(d) * 1.9 + vec2(0.5, 0.1)).r - 0.5) * 0.12;
		float wisps = smoothstep(0.62, 0.86, texture(cloud_field, streak_uv).r) * cirrus * (1.0 - c) * smoothstep(0.08, 0.35, d.y);
		col += (cloud_color * 0.5 + moon_color * (0.015 + 0.2 * near_moon)) * wisps;
		// ...and where they cross it, a faint ring round the moon 22 degrees out.
		float ring = exp(-pow((angle - HALO_RING) / 0.02, 2.0)) * cirrus * (1.0 - fog);
		col += vec3(0.012, 0.013, 0.016) * ring * (0.4 + 2.0 * wisps);

		// The fog's haze.
		col = mix(col, haze_color, fog * (1.0 - 0.6 * up));

		// Lightning: the clouds lit from within round its place, the whole sky
		// a little, and its bolt while the flash is at its height.
		// (The sky round the strike lights, not all of it: a white-out would
		// swallow the bolt.)
		float from_flash = acos(clamp(dot(d, normalize(flash_dir)), -1.0, 1.0));
		col += flash * vec3(0.5, 0.56, 0.72) * (0.05 + 0.08 * up + c * (0.1 + 0.7 * exp(-from_flash / 0.28)) + 0.15 * exp(-from_flash / 0.18));

		if (bolt > 0.0 && d.y < flash_dir.y + 0.02) {
			float gap = bolt_distance(d);
			col += bolt * (vec3(0.92, 0.95, 1.0) * (1.0 - smoothstep(0.0015, 0.0035, gap)) * 9.0 + vec3(0.45, 0.5, 0.7) * exp(-gap / 0.025) * 1.2);
		}

		// The skyline: silhouettes and a few lit windows round the horizon, lit
		// by the moon's side a little, paled by the fog, shown by lightning.
		float v = (sph.y - SKYLINE_TOP) / (SKYLINE_BOTTOM - SKYLINE_TOP);

		if (v >= 0.0) {
			vec4 s = v <= 1.0 ? texture(skyline, vec2(sph.x / 6.2831853 + 0.5, v)) : vec4(0.01, 0.012, 0.016, 1.0);
			vec3 silhouette = s.rgb * (0.7 + 0.3 * moonward);
			// (Roofs against the sky are always darker than it, but for their lit
			// windows: under a black overcast they must not turn pale.)
			float lit_window = smoothstep(0.15, 0.4, dot(s.rgb, vec3(0.33)));
			silhouette = mix(min(silhouette, col * 0.8), silhouette, lit_window) + flash * vec3(0.05, 0.055, 0.07);
			silhouette = mix(silhouette, haze_color, fog * 0.6);
			col = mix(col, silhouette, s.a);
		}

		COLOR = col;
	}
}
