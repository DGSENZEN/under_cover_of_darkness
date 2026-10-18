// Smoke and steam drawn on meshes, the Deadlock way (docs/superpowers/refs/underground/vfx_method.md):
// a plume tube (MeshVfx.plume) or a puff (a lumpy ball the particles carry). Noise climbing it eats it
// away with a hard edge, thickest where you look through most of it (facing you) and fraying at its
// silhouette; lit in hard painted bands, warm where the lamps catch it, cool in its shadow; its foot
// glowing with the warmth it carries out of the works. A puff (`puff` 1) swells and eats itself away
// over its life (INSTANCE_CUSTOM.y); a plume churns and streams downwind along its length (UV.y).
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, shadows_disabled, diffuse_lambert, specular_disabled;

uniform sampler2D noise : filter_linear_mipmap, repeat_enable;
uniform sampler3D noise_3d : filter_linear, repeat_enable;
uniform sampler2D depth : hint_depth_texture, filter_nearest;
uniform vec4 lit : source_color = vec4(0.86, 0.8, 0.72, 1.0);
uniform vec4 shade : source_color = vec4(0.42, 0.44, 0.52, 1.0);
// The warmth at its foot (emitted, fading up it or over a puff's life).
uniform vec4 warm : source_color = vec4(0.9, 0.5, 0.25, 1.0);
uniform float warmth = 0.12;
uniform float glow = 0.12;
uniform float opacity = 0.5;
// How eaten it is to begin with, how much more toward its far end, how hard the edge.
uniform float erosion = 0.3;
uniform float tail_eat = 0.55;
uniform float hardness = 0.035;
uniform float scroll = 0.35;
uniform vec2 tiling = vec2(1.2, 1.5);
uniform float churn = 0.03;
uniform vec3 sway = vec3(0.0);
uniform float seed = 0.0;
// 1: a puff, carried by particles; 0: a plume.
uniform float puff = 0.0;
// Fade where it meets a wall or the floor (m).
uniform float soft = 0.15;

varying float age;
varying vec3 local;
varying float n_vert;

float plume_noise(vec2 uv) {
	vec2 warp = (texture(noise, uv * 0.5 + vec2(seed, -TIME * scroll * 0.4)).rg - 0.5) * 0.35;
	vec2 at = uv * tiling + vec2(seed * 0.37, -TIME * scroll + seed) + warp;
	return texture(noise, at).r * 0.65 + texture(noise, at * 2.1 + vec2(0.31, -TIME * scroll * 0.7)).r * 0.35;
}

float puff_noise(vec3 p) {
	// (Broad billows with a little breakup: clean painted shapes, never frizz.)
	vec3 at = p * 1.2 + vec3(seed, -TIME * scroll, seed * 0.5);
	return texture(noise_3d, at).r * 0.8 + texture(noise_3d, at * 2.0 + vec3(0.2, -TIME * scroll * 0.6, 0.0)).r * 0.2;
}

void vertex() {
	local = VERTEX;
	age = puff > 0.5 ? INSTANCE_CUSTOM.y : UV.y;
	if (puff > 0.5) {
		n_vert = puff_noise(VERTEX * 1.5 + vec3(INSTANCE_CUSTOM.x));
		// Lumpy: pushed out in billows, more as it swells.
		VERTEX += NORMAL * (n_vert - 0.45) * (0.35 + 0.4 * age) * length(VERTEX);
	} else {
		n_vert = plume_noise(UV);
		// Waves travelling up it, growing with height, and its far end streaming downwind.
		float v = UV.y;
		VERTEX += NORMAL * churn * (n_vert - 0.5) * 2.0 * (0.3 + v);
		VERTEX.x += sin(v * 6.0 - TIME * 1.3 + seed * 5.0) * churn * 1.5 * v;
		VERTEX.z += cos(v * 5.0 - TIME * 1.1 + seed * 3.0) * churn * v;
		VERTEX += sway * v * v;
	}
}

void fragment() {
	float n = puff > 0.5 ? puff_noise(local * 1.5 + vec3(seed)) : plume_noise(UV);
	float facing = clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0);
	// Thick through its middle, frayed at its silhouette; eaten more as it ages or climbs.
	float body = n * mix(0.1, 1.0, pow(facing, 1.3));
	float eat = erosion + tail_eat * age * age;
	if (puff > 0.5) {
		// (Born eaten, it fills out fast, then eats itself away.)
		eat = mix(0.55, erosion, smoothstep(0.0, 0.12, age)) + tail_eat * pow(age, 1.4);
	}
	float keep = smoothstep(eat - hardness, eat + hardness, body);
	if (keep < 0.01) {
		discard;
	}
	// Faded where it meets what stands behind it.
	float behind = texture(depth, SCREEN_UV).r;
	vec4 at = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, behind, 1.0);
	float gap = -at.z / at.w + VERTEX.z;
	// A plume's foot comes in out of the vent; its crown thins away.
	float ends = puff > 0.5 ? 1.0 : smoothstep(0.0, 0.08, age) * (1.0 - smoothstep(0.8, 1.0, age));
	ALBEDO = lit.rgb;
	// (A little light of its own, so it reads pale against a lit wall and in shadow alike.)
	EMISSION = warm.rgb * warmth * (1.0 - smoothstep(0.0, 0.45, age)) + lit.rgb * glow;
	ALPHA = keep * opacity * ends * clamp(gap / soft, 0.0, 1.0);
}

void light() {
	// Light in three hard bands, wrapped round (smoke takes light through itself), from its shadow's
	// cool to the lamps' warm.
	float wrap = clamp(dot(NORMAL, LIGHT) * 0.5 + 0.5, 0.0, 1.0);
	float band = floor(wrap * 3.0 + 0.5) / 3.0;
	vec3 tone = mix(shade.rgb / max(lit.rgb, vec3(0.01)), vec3(1.0), band);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * tone * mix(0.35, 1.0, band) / PI;
}
