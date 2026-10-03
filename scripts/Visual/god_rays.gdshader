// Additive coloured window shafts (GodRays): glass picture and drifting dust,
// with scene-depth contact softening and smooth edge-on fade.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform sampler2D glass : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D dust : filter_linear, repeat_enable;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform float strength = 1.0;
// Moonlight's colour through clear glass; how much the whole shaft adds.
uniform vec3 tint : source_color = vec3(0.6, 0.78, 1.25);
uniform float gain = 0.14;
// The glass seen through dusty air: its picture this blurred (mip levels).
uniform float blur = 3.5;
// It softens this close (m) to what it falls on.
uniform float soft_depth = 0.5;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// The glass's colours in soft patches (no lead lines drawn down the
	// shaft), a little richer than the panes themselves.
	vec3 colour = textureLod(glass, UV, blur).rgb;
	float grey = dot(colour, vec3(0.3, 0.59, 0.11));
	colour = max(mix(vec3(grey), colour, 1.6), vec3(0.0)) * 1.45;
	float along = UV2.x;
	float fall = pow(1.0 - along, 0.7) * smoothstep(0.0, 0.04, along);
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float edge = smoothstep(0.03, 0.45, facing);
	vec2 drift = vec2(TIME * 0.011, TIME * -0.007);
	float motes = texture(dust, world_pos.xz * 0.23 + vec2(world_pos.y * 0.17, 0.0) + drift).r;
	motes = 0.55 + 0.9 * motes * texture(dust, world_pos.zy * 0.41 - drift * 1.7).r;
	float depth = texture(depth_texture, SCREEN_UV).r;
	vec4 behind = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	float scene = -behind.z / behind.w;
	float soft = clamp((scene + VERTEX.z) / soft_depth, 0.0, 1.0);
	// (A shaft the eye stands in, or all but, thins away: no wall of light
	// across the lens.)
	float near = smoothstep(0.6, 3.0, -VERTEX.z);
	// (UV2.y: this shaft's weight among its node's, a window's share of sky.)
	ALBEDO = colour * tint * strength * gain * fall * edge * motes * soft * near * UV2.y;
}
