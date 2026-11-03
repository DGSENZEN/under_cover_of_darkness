shader_type spatial;
// A revenant's skin. It never left the lake: painted as the others are, cold, with the light of the water still crawling over it,
// black water running up it, and the seep that raised it (phosphor green, the colour of the seeped) lighting the split in its
// chest and the cracks round what holds it down, in thin lines. Its edge breaks up, lit, as the mouth's does: not all of it is here.
// What drifts on it (UV x: how far along) moves as if under water. Its eyes (the colour's alpha, above 0.85) burn; the one that
// laid a touch on you burns hotter (`eyes`). Fire comes up through it (`burn`), and the brazier leaves it hot and scored (`seared`).

#include "res://scripts/Monsters/eye_shared.gdshaderinc"
#include "res://scripts/Monsters/eye_paint.gdshaderinc"

instance uniform float eyes = 0.0;
instance uniform float burn = 0.0;
instance uniform float seared = 0.0;
// How angry it is, 0..1: everything of the seep comes up with it.
instance uniform float wrath = 0.0;
// What it has just done, for what drifts on it to come after (m, in the model's space).
instance uniform vec3 drift_way = vec3(0.0);
// Dying, by fire: the char running over it, a hot edge ahead of it (`charred`), and then the ash of it going pale and falling away (`crumbled`).
instance uniform float charred = 0.0;
instance uniform float crumbled = 0.0;

const vec3 SEEP = vec3(0.5, 0.83, 0.42);
const vec3 SEEP_HOT = vec3(1.1, 1.5, 0.75);
const vec3 EYE = vec3(0.75, 2.1, 0.5);
const vec3 EYE_HOT = vec3(6.0, 8.0, 4.0);
const vec3 FIRE = vec3(1.0, 0.36, 0.06);

varying float drift_t;
varying float seep_here;

void vertex() {
	paint_at = VERTEX;
	paint_normal = NORMAL;
	drift_t = UV.x;
	seep_here = COLOR.a;

	if (UV.x > 0.001) {
		float phase = UV.y * 6.283;
		float t = UV.x * UV.x;
		// Seaweed: it floats, and a slow wave runs out along it, each at its own time. It comes after what the body did, the far end last; the more it's being dragged, the more it waves.
		float drag = length(drift_way);
		vec3 wave = vec3(sin(TIME * 0.7 + phase - UV.x * 4.6), sin(TIME * 0.5 + phase * 1.7 - UV.x * 3.6) * 0.6, cos(TIME * 0.6 + phase * 2.3 - UV.x * 3.9));
		vec3 fine = vec3(sin(TIME * 1.3 + phase * 3.0 - UV.x * 9.0), 0.0, cos(TIME * 1.1 + phase * 4.0 - UV.x * 8.0));
		VERTEX += wave * t * (0.24 + drag * 0.3) + fine * t * 0.05;
		VERTEX += drift_way * (0.65 + 0.5 * sin(phase * 3.0)) * mix(UV.x, t, 0.5) * 1.5;
	}
}

