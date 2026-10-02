// The shore's rock (Materials' shore slots: the coast's granite, its cliffs):
// its photo laid on the world from three sides, as the level's other tiled
// slots are, shaded by the level's baked vertex colours; and banded by
// height as an Atlantic shore is (docs/superpowers/refs/coast_life.md):
// under high water dark, greenish and glossy with the sea (the band that
// catches the moon), over it a band blackened by lichen, dry grey rock
// above. The bands' edges wander a little along the shore.
shader_type spatial;
render_mode cull_back, specular_schlick_ggx;

uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec4 albedo : source_color = vec4(1.0);
uniform float tile = 3.0;
uniform float sharpness = 8.0;
// The top of the wet band and of the black band (m over the sea).
uniform float high_water = 1.4;
uniform float lichen_top = 3.0;

varying vec3 world;
varying vec3 world_normal;
varying vec3 baked;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(mat3(MODEL_MATRIX) * NORMAL);
	baked = COLOR.rgb;
}

float wander(vec2 p) {
	return sin(p.x * 0.83 + p.y * 0.41) * 0.18 + sin(p.x * 0.29 - p.y * 0.67 + 1.7) * 0.22;
}

void fragment() {
	vec3 w = pow(abs(world_normal), vec3(sharpness));
	w /= max(w.x + w.y + w.z, 0.0001);
	vec3 photo = texture(albedo_texture, vec2(world.z, -world.y) / tile).rgb * w.x
		+ texture(albedo_texture, world.xz / tile).rgb * w.y
		+ texture(albedo_texture, vec2(world.x, -world.y) / tile).rgb * w.z;
	vec3 rock = photo * albedo.rgb;
	float y = world.y + wander(world.xz);
	float wet = 1.0 - smoothstep(high_water - 0.12, high_water + 0.12, y);
	float black = smoothstep(high_water - 0.05, high_water + 0.25, y) * (1.0 - smoothstep(lichen_top - 0.35, lichen_top + 0.35, y));
	vec3 lichen = rock * vec3(0.18, 0.18, 0.17);
	vec3 sea = rock * vec3(0.38, 0.44, 0.34);
	ALBEDO = mix(mix(rock, lichen, black), sea, wet) * baked;
	ROUGHNESS = mix(0.92, 0.3, wet);
	SPECULAR = mix(0.25, 0.65, wet);
}
