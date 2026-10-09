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
uniform float roughness : hint_range(0.0, 1.0) = 0.9;
uniform float specular : hint_range(0.0, 1.0) = 0.3;

varying vec3 world_pos;
varying vec3 world_normal;

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

	// The nearest of the palette's colours.
	vec3 best = texelFetch(palette, ivec2(0, 0), 0).rgb;
	float d = 1e9;

	for (int i = 0; i < 16; i++) {
		vec3 c = texelFetch(palette, ivec2(i, 0), 0).rgb;
		float e = dot(pushed - c, pushed - c);

		if (e < d) {
			d = e;
			best = c;
		}
	}

	ALBEDO = mix(base, best, paint_mix);
#ifndef PAINTERLY_UNSHADED
	NORMAL_MAP = texture(normal_atlas, UV).rgb;
	NORMAL_MAP_DEPTH = normal_depth;
#endif
	ROUGHNESS = roughness;
	SPECULAR = specular;
}
