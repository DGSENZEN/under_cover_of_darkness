// A shade: a person made of slow, dark smoke and light (the talk and quests
// spec, section 5). Drawn unshaded: inside, dim drifting smoke in its one
// colour, darker and thinner than its edges; a bright rim in that colour
// carries the silhouette; the head is a hood of haze (no face); from the
// knees down it is eaten away by rising smoke.
//
// Drawn twice (Shade.gd): first with depth_only, which writes only the
// nearest surface's depth and no colour, then for colour, which draws only
// that nearest surface. So the body never shows its own inside, its back,
// or one arm through the other. Thin strips (a mantle, a fringe, a flap)
// are drawn from both sides, with no rim, fading when seen edge-on.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_always, cull_disabled, shadows_disabled, fog_disabled;

// The character's one colour (DialogueBook.SWATCHES).
uniform vec4 shade_colour : source_color = vec4(1.0, 0.62, 0.22, 1.0);
// How bright it burns: calm 1, flare 2.2, dim 0.35. The rim flares hotter
// with it and all but goes out when dim; dim also cools the colour.
uniform float glow = 1.0;
// How much of it is there: calm 0.55, flare 0.7, dim 0.25.
uniform float opacity = 0.55;
// A candle guttering: 1 while it gutters, else 0.
uniform float flicker = 0.0;
// How agitated the smoke is (calm 0.15, flare 0.35). Its climb is `drift`,
// summed over time by Shade.gd at this speed, so a change of speed never
// makes the smoke jump.
uniform float smoke_speed = 0.15;
// From the soles up this far (m, the body's own space) it dissolves.
uniform float fray_height = 0.5;
// Each shade's own smoke.
uniform float seed = 0.0;
// The first pass: depth only, no colour.
uniform bool depth_only = false;
// The clothes' painted texture, and how much of its light and dark shows
// faintly in the smoke (broad panels and trims only).
uniform sampler2D albedo : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float detail = 0.3;
// A face mesh: it is open at the back (for the hair to cover).
uniform float face = 0.0;
// Thin two-sided strips.
uniform float strips = 0.0;
// Hair: drawn as strips where it hangs off the head (a ponytail).
uniform float cards = 0.0;
// How far this part is drawn in toward the hood (the head and its hair; the
// clothes keep their shape).
uniform float hood_pull = 0.0;

// Per body, every frame (Shade.gd): the smoke's climb so far, and the
// middle of the head in the body's own space.
instance uniform float drift = 0.0;
instance uniform vec3 head_centre = vec3(0.0, 1.65, 0.0);

// The head is drawn in toward a ball of this radius (m) around its middle,
// out to where the hood ends.
const float HOOD_RADIUS = 0.125;
const float HOOD_INNER = 0.13;
const float HOOD_OUTER = 0.2;

varying vec3 v_body;
varying float v_hood;
varying vec3 v_hood_normal;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(hash13(i), hash13(i + vec3(1.0, 0.0, 0.0)), f.x);
	float b = mix(hash13(i + vec3(0.0, 1.0, 0.0)), hash13(i + vec3(1.0, 1.0, 0.0)), f.x);
	float c = mix(hash13(i + vec3(0.0, 0.0, 1.0)), hash13(i + vec3(1.0, 0.0, 1.0)), f.x);
	float d = mix(hash13(i + vec3(0.0, 1.0, 1.0)), hash13(i + vec3(1.0, 1.0, 1.0)), f.x);
	return mix(mix(a, b, f.y), mix(c, d, f.y), f.z);
}

float fbm(vec3 p) {
	float sum = 0.0;
	float amp = 0.5;

	for (int i = 0; i < 3; i++) {
		sum += amp * vnoise(p);
		p = p * 2.03 + vec3(1.7, 9.2, 3.1);
		amp *= 0.5;
	}

	return sum / 0.875;
}

void vertex() {
	// The head drawn in toward a ball: a hood of haze with no features. The
	// depth pass runs the same, so both agree.
	vec3 from_head = VERTEX - head_centre;
	float near_head = length(from_head);
	v_hood = 1.0 - smoothstep(HOOD_INNER, HOOD_OUTER, near_head);
	vec3 ball = head_centre + from_head / max(near_head, 0.001) * HOOD_RADIUS;
	// Not the neck, though: drawn up into the hood it would open a gap
	// above the collar.
	float above_neck = smoothstep(head_centre.y - 0.13, head_centre.y - 0.05, VERTEX.y);
	VERTEX = mix(VERTEX, ball, v_hood * hood_pull * above_neck);
	v_hood_normal = normalize((MODELVIEW_MATRIX * vec4(from_head, 0.0)).xyz);
	// The skinned position, in the body's own space (metres, soles at 0):
	// the smoke moves with her.
	v_body = VERTEX;
}

// How much of her is left at this height: from the soles up she is eaten
// away by smoke that rises through her, so the line is ragged and moving.
float dissolve() {
	// Mostly the height, so she thins steadily all the way down; the smoke
	// climbing through her tears the line and keeps it moving.
	float up = v_body.y / max(fray_height, 0.01);
	float eaten = fbm(v_body * vec3(8.0, 4.0, 8.0) - vec3(0.0, drift * 4.0, 0.0) + seed);
	return smoothstep(0.15, 0.6, up * 1.3 - 0.15 + (eaten - 0.5) * 1.4);
}

