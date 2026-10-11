// A drifting sprite (FireParticles' petals and leaves): one of the four
// frames of its 2 x 2 sheet (the instance's custom x), cut out clean, lit by
// the scene so it darkens at night, tinted by the instance's colour.
shader_type spatial;
render_mode cull_disabled, diffuse_lambert;

uniform sampler2D sheet : source_color, filter_nearest, repeat_disable;

varying float frame;

void vertex() {
	frame = INSTANCE_CUSTOM.x;
}

void fragment() {
	vec2 cell = vec2(mod(frame, 2.0), floor(frame / 2.0));
	vec4 paint = texture(sheet, (UV + cell) * 0.5);
	ALBEDO = paint.rgb * COLOR.rgb;
	ALPHA = paint.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 0.9;
	BACKLIGHT = paint.rgb * 0.3;
}
