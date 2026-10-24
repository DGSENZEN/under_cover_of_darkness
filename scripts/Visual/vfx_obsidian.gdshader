// Obsidian: black glass that is lit, glossy and near black, its fresnel cut
// into hard bands so each flat facet flashes a cold edge as it turns, and a
// hairline of the cold glint along every facet's edge (the mesh carries
// barycentric corners in COLOR: MagicFx.spearhead_mesh). It still reads at
// night. In your view it is drawn as the arms are (z_clip, fov_override).
shader_type spatial;
render_mode cull_back, specular_schlick_ggx;

uniform vec4 glass : source_color = vec4(0.039, 0.039, 0.051, 1.0);
uniform vec4 glint : source_color = vec4(0.9, 0.933, 0.96, 1.0);
// How bright the banded fresnel and the facet edges glow (above 1 the bloom takes them).
uniform float glint_energy = 1.8;
uniform float edge_energy = 1.1;
// How wide the facet edges' hairline is, in barycentric terms.
uniform float edge_width = 0.04;
// The viewmodel's depth squeeze and its own field of view (0: the camera's).
uniform float z_clip = 1.0;
uniform float fov_override = 0.0;

varying vec3 corner;

void vertex() {
	Z_CLIP_SCALE = z_clip;

	if (fov_override > 0.0) {
		float f = 1.0 / tan(radians(fov_override) * 0.5);
		float aspect = abs(PROJECTION_MATRIX[1][1] / PROJECTION_MATRIX[0][0]);
		PROJECTION_MATRIX[1][1] = f * sign(PROJECTION_MATRIX[1][1]);
		PROJECTION_MATRIX[0][0] = f / aspect * sign(PROJECTION_MATRIX[0][0]);
	}

	corner = COLOR.rgb;
}

void fragment() {
	ALBEDO = glass.rgb;
	METALLIC = 0.6;
	ROUGHNESS = 0.07;
	SPECULAR = 0.9;
	float turned = 1.0 - clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0);
	// Two hard bands: a facet half turned away, a facet nearly edge-on.
	float band = step(0.5, turned) * 0.4 + step(0.78, turned) * 0.6;
	float edge = 1.0 - smoothstep(0.0, edge_width, min(corner.x, min(corner.y, corner.z)));
	EMISSION = glint.rgb * (band * glint_energy + edge * edge_energy);
}
