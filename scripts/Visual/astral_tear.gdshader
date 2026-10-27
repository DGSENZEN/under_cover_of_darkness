// The burning edge where the astral passage's void bleeds out over the world (scripts/Visual/AstralPassage.gd): laid
// over a bleed's mark (astral_mark.gdshader: the same quad, the same astral_bleed.gdshaderinc), a hairline of marigold
// along the ragged edge, oxblood smouldering a little way into the world beside it, sparks coming and going.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled, blend_add;

uniform sampler3D noise : filter_linear, repeat_enable;
uniform vec3 marigold : source_color = vec3(1.0, 0.62, 0.16);
uniform vec3 oxblood : source_color = vec3(0.431, 0.122, 0.102);
uniform vec3 pale : source_color = vec3(1.0, 0.88, 0.62);

varying vec3 world_pos;

#include "res://scripts/Visual/astral_bleed.gdshaderinc"

// How far it leans toward the eye off its bleed's plane (m), so the two never fight.
uniform float lean = 0.015;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 eye = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
	VERTEX += normalize(eye - VERTEX) * lean;
}

void fragment() {
	float d = inside_by(world_pos);
	// (d < 0: the world, beside the tear; d > 0: the void.)
	float line = exp(-pow(d / 0.012, 2.0));
	float smoulder = smoothstep(-0.3, 0.0, d) * step(d, 0.0);
	float spark = smoothstep(0.82, 0.95, texture(noise, world_pos * 6.0 + vec3(0.0, -TIME * 0.3, 0.0)).r) * exp(-abs(d) / 0.05);
	float breath = 0.75 + 0.25 * sin(TIME * 0.8 + world_pos.x + world_pos.y);
	ALBEDO = (pale * line * 0.9 + marigold * line * 0.6 + oxblood * smoulder * 0.35 + marigold * spark) * breath;
}
