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
// How long and wide the ribbon is (m), how fast its lights go (m/s), how many to a metre in each lane.
uniform float span = 60.0;
uniform float width = 3.0;
uniform float pace = 0.9;
uniform float many = 0.9;
uniform float strength = 1.0;

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

void fragment() {
	float along = UV.x * span;
	float across = (UV.y - 0.5) * width;
	vec3 col = vec3(0.0);
	// Lanes of lights across the ribbon, each its own pace and spacing (in metres both ways).
	for (int lane = 0; lane < 7; lane++) {
		float l = float(lane);
		float y = (l / 6.0 - 0.5) * width * 0.75 + 0.12 * width * sin(UV.x * 18.0 + l * 2.1);
		float spacing = 1.0 / (many * (0.6 + 0.6 * hash(l * 3.1)));
		float x = along - TIME * pace * (0.8 + 0.4 * hash(l)) + hash(l * 7.0) * 10.0;
		float cell = floor(x / spacing);
		float here = hash(cell + l * 101.0);
		if (here < 0.45) {
			continue;
		}
		float dx = (fract(x / spacing) - 0.5) * spacing;
		float dy = across - y;
		float size = 0.06 + 0.05 * here;
		float head = exp(-(dx * dx + dy * dy) / (size * size));
		float tail = exp(-(dy * dy) / (size * size * 0.35)) * smoothstep(0.0, -0.08, dx) * exp(dx / 0.45) * 0.45;
		float flicker = 0.75 + 0.25 * sin(TIME * (1.5 + here * 2.5) + cell);
		float edge = 1.0 - smoothstep(0.2, 0.5, abs(y) / width);
		col += mix(marigold, pale, head * 0.7) * (head + tail) * flicker * (0.35 + 0.65 * edge);
	}
	// The current: a soft flowing glow along its middle.
	float flow = texture(noise, vec3(along * 0.08 - TIME * 0.05, across * 0.4, 0.3)).r;
	col += marigold * 0.05 * exp(-pow(across / (width * 0.35), 2.0)) * (0.5 + flow);
	// Fading in and out at its ends.
	col *= smoothstep(0.0, 0.08, UV.x) * smoothstep(1.0, 0.92, UV.x);
	ALBEDO = col * strength;
}
