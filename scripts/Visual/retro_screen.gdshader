shader_type canvas_item;
// Coarse screen grid with channel quantization and ordered 4x4 Bayer dithering.
// Four filtered taps average each cell; screen mipmaps would Gaussian-blur the grid.

uniform sampler2D screen : hint_screen_texture, filter_linear;
// The grid, in cells.
uniform vec2 virtual_size = vec2(640.0, 360.0);
// Levels per channel; 0 leaves colour alone.
uniform float levels = 32.0;
uniform float dither_strength = 0.85;

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

	COLOR = vec4(clamp(colour, 0.0, 1.0), 1.0);
}
