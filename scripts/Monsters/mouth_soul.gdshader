// One of those it has swallowed, straining to get out of it (AnimaMouth.gd): only light, in the ánimas'
// sick fire, brightest at its edges so its sockets and its gape stay hollow. Noise through stepped bands,
// so it has shapes, not a glow. Its tail wrings and eats away toward the end, back to where it is held.
shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled;

uniform vec3 edge_colour : source_color = vec3(0.42, 0.46, 0.4);
uniform vec3 core_colour : source_color = vec3(0.78, 0.82, 0.68);
uniform vec3 hungry_colour : source_color = vec3(0.5, 0.68, 0.2);
uniform vec3 tail_colour : source_color = vec3(0.3, 0.2, 0.09);
uniform sampler2D noise : filter_linear_mipmap, repeat_enable;
uniform float z_clip = 1.0;
uniform float fov_override = 0.0;
// How long its tail is, of as built; how much of it there is, 0..1; how hard it strains, 0..1; its own, so no two go alike.
instance uniform float tail_long = 1.0;
instance uniform float shown = 0.0;
instance uniform float strain = 0.0;
instance uniform float seed = 0.0;

varying float along;
varying vec3 local;

void vertex() {
	along = COLOR.r;
	local = VERTEX;
	float back = 1.0 - along;
	// (Only the tail draws out: the head stays a head.)
	VERTEX.z = VERTEX.z > 0.08 ? 0.08 + (VERTEX.z - 0.08) * tail_long : VERTEX.z;
	// It wrings, more toward the end; the harder it strains the faster.
	float rate = 2.2 + strain * 4.5;
	VERTEX.x += sin(TIME * rate + VERTEX.z * 5.0 + seed) * back * 0.1;
	VERTEX.y += cos(TIME * rate * 0.8 + VERTEX.z * 4.0 + seed * 1.7) * back * 0.08;
	Z_CLIP_SCALE = z_clip;

	if (fov_override > 0.0) {
		float f = 1.0 / tan(radians(fov_override) * 0.5);
		float aspect = abs(PROJECTION_MATRIX[1][1] / PROJECTION_MATRIX[0][0]);
		PROJECTION_MATRIX[1][1] = f * sign(PROJECTION_MATRIX[1][1]);
		PROJECTION_MATRIX[0][0] = f / aspect * sign(PROJECTION_MATRIX[0][0]);
	}
}

void fragment() {
	float back = 1.0 - along;
	// Streaks of it, drawn along its length, going back.
	float n = texture(noise, vec2(local.x * 2.3 + seed, local.z * 0.55 + local.y * 1.6 + TIME * (0.28 + strain * 0.5))).r;
	float n2 = texture(noise, vec2(local.y * 3.1 - seed, local.z * 0.9 + TIME * 0.17)).r;

	// Eaten away toward its end, and in rags at any of it.
	if (n * 0.75 + n2 * 0.25 < back * back * 0.75 + (1.0 - shown) * 0.8 + 0.12) {
		discard;
	}

	// Smoke with a skull's shape to it: a little all through, more at its edges, its sockets hollow.
	float edge = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 1.5);
	float streaks = smoothstep(0.42, 0.8, n);
	float light = edge * (0.32 + streaks * 0.55) + streaks * 0.05;
	vec3 colour = mix(edge_colour, core_colour, smoothstep(0.25, 0.6, light));
	colour = mix(colour, hungry_colour, strain * 0.45);
	colour = mix(colour, tail_colour, smoothstep(0.35, 0.9, back));
	ALBEDO = colour * light * shown * (0.8 + strain * 0.6);
}
