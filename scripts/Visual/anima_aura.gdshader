// An ánima's aura, as Graves' Deadheads glow (docs/superpowers/refs/underground/vfx_method.md): its hand's
// shape pushed out a little and drawn from behind (an inverted hull), adding chartreuse light, so its black
// silhouette is outlined in burning spirit-fire; the outline breathes and licks upward; eaten at the wrist
// with the hand, and all of it as it fades.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, blend_add, shadows_disabled;

uniform vec4 glow : source_color = vec4(0.78, 1.0, 0.32, 1.0);
uniform float energy = 2.4;
uniform float thickness = 0.014;
uniform sampler2D noise : filter_linear_mipmap, repeat_enable;
uniform float presence = 1.0;
uniform float wrist = 0.06;
uniform float seed = 0.0;

varying vec3 local;

void vertex() {
	local = VERTEX;
	float lick = texture(noise, vec2(VERTEX.x * 4.0 + seed, VERTEX.y * 3.0 - TIME * 1.2)).r;
	VERTEX += NORMAL * thickness * (0.7 + 0.9 * lick);
}

void fragment() {
	vec2 at = vec2(local.x * 3.0 + local.z * 2.0 + seed, local.y * 2.5 - TIME * 0.8);
	float n = texture(noise, at).r;
	float eat = (1.0 - smoothstep(0.0, wrist, local.y)) * 0.9 + (1.0 - presence) * 1.1;
	if (n < eat) {
		discard;
	}
	ALBEDO = glow.rgb * energy * presence * (0.8 + 0.2 * sin(TIME * 4.0 + seed));
}
