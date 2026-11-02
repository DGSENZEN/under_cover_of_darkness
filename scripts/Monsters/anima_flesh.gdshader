shader_type spatial;
// A ravenous ánima's skin: dried and painted, as the eye's flesh is, from the model's
// own colours, with ink in its creases. As it drinks (`fed`) it fills a little, and the
// sick fire it has nearly lost comes up under the skin. Smoked, it smoulders. The
// viewmodel's hands take the same look, with its depth and field of view.

#include "res://scripts/Monsters/eye_shared.gdshaderinc"
#include "res://scripts/Monsters/eye_paint.gdshaderinc"

instance uniform float fed = 0.0;
uniform float z_clip = 1.0;
uniform float fov_override = 0.0;

const vec3 SICK = vec3(0.5, 0.62, 0.1);

void vertex() {
	paint_at = VERTEX;
	paint_normal = NORMAL;
	VERTEX += NORMAL * fed * 0.006;
	Z_CLIP_SCALE = z_clip;

	if (fov_override > 0.0) {
		float f = 1.0 / tan(radians(fov_override) * 0.5);
		float aspect = abs(PROJECTION_MATRIX[1][1] / PROJECTION_MATRIX[0][0]);
		PROJECTION_MATRIX[1][1] = f * sign(PROJECTION_MATRIX[1][1]);
		PROJECTION_MATRIX[0][0] = f / aspect * sign(PROJECTION_MATRIX[0][0]);
	}
}

void fragment() {
	float stroke = brush_here(paint_at, paint_normal, 0.24);
	painted_breakup = stroke;
	vec3 skin = COLOR.rgb;
	skin = mix(skin, skin * vec3(1.32, 1.16, 0.96), smoothstep(0.45, 0.62, stroke) * 0.7);
	skin = mix(skin, skin * vec3(0.6, 0.52, 0.56), smoothstep(0.55, 0.38, stroke) * 0.75);
	skin = mix(skin, vec3(0.62, 0.02, 0.015), hurt * 0.75);
	ALBEDO = skin;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	vec3 world_normal = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	float beat = eye_beat(TIME + eye_hash(NODE_POSITION_WORLD) * 3.0, fed);
	float under = eye_veins(paint_at * 11.0);
	EMISSION = painted_fill(skin, world_normal, NORMAL, VIEW) * 0.8
		+ SICK * (0.02 + under * fed * (0.35 + beat * 0.5))
		+ eye_smoulder(paint_at * 2.0, NORMAL, VIEW, TIME);
}
