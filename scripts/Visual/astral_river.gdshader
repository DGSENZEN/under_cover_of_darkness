// A river of the dead in the astral deep (scripts/Visual/AstralPassage.gd): a slow current of faint marigold along a
// ribbon (its UV.x along the way it flows, UV.y across), and in it the dead going toward the market as small soft
// lights, each a round glow with a tail drawn out behind it, many and faint at its edges, the stream thick at its
// middle; seen only through the passage's windows.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, fog_disabled, blend_add;
stencil_mode read, compare_equal, 1;

uniform sampler3D noise : filter_linear, repeat_enable;
uniform vec3 marigold : source_color = vec3(1.0, 0.62, 0.16);
uniform vec3 pale : source_color = vec3(1.0, 0.88, 0.62);
uniform vec3 oxblood_glow : source_color = vec3(0.431, 0.122, 0.102);
// How long and wide the ribbon is (m), how fast its lights go (m/s), how many to a metre in each lane.
uniform float span = 60.0;
uniform float width = 3.0;
uniform float pace = 0.9;
uniform float many = 0.5;
uniform float strength = 1.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

void fragment() {
	float along = UV.x * span;
	float across = (UV.y - 0.5) * width;
	vec3 col = vec3(0.0);
	// Lanes of lights across the ribbon, each its own pace and spacing (in metres both ways).
	for (int lane = 0; lane < 5; lane++) {
		float l = float(lane);
		float y = (l / 4.0 - 0.5) * width * 0.75 + 0.12 * width * sin(UV.x * 18.0 + l * 2.1);
		float spacing = 1.0 / (many * (0.6 + 0.6 * hash(l * 3.1)));
		float x = along - TIME * pace * (0.8 + 0.4 * hash(l)) + hash(l * 7.0) * 10.0;
		float cell = floor(x / spacing);
		float here = hash(cell + l * 101.0);
		if (here < 0.45) {
			continue;
		}
		float dx = (fract(x / spacing) - 0.5) * spacing;
		float dy = across - y;
		// Each a soul's small flame: a bright core in a soft halo, a faint wake behind.
		float size = 0.05 + 0.04 * here;
		float d2 = dx * dx + dy * dy;
		float core = exp(-d2 / (size * size));
		float halo = exp(-d2 / (size * size * 9.0)) * 0.35;
		float wake = exp(-(dy * dy) / (size * size * 1.5)) * smoothstep(0.0, -0.1, dx) * exp(dx / 0.35) * 0.18;
		float flicker = 0.75 + 0.25 * sin(TIME * (1.5 + here * 2.5) + cell);
		float edge = 1.0 - smoothstep(0.2, 0.5, abs(y) / width);
		col += (pale * core + marigold * (halo + wake)) * flicker * (0.35 + 0.65 * edge);
	}
	// The current under them: a soft glow along its middle, strands of it drawn along the flow.
	float flow = texture(noise, vec3(along * 0.06 - TIME * 0.05, across * 0.5, 0.3)).r;
	float strands = texture(noise, vec3(along * 0.03 - TIME * 0.03, across * 2.5, 1.7)).r;
	float bed = exp(-pow(across / (width * 0.4), 2.0));
	col += marigold * bed * (0.04 + 0.05 * flow + 0.06 * smoothstep(0.55, 0.8, strands));
	col += oxblood_glow * bed * 0.03;
	// Fading in and out at its ends, and into the deep's haze far off.
	col *= smoothstep(0.0, 0.08, UV.x) * smoothstep(1.0, 0.92, UV.x);
	col *= 1.0 - 0.85 * smoothstep(30.0, 150.0, distance(world_pos, CAMERA_POSITION_WORLD));
	ALBEDO = col * strength;
}
