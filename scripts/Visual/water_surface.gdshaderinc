
// Ripples: a seamless normal map, a ripple `tile` metres along the flow,
// `stretch` times closer across it; how steep; which way and how fast (m/s).
uniform sampler2D ripples : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float tile = 3.0;
uniform float stretch = 1.0;
uniform float steep = 0.55;
uniform vec2 flow = vec2(0.02, 0.0);
// The water's body; the sky it shows (zenith, horizon), as bright as the
// moon's share of it lets.
uniform vec3 deep : source_color = vec3(0.014, 0.024, 0.022);
uniform vec3 sky_zenith : source_color = vec3(0.03, 0.04, 0.075);
uniform vec3 sky_horizon : source_color = vec3(0.09, 0.1, 0.13);
uniform float sky_light = 1.0;
uniform float water_clock = 0.0;
uniform vec3 moon_direction = vec3(0.0, 1.0, 0.0);
uniform vec3 moon_colour : source_color = vec3(0.6, 0.7, 0.9);
uniform float moon_visibility = 0.0;
// Where the moon can be seen from the water (WaterVolume.survey_moon, over
// the survey; white before it is cast): its glade glints only there.
uniform sampler2D moon_mask : hint_default_white, filter_linear, repeat_disable;
// The moon's glade: its width as an angle seen from the eye near by and far
// off; how bright its broken column is.
uniform float glade_near = 0.11;
uniform float glade_far = 0.035;
uniform float glade_gain = 0.55;
// Rain on it (0..1): rings, and the surface roughened.
uniform float rain = 0.0;
// The box seen from above (half its width and length, m): the scum line
// along its edges, the duckweed near them.
uniform vec2 half_size = vec2(3.0, 3.0);
uniform sampler2D patches : filter_linear_mipmap, repeat_enable;
uniform vec3 scum : source_color = vec3(0.17, 0.17, 0.14);
uniform vec3 weed : source_color = vec3(0.07, 0.11, 0.035);
uniform float weed_reach = 3.5;
uniform float weed_amount = 0.5;
// The lights by it (WaterVolume gathers them): where (xyz), and their colour
// times their energy (rgb, a: how far their column carries, m); how many.
// A column's width and length (as angles seen from the eye), how bright.
uniform int light_count = 0;
uniform vec4 lights[16];
uniform vec4 light_colours[16];
uniform float column_width = 0.006;
uniform float column_length = 0.09;
uniform float column_gain = 0.6;

// A static bed survey keeps deep water in the opaque reflection pass.
uniform sampler2D shore_depth : filter_linear, repeat_disable;
uniform bool shore_ready = false;
uniform vec2 shore_texel = vec2(0.01);
uniform float shore_fade = 0.75;
// Where the survey lies (world x, z of its corner, its width and length): the
// whole box unless only part of it is near anything (an open sea's harbour).
// Past it the water is deep.
uniform vec2 shore_low = vec2(-3.0, -3.0);
uniform vec2 shore_span = vec2(6.0, 6.0);
varying vec3 world_pos;
varying vec2 local_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	local_pos = VERTEX.xz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 hash2(vec2 p) {
	return vec2(hash(p), hash(p + vec2(17.3, 5.1)));
}

// Rings where drops fall: a grid of cells, one drop each at a time, its ring
// running out and dying. The slope it gives the surface (xz).
vec2 drops(vec2 p, float cell, float t) {
	vec2 slope = vec2(0.0);
	vec2 base = floor(p / cell);

	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 id = base + vec2(float(x), float(y));
			vec2 r = hash2(id);
			float phase = fract(t * (0.9 + 0.5 * r.x) + r.y);
			vec2 centre = (id + 0.2 + 0.6 * hash2(id + floor(t * (0.9 + 0.5 * r.x) + r.y))) * cell;
			vec2 off = p - centre;
			float d = length(off);
			float radius = phase * cell * 0.9;
			float ring = d - radius;
			float wave = sin(ring * 42.0) * exp(-ring * ring * 260.0) * (1.0 - phase) * (1.0 - phase);
			slope += (d > 0.001 ? off / d : vec2(0.0)) * wave;
		}
	}

	return slope;
}

