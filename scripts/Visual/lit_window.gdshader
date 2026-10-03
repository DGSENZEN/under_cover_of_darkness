shader_type spatial;
// A window lit from within (Materials "glass_lit"): drawn in its own light,
// whatever falls on it; each house's (each piece's: its node's place) its own
// brightness and warmth, a candle's or a hearth's, a few of them flickering
// slowly as a flame does behind a shutter.
render_mode unshaded, cull_disabled;

uniform vec3 colour : source_color = vec3(1.0, 0.72, 0.4);
uniform float bright = 0.9;

void fragment() {
	vec3 at = NODE_POSITION_WORLD;
	float h = fract(sin(dot(floor(at.xz * 0.5), vec2(12.9898, 78.233))) * 43758.5453);
	float h2 = fract(h * 91.7 + 0.31);
	float own = 0.7 + 0.45 * h;
	vec3 warmth = mix(colour, vec3(1.0, 0.86, 0.62), h2 * 0.6);
	float flicker = h2 > 0.68 ? 0.86 + 0.1 * sin(TIME * (2.0 + 3.0 * h) + h * 20.0) + 0.04 * sin(TIME * 11.0 + h * 7.0) : 1.0;
	ALBEDO = warmth * bright * own * flicker;
}
