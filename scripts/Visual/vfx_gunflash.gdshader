// The muzzle flash in your view: vfx_mesh.gdshader drawn as the arms and the
// gun are, at their own field of view and depth squeeze (ViewArms.dress).
//
// A mesh effect, the Deadlock way (docs/superpowers/refs/underground/vfx_method.md): noise scrolled
// along the mesh's UVs (v runs along it: up a flame, along a ribbon, up a tendril) erodes it with a
// hard edge; its colour in flat bands (core, body, edge); a fresnel rim gives the volume its edge;
// a little of the noise pushes its vertices out so its silhouette churns.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 core : source_color = vec4(0.92, 1.0, 0.86, 1.0);
uniform vec4 body : source_color = vec4(0.5, 0.88, 0.5, 1.0);
uniform vec4 edge : source_color = vec4(0.12, 0.34, 0.28, 1.0);
uniform sampler2D noise : filter_linear_mipmap, repeat_enable;
// How much it has eaten away (0 whole, 1 gone); how far along v it eats from its tail (0..1 of its
// length, the far end first); how hard the eaten edge is.
uniform float erosion : hint_range(0.0, 1.0) = 0.25;
uniform float tail_eat : hint_range(0.0, 1.0) = 0.6;
uniform float hardness = 0.04;
// The noise: its tiling (u, v) and how fast it slides along v (per s).
uniform vec2 tiling = vec2(1.0, 1.5);
uniform float scroll = 0.6;
uniform float seed = 0.0;
// Its rim, and how bright it is all told (above 1 the night's bloom takes it).
uniform float rim = 2.0;
uniform float energy = 1.6;
uniform float opacity = 1.0;
// How far its vertices churn (m).
uniform float churn = 0.01;
// Where its far end is blown (m, in its own space): a flame streams behind what carries it.
uniform vec3 sway = vec3(0.0);
// How far along v its pale core reaches (1 all the way; a fire's white only at its roots).
uniform float core_reach = 1.0;

// The viewmodel's depth squeeze (BaseMaterial3D.z_clip_scale) and its own
// field of view (vertical degrees; 0: the camera's).
uniform float z_clip = 1.0;
uniform float fov_override = 0.0;

varying float n_at;

float sample_noise(vec2 uv) {
	vec2 at = uv * tiling + vec2(seed * 0.37, -TIME * scroll + seed);
	return texture(noise, at).r * 0.65 + texture(noise, at * 2.13 + vec2(0.31, -TIME * scroll * 0.6)).r * 0.35;
}

void vertex() {
	Z_CLIP_SCALE = z_clip;

	if (fov_override > 0.0) {
		float f = 1.0 / tan(radians(fov_override) * 0.5);
		float aspect = abs(PROJECTION_MATRIX[1][1] / PROJECTION_MATRIX[0][0]);
		PROJECTION_MATRIX[1][1] = f * sign(PROJECTION_MATRIX[1][1]);
		PROJECTION_MATRIX[0][0] = f / aspect * sign(PROJECTION_MATRIX[0][0]);
	}

	n_at = sample_noise(UV);
	VERTEX += NORMAL * churn * (n_at - 0.5) * 2.0;
	VERTEX += sway * UV.y * UV.y;
}

void fragment() {
	float n = sample_noise(UV);
	// Eaten more toward its far end (v 1), and all over by `erosion`.
	float eat = erosion + tail_eat * UV.y * UV.y;
	float keep = smoothstep(eat - hardness, eat + hardness, n);
	if (keep <= 0.01) {
		discard;
	}
	float facing = clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0);
	float rim_at = pow(1.0 - facing, rim);
	// Bands: the edge of what is eaten, the body, the bright core where it faces you and is whole.
	float depth = n - eat;
	vec3 colour = edge.rgb;
	colour = mix(colour, body.rgb, step(0.04, depth));
	colour = mix(colour, core.rgb, step(0.18, depth) * step(0.35, facing) * step(UV.y, core_reach));
	colour += body.rgb * rim_at * 0.8;
	ALBEDO = colour * energy;
	ALPHA = keep * opacity;
}
