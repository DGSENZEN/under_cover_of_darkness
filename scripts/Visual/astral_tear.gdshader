// The burning edge where the astral passage's void bleeds out over the world (scripts/Visual/AstralPassage.gd): laid
// over a bleed's window (astral_window.gdshader: the same quad and uniforms), a hairline of marigold along the ragged
// edge, oxblood smouldering a little way into the world beside it, sparks coming and going. Its torn_to and
// inside_by must stay the window's.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled, blend_add;

uniform sampler3D noise : filter_linear, repeat_enable;
uniform float bleed = 0.0;
uniform vec3 seg_a;
uniform vec3 seg_b;
uniform vec3 marigold : source_color = vec3(1.0, 0.62, 0.16);
uniform vec3 oxblood : source_color = vec3(0.431, 0.122, 0.102);
uniform vec3 pale : source_color = vec3(1.0, 0.88, 0.62);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float torn_to(vec3 at, float reach) {
	float big = texture(noise, at * 0.45 + vec3(0.0, TIME * 0.01, 0.0)).r;
	float fine = texture(noise, at * 2.2 + vec3(TIME * 0.02)).r;
	return reach * clamp(0.15 + 1.1 * big + 0.35 * (fine - 0.5), 0.0, 1.4);
}

float inside_by() {
	vec3 ab = seg_b - seg_a;
	vec3 nearest = seg_a + ab * clamp(dot(world_pos - seg_a, ab) / max(dot(ab, ab), 0.0001), 0.0, 1.0);
	return torn_to(world_pos, bleed) - distance(world_pos, nearest);
}

void fragment() {
	float d = inside_by();
	// (d < 0: the world, beside the tear; d > 0: the void.)
	float line = exp(-pow(d / 0.012, 2.0));
	float smoulder = smoothstep(-0.3, 0.0, d) * step(d, 0.0);
	float spark = smoothstep(0.82, 0.95, texture(noise, world_pos * 6.0 + vec3(0.0, -TIME * 0.3, 0.0)).r) * exp(-abs(d) / 0.05);
	float breath = 0.75 + 0.25 * sin(TIME * 0.8 + world_pos.x + world_pos.y);
	ALBEDO = (pale * line * 0.9 + marigold * line * 0.6 + oxblood * smoulder * 0.35 + marigold * spark) * breath;
}