void fragment() {
	if (!FRONT_FACING) { discard; }
	vec2 shore_uv = (world_pos.xz - shore_low) / shore_span;
	bool surveyed = shore_uv.x >= 0.0 && shore_uv.y >= 0.0 && shore_uv.x <= 1.0 && shore_uv.y <= 1.0;
	float bed_depth = shore_ready && surveyed ? texture(shore_depth, shore_uv).r : 100.0;
	#ifdef WATER_SHORE
	if (!shore_ready || bed_depth >= shore_fade) { discard; }
	#else
	if (shore_ready && bed_depth < shore_fade) { discard; }
	#endif
	float shallows = 1.0 - smoothstep(0.0, shore_fade, bed_depth);
	// Include solid banks beside this point, so the contact detail also
	// follows islands and seawalls rather than only the rectangular bounds.
	float bank_depth = min(bed_depth, min(
		min(texture(shore_depth, shore_uv + vec2(shore_texel.x, 0.0)).r,
			texture(shore_depth, shore_uv - vec2(shore_texel.x, 0.0)).r),
		min(texture(shore_depth, shore_uv + vec2(0.0, shore_texel.y)).r,
			texture(shore_depth, shore_uv - vec2(0.0, shore_texel.y)).r)));
	float contact = shore_ready && surveyed ? 1.0 - smoothstep(0.02, 0.35, bank_depth) : 0.0;
	// The ripples: two layers flowing at different speeds, drawn out along
	// the flow, their slopes added.
	vec2 along = normalize(flow + vec2(0.0001, 0.0));
	vec2 across = vec2(-along.y, along.x);
	vec2 p = vec2(dot(world_pos.xz, along), dot(world_pos.xz, across));
	vec2 run = vec2(length(flow) * water_clock, 0.0);
	vec2 a = texture(ripples, (p - run) / vec2(tile, tile / stretch)).xy * 2.0 - 1.0;
	vec2 b = texture(ripples, (p * vec2(0.61, 0.73) - run * 1.7 + vec2(0.37, 0.11)) / vec2(tile, tile / stretch)).xy * 2.0 - 1.0;
	vec2 slope = (a + b * 0.7) * steep;
	slope = along * slope.x + across * slope.y;

	// Rain: two grids of rings, the surface a little rougher.
	if (rain > 0.001) {
		slope += (drops(world_pos.xz, 0.55, water_clock * 1.3) + drops(world_pos.xz + 0.27, 0.8, water_clock * 1.1 + 0.5)) * 0.9 * rain;
	}

	// Where it laps the walls: a pale scum line; the duckweed's skin in the
	// still water near them, drifting a little, dull and flat.
	float edge = min(half_size.x - abs(local_pos.x), half_size.y - abs(local_pos.y));
	vec2 drift = world_pos.xz * 0.35 - flow * water_clock * 0.6;
	float patchy = texture(patches, drift * 0.13).r * 0.6 + texture(patches, drift * 0.41 + 0.3).r * 0.4;
	float line = (1.0 - smoothstep(0.05, 0.45, edge)) * smoothstep(0.3, 0.55, patchy + 0.2);
	float skin = (1.0 - smoothstep(weed_reach * 0.3, weed_reach, edge)) * smoothstep(0.62 - 0.25 * weed_amount, 0.7 - 0.25 * weed_amount, patchy);
	line = max(line, contact * smoothstep(0.35, 0.65, patchy) * 0.3);
	float film = max(line, skin);
	slope *= 1.0 - 0.65 * max(shallows, contact);
	slope *= 1.0 - 0.85 * film;

	vec3 n_world = normalize(vec3(-slope.x, 1.0, -slope.y));

	if (!FRONT_FACING) {
		n_world = -n_world;
	}

	NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);
	vec3 v_world = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	float facing = clamp(dot(n_world, v_world), 0.0, 1.0);
	float fresnel = 0.02 + 0.98 * pow(1.0 - facing, 5.0);
	vec3 r = reflect(-v_world, n_world);
	vec3 sky = mix(sky_horizon, sky_zenith, smoothstep(0.0, 0.7, r.y)) * sky_light;

	// Each light's column: where its mirror image under the surface lies,
	// seen from the eye; close across, long toward the eye, shivered by the
	// ripples (and rain), fainter the further it has to carry.
	vec3 columns = vec3(0.0);
	vec3 eye = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 to_here = normalize(world_pos - eye);

	for (int i = 0; i < light_count; i++) {
		vec3 source = lights[i].xyz;
		vec3 mirror = vec3(source.x, 2.0 * world_pos.y - source.y, source.z);
		vec3 to_mirror = normalize(mirror - eye);
		vec3 side = normalize(cross(to_mirror, vec3(0.0, 1.0, 0.0)));
		// Down the column (away from the eye) and across it, on the water.
		vec2 toward = normalize(source.xz - eye.xz + vec2(0.0001, 0.0));
		float depth = dot(world_pos.xz - eye.xz, toward);
		float lateral = dot(world_pos.xz - eye.xz, vec2(-toward.y, toward.x));
		// The ripples shiver it side to side, and break it into dashes
		// across the swell (each dash its own brightness, drifting).
		float wobble = texture(patches, vec2(depth * 0.9 - water_clock * 0.35, lateral * 0.08)).r - 0.5;
		float across_by = dot(to_here - to_mirror, side) + (slope.x * along.y - slope.y * along.x) * 0.02 + wobble * column_width * 1.6;
		float down_by = to_here.y - to_mirror.y + dot(slope, vec2(0.7, 0.7)) * 0.01;
		float width = column_width * (1.0 + 2.0 * rain);
		float dashes = smoothstep(0.3, 0.7, texture(patches, vec2(depth * 2.3 + water_clock * 0.5, lateral * 0.35 + float(i) * 0.37)).r);
		float column = exp(-across_by * across_by / (width * width)) * exp(-down_by * down_by / (column_length * column_length)) * (0.25 + 1.5 * dashes);
		float carry = light_colours[i].a / (light_colours[i].a + distance(source.xz, world_pos.xz));
		columns += light_colours[i].rgb * column * carry;
	}

	// The moon's glade: a column of glints on the water from under the moon to
	// the eye (its mirror image at infinity), as a lamp's column: narrow far
	// off, wider near, shivered side to side and broken into dashes across the
	// swell, brighter where the water looks at the eye aslant; and sharp glints
	// of its own in the ripples close by. Only where the moon can be seen from
	// the water (moon_mask), under a clear moon.
	vec2 moonward = normalize(moon_direction.xz + vec2(0.0001, 0.0));
	vec2 from_eye = world_pos.xz - eye.xz;
	float glade_depth = dot(from_eye, moonward);
	float glade_side = dot(from_eye, vec2(-moonward.y, moonward.x));
	float shiver = (texture(patches, vec2(glade_depth * 0.35 - water_clock * 0.25, glade_side * 0.05)).r - 0.5) * 0.05;
	float half_width = mix(glade_near, glade_far, smoothstep(10.0, 300.0, length(from_eye)));
	float bearing = glade_side / max(glade_depth, 0.5) + shiver;
	float glade = glade_depth > 0.0 ? exp(-bearing * bearing / (half_width * half_width)) : 0.0;
	float glade_dash = smoothstep(0.42, 0.8, texture(patches, vec2(glade_depth * 1.7 + water_clock * 0.4, glade_side * 0.3)).r);
	float alignment = max(dot(r, moon_direction), 0.0);
	float glitter = pow(alignment, 180.0) * (0.3 + 0.7 * texture(patches, world_pos.xz * 1.3 - flow * water_clock).r);
	float seen = surveyed ? texture(moon_mask, shore_uv).r : 1.0;
	vec3 moon_trail = moon_colour * moon_visibility * smoothstep(0.0, 0.12, moon_direction.y) * seen
		* (glade * (0.06 + glade_dash) * (0.25 + fresnel) * glade_gain + glitter * 0.65);
	vec3 body = mix(deep, mix(scum, weed, skin), film);
	ALBEDO = body;
	ROUGHNESS = mix(0.05 + 0.12 * rain, 0.7, max(film, shallows * 0.4));
	METALLIC = 0.0;
	SPECULAR = mix(0.5, 0.2, film);
	EMISSION = FRONT_FACING ? (sky * fresnel + moon_trail + columns * column_gain * (0.35 + 0.65 * fresnel)) * (1.0 - film) : deep * 0.5;
	#ifdef WATER_SHORE
	// The bed itself supplies the shore colour. It fades into the same
	// water lighting as the opaque body, without moving the surface vertices.
	ALPHA = smoothstep(0.0, shore_fade, bed_depth);
	#endif
}
