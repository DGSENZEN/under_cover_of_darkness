// A word's glyph (scripts/Visual/Library/WordChain.gd): one quad, its glyph read from the distance-field atlas cell
// its instance names, so its edge stays sharp at any distance. A bright core, a dark rim round it so it reads over
// the lit pages, a faint halo of its colour beyond. Each instance's custom data: its cell (x, y), how present it is
// (z: fading at the chain's ends), a seed (w) for its flicker.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;

uniform sampler2D atlas : filter_linear_mipmap, repeat_disable;
uniform vec2 grid = vec2(8.0, 6.0);
uniform vec4 core : source_color = vec4(1.0, 0.9, 0.7, 1.0);
uniform vec4 rim : source_color = vec4(0.05, 0.03, 0.02, 1.0);
uniform float energy = 2.2;
uniform float presence = 1.0;

varying vec4 custom;

void vertex() {
	custom = INSTANCE_CUSTOM;
}

void fragment() {
	// (Inset half a texel's worth so a neighbour's cell never bleeds in at a distance.)
	vec2 at = (custom.xy + clamp(UV, vec2(0.02), vec2(0.98))) / grid;
	float d = texture(atlas, at).r;
	float w = max(fwidth(d) * 0.75, 0.015);
	float ink = smoothstep(0.5 - w, 0.5 + w, d);
	float inner = smoothstep(0.58 - w, 0.58 + w, d);
	float halo = smoothstep(0.3, 0.5, d) * 0.28;
	float flicker = 0.85 + 0.15 * sin(TIME * 3.0 + custom.w * 6.283);
	ALBEDO = mix(core.rgb * energy * 0.6, mix(rim.rgb, core.rgb * energy * flicker, inner), ink);
	ALPHA = clamp(max(ink, halo), 0.0, 1.0) * custom.z * presence;
	if (ALPHA < 0.01) {
		discard;
	}
}
