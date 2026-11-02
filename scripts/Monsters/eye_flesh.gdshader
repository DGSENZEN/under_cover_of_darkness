shader_type spatial;
// The eye's meat and lids: flat wet reds laid in strokes over the model's own
// colours, liver in the folds, veins standing out violet and flushing arterial as
// its blood comes up, a hard wet dab, swelling with its heartbeat. What it is doing
// comes in as rage, hurt and wounds.

#include "res://scripts/Monsters/eye_shared.gdshaderinc"
#include "res://scripts/Monsters/eye_paint.gdshaderinc"

uniform float swell = 0.009;

void vertex() {
	paint_at = VERTEX;
	paint_normal = NORMAL;
	float beat = eye_beat(TIME + eye_hash(MODEL_MATRIX[3].xyz) * 3.0, rage);
	float lump = eye_noise(VERTEX * 9.0 + vec3(0.0, TIME * 0.25, 0.0));
	VERTEX += NORMAL * swell * lump * (0.6 + beat * (1.0 + rage * 1.6));
}

void fragment() {
	float stroke = brush_here(paint_at, paint_normal, 0.35);
	painted_breakup = stroke;
	float vein = eye_veins(paint_at * 8.0);
	float beat = eye_beat(TIME + eye_hash(NODE_POSITION_WORLD) * 3.0, rage);
	vec3 meat = COLOR.rgb;
	// A second and third paint, near it: hue and value, not dirt.
	meat = mix(meat, meat * vec3(1.45, 0.8, 0.75) + vec3(0.03, 0.0, 0.0), smoothstep(0.42, 0.62, stroke));
	meat = mix(meat, meat * vec3(0.55, 0.42, 0.55), smoothstep(0.6, 0.4, stroke) * 0.8);
	vec3 violet = vec3(0.1, 0.022, 0.09);
	vec3 artery = vec3(0.62, 0.012, 0.012) * (0.7 + beat * 0.5);
	meat = mix(meat, mix(violet, artery, clamp(rage * 1.3, 0.0, 1.0)), vein * 0.85);
	meat = mix(meat, meat * vec3(1.5, 0.35, 0.3), wounds * 0.6);
	meat = mix(meat, vec3(0.78, 0.02, 0.015), hurt * 0.85);
	ALBEDO = meat;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	vec3 world_normal = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	EMISSION = painted_fill(meat, world_normal, NORMAL, VIEW) + artery * vein * rage * 0.3 + vec3(0.5, 0.01, 0.01) * hurt * 0.3 + eye_smoulder(paint_at, NORMAL, VIEW, TIME);
}
