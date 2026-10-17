// A cluster's candle flames, one MultiMesh (Vfx.gd): each a frame of our
// candle sheet (heat levels, assets/vfx/flame_candle.png) through its ramp,
// its own phase (INSTANCE_CUSTOM.x), facing the camera about its upright.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D sheet : filter_nearest, repeat_disable;
uniform sampler2D ramp : source_color, filter_linear, repeat_disable;
uniform float frames = 5.0;
uniform float fps = 9.0;
// A draught guttering them (0 none, 1 nearly out): bent over along `lean` (view space x), shrunk.
uniform float gutter = 0.0;

varying float phase;

void vertex() {
	phase = INSTANCE_CUSTOM.x;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
		vec4(0.0, 1.0, 0.0, 0.0), vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0), MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	// Guttered: shorter, bent over from its foot, wavering.
	float up = VERTEX.y;
	VERTEX.y *= 1.0 - 0.65 * gutter;
	VERTEX.x += up * gutter * (0.9 + 0.35 * sin(TIME * 17.0 + phase * 40.0));
	VERTEX.xz *= 1.0 - 0.35 * gutter;
}

void fragment() {
	float frame = mod(floor(TIME * fps + phase * frames), frames);
	float heat = texture(sheet, vec2((frame + UV.x) / frames, UV.y)).r;
	vec3 colour = texture(ramp, vec2(clamp(heat, 0.0, 1.0), 0.5)).rgb;
	ALBEDO = colour;
	EMISSION = colour * 2.0;
	ALPHA = step(0.07, heat);
}
