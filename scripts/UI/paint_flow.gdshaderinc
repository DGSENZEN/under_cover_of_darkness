// Two overlapping advection phases, inspired by these original references:
// https://catlikecoding.com/unity/tutorials/flow/texture-distortion/
// https://godotshaders.com/shader/wobbly-effect-hand-painted-animation/
uniform sampler2D flow_map : filter_linear, repeat_enable;

vec2 pigment_velocity(vec2 uv, float style, float time) {
	vec2 q = uv * vec2(1.2, 1.0) + vec2(style * 0.19, -style * 0.23);
	vec2 warp = texture(flow_map, q * 0.55 + vec2(time * 0.016, 0.0)).rg * 2.0 - 1.0;
	vec2 velocity = texture(flow_map, q + warp * 0.25).rg * 2.0 - 1.0;
	if (style < 0.5) {
		velocity *= vec2(1.7, 0.55);
	} else if (style < 1.5) {
		velocity = vec2(velocity.y * 0.7, -abs(velocity.x) - 0.25);
	} else if (style < 2.5) {
		velocity = vec2(velocity.y, -velocity.x) * vec2(1.4, 0.8);
	} else {
		vec2 p = uv - vec2(0.65, 0.45);
		velocity += vec2(-p.y, p.x) * 0.7;
	}
	return velocity;
}

vec3 paint_phase(vec2 uv, vec2 velocity, float phase, float strength) {
	float p = fract(phase);
	return vec3(uv - velocity * (p - 0.5) * strength, 1.0 - abs(1.0 - 2.0 * p));
}
