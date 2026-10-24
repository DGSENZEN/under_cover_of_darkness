// A shade: a person made of slow smoke and light (the talk and quests spec,
// section 5). Drawn unshaded, half see-through so the clothes still read as
// a silhouette, with a bright rim, smoke drifting up through it in the
// body's own space, and a ragged fray into nothing toward the feet.
//
// Drawn twice (Shade.gd): first with depth_only, which writes only the
// nearest surface's depth and no colour, then for colour, which draws only
// that nearest surface. So the body never shows its own inside, its back,
// or one arm through the other. Thin strips (a mantle, a fringe, a flap)
// are drawn from both sides, with no rim.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_always, cull_disabled, shadows_disabled, fog_disabled;

// The character's one colour (DialogueBook.SWATCHES).
uniform vec4 shade_colour : source_color = vec4(1.0, 0.62, 0.22, 1.0);
// How bright it burns: calm 1, flare 2.2, dim 0.35 (dim also cools it).
uniform float glow = 1.0;
// How much of it is there: calm 0.55, flare 0.7, dim 0.25.
uniform float opacity = 0.55;
// A candle guttering: 1 while it gutters, else 0.
uniform float flicker = 0.0;
// How agitated the smoke inside is (calm 0.15, flare 0.35). Its climb is
// `drift`, summed over time by Shade.gd at this speed, so a change of speed
// never makes the smoke jump.
uniform float smoke_speed = 0.15;
uniform float drift = 0.0;
// From the soles up this far (m, the body's own space) it frays away.
uniform float fray_height = 0.35;
// Each shade's own smoke.
uniform float seed = 0.0;
// The first pass: depth only, no colour.
uniform bool depth_only = false;
// The clothes' painted texture, and how much of its light and dark shows
// in the smoke (its folds, belt and trims; none on a face).
uniform sampler2D albedo : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float detail = 0.5;
// The head: the face lost in a glow of thick smoke, a lit mask and not
// features.
uniform float veil = 0.0;
// Thin two-sided strips: no rim (seen edge-on a strip would be all rim),
// only a veil of smoke.
uniform float strips = 0.0;

varying vec3 v_body;

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
	// The skinned position, in the body's own space (metres, soles at 0):
	// the smoke moves with her.
	v_body = VERTEX;
}

// What shapes her at this point: the smoke's density and its bright
// threads, the rim, the fray and its burning edge (wick), the gutter, and
// how much of her is there (alpha). Shared by both passes so they agree.
void body_alpha(vec3 n, vec3 view, bool front, out float alpha, out float smoke, out float threads, out float rim,
		out float fray, out float wick, out float gutter) {
	float facing = clamp(dot(n, view), 0.0, 1.0);
	// No rim on a strip, nor on her inside (seen only through a slit
	// between two parts, or where she has frayed): its walls are edge-on
	// there, and would draw the slit as a bright line.
	rim = pow(1.0 - facing, 2.5) * (1.0 - strips) * (front ? 1.0 : 0.0);

	// Smoke climbing through her, drawn out upward: billows, curled by a
	// slower smoke of its own, and through them thin bright threads.
	// Finer over a face, so it breaks up what features it has.
	vec3 body = v_body * vec3(6.0, 2.6, 6.0) * (1.0 + 0.8 * veil);
	vec3 p = body + vec3(seed * 1.37, seed * 0.71 - drift * 3.0, seed * 2.11);
	vec3 slow = p * 0.35 + vec3(0.0, drift * 1.2, 0.0);
	vec3 curl = vec3(fbm(slow), fbm(slow + vec3(5.2, 1.3, -2.8)), fbm(slow + vec3(-3.7, 8.1, 2.4))) - 0.5;
	float stir = 2.2 + smoke_speed * 5.0;
	smoke = smoothstep(0.34, 0.68, fbm(p + curl * stir));
	float ridge = 1.0 - abs(2.0 * fbm(p * 1.7 + curl * stir * 1.5 + vec3(11.0, 0.0, 7.0)) - 1.0);
	threads = pow(ridge, 4.5) * (0.7 + 0.4 * veil);

	// Toward the soles she comes apart in hanging threads, burning at their
	// torn edge like a wick, and is gone at the soles themselves.
	vec3 streaks = vec3(v_body.x * 10.0, v_body.y * 0.8 - drift * 1.0, v_body.z * 10.0) + seed;
	// (Stretched only so far that no lone hole opens above the threads.)
	float tear = clamp((fbm(streaks) - 0.5) * 2.0 + 0.5, 0.0, 1.0);
	float up = v_body.y / max(fray_height, 0.01);
	float cut = up * 1.3 - 0.15;
	// No islands of her left lying at the soles.
	fray = smoothstep(tear - 0.08, tear + 0.08, cut) * smoothstep(0.2, 0.45, up);
	wick = clamp(1.0 - abs(cut - tear) / 0.14, 0.0, 1.0);
	wick *= wick * (1.0 - smoothstep(0.8, 1.0, up));

	// A candle guttering: an uneven waver with now and then a near-out.
	float t = TIME;
	float waver = vnoise(vec3(t * 7.0, seed, 0.0)) * 0.45 + vnoise(vec3(t * 19.0, seed + 3.0, 0.0)) * 0.25;
	float gasp = smoothstep(0.62, 0.8, vnoise(vec3(t * 2.3, seed + 7.0, 0.0))) * 0.5;
	gutter = clamp(1.0 - flicker * (waver + gasp), 0.12, 1.0);

	float glow_k = min(glow, 1.6);
	alpha = opacity * (0.12 + 0.7 * smoke + 0.5 * threads) + rim * (0.3 + 0.4 * smoke) * glow_k;
	// A face thinner than the rest of her: it recedes behind its smoke.
	alpha *= 1.0 - 0.25 * veil;
	alpha *= mix(1.0, gutter, 0.6);
	alpha = clamp(alpha, 0.0, 1.0) * fray;
}

