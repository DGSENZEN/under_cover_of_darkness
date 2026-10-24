// The edge of the view coloured by magic (MagicView.gd): Blink's cold flash,
// Empower's beast pulse. A soft vignette, strongest in the corners.
shader_type canvas_item;

uniform vec4 tint : source_color = vec4(0.87, 0.9, 0.95, 1.0);
uniform float amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 from_middle = (UV - 0.5) * vec2(1.25, 1.0);
	float edge = smoothstep(0.32, 0.78, length(from_middle));
	COLOR = vec4(tint.rgb, tint.a * edge * amount);
}
