// The painterly look (the Eclipse city's style lab): a hand-painted atlas,
// then brush strokes projected from the world's three axes nudge it, and the
// result is mapped onto the district's palette. paint_mix is how much of the
// shader's version shows over the painted one. Included by painterly.gdshader
// (lit) and painterly_unshaded.gdshader (the pixel check). A painted normal
// map gives the painted relief its depth under the lamps.

// Filtered smoothly, as the PS2 did (the user, Oct 9 2026), not nearest.
uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_enable;
// A district's colours, one texel each, 16 wide.
uniform sampler2D palette : source_color, filter_nearest;
uniform sampler2D brush : filter_linear_mipmap, repeat_enable;
// The painted normal map (the atlas's relief); flat when none is given.
uniform sampler2D normal_atlas : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float normal_depth : hint_range(0.0, 4.0) = 1.0;
uniform float paint_mix : hint_range(0.0, 1.0) = 0.5;
uniform float stroke_strength : hint_range(0.0, 1.0) = 0.12;
// Metres of wall per brush tile.
uniform float stroke_scale = 1.2;
uniform float roughness : hint_range(0.0, 1.0) = 0.9;
uniform float specular : hint_range(0.0, 1.0) = 0.3;

// Vertex paint (the vertex-paint spec, section 5): the kit's corners carry
// R grime and soot, G how far the top has worn through to the under layer,
// B tint (0.5 neutral, below damp, above bleached), A baked light. Godot
// hands them over linear (Painterly.VERTEX_COLOUR_SRGB). 0 is today's image;
// set only on meshes that carry colours (a mesh without them reads white).
uniform float vertex_paint : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D under_atlas : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D under_normal : hint_normal, filter_linear_mipmap, repeat_enable;
// The wear-through's edge: how sharp (G either side of 0.5) and how far the
// strokes push it about.
uniform float blend_edge : hint_range(0.0, 0.5) = 0.06;
uniform float blend_break : hint_range(0.0, 2.0) = 0.5;
uniform float tint_amount : hint_range(0.0, 1.0) = 0.5;
uniform float grime_amount : hint_range(0.0, 1.0) = 0.6;
uniform vec3 grime_colour : source_color = vec3(0.239, 0.122, 0.110);
uniform float baked_light_amount : hint_range(0.0, 1.0) = 1.0;

// The world macro layer (the vertex-paint spec, section 6.2): our own soft
// blotches (R value, G warmth, B grime) laid by world position at two
// scales that never line up, so no two copies of a piece look alike.
uniform sampler2D macro : filter_linear_mipmap, repeat_enable;
uniform float macro_amount : hint_range(0.0, 1.0) = 0.0;
// Metres a macro tile covers, twice.
uniform vec2 macro_scales = vec2(23.0, 7.3);

// Linear RGB to Oklab (Björn Ottosson): equal steps look equal, so the
// nearest palette colour is the one that looks nearest.
vec3 oklab(vec3 c) {
	c = max(c, vec3(0.0));
	vec3 lms = vec3(
		0.4122214708 * c.r + 0.5363325363 * c.g + 0.0514459929 * c.b,
		0.2119034982 * c.r + 0.6806995451 * c.g + 0.1073969566 * c.b,
		0.0883024619 * c.r + 0.2817188376 * c.g + 0.6299787005 * c.b);
	lms = pow(lms, vec3(1.0 / 3.0));
	return vec3(
		0.2104542553 * lms.x + 0.7936177850 * lms.y - 0.0040720468 * lms.z,
		1.9779984951 * lms.x - 2.4285922050 * lms.y + 0.4505937099 * lms.z,
		0.0259040371 * lms.x + 0.7827717662 * lms.y - 0.8086757660 * lms.z);
}

// Hex-tiling (Mikkelsen, "Practical Real-Time Hex-Tiling", JCGT 11(2),
// 2022): the plane cut into hexagons, each sampling the tile at its own
// offset (and turn, where allowed), three blended with a weight that keeps
// the contrast, so a tile's repeat stops showing. hex_tiling 1 does it for
// the brush; `tiled` 1 marks a material whose atlas is a tile (a ground),
// not a kit piece's own atlas, so its atlas is hex-tiled too.
uniform float hex_tiling : hint_range(0.0, 1.0) = 0.0;
uniform float tiled : hint_range(0.0, 1.0) = 0.0;

vec2 hex_hash(vec2 p) {
	return fract(sin(mat2(vec2(127.1, 311.7), vec2(269.5, 183.3)) * p) * 43758.5453);
}

