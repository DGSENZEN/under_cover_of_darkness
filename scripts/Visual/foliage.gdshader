// Leaves, needles, grass, reeds and ivy (Materials' foliage slots): our own
// paintings cut out where they are clear, shaded by the level's baked
// vertex colours, a little light through them from behind; stirred by the
// wind (Materials.blow): each card's top edge rustles, and what stands high
// (a tree's crown) sways slowly on its boughs; a card seen edge-on thins
// away. The cards carry their own faces both ways (kit_shapes), so each
// side is drawn by its own face.
shader_type spatial;
render_mode cull_back, specular_schlick_ggx;

uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap, repeat_disable;
uniform vec4 albedo : source_color = vec4(1.0);
uniform float alpha_scissor = 0.5;
// How far a card's top edge rustles (m), and how far a bough sways for each
// metre it stands over a man's height (m); the wind (m/s, flat: Night's,
// through Materials.blow), and how strong a wind moves them fully.
uniform float rustle = 0.05;
uniform float bough = 0.0;
uniform vec3 wind = vec3(0.6, 0.0, 0.6);
uniform float full_wind = 8.0;
// Light through the leaves from behind.
uniform float translucency = 0.35;

varying vec3 baked;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float speed = length(wind.xz);
	vec2 way = speed > 0.001 ? wind.xz / speed : vec2(0.7, 0.7);
	float strength = clamp(speed / full_wind, 0.0, 1.3);
	float phase = TIME * (1.2 + 2.2 * strength) + dot(world.xz, vec2(0.37, 0.23));
	float top = 1.0 - UV.y;
	float flutter = rustle * top * top * (0.25 + strength) * (0.6 * sin(phase * 2.3) + 0.4 * sin(phase * 3.7 + 1.3));
	float lean = max(world.y - 1.8, 0.0) * bough * (strength * 0.8 + 0.2 * sin(TIME * 0.6 + world.x * 0.05 + world.z * 0.04) + 0.15 * strength * sin(TIME * 1.7 + world.z * 0.1));
	vec3 offset = vec3(way.x, 0.0, way.y) * (flutter + lean) + vec3(0.0, flutter * 0.25, 0.0);
	VERTEX += (inverse(mat3(MODEL_MATRIX)) * offset);
	baked = COLOR.rgb;
}

void fragment() {
	vec4 paint = texture(albedo_texture, UV) * albedo;
	ALBEDO = paint.rgb * baked;
	// A card seen edge-on thins away (no flat shard of leaves across the
	// crown's rim): its own face's way, not its rounded normal.
	vec3 face = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	ALPHA = paint.a * smoothstep(0.08, 0.38, abs(dot(face, VIEW)));
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor;
	ROUGHNESS = 0.85;
	SPECULAR = 0.25;
	BACKLIGHT = paint.rgb * translucency;
}
