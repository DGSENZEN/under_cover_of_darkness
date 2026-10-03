shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_never, depth_test_disabled;
uniform sampler2D scene : hint_screen_texture, filter_linear;
uniform sampler2D scene_depth : hint_depth_texture, filter_nearest;
uniform sampler2D caustics : filter_linear, repeat_enable;
uniform vec3 water_tint : source_color = vec3(0.1, 0.2, 0.22);
uniform vec3 moon_colour : source_color = vec3(0.6, 0.7, 0.9);
uniform vec3 moon_inside = vec3(0.0, 1.0, 0.0);
uniform vec2 water_center;
uniform vec2 half_size;
uniform float surface_y;
uniform float water_bottom;
uniform float clarity = 0.25;
uniform float ray_strength = 0.0;
uniform float water_clock = 0.0;
void vertex() { POSITION = vec4(VERTEX.xy, 1.0, 1.0); }
void fragment() {
	float depth = texture(scene_depth, SCREEN_UV).r;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, max(depth, 0.00001));
	#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	ndc.z = max(depth, 0.00001) * 2.0 - 1.0;
	#endif
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	vec3 endpoint = view.xyz / view.w;
	float scene_far = length(endpoint);
	float scene_distance = min(scene_far, 70.0);
	vec3 dir = normalize((INV_VIEW_MATRIX * vec4(normalize(endpoint), 0.0)).xyz);
	vec3 eye = INV_VIEW_MATRIX[3].xyz;
	// Clip the optical path to this water's box, including the clear sky above it.
	vec3 lower = vec3(water_center.x - half_size.x, water_bottom, water_center.y - half_size.y);
	vec3 upper = vec3(water_center.x + half_size.x, surface_y, water_center.y + half_size.y);
	vec3 safe_dir = sign(dir + vec3(0.000001)) * max(abs(dir), vec3(0.00001));
	vec3 exits = max((lower - eye) / safe_dir, (upper - eye) / safe_dir);
	float path = max(0.0, min(scene_distance, min(exits.x, min(exits.y, exits.z))));
	float density = mix(0.38, 0.055, clarity);
	vec3 transmission = exp(-path * density * vec3(1.35, 0.75, 0.55));
	float wet = smoothstep(0.0, 0.12, surface_y - eye.y);
	vec2 distortion = vec2(sin(SCREEN_UV.y * 27.0 + water_clock * 1.1), cos(SCREEN_UV.x * 23.0 - water_clock * 0.8)) * 0.0012 * wet;
	vec3 original = texture(scene, SCREEN_UV).rgb;
	vec2 sample_uv = SCREEN_UV + distortion;
	bool internal_reflection = false;
	float window = 1.0;
	float ripple_light = 0.0;
	// The surface seen from under it: wherever the ray meets it before the
	// scene (the sky, or anything standing over the water), inside the box.
	// Rippled; inside Snell's window the world above, refracted (squeezed into
	// the window, dimmer toward its rim); outside it the surface mirrors the
	// dark water, its ripples catching the window's light.
	float to_surface = dir.y > 0.0001 ? (surface_y - eye.y) / dir.y : -1.0;
	vec3 under = eye + dir * max(to_surface, 0.0);
	bool ceiling = to_surface > 0.0 && (depth < 0.00002 || to_surface < scene_far)
		&& abs(under.x - water_center.x) < half_size.x && abs(under.z - water_center.y) < half_size.y;
	if (ceiling) {
		vec2 q = under.xz * 0.22 + water_clock * vec2(0.02, -0.014);
		float h0 = texture(caustics, q).r;
		vec3 n = normalize(vec3((h0 - texture(caustics, q + vec2(0.03, 0.0)).r) * 0.8, -1.0, (h0 - texture(caustics, q + vec2(0.0, 0.03)).r) * 0.8));
		ripple_light = clamp(0.5 + (n.x * dir.x + n.z * dir.z) * 6.0, 0.0, 1.0);
		vec3 air = refract(dir, n, 1.333);
		if (length(air) > 0.1) {
			vec4 projected = PROJECTION_MATRIX * VIEW_MATRIX * vec4(air, 0.0);
			vec2 above_uv = projected.xy / max(projected.w, 0.0001) * 0.5 + 0.5;
			float margin = min(min(above_uv.x, above_uv.y), min(1.0 - above_uv.x, 1.0 - above_uv.y));
			sample_uv = projected.w > 0.0 && margin > 0.002 ? above_uv + distortion : SCREEN_UV + distortion;
			// (Toward the window's rim less gets through: Schlick's reflectance.)
			float cosine = clamp(dot(-dir, -n), 0.0, 1.0);
			window = 1.0 - pow(1.0 - cosine, 5.0) * 0.98;
			window *= 0.4 + 0.6 * smoothstep(0.0, 0.35, 1.0 - length(air.xz));
		} else {
			internal_reflection = true;
		}
	}
	vec3 colour = texture(scene, clamp(sample_uv, vec2(0.002), vec2(0.998))).rgb * window;
	if (ceiling && !internal_reflection) {
		// (The night sky's own light through the window: it is the brightest
		// thing under the water, moon or none.)
		colour += (water_tint * 0.12 + moon_colour * 0.03) * window * (0.7 + 0.3 * ripple_light);
		// The moon itself through the surface, rippled into a blur (its image
		// on the screen is rarely where the refracted ray looks).
		float toward_moon = max(dot(dir, moon_inside), 0.0);
		colour += moon_colour * (pow(toward_moon, 300.0) * 0.9 + pow(toward_moon, 30.0) * 0.07) * window * ray_strength;
	}
	if (internal_reflection) {
		// Outside Snell's window the surface mirrors the dark water body, its
		// ripples catching a little of the window's light.
		colour = water_tint * (0.025 + 0.025 * ripple_light);
	}
	colour = colour * transmission + water_tint * 0.22 * (vec3(1.0) - transmission);
	// Surface caustics advect above samples along the refracted moon direction.
	// Integrating only to scene depth keeps the light in front of solid geometry.
	float shafts = 0.0;
	if (ray_strength > 0.001) {
		for (int i = 0; i < 8; i++) {
			float travel = path * (float(i) + 0.5) / 8.0;
			vec3 p = eye + dir * travel;
			float below = max(surface_y - p.y, 0.0);
			vec2 entry = p.xz + moon_inside.xz * below / max(moon_inside.y, 0.05);
			float a = texture(caustics, entry * 0.19 + water_clock * vec2(0.007, -0.004)).r;
			float b = texture(caustics, entry * 0.33 + water_clock * vec2(-0.003, 0.005)).r;
			// (Soft beams, not a net: broad bands where the two drifting
			// fields meet, shimmering.)
			float lattice = pow(clamp(1.0 - abs(a - b) * 2.2, 0.0, 1.0), 2.5) * (0.6 + 0.4 * a);
			vec2 edge = half_size - abs(entry - water_center);
			float in_water = smoothstep(0.0, 0.3, min(edge.x, edge.y));
			shafts += lattice * exp(-below * density * 1.8) * exp(-travel * density * 0.5) * in_water;
		}
	}
	float phase = 0.12 + 0.88 * pow(max(dot(dir, moon_inside), 0.0), 12.0);
	colour += moon_colour * shafts / 8.0 * min(path, 8.0) * 0.07 * ray_strength * phase;
	ALBEDO = mix(original, colour, wet);
	ALPHA = 1.0;
}
