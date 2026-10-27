// An eye opening in the astral void (scripts/Visual/AstralPassage.gd), far off, turned to whoever looks. Its quad twice
// as wide as tall. The eye: fleshy lids (a crease over, a wet line under, the upper closing further than the lower),
// its white veined toward the corners and shadowed under the upper lid, its iris marigold and fibred (paler round the
// pupil, a collarette, dark at its limbus), its pupil a slit that widens and narrows, a glint. Its lids close now and
// then on its own slow clock; it looks a little about. With `socket`, the crack in the dark it looks through instead:
// a torn almond of ink round it, its edges burning faint oxblood with a marigold hairline, fine fractures running out.
// Seen only through the passage's windows.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, fog_disabled, blend_mix;
stencil_mode read, compare_equal, 1;

uniform sampler3D noise : filter_linear, repeat_enable;
uniform float seed = 0.0;
uniform bool socket = false;
// How much of it is there (a glimpse: 0 gone, 1 whole).
uniform float shown = 1.0;
uniform vec3 white : source_color = vec3(0.74, 0.68, 0.56);
uniform vec3 vein : source_color = vec3(0.55, 0.12, 0.1);
uniform vec3 iris : source_color = vec3(1.0, 0.6, 0.16);
uniform vec3 pale : source_color = vec3(1.0, 0.88, 0.6);
uniform vec3 flesh : source_color = vec3(0.3, 0.1, 0.09);
uniform vec3 oxblood : source_color = vec3(0.431, 0.122, 0.102);
uniform vec3 ink : source_color = vec3(0.012, 0.01, 0.016);

void vertex() {
	// (Turned to the eye that looks at it.)
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}

// Its almond's upper and lower edges at `x` (-1..1), open by `open`.
vec2 lids(float x, float open) {
	float span = max(1.0 - x * x, 0.0);
	return vec2(pow(span, 0.8) * 0.62 * open + 0.02 * x, -pow(span, 1.25) * 0.42 * (0.4 + 0.6 * open));
}

