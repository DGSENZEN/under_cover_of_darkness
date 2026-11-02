shader_type spatial;
// The eye's stone and its spines: the model's painted sheet (`paint`, white if it
// has none) times its vertex colour, which carries the shadow low down and the ink
// along every edge.

#include "res://scripts/Monsters/eye_paint.gdshaderinc"

uniform sampler2D paint : source_color, filter_linear_mipmap, repeat_enable, hint_default_white;

void vertex() {
	paint_at = VERTEX;
	paint_normal = NORMAL;
}

void fragment() {
	painted_breakup = brush_here(paint_at, paint_normal, 0.5);
	ALBEDO = texture(paint, UV).rgb * COLOR.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	vec3 world_normal = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	EMISSION = painted_fill(ALBEDO, world_normal, NORMAL, VIEW) * min(COLOR.g * 40.0 + 0.2, 1.0);
}
