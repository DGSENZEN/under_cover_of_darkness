shader_type canvas_item;
// Coarse screen grid with channel quantization and ordered 4x4 Bayer dithering.
// Four filtered taps average each cell; screen mipmaps would Gaussian-blur the grid.

uniform sampler2D screen : hint_screen_texture, filter_linear;
// The grid, in cells.
uniform vec2 virtual_size = vec2(640.0, 360.0);
// Levels per channel; 0 leaves colour alone.
uniform float levels = 32.0;
uniform float dither_strength = 0.85;
// A district's palette (16 x 1) and how far each cell is pulled toward its
// nearest colour in Oklab: the whole frame reads as one painting. 0 is off.
uniform sampler2D palette : source_color, filter_nearest;
uniform float palette_pull = 0.0;

vec3 linear_of(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

vec3 srgb_of_oklab(vec3 lab) {
	vec3 lms = vec3(
		lab.x + 0.3963377774 * lab.y + 0.2158037573 * lab.z,
		lab.x - 0.1055613458 * lab.y - 0.0638541728 * lab.z,
		lab.x - 0.0894841775 * lab.y - 1.2914855480 * lab.z);
	lms = lms * lms * lms;
	vec3 c = clamp(vec3(
		4.0767416621 * lms.x - 3.3077115913 * lms.y + 0.2309699292 * lms.z,
		-1.2684380046 * lms.x + 2.6097574011 * lms.y - 0.3413193965 * lms.z,
		-0.0041960863 * lms.x - 0.7034186147 * lms.y + 1.7076147010 * lms.z), 0.0, 1.0);
	return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c));
}

vec3 oklab(vec3 srgb) {
	vec3 c = linear_of(clamp(srgb, 0.0, 1.0));
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

const float BAYER[16] = float[](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0
);

void fragment() {
	vec2 cell = floor(SCREEN_UV * virtual_size);
	vec2 size = 1.0 / virtual_size;
	vec2 centre = (cell + 0.5) * size;
	vec2 q = size * 0.25;

	// The cell's colour: the average of four taps across it.
	vec3 colour = (
		texture(screen, centre + vec2(-q.x, -q.y)).rgb
		+ texture(screen, centre + vec2(q.x, -q.y)).rgb
		+ texture(screen, centre + vec2(-q.x, q.y)).rgb
		+ texture(screen, centre + vec2(q.x, q.y)).rgb
	) * 0.25;

	if (levels > 0.0) {
		int index = int(mod(cell.x, 4.0)) + int(mod(cell.y, 4.0)) * 4;
		float threshold = (BAYER[index] + 0.5) / 16.0 - 0.5;
		colour += threshold * dither_strength / levels;
		colour = floor(colour * levels + 0.5) / levels;
	}

	if (palette_pull > 0.0) {
		vec3 want = oklab(colour);
		vec3 best = colour;
		float d = 1e9;

		for (int i = 0; i < 16; i++) {
			// The palette is sRGB; texelFetch of a source_color texture gives it linear.
			vec3 c = pow(texelFetch(palette, ivec2(i, 0), 0).rgb, vec3(1.0 / 2.2));
			vec3 gap = oklab(c) - want;
			float e = dot(gap, gap);

			if (e < d) {
				d = e;
				best = c;
			}
		}

		// Hue and chroma move toward the palette; each cell keeps its own
		// lightness, so the night keeps its blacks and its contrast.
		vec3 toward = oklab(best);
		colour = srgb_of_oklab(vec3(want.x, mix(want.yz, toward.yz, palette_pull)));
	}

	COLOR = vec4(clamp(colour, 0.0, 1.0), 1.0);
}