vec4 socket_crack(vec2 p) {
	// (The socket's quad a little wider than the eye's: its almond the same shape, torn.)
	float a = atan(p.y, p.x);
	float jag = texture(noise, vec3(cos(a) * 1.7, sin(a) * 1.7, seed * 3.0 + TIME * 0.01)).r - 0.5;
	float fine = texture(noise, vec3(p * 6.0, seed)).r - 0.5;
	vec2 edge = lids(p.x / 0.92, 1.0) * 1.35;
	float inside = max(p.y - edge.x, edge.y - p.y) - (jag * 0.22 + fine * 0.06);
	float body = smoothstep(0.02, -0.02, inside);
	// Its edge burning, a hairline of marigold on it.
	float burn = exp(-max(inside, 0.0) * 9.0) * (1.0 - body);
	float hair = smoothstep(0.03, 0.0, abs(inside));
	// Fine fractures running out from it.
	float lines = 1.0 - smoothstep(0.0, 0.025, abs(texture(noise, vec3(p.x * 2.2, p.y * 4.0, seed * 7.0)).r - 0.5));
	lines *= smoothstep(0.6, 0.0, inside) * step(0.0, inside);
	float breath = 0.75 + 0.25 * sin(TIME * 0.5 + seed * 11.0);
	vec3 col = mix(oxblood * (burn + lines * 0.8) * breath, ink, body);
	col += iris * hair * 0.7 * breath;
	return vec4(col, clamp(body + burn * 0.85 + hair + lines * 0.7, 0.0, 1.0));
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	if (socket) {
		vec4 torn = socket_crack(p);
		ALBEDO = torn.rgb;
		ALPHA = torn.a * shown;
	} else {
		// Its lids: open most of the time, closing slowly now and then.
		float cycle = fract(TIME * 0.07 + seed);
		float open = 1.0 - smoothstep(0.82, 0.9, cycle) * (1.0 - smoothstep(0.92, 1.0, cycle));
		vec2 edge = lids(p.x, open);
		float in_almond = step(p.y, edge.x) * step(edge.y, p.y);
		// (Distance in metres across: the quad twice as wide as tall.)
		vec2 look = vec2(sin(TIME * 0.21 + seed * 9.0) * 0.22, 0.04 * sin(TIME * 0.13 + seed * 4.0));
		vec2 c = vec2(p.x - look.x, (p.y - look.y) * 0.5);
		float d = length(c);
		float ri = 0.25;
		// Its white: veined toward the corners, shadowed under the upper lid and at the corners.
		float veins = 1.0 - smoothstep(0.0, 0.03, abs(texture(noise, vec3(p * vec2(2.5, 5.0), seed * 2.0)).r - 0.5));
		veins *= smoothstep(0.25, 0.85, abs(p.x));
		float shade = smoothstep(0.0, 0.35, edge.x - p.y) * smoothstep(1.0, 0.6, abs(p.x));
		// (Round, as an eyeball is: darker toward its corners and under its lids, a wet sheen across its top.)
		float ball = 1.0 - smoothstep(0.2, 1.0, length(vec2(p.x, p.y * 1.4)));
		vec3 col = mix(white, vein, veins * 0.7) * (0.2 + 0.5 * shade) * (0.55 + 0.45 * ball);
		col += pale * 0.08 * smoothstep(0.12, 0.0, abs(p.y - edge.x * 0.55)) * ball;
		// Its inner corner's caruncle, wet flesh.
		float corner = smoothstep(0.16, 0.05, length(vec2((p.x + 0.86) * 0.8, p.y - 0.02)));
		col = mix(col, mix(flesh, oxblood, 0.5) * 1.2 + pale * 0.06, corner);
		// Its iris: fibred, paler round the pupil, a collarette, dark at its limbus.
		float ang = atan(c.y, c.x);
		float fibres = texture(noise, vec3(cos(ang) * 4.0, sin(ang) * 4.0, d * 3.0 + seed)).r;
		fibres = 0.6 + 0.8 * (fibres - 0.5) + 0.25 * sin(ang * 60.0 + fibres * 8.0);
		float rr = d / ri;
		vec3 ring = mix(pale, iris, smoothstep(0.25, 0.6, rr)) * fibres;
		ring = mix(ring, oxblood, smoothstep(0.65, 1.0, rr) * 0.7);
		ring += pale * 0.25 * smoothstep(0.06, 0.0, abs(rr - 0.45));
		ring = mix(ring, ink, smoothstep(0.84, 0.98, rr));
		float in_iris = smoothstep(ri, ri - 0.01, d);
		col = mix(col, ring * (0.45 + 0.55 * shade), in_iris);
		// Its slit, widening and narrowing.
		float wide = 0.025 + 0.025 * sin(TIME * 0.17 + seed * 3.0);
		float slit = smoothstep(wide + 0.008, wide, abs(c.x) + c.y * c.y * 0.6) * in_iris;
		col = mix(col, ink, slit);
		// Its glint.
		col += pale * smoothstep(0.03, 0.0, length(c - vec2(-0.08, 0.07))) * 0.9;
		col += pale * smoothstep(0.015, 0.0, length(c - vec2(0.06, -0.06))) * 0.5;
		// Its wet line on the lower lid.
		col += pale * 0.4 * smoothstep(0.035, 0.0, abs(p.y - edge.y - 0.02)) * smoothstep(0.9, 0.4, abs(p.x));
		// Its lids: flesh round the almond, a crease over it, darker at the corners.
		float upper = p.y - edge.x;
		float lower = edge.y - p.y;
		float lid_band = max(upper, lower);
		float on_lid = step(0.0, lid_band) * smoothstep(0.26, 0.2, lid_band);
		float crease = smoothstep(0.04, 0.0, abs(upper - 0.14 - 0.05 * (1.0 - p.x * p.x))) * step(0.0, upper);
		float skin = texture(noise, vec3(p * 5.0, seed * 5.0)).r;
		vec3 lid_col = flesh * (0.7 + 0.5 * skin) * (1.0 - 0.6 * crease) * smoothstep(1.05, 0.7, abs(p.x));
		lid_col += pale * 0.08 * smoothstep(0.05, 0.0, lid_band);
		col = mix(lid_col, col, in_almond);
		ALBEDO = col;
		ALPHA = max(in_almond, on_lid * smoothstep(1.0, 0.85, abs(p.x))) * shown;
	}
}
