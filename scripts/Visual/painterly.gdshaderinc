// The painterly look (the Eclipse city's style lab): a hand-painted atlas,
// then brush strokes projected from the world's three axes nudge it, and the
// result is mapped onto the district's palette. paint_mix is how much of the
// shader's version shows over the painted one. Included by painterly.gdshader
// (lit) and painterly_unshaded.gdshader (the pixel check). A painted normal
// map gives the painted relief its depth under the lamps.

uniform sampler2D atlas : source_color, filter_nearest_mipmap, repeat_enable;
// A district's colours, one texel each, 16 wide.
uniform sampler2D palette : source_color, filter_nearest;
uniform sampler2D brush : filter_linear_mipmap, repeat_enable;
// The painted normal map (the atlas's relief); flat when none is given.
uniform sampler2D normal_atlas : hint_normal, filter_nearest_mipmap, repeat_enable;
uniform float normal_depth : hint_range(0.0, 4.0) = 1.0;
uniform float paint_mix : hint_range(0.0, 1.0) = 0.5;
uniform float stroke_strength : hint_range(0.0, 1.0) = 0.12;
// Metres of wall per brush tile.
uniform float stroke_scale = 0.75;
// How much the shader's strokes stand out from the surface: their slopes
// lean the normal, so each stroke catches the light.
uniform float stroke_relief : hint_range(0.0, 2.0) = 0.4;
uniform float roughness : hint_range(0.0, 1.0) = 0.9;
uniform float specular : hint_range(0.0, 1.0) = 0.3;

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

// Painted light (the user's direction, Oct 9 2026): the diffuse in a few soft
// bands, the light/shadow edge broken by the strokes, the lit side a little
// warm and the side turned away a cool fill, not grey. 0 is the standard light.
uniform float painted_light : hint_range(0.0, 1.0) = 0.0;
uniform float light_bands : hint_range(1.0, 8.0) = 3.0;
uniform float band_softness : hint_range(0.0, 0.5) = 0.08;
uniform float terminator_break : hint_range(0.0, 1.0) = 0.35;
uniform vec3 lit_warm = vec3(1.04, 1.0, 0.92);
uniform vec3 shadow_cool = vec3(0.75, 0.85, 1.15);
uniform float shadow_fill : hint_range(0.0, 1.0) = 0.3;

varying vec3 world_pos;
varying vec3 world_normal;
// The strokes' value here, handed to the light pass.
varying float stroke_value;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 base = texture(atlas, UV).rgb;

	// The strokes, from whichever axes the surface faces.
	vec3 w = abs(world_normal);
	w /= (w.x + w.y + w.z);
	float s = texture(brush, world_pos.zy / stroke_scale).r * w.x
		+ texture(brush, world_pos.xz / stroke_scale).r * w.y
		+ texture(brush, world_pos.xy / stroke_scale).r * w.z;
	vec3 pushed = base + (s - 0.5) * stroke_strength;
	stroke_value = s;

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
	// The strokes' slopes, from each projection, as a lean in the world.
	float e = 1.0 / 128.0;
	vec2 px_ = world_pos.zy / stroke_scale, py_ = world_pos.xz / stroke_scale, pz_ = world_pos.xy / stroke_scale;
	vec2 sx = vec2(texture(brush, px_ + vec2(e, 0)).r - texture(brush, px_ - vec2(e, 0)).r,
		texture(brush, px_ + vec2(0, e)).r - texture(brush, px_ - vec2(0, e)).r);
	vec2 sy = vec2(texture(brush, py_ + vec2(e, 0)).r - texture(brush, py_ - vec2(e, 0)).r,
		texture(brush, py_ + vec2(0, e)).r - texture(brush, py_ - vec2(0, e)).r);
	vec2 sz = vec2(texture(brush, pz_ + vec2(e, 0)).r - texture(brush, pz_ - vec2(e, 0)).r,
		texture(brush, pz_ + vec2(0, e)).r - texture(brush, pz_ - vec2(0, e)).r);
	vec3 slope = w.x * vec3(0.0, sx.y, sx.x) + w.y * vec3(sy.x, 0.0, sy.y) + w.z * vec3(sz.x, sz.y, 0.0);
	vec3 leaned = normalize(world_normal - slope * stroke_relief * 2.0);
	NORMAL = normalize((VIEW_MATRIX * vec4(leaned, 0.0)).xyz);
	NORMAL_MAP = texture(normal_atlas, UV).rgb;
	NORMAL_MAP_DEPTH = normal_depth;
#endif
	ROUGHNESS = roughness;
	SPECULAR = specular;
}

#ifndef PAINTERLY_UNSHADED
void light() {
	float ndl = dot(NORMAL, LIGHT);
	float lambert = clamp(ndl, 0.0, 1.0);
	// All the light that reaches here (facing, falloff and cast shadow), so
	// on flat walls too the lamps' pools and the shadows' edges are painted:
	// banded, the bands' edges pushed about by the strokes.
	float energy = max(max(LIGHT_COLOR.r, LIGHT_COLOR.g), LIGHT_COLOR.b);
	float amount = lambert * ATTENUATION;
	float level = clamp(amount + (stroke_value - 0.5) * terminator_break * min(amount * 4.0 + 0.15, 1.0), 0.0, 1.0);
	float x = level * light_bands;
	float stepped = (floor(x) + smoothstep(0.5 - band_softness, 0.5 + band_softness, fract(x))) / light_bands;
	float painted = mix(amount, stepped, painted_light);
	vec3 hue = LIGHT_COLOR / max(energy, 1e-4);
	// Only the darkest band goes cool; the rest keeps the light's own colour
	// (a lamp's pool stays amber to its edge), a little warmer where full.
	vec3 tint = mix(vec3(1.0), mix(shadow_cool, lit_warm, smoothstep(0.0, 1.0 / light_bands, painted)), painted_light);
	DIFFUSE_LIGHT += hue * energy * painted * tint / PI;
	// The side turned away and the edges of shadow take a cool fill, so
	// shadow is a colour, not grey.
	DIFFUSE_LIGHT += hue * energy * (1.0 - painted) * shadow_fill * painted_light * shadow_cool * ATTENUATION / PI;
	// A soft highlight, as the standard light would give.
	vec3 halfway = normalize(VIEW + LIGHT);
	float shine = pow(clamp(dot(NORMAL, halfway), 0.0, 1.0), mix(64.0, 4.0, ROUGHNESS));
	SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * shine * specular * 0.25 * lambert;
}
#endif
