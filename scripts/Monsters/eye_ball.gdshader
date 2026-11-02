shader_type spatial;
// The ball: the painted eye (`paint`), its veins fattening and its white going to
// blood from the rim in as its blood comes up or it is hurt. The iris burns a
// little in the tell. A hard wet dab, no gloss.

#include "res://scripts/Monsters/eye_shared.gdshaderinc"
#include "res://scripts/Monsters/eye_paint.gdshaderinc"

uniform sampler2D paint : source_color, filter_linear_mipmap;
// Where the iris ends, as a fraction of the picture's half-width.
uniform float iris_reach = 0.44;

void vertex() {
	paint_at = VERTEX;
	paint_normal = NORMAL;
}

void fragment() {
	painted_breakup = 0.5;
	vec4 sharp = texture(paint, UV);
	float out_from_middle = length(UV - vec2(0.5)) * 2.0;
	float beat = eye_beat(TIME, rage);
	vec3 c = sharp.rgb;
	vec3 burn = vec3(0.0);

	if (out_from_middle > iris_reach) {
		// Veins: red with no green. Sampled softer they spread.
		vec3 soft = textureLod(paint, UV, 1.0 + rage * 1.8 + wounds).rgb;
		float vein = smoothstep(0.1, 0.28, sharp.r - sharp.g);
		float spread = smoothstep(0.015, 0.14, soft.r - soft.g);
		float blood = max(rage * 0.75 + beat * 0.2 * rage, wounds);
		c = mix(c, vec3(0.5 + beat * 0.2, 0.012, 0.012), max(vein, spread * blood));
		// The white flushes from its rim inward, a flat hard shape.
		float flush = smoothstep(1.0 - blood * 0.6, 1.0 - blood * 0.5, out_from_middle);
		c = mix(c, vec3(0.5, 0.045, 0.03), flush);
	} else {
		burn = sharp.rgb * rage * (0.3 + beat * 0.4);
	}

	c = mix(c, vec3(0.8, 0.03, 0.02), hurt * 0.75);
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	vec3 world_normal = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	EMISSION = painted_fill(c, world_normal, NORMAL, VIEW) + burn;
}
