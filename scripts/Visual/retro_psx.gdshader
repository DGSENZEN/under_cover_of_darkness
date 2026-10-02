shader_type spatial;
// Optional normally lit PS1-style prop material: snap_lines quantizes projected vertices,
// affine mixes perspective-correct and affine UVs.
// Keep level geometry on the normal look to avoid large swimming wall textures.

render_mode cull_back, diffuse_lambert, specular_schlick_ggx;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec2 uv_scale = vec2(1.0);
uniform float snap_lines = 0.0;
uniform float affine : hint_range(0.0, 1.0) = 0.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.9;
uniform float specular : hint_range(0.0, 1.0) = 0.3;
uniform vec3 emission : source_color = vec3(0.0);

varying vec3 affine_uv;

void vertex() {
	UV *= uv_scale;
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));

	if (snap_lines > 0.0) {
		vec2 grid = vec2(snap_lines * VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, snap_lines) * 0.5;
		vec2 ndc = clip.xy / clip.w;
		clip.xy = floor(ndc * grid + 0.5) / grid * clip.w;
	}

	// Written always: a shader that writes POSITION anywhere owns it
	// everywhere, and an unwritten one collapses every vertex to a point.
	POSITION = clip;

	// UV times w, interpolated with perspective and divided back: affine.
	affine_uv = vec3(UV * clip.w, clip.w);
}

void fragment() {
	vec2 uv = mix(UV, affine_uv.xy / affine_uv.z, affine);
	vec4 texel = texture(albedo_texture, uv);
	ALBEDO = albedo.rgb * texel.rgb;
	ROUGHNESS = roughness;
	SPECULAR = specular;
	EMISSION = emission;
}
