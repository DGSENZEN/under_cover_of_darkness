// A particle's sprite (Vfx.gd): a camera-facing frame of our own sheet, its
// colour the instance's tint, eroded over its life, soft where it meets the
// ground, lit in hard bands; six-way lit when it has a second sheet.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_lambert, specular_disabled;

#include "res://scripts/Visual/vfx_common.gdshaderinc"

uniform sampler2D sheet : source_color, filter_nearest, repeat_disable;
uniform sampler2D sheet_b : source_color, filter_nearest, repeat_disable;
uniform bool six_ways = false;
uniform ivec2 grid = ivec2(2, 2);
uniform vec4 tint : source_color = vec4(1.0);
uniform float opacity = 0.5;
// How far it erodes away by the end of its life (0: it only fades).
uniform float erosion = 0.0;
uniform float bands_count = 3.0;
uniform float fade_distance = 0.6;
uniform bool glows = false;
uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;

varying float life;
varying float progress;
varying mat3 sprite_axes;

void vertex() {
	// Faces the camera, turned by the particle's rotation, sized by its scale.
	mat4 world = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
	world = world * mat4(vec4(cos(INSTANCE_CUSTOM.x), -sin(INSTANCE_CUSTOM.x), 0.0, 0.0),
		vec4(sin(INSTANCE_CUSTOM.x), cos(INSTANCE_CUSTOM.x), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * world;
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	sprite_axes = mat3(normalize(MODELVIEW_MATRIX[0].xyz), normalize(MODELVIEW_MATRIX[1].xyz), normalize(MODELVIEW_MATRIX[2].xyz));
	life = INSTANCE_CUSTOM.y;
	progress = INSTANCE_CUSTOM.z;
}

void fragment() {
	vec2 uv = flipbook_uv(UV, progress, grid);
	vec4 a = texture(sheet, uv);
	float alpha = a.a * COLOR.a * opacity;
	alpha *= erode(a.a, life * erosion, 0.15);
	float depth = textureLod(depth_texture, SCREEN_UV, 0.0).r;
	vec4 behind = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	behind.xyz /= behind.w;
	alpha *= clamp(1.0 - smoothstep(behind.z + fade_distance, behind.z, VERTEX.z), 0.0, 1.0);
	vec3 colour = (six_ways ? vec3(1.0) : a.rgb) * tint.rgb * COLOR.rgb;
	ALBEDO = colour;
	ALPHA = alpha;
	// A sphere's normal across the sprite, so it lights as a volume.
	vec2 c = UV * 2.0 - 1.0;
	NORMAL = normalize(sprite_axes * vec3(c.x, -c.y, 0.75));

	if (glows) {
		EMISSION = colour * 1.5;
	}
}

void light() {
	float lit;

	if (six_ways) {
		vec2 uv = flipbook_uv(UV, progress, grid);
		vec3 l = transpose(sprite_axes) * LIGHT;
		lit = six_way(texture(sheet, uv), texture(sheet_b, uv), l);
	} else {
		lit = dot(NORMAL, LIGHT);
	}

	DIFFUSE_LIGHT += bands(lit, bands_count) * ATTENUATION * LIGHT_COLOR / PI;
}
