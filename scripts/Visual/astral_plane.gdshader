// The astral plane over the eye (scripts/Visual/AstralPassage.gd), under the HUD. `strength` how far into the plane
// the walker is (0 outside, 1 inside, eased): the edges of the view slowly flowing as if seen through moving water,
// its colours parting toward the edges, a faint second image breathing over it a little larger, its shadows going to
// the deep's ink-teal and its colour thinned, an ink vignette breathing at its edges with the seeped dark's green in
// it. `shift` the moment of crossing (1 as the threshold is passed, falling away): the view drawn in toward its middle
// and turned a little, its colours split, as an inhaled breath, then let go.
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D noise : filter_linear, repeat_enable;
uniform float strength = 0.0;
uniform float shift = 0.0;
uniform vec3 ink : source_color = vec3(0.012, 0.014, 0.02);
uniform vec3 seeped : source_color = vec3(0.498, 0.827, 0.416);
uniform vec3 marigold : source_color = vec3(1.0, 0.62, 0.16);

vec2 turned(vec2 v, float a) {
	return vec2(v.x * cos(a) - v.y * sin(a), v.x * sin(a) + v.y * cos(a));
}

void fragment() {
	vec2 c = SCREEN_UV - 0.5;
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 round_c = vec2(c.x * aspect, c.y);
	float r = length(round_c);
	float t = TIME;
	// The crossing's breath: drawn in and turned a little about the middle.
	vec2 uv = turned(c, shift * 0.22 * (1.0 - smoothstep(0.0, 0.8, r))) * (1.0 - 0.04 * shift) + 0.5;
	// The edges flowing, as through moving water: more the farther out.
	float edge = smoothstep(0.2, 0.75, r);
	vec2 flow = vec2(texture(noise, SCREEN_UV * 1.5 + vec2(t * 0.02, t * 0.013)).r,
		texture(noise, SCREEN_UV * 1.5 + vec2(-t * 0.017, t * 0.021) + 0.37).r) - 0.5;
	uv += flow * 0.012 * edge * strength;
	// Its colours parting toward the edges (and all over in the crossing).
	vec2 apart = c * (0.006 * edge * strength + 0.02 * shift);
	vec3 col = vec3(texture(screen, uv + apart).r, texture(screen, uv).g, texture(screen, uv - apart).b);
	// A faint second image breathing over it, a little larger.
	float breath = 0.5 + 0.5 * sin(t * 0.45);
	vec3 ghost = texture(screen, (uv - 0.5) * (0.985 - 0.01 * breath) + 0.5).rgb;
	col = mix(col, max(col, ghost), 0.18 * strength);
	// Its shadows to the deep's ink-teal, its colour thinned, its brights a touch warm.
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	vec3 graded = mix(vec3(luma), col, 0.75);
	graded = mix(graded + ink * 0.6 + seeped * 0.012, graded, smoothstep(0.0, 0.25, luma));
	graded += marigold * 0.03 * smoothstep(0.55, 1.0, luma);
	col = mix(col, graded, strength);
	// The ink vignette breathing at its edges, the seeped dark's green in it.
	float vignette = smoothstep(0.38 - 0.03 * breath, 0.85, r);
	col = mix(col, ink + seeped * 0.02 * flow.x, vignette * (0.55 * strength + 0.4 * shift));
	COLOR = vec4(col, 1.0);
}
