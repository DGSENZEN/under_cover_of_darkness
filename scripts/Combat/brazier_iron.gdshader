shader_type spatial;
// The brazier's iron: painted by its colours (worn, rusted, sooted), broken up in the brush's strokes, and lit from inside (the colour's alpha) by its coals, the more for being swung.

uniform sampler2D stroke_sheet : filter_linear_mipmap, repeat_enable;
instance uniform float fanned = 0.0;

const vec3 HOT = vec3(1.0, 0.3, 0.06);

varying vec3 paint_at;
varying vec3 paint_normal;
varying float heat;

void vertex() {
	paint_at = VERTEX;
	paint_normal = NORMAL;
	heat = COLOR.a;
}

// (As near as the flat of a brush lies on it.)
float stroke_here(vec3 at, vec3 normal, float size) {
	vec3 w = pow(abs(normal), vec3(4.0));
	w /= w.x + w.y + w.z + 0.001;
	return texture(stroke_sheet, at.zy / size).r * w.x + texture(stroke_sheet, at.xz / size).r * w.y + texture(stroke_sheet, at.xy / size).r * w.z;
}

void fragment() {
	float stroke = stroke_here(paint_at, paint_normal, 0.34);
	vec3 iron = COLOR.rgb;
	iron = mix(iron, iron * vec3(1.35, 1.3, 1.22), smoothstep(0.45, 0.62, stroke) * 0.8);
	iron = mix(iron, iron * vec3(0.55, 0.55, 0.58), smoothstep(0.55, 0.38, stroke) * 0.8);
	ALBEDO = iron;
	METALLIC = 0.35;
	ROUGHNESS = mix(0.5, 0.78, stroke);
	// It's always a little visible, in the dark, for what's burning in it.
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = iron * rim * 0.25 + HOT * heat * heat * (0.55 + fanned * 1.3) * smoothstep(0.3, 0.6, stroke + 0.2);
}