void fragment() {
	float stroke = brush_here(paint_at, paint_normal, 0.34);
	painted_breakup = stroke;
	// (Its colours are painted in sRGB: held down, or it blows out under a lamp.)
	vec3 skin = COLOR.rgb * 0.6;
	skin = mix(skin, skin * vec3(1.2, 1.2, 1.1), smoothstep(0.45, 0.62, stroke) * 0.7);
	skin = mix(skin, skin * vec3(0.55, 0.62, 0.62), smoothstep(0.55, 0.38, stroke) * 0.8);
	// Where the fire is at, here. Read always, out here: it should run in its own shapes, and from the middle of it out.
	float burn_at = clamp(stroke * 0.5 + eye_noise(paint_at * 4.3) * 0.5 + length(paint_at - vec3(0.0, 1.3, 0.0)) * 0.1, 0.0, 1.0);

	if (crumbled > 0.0 && burn_at < crumbled * 1.25 - 0.1) {
		discard;
	}

	float is_eye = step(0.86, seep_here);
	float rest = 1.0 - is_eye;
	vec3 light_of = vec3(0.0);

	if (drift_t < 0.001) {
		// Black water, running up it: long streaks, wet at their edge.
		float run = eye_noise(paint_at * vec3(9.0, 1.3, 9.0) + vec3(0.0, -TIME * 0.16, 0.0));
		float dark_run = smoothstep(0.66, 0.72, run);
		skin = mix(skin, skin * 0.42, dark_run * 0.7 * rest);
		// The water's light, on it though it is out of the water: a fine net of it, drifting, hardly there.
		float ripple_a = 1.0 - abs(eye_noise(paint_at * 9.0 + vec3(TIME * 0.22, TIME * 0.1, 0.0)) * 2.0 - 1.0);
		float ripple_b = 1.0 - abs(eye_noise(paint_at * 11.0 + vec3(-TIME * 0.17, 3.0, TIME * 0.19)) * 2.0 - 1.0);
		float caustic = smoothstep(0.955, 0.985, max(ripple_a, ripple_b)) * smoothstep(0.42, 0.6, eye_noise(paint_at * 2.3 + vec3(0.0, TIME * 0.06, 0.0)));
		skin = mix(skin, skin * vec3(1.4, 1.65, 1.55), caustic * 0.7 * rest);
		light_of += SEEP * caustic * 0.025 * rest;
		// The seep, in cracks: thin, and only where it lies near: round the split, the nails, the crust's edge.
		float crack_a = 1.0 - abs(eye_noise(paint_at * vec3(17.0, 11.0, 17.0) + vec3(0.0, -TIME * 0.2, 0.0)) * 2.0 - 1.0);
		float crack_b = eye_noise(paint_at * vec3(3.1, 4.2, 3.4) + vec3(TIME * 0.05, 0.0, TIME * 0.09));
		float nearness = smoothstep(0.14, 0.42, seep_here);
		float crack = smoothstep(0.972, 0.99, crack_a) * smoothstep(0.34, 0.5, crack_b) * nearness;
		skin = mix(skin, vec3(0.01), crack * 0.7 * rest);
		light_of += mix(SEEP, SEEP_HOT, wrath) * crack * (0.55 + wrath * 0.7) * rest;
		// And in the split it is all there is.
		float deep = smoothstep(0.5, 0.78, seep_here) * rest;
		float beat = eye_beat(TIME * 0.8 + eye_hash(NODE_POSITION_WORLD) * 3.0, wrath);
		// (Broken up by the brush: a wound with light in it, not a stripe. Hottest at its heart.)
		float broken_up = smoothstep(0.34, 0.56, stroke);
		skin = mix(skin, vec3(0.008, 0.01, 0.008), deep);
		light_of += mix(SEEP * 0.42, SEEP_HOT * 0.55, beat * 0.5 + wrath * 0.4) * deep * broken_up * (0.35 + smoothstep(0.78, 0.84, seep_here) * 0.9);
	}

	// Scored by the coals: dark, with heat in the cuts.
	float scored = smoothstep(0.58, 0.44, stroke) * seared;
	skin = mix(skin, vec3(0.03, 0.02, 0.018), scored * 0.8);
	// Burning as it comes: the hide splitting, heat in its folds, not all black. Dying: the char takes it all, from the middle out, and goes to pale ash at the last.
	float fire_cracks = smoothstep(0.46, 0.38, stroke) * burn;
	skin = mix(skin, skin * 0.4, smoothstep(0.62, 0.42, stroke) * burn * 0.8);
	float front = charred * 1.3 - 0.15;
	float char_here = 1.0 - smoothstep(front - 0.05, front + 0.03, burn_at);
	vec3 ash = vec3(0.016, 0.015, 0.014) + vec3(0.012) * smoothstep(0.4, 0.62, stroke);
	float crumble_front = crumbled * 1.25 - 0.1;
	float pale = crumbled > 0.0 ? 1.0 - smoothstep(crumble_front + 0.03, crumble_front + 0.26, burn_at) : 0.0;
	ash = mix(ash, vec3(0.22, 0.21, 0.2) * (0.55 + 0.75 * smoothstep(0.32, 0.62, stroke)), pale);
	skin = mix(skin, ash, char_here);
	skin = mix(skin, vec3(0.34, 0.03, 0.02), hurt * 0.45);
	float hot_edge = (1.0 - smoothstep(0.0, 0.05, abs(burn_at - front))) * step(0.001, charred) * (1.0 - smoothstep(0.92, 1.0, charred));
	float glow_behind = smoothstep(front - 0.2, front - 0.02, burn_at) * (1.0 - smoothstep(front - 0.02, front + 0.02, burn_at)) * step(0.001, charred);
	ALBEDO = skin * rest;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	// (All the seep on it goes out, as it burns.)
	light_of *= 1.0 - smoothstep(0.1, 0.6, charred);
	vec3 world_normal = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	// Its edge, in broken bands, as the mouth's is.
	float edge = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	float broken = eye_noise(paint_at * 7.0 + vec3(0.0, -TIME * 0.45, 0.0));
	float edge_shape = edge * (0.55 + broken * 0.8);
	light_of += SEEP * (smoothstep(0.66, 0.7, edge_shape) * 0.05 + smoothstep(0.84, 0.88, edge_shape) * 0.11) * (0.5 + wrath) * rest;
	EMISSION = painted_fill(skin * rest, world_normal, NORMAL, VIEW) * 0.8
		+ light_of
		+ is_eye * mix(EYE, EYE_HOT, max(eyes, wrath * 0.6)) * (1.0 - smoothstep(0.3, 0.75, charred))
		+ FIRE * (scored * 0.7 + fire_cracks * (0.5 + 0.5 * sin(TIME * 7.0 + paint_at.y * 9.0)) * 0.34 + hot_edge * 1.3 + glow_behind * 0.12)
		+ FIRE * char_here * (1.0 - crumbled) * smoothstep(0.64, 0.72, stroke) * 0.22
		+ eye_smoulder(paint_at * 2.0, NORMAL, VIEW, TIME);
}
