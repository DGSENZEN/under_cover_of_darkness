shader_type spatial;
// The PS1's own wobble, for the props that want it. Lit by Godot's lights
// like everything else (shadows, fog, shafts all work); on top of that:
//
//   snap_lines   vertices snap to a grid of this many screen lines, so edges
//                jitter as they move: the PS1 had no sub-pixel precision.
//                0 snaps them as the rest of the world does (Retro's
//                psx_snap_lines, gentle).
//   affine       texture coordinates interpolated across the screen instead
//                of in depth, so textures swim and bend on big polygons.
//                0 is correct perspective, 1 is a PS1.
//   per_vertex   lighting worked out at the corners and blended between them
//                (Gouraud), as consoles of the time did.
//
// Use it for idols, props and monsters that want more than the world's
// gentle snap; keep affine off level geometry, where swimming walls would
// make people sick.

render_mode cull_back, diffuse_lambert, specular_schlick_ggx;
#include "res://scripts/Visual/psx.gdshaderinc"

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
	} else {
		// The world's own wobble (psx.gdshaderinc, set by Retro).
		clip = psx_snapped(clip, VIEWPORT_SIZE);
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
