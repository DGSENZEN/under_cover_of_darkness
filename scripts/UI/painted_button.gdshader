shader_type canvas_item;
render_mode unshaded;
#include "res://scripts/UI/paint_flow.gdshaderinc"
uniform vec4 atlas_rect = vec4(0.0, 0.0, 0.5, 0.5);
uniform vec4 pigment : source_color = vec4(1.0, 0.4, 0.2, 1.0);
uniform sampler2D paint_atlas : source_color, filter_linear, repeat_disable;
uniform float style = 0.0;
uniform float hover = 0.0;
uniform float press = 0.0;
uniform float music = 0.0;
uniform vec2 canvas_size = vec2(314.0, 184.0);
uniform vec2 pointer = vec2(0.5);

void vertex() {
	VERTEX = (VERTEX - canvas_size * 0.5) * 1.14 + canvas_size * 0.5;
	UV = (UV - 0.5) * 1.14 + 0.5;
}

vec4 paint(vec2 uv) {
	float inside = step(0.0, uv.x) * step(uv.x, 1.0) * step(0.0, uv.y) * step(uv.y, 1.0);
	return texture(paint_atlas, atlas_rect.xy + clamp(uv, vec2(0.001), vec2(0.999)) * atlas_rect.zw) * inside;
}

void fragment() {
	vec2 uv = UV;
	float t = TIME * (0.13 + style * 0.012);
	float energy = hover + music * 0.7;
	vec2 velocity = pigment_velocity(uv, style, TIME);
	float edges = smoothstep(0.12, 0.52, length((uv - vec2(0.53, 0.45)) * vec2(0.8, 1.0)));
	float touch = exp(-length(uv - clamp(pointer, vec2(0.0), vec2(1.0))) * 5.0) * hover;
	float strength = (0.01 + energy * 0.095 + press * 0.065) * (0.18 + edges * 0.82);
	vec3 a = paint_phase(uv, velocity, t, strength);
	vec3 b = paint_phase(uv, velocity, t + 0.5, strength);
	vec4 col = paint(a.xy) * a.z + paint(b.xy) * b.z;
	float brush = texture(flow_map, uv * vec2(2.0, 17.0) + velocity * t * 0.12).r;
	float radius = (energy * 0.02 + press * 0.028) * (0.3 + brush * 0.7);
	vec4 daub = col;
	for (int i = 0; i < 12; i++) {
		float angle = float(i) * 6.2831853 / 12.0;
		vec2 offset = vec2(cos(angle) * 0.65, sin(angle)) * radius;
		vec4 sample_paint = paint(a.xy + offset) * a.z + paint(b.xy + offset) * b.z;
		if (sample_paint.a > daub.a) {
			daub = sample_paint;
		}
	}
	float edge = max(0.0, daub.a - col.a);
	col.rgb = mix(col.rgb, mix(daub.rgb, pigment.rgb, 0.18), edge);
	// Sheen follows pigment ridges instead of a scanning light stripe.
	float ridge = smoothstep(0.25, 0.85, brush) * smoothstep(0.05, 0.6, length(velocity));
	col.rgb += pigment.rgb * ridge * (0.025 + energy * 0.16 + touch * 0.07 + press * 0.1);
	if (style > 0.5 && style < 1.5) {
		float eyes = exp(-length((uv - vec2(0.26, 0.39)) * vec2(15.0, 10.0))) + exp(-length((uv - vec2(0.46, 0.39)) * vec2(15.0, 10.0)));
		col.rgb += pigment.rgb * eyes * (0.025 + energy * 0.15) * (0.65 + brush * 0.35);
	}
	col.rgb *= 1.0 - smoothstep(0.67, 0.97, uv.y) * 0.58;
	COLOR = vec4(col.rgb, max(col.a, edge));
}
