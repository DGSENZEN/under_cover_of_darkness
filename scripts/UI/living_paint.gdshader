shader_type canvas_item;
render_mode unshaded;
#include "res://scripts/UI/paint_flow.gdshaderinc"
uniform sampler2D painting : source_color, filter_linear, repeat_disable;
uniform float energy = 0.0;

void fragment() {
	vec2 uv = UV;
	float t = TIME * 0.065;
	vec2 velocity = pigment_velocity(uv * vec2(1.0, 0.8), 3.0, TIME * 0.55);
	// Sky and reflected paint move most; architecture stays anchored.
	float sky = 1.0 - smoothstep(0.26, 0.62, uv.y);
	float reflection = smoothstep(0.69, 0.98, uv.y);
	float strength = 0.003 + sky * 0.055 + reflection * 0.021 + energy * 0.012;
	// Keep the moon and the cathedral's thin spire registered while pigment
	// moves around them; blending moving copies would otherwise double them.
	float moon = 1.0 - smoothstep(0.017, 0.036, length(uv - vec2(0.075, 0.129)));
	float spire = exp(-pow((uv.x - 0.5) / 0.006, 2.0)) * (1.0 - smoothstep(0.3, 0.43, uv.y));
	strength *= 1.0 - max(moon, spire) * 0.98;
	float edge_mask = smoothstep(0.0, 0.05, uv.x) * smoothstep(0.0, 0.05, 1.0 - uv.x) * smoothstep(0.0, 0.05, uv.y) * smoothstep(0.0, 0.05, 1.0 - uv.y);
	vec3 a = paint_phase(uv, velocity, t, strength * edge_mask);
	vec3 b = paint_phase(uv, velocity, t + 0.5, strength * edge_mask);
	vec4 col = texture(painting, clamp(a.xy, vec2(0.001), vec2(0.999))) * a.z + texture(painting, clamp(b.xy, vec2(0.001), vec2(0.999))) * b.z;
	float wet = texture(flow_map, uv * vec2(2.0, 8.0) - velocity * t * 0.15).r;
	float warmth = smoothstep(0.02, 0.22, col.r - col.b);
	col.rgb *= 1.0 + (wet - 0.5) * (sky * 0.16 + reflection * 0.23 + warmth * 0.09);
	COLOR = col;
}
