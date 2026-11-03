shader_type spatial;
// A revenant's skin: pale, cold and wet, painted as the others are, from the model's own colours, with the
// brush on it and ink in its folds. Its eyes (the colour's alpha) burn, the one that laid a touch on you brightest
// (`eyes`). Fire comes up through it (`burn`), and the brazier's hits leave it hot and scored (`seared`).

#include "res://scripts/Monsters/eye_shared.gdshaderinc"
#include "res://scripts/Monsters/eye_paint.gdshaderinc"

instance uniform float eyes = 0.0;
instance uniform float burn = 0.0;
instance uniform float seared = 0.0;

const vec3 EYE_DIM = vec3(1.1, 0.72, 0.28);
const vec3 EYE_LIT = vec3(2.6, 1.7, 0.7);
const vec3 FIRE = vec3(1.0, 0.36, 0.06);

void vertex() {
	paint_at = VERTEX;
	paint_normal = NORMAL;
}

void fragment() {
	float stroke = brush_here(paint_at, paint_normal, 0.3);
	painted_breakup = stroke;
	// (Its colours are painted in sRGB, and it stands in brighter light than a mouth's dark bulk: held down, or it blows out.)
	vec3 skin = COLOR.rgb * 0.68;
	skin = mix(skin, skin * vec3(1.22, 1.2, 1.08), smoothstep(0.45, 0.62, stroke) * 0.7);
	skin = mix(skin, skin * vec3(0.56, 0.6, 0.62), smoothstep(0.55, 0.38, stroke) * 0.75);
	// Scored by the coals: dark, with heat in the cuts.
	float scored = smoothstep(0.58, 0.44, stroke) * seared;
	skin = mix(skin, vec3(0.03, 0.02, 0.018), scored * 0.8);
	// Burning: black coming up from under, in the brush's shapes.
	float char_here = smoothstep(0.62 - burn * 0.7, 0.7 - burn * 0.7, stroke) * step(0.001, burn);
	skin = mix(skin, vec3(0.012), char_here * 0.85);
	ALBEDO = skin;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	vec3 world_normal = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	float lit_eye = smoothstep(0.4, 0.8, COLOR.a);
	EMISSION = painted_fill(skin, world_normal, NORMAL, VIEW) * 0.8
		+ lit_eye * mix(EYE_DIM, EYE_LIT, eyes)
		+ FIRE * (scored * 0.7 + char_here * (1.0 - char_here) * 2.0 * burn)
		+ eye_smoulder(paint_at * 2.0, NORMAL, VIEW, TIME);
}
