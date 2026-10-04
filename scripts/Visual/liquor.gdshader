// A tannery vat's liquor (our own, no photo): murky brown water, drifting
// patches of pale scum, a slow stir, an oily sheen where it is clear.
// World-mapped, so every vat's surface differs.
shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;

uniform vec3 deep : source_color = vec3(0.16, 0.11, 0.06);
uniform vec3 murk : source_color = vec3(0.30, 0.23, 0.12);
uniform vec3 scum : source_color = vec3(0.52, 0.46, 0.30);
// How fast the scum drifts (m/s) and the liquor's stir.
uniform float drift = 0.03;
uniform float stir = 0.15;
// Texels a metre, as the level's photos are drawn.
uniform float texels = 48.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float total = 0.0;
	float weight = 0.5;

	for (int i = 0; i < 4; i++) {
		total += noise(p) * weight;
		p = p * 2.03 + vec2(1.7, 9.2);
		weight *= 0.5;
	}

	return total;
}

varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// (On the texel grid the stone's photos are drawn at.)
	vec2 p = floor(world.xz * texels) / texels;
	float t = TIME;
	// (The liquor stirring under its scum: two layers drifting apart.)
	vec2 swirl = vec2(fbm(p * 0.8 + t * stir), fbm(p * 0.8 - t * stir + 3.1)) - 0.5;
	float body = fbm(p * 1.6 + swirl * 1.5);
	float skin = smoothstep(0.52, 0.66, fbm(p * 2.4 + swirl + vec2(t * drift, -t * drift * 0.6)));
	// (Pixels to the PS2's grid: a few flat tones, not a smooth gradient.)
	body = floor(body * 6.0) / 6.0;
	vec3 liquid = mix(deep, murk, body);
	ALBEDO = mix(liquid, scum, skin);
	ROUGHNESS = mix(0.18, 0.95, skin);
	SPECULAR = mix(0.6, 0.1, skin);
	METALLIC = 0.0;
}
