shader_type spatial;
// The egg in the hand as it takes a curse: pale shell, painted as the eye is, with
// an ink line round it, the stain of what it has taken rising through it from the
// palm, until it is nearly black. `taken` 0..1.

#include "res://scripts/Monsters/eye_paint.gdshaderinc"

uniform float taken : hint_range(0.0, 1.0) = 0.0;
// Half its height, in its own space.
uniform float half_height = 0.036;
// The viewmodel's depth squeeze, and field of view (HandSlot's others).
uniform float z_clip = 1.0;
uniform float fov_override = 0.0;

const vec3 SHELL = vec3(0.86, 0.79, 0.62);
const vec3 SHELL_DARK = vec3(0.56, 0.46, 0.34);
const vec3 INK = vec3(0.025, 0.012, 0.015);
const vec3 LIVER = vec3(0.2, 0.035, 0.04);

void vertex() {
	paint_at = VERTEX;
	paint_normal = NORMAL;
	Z_CLIP_SCALE = z_clip;

	if (fov_override > 0.0) {
		float f = 1.0 / tan(radians(fov_override) * 0.5);
		float aspect = abs(PROJECTION_MATRIX[1][1] / PROJECTION_MATRIX[0][0]);
		PROJECTION_MATRIX[1][1] = f * sign(PROJECTION_MATRIX[1][1]);
		PROJECTION_MATRIX[0][0] = f / aspect * sign(PROJECTION_MATRIX[0][0]);
	}
}

void fragment() {
	painted_breakup = brush_here(paint_at, paint_normal, 0.07);
	float height = paint_at.y / half_height * 0.5 + 0.5;
	vec3 albedo = mix(SHELL_DARK, SHELL, smoothstep(0.3, 0.62, painted_breakup));
	// The stain, rising by the brush's grain, its edge veined.
	float rose = taken * 1.5 - 0.25 - height + (painted_breakup - 0.5) * 1.1;
	float stain = smoothstep(-0.02, 0.05, rose);
	albedo = mix(albedo, mix(LIVER, INK, smoothstep(0.1, 0.45, rose)), stain);
	// An ink line round it.
	float edge = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	albedo = mix(albedo, INK, smoothstep(0.62, 0.8, edge));
	ALBEDO = albedo;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	vec3 world_normal = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	// It stays seen in the dark: what you are holding, even at night.
	EMISSION = painted_fill(albedo, world_normal, NORMAL, VIEW) + albedo * 0.16;
}
