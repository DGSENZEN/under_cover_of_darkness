// Shared wardrobe shading for closed and two-sided parts. Baked albedo contains AO/top light;
// runtime adds diffuse light/shadow, without specular. Instance dye/fade/skin/grime vary each guard.
// Mask red=dye, green=skin, blue=dirt. Shader nearest sampling is explicit because Retro converts standard materials only.

uniform sampler2D albedo : source_color, filter_nearest_mipmap, repeat_disable;
uniform sampler2D mask : filter_nearest_mipmap, repeat_disable;
// The colour the dyed cloth was baked in: the new dye keeps its shading.
uniform vec3 dye_base : source_color = vec3(1.0);

instance uniform vec3 dye_colour : source_color = vec3(1.0);
instance uniform float dye_fade = 0.0;
// A linear multiplier: his skin from the light tone to his own.
instance uniform vec3 skin_tone = vec3(1.0);
instance uniform float grime = 0.0;

const vec3 LUMA = vec3(0.299, 0.587, 0.114);

vec3 wardrobe_colour(vec2 uv) {
	vec3 c = texture(albedo, uv).rgb;
	vec3 m = texture(mask, uv).rgb;
	// His dye, lit as the baked one was, and washed toward grey by wear.
	vec3 dyed = dye_colour * (dot(c, LUMA) / max(dot(dye_base, LUMA), 0.001));
	dyed = mix(dyed, vec3(dot(dyed, LUMA)), dye_fade);
	c = mix(c, dyed, m.r);
	c = mix(c, c * skin_tone, m.g);
	// Dirt: darker, browner, where dirt gathers (hems, boots, creases); at
	// most 80% of the way (by eye: 60% hid it at a few metres).
	c = mix(c, vec3(dot(c, LUMA)) * vec3(0.52, 0.46, 0.38), clamp(m.b * grime, 0.0, 1.0) * 0.8);
	return c;
}
