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
	float scene_distance = min(length(endpoint), 70.0);
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
	// The sky is seen through the surface's refracted window. Screen-space
	// sampling falls back at its limits rather than stretching an off-screen moon.
	if (depth < 0.00002 && dir.y > 0.0) {
		vec3 air = refract(dir, vec3(0.0, -1.0, 0.0), 1.333);
		if (length(air) > 0.1) {
			vec4 projected = PROJECTION_MATRIX * VIEW_MATRIX * vec4(air, 0.0);
			vec2 sky_uv = projected.xy / max(projected.w, 0.0001) * 0.5 + 0.5;
			float margin = min(min(sky_uv.x, sky_uv.y), min(1.0 - sky_uv.x, 1.0 - sky_uv.y));
			if (margin > 0.002 && projected.w > 0.0) {
				sample_uv = sky_uv + distortion;
			}
		} else {
			internal_reflection = true;
		}
	}
	vec3 colour = texture(scene, clamp(sample_uv, vec2(0.002), vec2(0.998))).rgb;
	if (internal_reflection) {
		// Outside Snell's window the surface reflects the dark water body;
		// showing the un-refracted sky here would draw a second moon.
		colour = water_tint * 0.06;
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
			float lattice = pow(clamp(1.0 - abs(a - b) * 5.0, 0.0, 1.0), 5.0);
			vec2 edge = half_size - abs(entry - water_center);
			float in_water = smoothstep(0.0, 0.3, min(edge.x, edge.y));
			shafts += lattice * exp(-below * density * 1.8) * exp(-travel * density * 0.5) * in_water;
		}
	}
	float phase = 0.12 + 0.88 * pow(max(dot(dir, moon_inside), 0.0), 12.0);
	colour += moon_colour * shafts / 8.0 * min(path, 8.0) * 0.12 * ray_strength * phase;
	ALBEDO = mix(original, colour, wet);
	ALPHA = 1.0;
}
