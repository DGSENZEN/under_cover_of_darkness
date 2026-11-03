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
// Where those in it push up through the skin (AnimaMouth.gd), in the mesh's own space. `at` w how hard, `way` w
// 2 where a real hand has torn it, `up` w how far that tear is open.
uniform int press_count = 0;
uniform vec4 press_at[11];
uniform vec4 press_way[11];
uniform vec4 press_up[11];
uniform float press_size[11];
uniform sampler2D burn_noise : filter_linear_mipmap, repeat_enable;
// How fine the burn runs over it: big shapes want it finer, or it is patches.
uniform float burn_tile = 1.0;

// x: how far the skin stands out here (m), y: how torn, z: how taut.
vec3 press_read(vec3 p, int i) {
	float strength = press_at[i].w;

	if (abs(strength) < 0.01) {
		return vec3(0.0);
	}

	vec3 way = press_way[i].xyz;
	float size = press_size[i];
	vec3 d = p - press_at[i].xyz;
	float along_way = dot(d, way);
	float r = length(d - way * along_way) / size;

	if (r > 1.0) {
		return vec3(0.0);
	}

	float near = 1.0 - smoothstep(size * 0.7, size * 1.3, abs(along_way));
	float tent = 1.0 - smoothstep(0.15, 1.0, r);
	tent *= tent * (3.0 - 2.0 * tent);

	if (press_way[i].w > 1.5) {
		// Where a real one has torn it: a lip, standing up round a hole.
		vec3 up = press_up[i].xyz;
		vec3 right = cross(up, way);
		float rags = textureLod(burn_noise, vec2(dot(d, right), dot(d, up)) * 3.0, 0.0).r;
		float lip = smoothstep(0.1, 0.42, r) * (1.0 - smoothstep(0.42, 1.0, r));
		float hole = (1.0 - smoothstep(0.24, 0.34, r + (rags - 0.5) * 0.22)) * press_up[i].w;
		return vec3((lip * 0.75 + tent * 0.25) * near * strength * size * 0.9, hole * near, lip * max(strength, 0.0));
	}

	return vec3(tent * near * strength * size * 0.32, 0.0, tent * near * max(strength, 0.0));
}

const vec3 ASHEN = vec3(0.72, 0.76, 0.66);
const vec3 SOUL_FIRE = vec3(0.3, 0.42, 0.11);
const vec3 SOUL_HOT = vec3(0.62, 0.74, 0.34);
uniform float z_clip = 1.0;
uniform float fov_override = 0.0;
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

	for (int i = 0; i < press_count; i++) {
		VERTEX += press_way[i].xyz * press_read(paint_at, i).x;
	}

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
	skin = mix(skin, vec3(0.3, 0.035, 0.03), smoothstep(0.5, 0.34, stroke) * swell * 0.45);
	// What is pressing at it from inside: the skin takes the shape, goes taut and pale, and what is in there
	// shows through where it is thinnest. Where it is torn there is only dark, and that light.
	float taut = 0.0;
	float torn_here = 0.0;
	vec3 lean_normal = vec3(0.0);

	for (int i = 0; i < press_count; i++) {
		vec3 read = press_read(paint_at, i);

		if (read.x == 0.0 && read.y == 0.0) {
			continue;
		}

		vec3 way = press_way[i].xyz;
		vec3 up = press_up[i].xyz;
		vec3 right = normalize(cross(up, way));
		up = cross(way, right);
		float e = 0.012;
		lean_normal -= right * (press_read(paint_at + right * e, i).x - read.x) / e + up * (press_read(paint_at + up * e, i).x - read.x) / e;

		torn_here = max(torn_here, read.y);
		taut = max(taut, read.z);
	}

	if (dot(lean_normal, lean_normal) > 0.0) {
		NORMAL = normalize((VIEW_MATRIX * MODEL_MATRIX * vec4(normalize(paint_normal + lean_normal * 0.9), 0.0)).xyz);
	}

	skin = mix(skin, vec3(0.3, 0.27, 0.19) * (0.8 + stroke * 0.5), smoothstep(0.25, 0.95, taut) * 0.3);
	float soul_edge = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	vec3 soul_light = vec3(0.0);

	if (spectral > 0.0) {
		// The meat goes out of it.
		float dull = dot(skin, vec3(0.3, 0.55, 0.15));
		skin = mix(skin, ASHEN * dull * 0.72, spectral * 0.6 * (1.0 - swell * 0.6));
		// Veins of them, running to its throat: two sets of ridges, crossed, only where both are.
		float ridge_a = 1.0 - abs(eye_noise(paint_at * vec3(11.0, 7.0, 4.5) + vec3(0.0, 0.0, TIME * 0.32)) * 2.0 - 1.0);
		float ridge_b = eye_noise(paint_at * vec3(2.6, 4.0, 3.0) + vec3(TIME * 0.07, 0.0, TIME * 0.21));
		float veins = smoothstep(0.962, 0.985, ridge_a) * smoothstep(0.42, 0.6, ridge_b);
		// (Only its flesh is cracked with it. Bone is bone.)
		soul_light += mix(SOUL_FIRE, SOUL_HOT, hunger) * veins * (0.25 + hunger * 0.75) * frays;
		// Its edge, in broken bands.
		float broken = eye_noise(paint_at * 7.0 + vec3(0.0, -TIME * 0.5, 0.0));
		float edge_shape = soul_edge * (0.55 + broken * 0.8);
		soul_light += SOUL_FIRE * (smoothstep(0.62, 0.66, edge_shape) * 0.12 + smoothstep(0.8, 0.84, edge_shape) * 0.22) * (0.35 + hunger * 1.1) * spectral * (0.3 + frays * 0.7);

		// Torn: nothing in there but dark and that light, burning at its edge.
		soul_light += SOUL_HOT * (smoothstep(0.1, 0.5, torn_here) - smoothstep(0.5, 0.95, torn_here)) * 1.3;
		skin = mix(skin, vec3(0.012, 0.004, 0.005), torn_here);

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
	vec3 burnt_at = paint_at * burn_tile;
	float burn_at = texture(burn_noise, burnt_at.xz * 1.1 + burnt_at.yy * 0.4).r * 0.7 + texture(burn_noise, burnt_at.zy * 2.3).r * 0.3;
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
