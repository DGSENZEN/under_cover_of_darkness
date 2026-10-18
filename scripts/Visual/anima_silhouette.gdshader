// An ánima's hand, as Graves' Deadheads are drawn (docs/superpowers/refs/underground/vfx_method.md):
// a solid black silhouette, Mignola's black, wrapped in a glowing chartreuse rim where it turns from you
// (past white, so the night's bloom takes it), the rim breathing a little; eaten into its spirit-fire
// toward the wrist, and all of it as it fades.
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque, shadows_disabled;

uniform vec4 ink : source_color = vec4(0.02, 0.025, 0.02, 1.0);
uniform vec4 glow : source_color = vec4(0.78, 1.0, 0.32, 1.0);
uniform float rim_power = 5.0;
uniform float energy = 3.2;
uniform sampler2D noise : filter_linear_mipmap, repeat_enable;
// How much of it is here (1 whole, 0 eaten away), and up to what height (its own, m) the wrist is eaten.
uniform float presence = 1.0;
uniform float wrist = 0.06;
uniform float seed = 0.0;

varying vec3 local;

void vertex() {
	local = VERTEX;
}

void fragment() {
	vec2 at = vec2(local.x * 3.0 + local.z * 2.0 + seed, local.y * 2.5 - TIME * 0.8);
	float n = texture(noise, at).r;
	float eat = (1.0 - smoothstep(0.0, wrist, local.y)) * 0.9 + (1.0 - presence) * 1.1;
	if (n < eat) {
		discard;
	}
	float facing = clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0);
	float rim = pow(1.0 - facing, rim_power);
	// Where it is about to be eaten, it burns: the edge of the eaten wrist glows too.
	float burning = 1.0 - smoothstep(0.0, 0.08, n - eat);
	float lit = clamp(rim * 0.6 + burning, 0.0, 1.0) * (0.85 + 0.15 * sin(TIME * 3.0 + seed));
	ALBEDO = mix(ink.rgb, glow.rgb * energy, lit);
}
