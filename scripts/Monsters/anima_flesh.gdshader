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
// Stretched, swelling at you: the skin goes out on what is under it, and splits along its folds.
instance uniform float swell = 0.0;
// What is not flesh at all (the mouth): a dead ash over it, the fire of those in it running under its skin
// toward its throat, a broken light at its edges, and, where `frays`, places it just isn't there.
uniform float spectral = 0.0;
uniform float frays = 0.0;
instance uniform float hunger = 0.0;
const vec3 ASHEN = vec3(0.72, 0.76, 0.66);
const vec3 SOUL_FIRE = vec3(0.3, 0.42, 0.11);
const vec3 SOUL_HOT = vec3(0.62, 0.74, 0.34);
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
	VERTEX += NORMAL * (fed * 0.006 + swell * 0.075);
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
	skin = mix(skin, vec3(0.3, 0.035, 0.03), smoothstep(0.52, 0.34, stroke) * swell * 0.9);
	float soul_edge = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	vec3 soul_light = vec3(0.0);

	if (spectral > 0.0) {
		// The meat goes out of it.
		float dull = dot(skin, vec3(0.3, 0.55, 0.15));
		skin = mix(skin, ASHEN * dull * 0.85, spectral * 0.6 * (1.0 - swell * 0.6));
		// Veins of them, running to its throat: two sets of ridges, crossed, only where both are.
		float ridge_a = 1.0 - abs(eye_noise(paint_at * vec3(11.0, 7.0, 4.5) + vec3(0.0, 0.0, TIME * 0.32)) * 2.0 - 1.0);
		float ridge_b = eye_noise(paint_at * vec3(2.6, 4.0, 3.0) + vec3(TIME * 0.07, 0.0, TIME * 0.21));
		float veins = smoothstep(0.962, 0.985, ridge_a) * smoothstep(0.42, 0.6, ridge_b);
		soul_light += mix(SOUL_FIRE, SOUL_HOT, hunger) * veins * (0.3 + hunger * 1.3);
		// Its edge, in broken bands.
		float broken = eye_noise(paint_at * 7.0 + vec3(0.0, -TIME * 0.5, 0.0));
		float edge_shape = soul_edge * (0.55 + broken * 0.8);
		soul_light += SOUL_FIRE * (smoothstep(0.46, 0.5, edge_shape) * 0.14 + smoothstep(0.68, 0.72, edge_shape) * 0.22) * (0.35 + hunger * 1.5) * spectral;

		if (frays > 0.0) {
			// Where it isn't: slowly going and coming, wider at its edges, lit round where it stops.
			float there = eye_noise(paint_at * 3.4 + vec3(TIME * 0.05, TIME * 0.11, 0.0)) + soul_edge * 0.1 + broken * 0.05;
			float stops = 0.96 - frays * 0.1;

			if (there > stops) {
				discard;
			}

			soul_light += SOUL_FIRE * smoothstep(stops - 0.03, stops - 0.004, there) * (0.45 + hunger * 1.0);
		}
	}

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
		+ soul_light
		// The heat at the fire's edge, thin and hot, dying off into the black behind it.
		+ FIRE_EDGE * (smoothstep(front - 0.05, front - 0.005, burn_at) * (1.0 - smoothstep(front - 0.005, front + 0.05, burn_at)) * 1.5
			+ smoothstep(front - 0.26, front - 0.02, burn_at) * (1.0 - smoothstep(front - 0.02, front + 0.03, burn_at)) * 0.22)
			* step(0.001, charred) * (1.0 - smoothstep(0.9, 1.0, charred))
		+ FIRE_EDGE * (1.0 - smoothstep(0.0, 0.03, burn_at - crumble_front)) * step(0.001, crumbled) * 0.8;
}