// The triangle of hex centres round st, and each one's weight.
void hex_grid(vec2 st, out vec3 w, out vec2 v1, out vec2 v2, out vec2 v3) {
	vec2 skewed = mat2(vec2(1.0, 0.0), vec2(-0.57735027, 1.15470054)) * (st * 3.46410162);
	vec2 base = floor(skewed);
	vec3 t = vec3(fract(skewed), 0.0);
	t.z = 1.0 - t.x - t.y;
	float s = step(0.0, -t.z);
	float s2 = 2.0 * s - 1.0;
	w = vec3(-t.z * s2, s - t.y * s2, s - t.x * s2);
	v1 = base + vec2(s, s);
	v2 = base + vec2(s, 1.0 - s);
	v3 = base + vec2(1.0 - s, s);
}

vec2 hex_centre(vec2 v) {
	return mat2(vec2(1.0, 0.0), vec2(0.5, 0.8660254)) * v / 3.46410162;
}

mat2 hex_turn(vec2 v, bool turn) {
	float a = turn ? 6.2831853 * hex_hash(v + 7.0).x : 0.0;
	return mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a)));
}

// One hexagon's sample: turned about its centre, moved by its offset,
// filtered with the turned derivatives so no seam shows in the mips.
vec4 hex_one(sampler2D tex, vec2 uv, vec2 v, mat2 r, vec2 dx, vec2 dy) {
	vec2 c = hex_centre(v);
	return textureGrad(tex, r * (uv - c) + c + hex_hash(v), r * dx, r * dy);
}

vec3 hex_weights(vec3 w, vec3 a, vec3 b, vec3 c) {
	vec3 luma = vec3(dot(a, vec3(0.299, 0.587, 0.114)), dot(b, vec3(0.299, 0.587, 0.114)), dot(c, vec3(0.299, 0.587, 0.114)));
	vec3 weights = mix(vec3(1.0), luma, 0.6) * pow(max(w, vec3(0.0)), vec3(7.0));
	return weights / max(weights.x + weights.y + weights.z, 1e-6);
}

vec4 hex_sample(sampler2D tex, vec2 uv, bool turn) {
	vec3 w;
	vec2 v1, v2, v3;
	hex_grid(uv, w, v1, v2, v3);
	vec2 dx = dFdx(uv);
	vec2 dy = dFdy(uv);
	vec4 c1 = hex_one(tex, uv, v1, hex_turn(v1, turn), dx, dy);
	vec4 c2 = hex_one(tex, uv, v2, hex_turn(v2, turn), dx, dy);
	vec4 c3 = hex_one(tex, uv, v3, hex_turn(v3, turn), dx, dy);
	vec3 k = hex_weights(w, c1.rgb, c2.rgb, c3.rgb);
	return c1 * k.x + c2 * k.y + c3 * k.z;
}

// A tangent-space normal map hex-tiled: each sample's normal turned back by
// its hexagon's turn before the blend (weights from the colour tile's).
vec3 hex_normal(sampler2D tex, vec2 uv) {
	vec3 w;
	vec2 v1, v2, v3;
	hex_grid(uv, w, v1, v2, v3);
	vec2 dx = dFdx(uv);
	vec2 dy = dFdy(uv);
	mat2 r1 = hex_turn(v1, true);
	mat2 r2 = hex_turn(v2, true);
	mat2 r3 = hex_turn(v3, true);
	vec3 n1 = hex_one(tex, uv, v1, r1, dx, dy).rgb * 2.0 - 1.0;
	vec3 n2 = hex_one(tex, uv, v2, r2, dx, dy).rgb * 2.0 - 1.0;
	vec3 n3 = hex_one(tex, uv, v3, r3, dx, dy).rgb * 2.0 - 1.0;
	// Turned back in the tangent frame, whose y runs down the UV's v (Godot's
	// binormal), so the inverse turn in UV is the turn itself here.
	n1.xy = r1 * n1.xy;
	n2.xy = r2 * n2.xy;
	n3.xy = r3 * n3.xy;
	vec3 k = pow(max(w, vec3(0.0)), vec3(7.0));
	k /= max(k.x + k.y + k.z, 1e-6);
	return normalize(n1 * k.x + n2 * k.y + n3 * k.z) * 0.5 + 0.5;
}

// The atlas (or a ground's tile), the brush: plainly, or hex-tiled.
vec3 painted(sampler2D tex, vec2 uv) {
	return tiled > 0.5 && hex_tiling > 0.5 ? hex_sample(tex, uv, true).rgb : texture(tex, uv).rgb;
}

vec3 painted_normal(sampler2D tex, vec2 uv) {
	return tiled > 0.5 && hex_tiling > 0.5 ? hex_normal(tex, uv) : texture(tex, uv).rgb;
}

float stroke(vec2 uv) {
	return hex_tiling > 0.5 ? hex_sample(brush, uv, false).r : texture(brush, uv).r;
}

