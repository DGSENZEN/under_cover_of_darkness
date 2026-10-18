// A candle's thread of smoke (Vfx.gd's candles: one per flame, on the flames'
// own MultiMesh transforms): a thin ribbon standing off the flame's tip, turned
// to face you about its upright, curling as it climbs (two waves travelling up
// it), fraying away by climbing noise, leaning on the draught. A steady flame
// only now and then sends one up; a guttering one smokes.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, world_vertex_coords;

uniform sampler2D noise : filter_linear_mipmap, repeat_enable;
uniform vec4 colour : source_color = vec4(0.5, 0.45, 0.42, 1.0);
uniform vec4 thin : source_color = vec4(0.27, 0.26, 0.29, 1.0);
uniform vec3 draught = vec3(0.0);
uniform float gutter = 0.0;
// Its height and width at a flame of 1 (m), how far off the flame's foot it starts (m, at 1).
uniform float height = 0.38;
uniform float width = 0.022;
uniform float start = 0.07;
uniform float opacity = 0.5;

varying float phase;
varying float smoking;

void vertex() {
	phase = INSTANCE_CUSTOM.x;
	float scale = length(MODEL_MATRIX[0].xyz) / 0.065;
	float v = UV.y;
	vec3 foot = MODEL_MATRIX[3].xyz + vec3(0.0, start * scale, 0.0);
	// Two waves travelling up it, the slower one wider: a thread that curls.
	float curl = sin(v * 13.0 - TIME * 2.4 + phase * 20.0) * 0.016 * v
		+ sin(v * 5.0 - TIME * 1.2 + phase * 7.0) * 0.045 * pow(v, 1.3);
	float curl_z = cos(v * 9.0 - TIME * 1.7 + phase * 13.0) * 0.02 * v;
	vec3 up = vec3(0.0, 1.0, 0.0);
	vec3 to_eye = normalize(CAMERA_POSITION_WORLD - foot);
	vec3 across = normalize(cross(up, to_eye));
	vec3 depth_way = cross(across, up);
	vec3 centre = foot + up * v * height * scale + (across * curl + depth_way * curl_z) * scale
		+ draught * 0.45 * v * v * scale;
	VERTEX = centre + across * (UV.x - 0.5) * width * scale * (0.5 + 1.5 * v);
	// It comes and goes on a steady flame; a guttering one always smokes.
	smoking = max(smoothstep(0.25, 0.7, sin(TIME * 0.27 + phase * 25.0) * 0.5 + 0.5), gutter);
}

void fragment() {
	float v = UV.y;
	if (smoking < 0.01) {
		discard;
	}
	float across = 1.0 - abs(UV.x - 0.5) * 2.0;
	vec2 at = vec2(UV.x * 0.6 + phase * 3.0, v * 1.6 - TIME * 0.55 + phase);
	float n = texture(noise, at).r * 0.7 + texture(noise, at * 2.7 + vec2(0.0, -TIME * 0.3)).r * 0.3;
	// Frays from its top down, hard edged; whole and thin at its root.
	float eat = 0.25 + 0.55 * v;
	float keep = smoothstep(eat - 0.05, eat + 0.05, n * across + 0.15 * (1.0 - v));
	float shape = smoothstep(0.0, 0.25, across) * smoothstep(0.0, 0.08, v) * (1.0 - smoothstep(0.75, 1.0, v));
	ALBEDO = mix(colour.rgb, thin.rgb, smoothstep(0.2, 0.9, v));
	ALPHA = keep * shape * opacity * smoking * (1.0 + 0.6 * gutter);
}