void fragment() {
	// A face shows only its outside: it is open at the back (for the hair
	// to cover). Its neck shows both sides: seen through the gap above the
	// collar, its inside is her and not the night.
	if (!FRONT_FACING && face > 0.5 && v_body.y > head_centre.y - 0.06) {
		discard;
	}

	float fray = dissolve();
	// How much this point is a thin card, seen from both sides.
	float thin = max(strips, cards * (1.0 - v_hood));

	if (depth_only) {
		// Wherever any of her near side still shows, it hides her far side.
		// Nor does a strip seen edge-on, which the colour pass fades out
		// (else it would cut a hole in her the shape of the strip).
		float edge_on = thin * (1.0 - smoothstep(0.08, 0.5, clamp(dot(NORMAL, VIEW), 0.0, 1.0)));

		if (fray < 0.02 || edge_on > 0.5) {
			discard;
		}

		ALBEDO = vec3(0.0);
		ALPHA = 0.0;
	} else {
		// (Godot already turns NORMAL to the camera on a back face.)
		vec3 n = normalize(mix(NORMAL, v_hood_normal, v_hood));
		float facing = clamp(dot(n, VIEW), 0.0, 1.0);

		// Slow billows climbing through her, curled by a slower smoke: thick
		// and thin, so she is see-through where it thins.
		vec3 p = v_body * vec3(3.2, 2.0, 3.2) + vec3(seed * 1.37, seed * 0.71 - drift * 1.5, seed * 2.11);
		vec3 curl = vec3(fbm(p * 0.45 + vec3(0.0, drift * 0.3, 0.0)), fbm(p * 0.45 + vec3(5.2, 1.3, -2.8)), 0.5) - 0.5;
		float billow = fbm(p + curl * (1.6 + smoke_speed * 4.0));
		float wisp = fbm(p * 2.3 + curl * 3.0 + vec3(0.0, -drift * 2.0, 7.0));
		float smoke = smoothstep(0.42, 0.66, billow * 0.6 + wisp * 0.4);
		// Over the head a quicker veil of smoke drifts across.
		float veil = smoothstep(0.3, 0.7, fbm(v_body * vec3(6.0, 4.0, 6.0) + vec3(drift * 2.0, -drift * 4.0, seed)));
		smoke = mix(smoke, veil, v_hood);

		// A candle guttering: an uneven waver with now and then a near-out.
		float t = TIME;
		float waver = vnoise(vec3(t * 7.0, seed, 0.0)) * 0.45 + vnoise(vec3(t * 19.0, seed + 3.0, 0.0)) * 0.25;
		float gasp = smoothstep(0.62, 0.8, vnoise(vec3(t * 2.3, seed + 7.0, 0.0))) * 0.5;
		float gutter = clamp(1.0 - flicker * (waver + gasp), 0.12, 1.0);
		float g = glow * gutter;

		// Dim cools her: the colour drains toward a cold grey-blue.
		float cool = clamp((1.0 - glow) / 0.65, 0.0, 1.0);
		vec3 hue = shade_colour.rgb;
		float lum = dot(hue, vec3(0.3, 0.59, 0.11));
		hue = mix(hue, mix(vec3(lum), vec3(0.42, 0.52, 0.72) * lum * 1.4, 0.6), cool * 0.75);
		vec3 hot = mix(hue, vec3(1.0, 0.94, 0.85), 0.25);

		// The rim carries her shape: hotter on a flare, all but gone when
		// dim, a little broken by the smoke so it is never a drawn line.
		float edge = 1.0 - facing;
		float rim = (pow(edge, 3.0) * 0.8 + pow(edge, 6.0) * 0.7) * (1.0 - thin);
		float rim_gain = mix(0.1, 1.0, smoothstep(0.35, 1.0, glow)) * (0.9 + 1.0 * glow) * gutter;
		// Over the hood the veil frays it, so the head is no clean shape.
		rim *= mix(0.55 + 0.45 * smoke, 0.35 + 0.75 * veil, v_hood);

		// Inside, dark smoke: a soft light from above for form, the
		// clothes' broad panels faintly (neither on the hood).
		vec3 world_n = normalize((INV_VIEW_MATRIX * vec4(n, 0.0)).xyz);
		float form = mix(0.7 + 0.3 * clamp(world_n.y * 0.6 + 0.45, 0.0, 1.0), 1.0, v_hood);
		float paint = dot(texture(albedo, UV, 2.5).rgb, vec3(0.3, 0.59, 0.11));
		float cloth = mix(1.0, 0.5 + paint * 1.1, detail * (1.0 - v_hood));
		// Dark smoke, its billows a little lit where they are thickest.
		vec3 inner = hue * (0.02 + 0.55 * smoke * smoke) * form * cloth * g;
		// The hood darker still: a shadow of smoke where a face would be.
		inner *= 1.0 - 0.55 * v_hood;
		vec3 colour = inner + hot * rim * rim_gain;
		// The torn edge where she dissolves glows faintly.
		colour += hue * fray * (1.0 - fray) * 0.6 * g;

		float alpha = opacity * (0.03 + 0.95 * smoke) * mix(1.0, 0.65, v_hood) + rim * 0.9 * min(rim_gain, 1.0);
		// Her inside, seen through a slit or the neck's opening, is as full
		// of smoke as she is, never a hole to the night.
		bool inside = !FRONT_FACING && thin < 0.5;
		alpha = inside ? max(alpha, opacity * 0.6) : alpha;
		colour = inside ? max(colour, hue * 0.22 * g) : colour;
		// A strip seen edge-on fades out, so a flap has no hard line.
		alpha *= mix(1.0, smoothstep(0.08, 0.5, facing), thin);
		alpha *= mix(1.0, gutter, 0.6);
		ALBEDO = colour;
		ALPHA = clamp(alpha, 0.0, 1.0) * fray;
	}
}