vec3 linear_of_oklab(vec3 lab) {
	vec3 lms = vec3(
		lab.x + 0.3963377774 * lab.y + 0.2158037573 * lab.z,
		lab.x - 0.1055613458 * lab.y - 0.0638541728 * lab.z,
		lab.x - 0.0894841775 * lab.y - 1.2914855480 * lab.z);
	lms = lms * lms * lms;
	return vec3(
		4.0767416621 * lms.x - 3.3077115913 * lms.y + 0.2309699292 * lms.z,
		-1.2684380046 * lms.x + 2.6097574011 * lms.y - 0.3413193965 * lms.z,
		-0.0041960863 * lms.x - 0.7034186147 * lms.y + 1.7076147010 * lms.z);
}

// Painted light (the user's direction, Oct 9 2026): the diffuse in a few soft
// bands, the light/shadow edge broken by the strokes, the lit side a little
// warm and the side turned away a cool fill, not grey. 0 is the standard light.
uniform float painted_light : hint_range(0.0, 1.0) = 0.0;
uniform float light_bands : hint_range(1.0, 8.0) = 3.0;
uniform float band_softness : hint_range(0.0, 0.5) = 0.08;
uniform float terminator_break : hint_range(0.0, 2.0) = 1.0;
uniform vec3 lit_warm = vec3(1.04, 1.0, 0.92);
uniform vec3 shadow_cool = vec3(0.75, 0.85, 1.15);
uniform float shadow_fill : hint_range(0.0, 1.0) = 0.3;

// Variant D: the light ramp (after TF2's warped diffuse), a painted strip
// from no light to full that the user may repaint, in place of the bands.
uniform sampler2D light_ramp : source_color, filter_linear, repeat_disable;
uniform float ramp_amount : hint_range(0.0, 1.0) = 0.0;
// Painted ambient: sky colour from above, the ground's bounce from below.
uniform vec3 ambient_sky : source_color = vec3(0.40, 0.44, 0.58);
uniform vec3 ambient_ground : source_color = vec3(0.42, 0.30, 0.24);
uniform float ambient_amount : hint_range(0.0, 1.0) = 0.0;
// A thin light round the silhouettes, against the dark.
uniform vec3 rim_colour : source_color = vec3(0.62, 0.70, 0.95);
uniform float rim_amount : hint_range(0.0, 1.0) = 0.0;
uniform float rim_width : hint_range(1.0, 8.0) = 3.0;

varying vec3 world_pos;
varying vec3 world_normal;
// The strokes' value here, handed to the light pass.
varying float stroke_value;
// The vertex paint's baked light, handed to the light pass.
varying float baked_light;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 base = painted(atlas, UV);

	// The strokes, from whichever axes the surface faces.
	vec3 w = abs(world_normal);
	w /= (w.x + w.y + w.z);
	float s = stroke(world_pos.zy / stroke_scale) * w.x
		+ stroke(world_pos.xz / stroke_scale) * w.y
		+ stroke(world_pos.xy / stroke_scale) * w.z;
	stroke_value = s;

	// The vertex paint: worn through, tinted, grimed, each broken by the strokes.
	float edge = 0.0;
	baked_light = mix(1.0, COLOR.a, vertex_paint * baked_light_amount);

	if (vertex_paint > 0.0) {
		edge = smoothstep(0.5 - blend_edge, 0.5 + blend_edge, COLOR.g + (s - 0.5) * blend_break) * vertex_paint;
		// The broken lip: a darker band where the top gives way.
		float lip = 1.0 - 0.25 * smoothstep(0.0, 0.3, edge) * smoothstep(1.0, 0.7, edge);
		base = mix(base, painted(under_atlas, UV), edge) * lip;
		vec3 lab = oklab(base);
		float t = (COLOR.b - 0.5) * 2.0 * tint_amount * vertex_paint * clamp(0.7 + (s - 0.5) * 2.0, 0.0, 1.3);
		lab.x += t * 0.25;
		lab.yz *= t < 0.0 ? 1.0 - t * 0.3 : 1.0 - t * 0.6;
		lab.z -= min(t, 0.0) * -0.02;
		base = max(linear_of_oklab(lab), vec3(0.0));
		float grime = COLOR.r * grime_amount * vertex_paint * clamp(0.75 + (s - 0.5) * 2.0, 0.0, 1.0);
		base = mix(base, grime_colour, grime);
	}

	// The macro layer: a little lighter or darker, warmer or cooler, dirtier
	// or cleaner, place by place (at most 6% in lightness).
	if (macro_amount > 0.0) {
		vec2 place = world_pos.xz + vec2(world_pos.y * 0.37, -world_pos.y * 0.29);
		vec3 m = (texture(macro, place / macro_scales.x).rgb + texture(macro, place / macro_scales.y).rgb) * 0.5 - 0.5;
		vec3 lab = oklab(base);
		lab.x += m.r * 0.12 * macro_amount;
		float turn = m.g * 0.3 * macro_amount;
		lab.yz = mat2(vec2(cos(turn), sin(turn)), vec2(-sin(turn), cos(turn))) * lab.yz;
		base = max(linear_of_oklab(lab), vec3(0.0));
		base = mix(base, grime_colour, clamp(m.b * 0.3 * macro_amount, 0.0, 1.0));
	}

	vec3 pushed = base + (s - 0.5) * stroke_strength;

	// The nearest of the palette's colours, as the eye judges it (Oklab).
	vec3 want = oklab(pushed);
	vec3 best = texelFetch(palette, ivec2(0, 0), 0).rgb;
	float d = 1e9;

	for (int i = 0; i < 16; i++) {
		vec3 c = texelFetch(palette, ivec2(i, 0), 0).rgb;
		vec3 gap = oklab(c) - want;
		float e = dot(gap, gap);

		if (e < d) {
			d = e;
			best = c;
		}
	}

	ALBEDO = mix(base, best, paint_mix);
