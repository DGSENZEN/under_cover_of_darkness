// What floats in the void (scripts/Visual/AstralPassage.gd: the city's fragments, the serpent), seen only through the
// astral passage's windows: inked nearly black, a rim of cold teal and marigold catching an unseen light, the city's
// glyphs flickering over it now and then.
shader_type spatial;
render_mode unshaded, cull_back, fog_disabled;

uniform sampler3D noise : filter_linear, repeat_enable;
uniform vec3 ink : source_color = vec3(0.018, 0.014, 0.026);
uniform vec3 rim_cold : source_color = vec3(0.3, 0.78, 0.86);
uniform vec3 rim_warm : source_color = vec3(1.0, 0.6, 0.18);
uniform float glow = 1.0;
uniform float flicker_seed = 0.0;
// The haze it is lost into with distance (m: where it starts, where it is nearly whole).
uniform vec3 haze : source_color = vec3(0.03, 0.035, 0.032);
uniform float haze_near = 20.0;
uniform float haze_far = 120.0;
// How much of it is there (a glimpse forming out of the dark and going back to it: below 1 it dissolves).
uniform float shown = 1.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (texture(noise, world_pos * 0.15 + vec3(flicker_seed)).r > shown * 1.1 - 0.05) {
		discard;
	}
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	// (Its rim warmer where it faces down, colder up: as if lit from the market below and the deep above.)
	vec3 world_n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 rim_col = mix(rim_warm, rim_cold, smoothstep(-0.4, 0.4, world_n.y));
	// The glyphs: bright flecks in the noise's fine grain, coming and going.
	float grain = texture(noise, world_pos * 0.9 + vec3(flicker_seed)).r;
	float pulse = smoothstep(0.6, 1.0, sin(TIME * 0.7 + flicker_seed * 13.0) * 0.5 + 0.5);
	float glyphs = smoothstep(0.71, 0.74, grain) * (1.0 - smoothstep(0.74, 0.77, grain)) * pulse;
	vec3 col = ink + rim_col * rim * 1.4 * glow + rim_warm * glyphs * 0.9 * glow;
	// The deep's haze: farther, the more it is lost into the dark (so the near reads near, the far vast).
	float far = smoothstep(haze_near, haze_far, distance(world_pos, CAMERA_POSITION_WORLD));
	ALBEDO = mix(col, haze, far * 0.85);
}
