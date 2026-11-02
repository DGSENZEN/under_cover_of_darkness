shader_type spatial;
// A ravenous ánima's skin: dried and painted, as the eye's flesh is, from the model's
// own colours, with ink in its creases. As it drinks (`fed`) it fills a little, and the
// sick fire it has nearly lost comes up under the skin. Smoked, it smoulders. The
// viewmodel's hands take the same look, with its depth and field of view. Dying, it goes to
// pale ash from its own fire's edge inward (`charred`), and the ash falls apart (`crumbled`).

#include "res://scripts/Monsters/eye_shared.gdshaderinc"
#include "res://scripts/Monsters/eye_paint.gdshaderinc"

instance uniform float fed = 0.0;
uniform float z_clip = 1.0;
uniform float fov_override = 0.0;
uniform sampler2D burn_noise : filter_linear_mipmap, repeat_enable;
instance uniform float charred = 0.0;
instance uniform float crumbled = 0.0;

const vec3 FIRE_EDGE = vec3(0.3, 0.37, 0.08);
const vec3 ASH_PALE = vec3(0.2, 0.215, 0.25);
const vec3 ASH_DARK = vec3(0.045, 0.045, 0.05);

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
	// Where the fire has been. (Read always, out here: inside a branch it picks the wrong mip
	// at the branch's edge, and draws a line.)
	float burn_at = texture(burn_noise, paint_at.xz * 1.1 + paint_at.yy * 0.4).r * 0.7 + texture(burn_noise, paint_at.zy * 2.3).r * 0.3;
	burn_at = smoothstep(0.3, 0.72, burn_at);
	float front = charred * 1.3 - 0.15;
	float ash = 1.0 - smoothstep(front - 0.07, front + 0.07, burn_at);

	if (crumbled > 0.0 && burn_at < crumbled * 1.25 - 0.1) {
		discard;
	}

	// Burnt black at the fire's edge, greying behind it, in broad patches.
	float greyed = smoothstep(front - 0.34, front - 0.1, burn_at);
	vec3 ash_tone = mix(ASH_PALE, ASH_DARK, greyed * 0.85 + (1.0 - smoothstep(0.25, 0.65, stroke)) * 0.25);
	skin = mix(skin, ash_tone, ash);
	ALBEDO = skin;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	vec3 world_normal = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	float beat = eye_beat(TIME + eye_hash(NODE_POSITION_WORLD) * 3.0, fed);
	// Its fire under the skin, in the brush's shapes.
	float under = smoothstep(0.6, 0.68, stroke);
	EMISSION = painted_fill(skin, world_normal, NORMAL, VIEW) * 0.8
		+ SICK * (0.012 + under * fed * (0.1 + beat * 0.16))
		+ eye_smoulder(paint_at * 2.0, NORMAL, VIEW, TIME)
		// The heat going along the fire's edge, dying off into the ash behind it.
		+ FIRE_EDGE * smoothstep(front - 0.3, front - 0.02, burn_at) * (1.0 - smoothstep(front - 0.02, front + 0.04, burn_at)) * step(0.001, charred) * (1.0 - smoothstep(0.86, 1.0, charred)) * 0.8
		+ FIRE_EDGE * (1.0 - smoothstep(0.0, 0.025, burn_at - (crumbled * 1.25 - 0.1))) * step(0.001, crumbled) * 0.5;
}