#ifndef PAINTERLY_UNSHADED
	// Painted ambient and rim, laid on as light of their own.
	float up = clamp(world_normal.y * 0.5 + 0.5, 0.0, 1.0);
	EMISSION = ALBEDO * mix(ambient_ground, ambient_sky, up) * ambient_amount * baked_light;
	EMISSION += rim_colour * pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_width) * rim_amount;
#endif
#ifndef PAINTERLY_UNSHADED
	NORMAL_MAP = mix(painted_normal(normal_atlas, UV), painted_normal(under_normal, UV), edge);
	NORMAL_MAP_DEPTH = normal_depth;
#endif
	ROUGHNESS = roughness;
	SPECULAR = specular;
}

#ifndef PAINTERLY_UNSHADED
// A lamp's ramp is sampled this far either side, twice (a soft band in place
// of the steps), and fades in from nothing over this much of its light.
const float LAMP_RAMP_SPREAD = 0.06;
const float LAMP_GATE = 0.25;

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float lambert = clamp(ndl, 0.0, 1.0);
	// All the light that reaches here (facing, falloff and cast shadow), so
	// on flat walls too the lamps' pools and the shadows' edges are painted:
	// banded, the bands' edges pushed about by the strokes.
	float energy = max(max(LIGHT_COLOR.r, LIGHT_COLOR.g), LIGHT_COLOR.b);
	float amount = lambert * ATTENUATION * baked_light;
	float level = clamp(amount + (stroke_value - 0.5) * terminator_break * min(amount * 4.0 + 0.15, 1.0), 0.0, 1.0);
	float x = level * light_bands;
	float stepped = (floor(x) + smoothstep(0.5 - band_softness, 0.5 + band_softness, fract(x))) / light_bands;
	float painted = mix(amount, stepped, painted_light);
	vec3 hue = LIGHT_COLOR / max(energy, 1e-4);
	// Only the darkest band goes cool; the rest keeps the light's own colour
	// (a lamp's pool stays amber to its edge), a little warmer where full.
	vec3 tint = mix(vec3(1.0), mix(shadow_cool, lit_warm, smoothstep(0.0, 1.0 / light_bands, painted)), painted_light);
	// The side turned away and the edges of shadow take a cool fill, so
	// shadow is a colour, not grey.
	vec3 banded = painted * tint + (1.0 - painted) * shadow_fill * painted_light * shadow_cool * ATTENUATION;
	// Or the painted ramp's colour for this much light. The sun and moon take
	// it whole, its violet floor the colour of their shadows. A lamp takes it
	// softened (sampled across a band, so its steps lay no hard rings on the
	// way out) and gated to nothing where its own light dies: Godot runs a
	// lamp over whole screen tiles round it, and the floor added there drew
	// blocky bands that moved with the player.
	vec3 ramped = texture(light_ramp, vec2(clamp(level, 0.01, 0.99), 0.5)).rgb;

	if (!LIGHT_IS_DIRECTIONAL) {
		vec3 soft = vec3(0.0);

		for (int k = -2; k <= 2; k++) {
			soft += texture(light_ramp, vec2(clamp(level + float(k) * LAMP_RAMP_SPREAD, 0.01, 0.99), 0.5)).rgb;
		}

		ramped = soft / 5.0 * smoothstep(0.0, LAMP_GATE, amount);
	}
	DIFFUSE_LIGHT += hue * energy * mix(banded, ramped, ramp_amount) / PI;
	// A soft highlight, as the standard light would give.
	vec3 halfway = normalize(VIEW + LIGHT);
	float shine = pow(clamp(dot(NORMAL, halfway), 0.0, 1.0), mix(64.0, 4.0, ROUGHNESS));
	SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * shine * specular * 0.25 * lambert;
}
#endif
