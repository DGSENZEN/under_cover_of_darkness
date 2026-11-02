shader_type spatial;
render_mode cull_disabled;
// The torn nerve and its shreds: they writhe, more the freer they are (UV.x, 0
// at the root), and stream along `sway` (in the model's space) as it flies. Its
// colours are the model's own, laid in strokes with a hard wet dab.

#include "res://scripts/Monsters/eye_shared.gdshaderinc"
#include "res://scripts/Monsters/eye_paint.gdshaderinc"

instance uniform vec3 sway = vec3(0.0);

void vertex() {
	paint_at = VERTEX;
	paint_normal = NORMAL;
	float free_end = UV.x * UV.x;
	float speed = 2.2 + rage * 3.5;
	vec3 writhe = vec3(sin(TIME * speed + VERTEX.y * 6.0 + VERTEX.x * 9.0), 0.0, cos(TIME * speed * 0.8 + VERTEX.y * 5.0 + VERTEX.z * 7.0));
	VERTEX += writhe * 0.045 * UV.x + sway * free_end;
}

void fragment() {
	float stroke = brush_here(paint_at, paint_normal, 0.3);
	painted_breakup = stroke;
	vec3 c = COLOR.rgb;
	c = mix(c, c * vec3(1.4, 0.85, 0.8), smoothstep(0.42, 0.62, stroke));
	c = mix(c, c * vec3(1.5, 0.35, 0.3), wounds * 0.5);
	c = mix(c, vec3(0.75, 0.02, 0.015), hurt * 0.7);
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	vec3 world_normal = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	EMISSION = painted_fill(c, world_normal, NORMAL, VIEW);
}
