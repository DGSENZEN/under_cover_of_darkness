// A cluster's candle flames, one MultiMesh (Vfx.gd), drawn the Deadlock way
// (docs/superpowers/refs/underground/vfx_method.md): each a real teardrop
// (MeshVfx.flame, a unit flame scaled by its instance), its colour in painted
// bands from a pale core out through gold and orange to a red rim, a blue
// root over the wick, its tip licked away by noise climbing it. It breathes
// with its light (`flicker`, VfxFlicker), leans on the draught, wavers on its
// own phase (INSTANCE_CUSTOM.x), and gutters when the dark train passes.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled;

uniform sampler2D noise : filter_linear_mipmap, repeat_enable;
// The light's flicker (0.6 .. 1.1), the same value its light burns at.
uniform float flicker = 0.85;
// The air on it (m/s, world): its tip streams downwind.
uniform vec3 draught = vec3(0.0);
// A draught guttering it (0 none, 1 nearly out): bent over, shrunk, wavering.
uniform float gutter = 0.0;
// The bands, inside out, and the root's blue.
// (Stepped like a painted ramp: wine-red rim, orange, amber, a cream core; never white, never black.)
uniform vec4 core : source_color = vec4(1.0, 0.88, 0.68, 1.0);
uniform vec4 gold : source_color = vec4(0.98, 0.72, 0.4, 1.0);
uniform vec4 flame : source_color = vec4(0.93, 0.36, 0.1, 1.0);
uniform vec4 rim : source_color = vec4(0.5, 0.15, 0.13, 1.0);
uniform vec4 root : source_color = vec4(0.22, 0.27, 0.62, 1.0);
// How bright it burns all told (above the night's glow threshold the bloom takes its core).
uniform float energy = 1.25;

varying float phase;
varying float waver;

float licks(vec2 uv) {
	// (A slow warp bends the climbing noise, so its tongues curl rather than slide.)
	vec2 warp = (texture(noise, uv * 0.6 + vec2(phase, -TIME * 0.35)).rg - 0.5) * 0.5;
	vec2 at = vec2(uv.x * 2.0 + phase * 7.0, uv.y * 1.2 - TIME * (1.4 + gutter * 2.0) + phase * 3.0) + warp;
	return texture(noise, at).r * 0.7 + texture(noise, at * 2.3 + vec2(0.5, -TIME * 0.9)).r * 0.3;
}

void vertex() {
	phase = INSTANCE_CUSTOM.x;
	float t = UV.y;
	// Its own quick waver on top of its light's flicker.
	waver = 0.55 * sin(TIME * 11.0 + phase * 40.0) + 0.3 * sin(TIME * 23.0 + phase * 17.0)
		+ 0.15 * sin(TIME * 37.0 + phase * 5.0);
	float breath = 1.0 + 0.7 * (flicker - 0.85) + 0.07 * waver;
	VERTEX.y *= breath * (1.0 - 0.6 * gutter);
	// Taller is thinner: it necks as it stretches.
	VERTEX.xz *= (1.0 - 0.1 * waver * t) * (1.0 - 0.3 * gutter);
	// The tip lags and swims; the draught carries it (in the flame's own axes, so in
	// metres whatever it is scaled by).
	vec3 swim = vec3(0.045 * sin(TIME * 3.1 + phase * 9.0) + 0.02 * sin(TIME * 7.7 + phase * 3.0), 0.0,
		0.035 * cos(TIME * 2.3 + phase * 5.0));
	// (A steady corridor draught, 0.35 m/s, tips it a fifth of its height; the dark train's bends it over.)
	vec3 lean = inverse(mat3(MODEL_MATRIX)) * (draught * 0.035);
	vec3 bend = inverse(mat3(MODEL_MATRIX)) * vec3(gutter * (0.05 + 0.015 * sin(TIME * 17.0 + phase * 40.0)), 0.0, 0.0);
	VERTEX += swim * t * t + lean * t * t + bend * t;
}

void fragment() {
	float t = UV.y;
	float facing = clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0);
	float n = licks(UV);
	// The tip eaten into a lick or two, hard edged; the rest whole.
	float eat = smoothstep(0.62, 1.0, t) * (0.7 + 0.3 * gutter);
	float keep = smoothstep(eat - 0.04, eat + 0.04, n * 0.8 + 0.2 * (1.0 - t));
	if (keep < 0.02) {
		discard;
	}
	// Heat: hottest facing you, low and in the middle; cooling up it and out to its rim.
	float heat = pow(facing, 1.4) * (1.0 - smoothstep(0.12, 0.95, t)) * (0.85 + 0.25 * flicker)
		+ (n - 0.5) * 0.14;
	float a = 0.02;
	// Each band its own brightness: only the core past the night's glow threshold, so the bloom takes
	// the core and the body keeps its colour (an overbright body tone-maps to white).
	vec4 colour = vec4(rim.rgb, 0.8);
	colour = mix(colour, vec4(flame.rgb, 1.0), smoothstep(0.07 - a, 0.07 + a, heat));
	colour = mix(colour, vec4(gold.rgb, 1.15), smoothstep(0.3 - a, 0.3 + a, heat));
	// The cream core a small seed low in it, never the whole flame.
	// (A seed drawn up the flame: the core reaches higher at its middle, narrower than the gold.)
	float seed = smoothstep(0.66 - a, 0.66 + a, heat + 0.25 * (t - 0.12)) * (1.0 - smoothstep(0.34, 0.46, t));
	colour = mix(colour, vec4(core.rgb, 1.3), seed);
	// Over the wick, a band of blue where the flame is thin.
	float blue = 1.0 - smoothstep(0.07, 0.12, t + (n - 0.5) * 0.04);
	colour.rgb = mix(colour.rgb, root.rgb, blue * 0.85);
	float bright = energy * colour.a * flicker * (1.0 - 0.45 * gutter) * mix(1.0, 0.6, blue);
	ALBEDO = colour.rgb * bright;
	// Crisp at its silhouette, the root's blue see-through.
	ALPHA = keep * smoothstep(0.03, 0.2, facing) * mix(1.0, 0.55, blue) * smoothstep(0.0, 0.05, t);
}
