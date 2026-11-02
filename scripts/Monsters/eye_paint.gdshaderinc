// How the floating eye is lit: painted, not rendered (the look's references:
// docs/superpowers/refs/polish_pass; painterly.gdshaderinc's painted light is its
// kin). Hard stepped shadow shapes broken by the brush, solid dark beyond them, a
// hard dab for a wet highlight, no sky in it: gloss reads as plastic and goes
// lilac under the moon. A fill, cool from above and warm from below, keeps its
// shapes against the night. Set `painted_breakup` in fragment.

uniform float wet = 0.0;
uniform float wet_tight = 48.0;
uniform float fill = 0.24;
uniform vec3 fill_sky : source_color = vec3(0.34, 0.33, 0.52);
uniform vec3 fill_ground : source_color = vec3(0.62, 0.3, 0.2);
uniform float rim = 0.22;
uniform vec3 rim_colour : source_color = vec3(0.5, 0.52, 0.85);
uniform sampler2D stroke_sheet : filter_linear_mipmap, repeat_enable;

varying vec3 paint_at;
varying vec3 paint_normal;
varying float painted_breakup;

// The brush, from whichever axes the surface faces: 0..1.
float brush_here(vec3 at, vec3 normal, float tile) {
	vec3 w = abs(normal);
	w /= (w.x + w.y + w.z);
	return texture(stroke_sheet, at.zy / tile).r * w.x + texture(stroke_sheet, at.xz / tile).r * w.y + texture(stroke_sheet, at.xy / tile).r * w.z;
}

// What the fill and the rim add over `albedo`.
vec3 painted_fill(vec3 albedo, vec3 world_normal, vec3 view_normal, vec3 view) {
	vec3 sky_or_ground = mix(fill_ground, fill_sky, world_normal.y * 0.5 + 0.5);
	float edge = pow(1.0 - clamp(dot(view_normal, view), 0.0, 1.0), 3.0);
	return albedo * sky_or_ground * fill + rim_colour * smoothstep(0.45, 0.7, edge) * rim * 0.35;
}

void light() {
	float n = dot(NORMAL, LIGHT) + (painted_breakup - 0.5) * 0.3;
	float bands = smoothstep(0.03, 0.09, n) * 0.5 + smoothstep(0.42, 0.48, n) * 0.5;
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * bands * vec3(1.05, 1.0, 0.92) * 1.15 / PI;

	if (wet > 0.0) {
		float s = pow(max(dot(NORMAL, normalize(LIGHT + VIEW)), 0.0), wet_tight);
		SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * smoothstep(0.5, 0.58, s) * wet * 0.5;
	}
}