void fragment() {
	// A face shows only its outside: it is open at the back, for the hair to
	// cover. Everything else shows both sides, so a crack or a slit between
	// two parts shows her own inside (behind her near side's depth, it is
	// hidden everywhere else), not the night through her.
	if (!FRONT_FACING && veil > 0.5) {
		discard;
	}

	vec3 n = normalize(FRONT_FACING ? NORMAL : -NORMAL);
	float alpha;
	float smoke;
	float threads;
	float rim;
	float fray;
	float wick;
	float gutter;
	body_alpha(n, VIEW, FRONT_FACING || strips > 0.5, alpha, smoke, threads, rim, fray, wick, gutter);

	if (depth_only) {
		// Only where she has come apart does what is behind show; however
		// faint she burns, her near side hides her far side.
		// (Wherever any of her near side still shows, it hides her far side:
		// a looser cut lets the far side's inside speckle through it.)
		if (fray < 0.02) {
			discard;
		}

		ALBEDO = vec3(0.0);
		ALPHA = 0.0;
	} else {
		float g = glow * gutter;
		// Dim cools her: the colour drains toward a cold grey-blue.
		float cool = clamp((1.0 - glow) / 0.65, 0.0, 1.0);
		vec3 hue = shade_colour.rgb;
		float lum = dot(hue, vec3(0.3, 0.59, 0.11));
		vec3 cold = mix(vec3(lum), vec3(0.42, 0.52, 0.72) * lum * 1.4, 0.6);
		hue = mix(hue, cold, cool * 0.75);
		vec3 hot = mix(hue, vec3(1.0, 0.92, 0.8), 0.3);

		// A soft light from above, so her folds and limbs have form (none on
		// a face).
		vec3 world_n = normalize((INV_VIEW_MATRIX * vec4(n, 0.0)).xyz);
		float form = mix(0.55 + 0.45 * clamp(world_n.y * 0.6 + 0.45, 0.0, 1.0), 1.0, veil);
		// The clothes' own light and dark, faintly and softened (its broad
		// panels and trims, not its stitches and laces).
		float paint = dot(texture(albedo, UV, 2.5).rgb, vec3(0.3, 0.59, 0.11));
		float cloth = mix(1.0, 0.4 + paint * 1.4, detail);

		vec3 inner = hue * (0.08 + 0.6 * smoke) * form * cloth + hot * threads * 0.9;
		// The face: a glow of thick smoke.
		inner = mix(inner, hue * (0.12 + 0.55 * smoke) + hot * threads * 0.8, veil);
		// The rim in her own colour, hotter; where the smoke is thick it
		// burns brighter, so the outline is never a clean line.
		float edge = rim * (0.35 + 0.65 * smoke) * (1.0 - 0.7 * veil);
		vec3 colour = inner * g + hot * edge * (0.45 + 0.55 * g);
		colour += hot * wick * 1.0 * g;
		ALBEDO = colour;
		ALPHA = clamp(alpha + wick * 0.5 * fray, 0.0, 1.0);
	}
}
