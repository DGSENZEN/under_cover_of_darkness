// Heat-sheet flipbook (assets/vfx/flame_<sheet>.png, tools/props/flames.py) mapped through colour ramps.
// Frame, strength, mirroring, and wind are instance uniforms so sprites share one material.
// Nearest sampling preserves the authored hard edges.

uniform sampler2D heat : filter_nearest, repeat_disable;
uniform sampler2D ramp : source_color, filter_nearest, repeat_disable;
uniform sampler2D ramp_low : source_color, filter_nearest, repeat_disable;
uniform int frames = 8;

instance uniform int frame = 0;
instance uniform float strength = 1.0;
instance uniform vec3 lean = vec3(0.0);
instance uniform float mirror = 0.0;
instance uniform float low = 0.0;

void vertex() {
	// Upright, always facing you (a fixed-Y billboard), keeping its scale.
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz));
	vec3 forward = normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0)));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(right, 0.0), vec4(0.0, 1.0, 0.0, 0.0), vec4(forward, 0.0), MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	// The wind pushes the tip across your view, the base stays on the fuel.
	float up = clamp(1.0 - UV.y, 0.0, 1.0);
	VERTEX.x += dot(lean, right) * 0.35 * VERTEX.y * up;
}

// The flame's colour and cover at this pixel (alpha 0 outside the flame).
vec4 flame_colour(vec2 uv) {
	float u = mirror > 0.5 ? 1.0 - uv.x : uv.x;
	float cell = 1.0 / float(frames);
	float h = texture(heat, vec2((float(frame % frames) + clamp(u, 0.001, 0.999)) * cell, uv.y)).r;
	vec4 full = textureLod(ramp, vec2(h, 0.5), 0.0);
	vec4 dying = textureLod(ramp_low, vec2(h, 0.5), 0.0);
	vec4 colour = mix(full, dying, clamp(low, 0.0, 1.0));
	colour.a = h > 0.0 ? colour.a : 0.0;
	return colour;
}

float flame_heat(vec2 uv) {
	float u = mirror > 0.5 ? 1.0 - uv.x : uv.x;
	float cell = 1.0 / float(frames);
	return texture(heat, vec2((float(frame % frames) + clamp(u, 0.001, 0.999)) * cell, uv.y)).r;
}
