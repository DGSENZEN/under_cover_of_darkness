// The floor giving way under the Burst: dark cracks running out from one point, fine and branching,
// each with a thread of the spell's violet down in it. They reach out to `reach_now` (m), ragged at
// their end. Not at the very middle, where lines running in to a point would swirl. `heat` is how
// much of the spell is in them; `fade` eats them away.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

uniform sampler2D noise : filter_linear_mipmap, repeat_enable;
uniform float size = 6.0;
uniform float reach_now = 0.0;
uniform float heat = 0.5;
uniform float fade = 0.0;
uniform vec4 gap : source_color = vec4(0.008, 0.006, 0.014, 1.0);
uniform vec4 glow : source_color = vec4(0.46, 0.26, 0.92, 1.0);

void fragment() {
	// (The scar's grid: nothing past the edge of the floor it found.)
	if (COLOR.a < 0.5) {
		discard;
	}

	vec2 at = (UV - vec2(0.5)) * 2.0 * size;
	float r = length(at);
	float a = atan(at.y, at.x) / TAU;
	// (Whole numbers round, so the noise meets itself at the seam.)
	float warp = texture(noise, vec2(a * 3.0, r * 0.11)).r - 0.5;
	float wide = texture(noise, vec2(a * 5.0 + warp * 0.3, r * 0.035)).r;
	float fine = texture(noise, vec2(a * 13.0 + warp * 0.5, r * 0.07)).r;
	float main_crack = 1.0 - smoothstep(0.0, 0.02, abs(wide - 0.5));
	float small_crack = 1.0 - smoothstep(0.0, 0.012, abs(fine - 0.5));
	// The fine ones come and go along their length.
	small_crack *= smoothstep(0.47, 0.56, texture(noise, vec2(a * 2.0, r * 0.2)).r);
	float crack = max(main_crack, small_crack);
	float end = reach_now + (texture(noise, vec2(a * 4.0, 0.3)).r - 0.5) * 1.2;
	float there = 1.0 - smoothstep(end - 0.05, end + 0.05, r);
	float clear_of_middle = smoothstep(0.18, 0.42, r);
	float eaten = smoothstep(fade - 0.05, fade + 0.05, texture(noise, UV * 2.3).r + 0.04) * step(fade, 0.999);
	float alpha = crack * there * clear_of_middle * eaten;

	if (alpha < 0.3) {
		discard;
	}

	float core = 1.0 - smoothstep(0.0, 0.006, abs(wide - 0.5));
	ALBEDO = gap.rgb + glow.rgb * core * (0.1 + heat * 1.6);
	ALPHA = 1.0;
}
