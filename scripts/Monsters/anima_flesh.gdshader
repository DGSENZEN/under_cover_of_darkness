shader_type spatial;
// A ravenous ánima's skin: dried and painted, as the eye's flesh is, from the model's
// own colours, with ink in its creases. As it drinks (`fed`) it fills a little, and the
// sick fire it has nearly lost comes up under the skin. Smoked, it smoulders. The
// viewmodel's hands take the same look, with its depth and field of view. Dying, it burns black
// from where the fire caught (`burn_from`), a hot edge running ahead of the char (`charred`);
// and then the char goes to pale ash and falls apart (`crumbled`), as burning paper does.

#include "res://scripts/Monsters/eye_shared.gdshaderinc"
#include "res://scripts/Monsters/eye_paint.gdshaderinc"

instance uniform float fed = 0.0;
uniform float z_clip = 1.0;
uniform float fov_override = 0.0;
uniform sampler2D burn_noise : filter_linear_mipmap, repeat_enable;
instance uniform float charred = 0.0;
instance uniform float crumbled = 0.0;
instance uniform vec3 burn_from = vec3(0.0);
instance uniform float burn_reach = 0.0;

const vec3 FIRE_EDGE = vec3(0.62, 0.8, 0.16);
const vec3 CHAR = vec3(0.012, 0.012, 0.012);
const vec3 ASH_PALE = vec3(0.21, 0.22, 0.25);

varying vec3 world_at;

const vec3 SICK = vec3(0.5, 0.62, 0.1);

void vertex() {
	paint_at = VERTEX;
	paint_normal = NORMAL;
	world_at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
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
	// at the branch's edge, and draws a line.) Sooner the nearer to where it caught.
	float burn_at = texture(burn_noise, paint_at.xz * 1.1 + paint_at.yy * 0.4).r * 0.7 + texture(burn_noise, paint_at.zy * 2.3).r * 0.3;
	burn_at = smoothstep(0.3, 0.72, burn_at);

	if (burn_reach > 0.0) {
		burn_at = mix(burn_at, clamp(distance(world_at, burn_from) / burn_reach, 0.0, 1.0), 0.62);
	}

	float front = charred * 1.3 - 0.15;
	float charred_here = 1.0 - smoothstep(front - 0.04, front + 0.05, burn_at);
	float crumble_front = crumbled * 1.3 - 0.15;

	if (crumbled > 0.0 && burn_at < crumble_front) {
		discard;
	}

	// Black, with the brush still in it; going pale, just ahead of where it falls apart.
	vec3 ash_tone = CHAR + vec3(0.016) * smoothstep(0.4, 0.62, stroke);
	float pale = crumbled > 0.0 ? 1.0 - smoothstep(crumble_front + 0.04, crumble_front + 0.3, burn_at) : 0.0;
	ash_tone = mix(ash_tone, ASH_PALE * (0.55 + 0.75 * smoothstep(0.32, 0.62, stroke)), pale);
	skin = mix(skin, ash_tone, charred_here);
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
		// The heat at the fire's edge, thin and hot, dying off into the black behind it.
		+ FIRE_EDGE * (smoothstep(front - 0.05, front - 0.005, burn_at) * (1.0 - smoothstep(front - 0.005, front + 0.05, burn_at)) * 1.5
			+ smoothstep(front - 0.26, front - 0.02, burn_at) * (1.0 - smoothstep(front - 0.02, front + 0.03, burn_at)) * 0.22)
			* step(0.001, charred) * (1.0 - smoothstep(0.9, 1.0, charred))
		+ FIRE_EDGE * (1.0 - smoothstep(0.0, 0.03, burn_at - crumble_front)) * step(0.001, crumbled) * 0.8;
}
