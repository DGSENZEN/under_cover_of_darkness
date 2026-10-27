// A stone of the astral passage's way (scripts/Visual/AstralPassage.gd): a piece of the market's own floor torn loose,
// its top still the Pasaje's chequer (cream and terracotta tiles in their grout, worn by the painted stone under them),
// its broken sides the painted stone, dim, as if lit from far off; a soft ward-white rim round it; the city's glyphs
// glowing marigold in its top's cracks, as if the ward that tore it loose were still written in it.
shader_type spatial;
render_mode unshaded, cull_back, fog_disabled;

uniform sampler2D atlas : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler3D noise : filter_linear, repeat_enable;
uniform vec3 ward : source_color = vec3(0.812, 0.91, 0.941);
uniform vec3 marigold : source_color = vec3(1.0, 0.6, 0.18);
uniform vec3 cream : source_color = vec3(0.8, 0.72, 0.56);
uniform vec3 terracotta : source_color = vec3(0.6, 0.3, 0.2);
uniform vec3 grout : source_color = vec3(0.16, 0.14, 0.12);
uniform vec3 earth_tone : source_color = vec3(0.24, 0.17, 0.12);
uniform vec3 oxblood : source_color = vec3(0.431, 0.122, 0.102);
uniform float dim = 0.34;
// Its top's height (m, the way's floor).
uniform float top_y = 0.0;
// The chequer's tile (m).
uniform float tile = 0.3;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 paint = texture(atlas, UV).rgb;
	float top = smoothstep(0.85, 0.99, world_normal.y);
	// Its top: the chequer, each tile its own tone, worn by the stone's own paint, in its grout.
	// (Filtered by how much of it a pixel covers, so it never shimmers as the eye moves: the chequer a box-filtered one,
	// the grout's lines as wide as a pixel at the least, both softening to their average far off.)
	vec2 at = world_pos.xz / tile;
	vec2 cell = floor(at);
	vec2 f = fract(at);
	vec2 w = fwidth(at) + 0.0001;
	float spread = max(w.x, w.y);
	vec2 i = 2.0 * (abs(fract((at - 0.5 * w) * 0.5) - 0.5) - abs(fract((at + 0.5 * w) * 0.5) - 0.5)) / w;
	float checker = 0.5 - 0.5 * i.x * i.y;
	float edge = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
	float line = 1.0 - smoothstep(0.05 - spread, 0.05 + spread, edge);
	line = mix(line, 0.18, smoothstep(0.08, 0.35, spread));
	float tone = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
	tone = mix(tone, 0.5, smoothstep(0.1, 0.4, spread));
	vec3 tiles = mix(cream, terracotta, checker) * (0.82 + 0.18 * tone);
	// (The painted stone's wear on them, eased off far away, where its texels would only flicker.)
	float luma = mix(dot(paint, vec3(0.333)), 0.5, smoothstep(0.05, 0.3, spread));
	tiles *= 0.65 + 0.6 * luma;
	tiles = mix(tiles, grout, line);
	// Its broken sides: the stone's own paint gone to earth, darker the deeper under its top, sinking into ink.
	float under = clamp((top_y - world_pos.y) / 0.6, 0.0, 1.0);
	float clod = texture(noise, world_pos * 3.0).r;
	vec3 earth = mix(paint * 0.8, earth_tone * (0.6 + 0.6 * clod), 0.55) * (1.0 - 0.85 * under);
	vec3 surface = mix(earth, tiles, top) * dim;
	// A soft ward-white rim on its upper edges only.
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.5) * (1.0 - under);
	float cracks = texture(noise, world_pos * 1.3).r;
	// (A thin line in the noise, at least a pixel wide, fading out where it would be thinner than one.)
	float thin = max(fwidth(cracks), 0.0001);
	float glyph = (1.0 - smoothstep(0.0, 0.012 + thin, abs(cracks - 0.71))) * (1.0 - smoothstep(0.02, 0.06, thin));
	float pulse = 0.6 + 0.4 * sin(TIME * 0.9 + world_pos.x * 1.7 + world_pos.z * 1.1);
	// Where it was torn loose, deep under, a faint glow in its cracks still.
	float torn = smoothstep(0.55, 0.75, clod) * smoothstep(0.4, 1.0, under) * (1.0 - top);
	ALBEDO = surface + ward * rim * 0.15 * (1.0 - top * 0.7) + marigold * glyph * top * pulse * 0.7
		+ mix(oxblood, marigold, pulse * 0.5) * torn * 0.18;
}
