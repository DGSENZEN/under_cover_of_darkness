// A shade of the procession (docs/superpowers/refs/underground/shade_refs.md): a shroud with no one
// in it, as the painted Santa Compaña glows: pale, unlit, see-through in its middle and bright at its
// rim; a slow noise climbing it; its hem eaten away into mist; its face (the "hollow" surface) Mignola's
// black, a soft ring of shadow round it so its edge never steps. Its candle's warm light the only colour.
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque, blend_mix, shadows_disabled;

uniform vec4 pale : source_color = vec4(0.8, 0.86, 0.9, 1.0);
uniform vec4 rim_colour : source_color = vec4(0.94, 0.98, 1.0, 1.0);
uniform vec4 candle : source_color = vec4(1.0, 0.72, 0.4, 1.0);
uniform sampler3D noise : filter_linear, repeat_enable;
// Its candle's flame (world) and how far its warmth reaches.
uniform vec3 candle_at = vec3(0.0);
uniform float candle_reach = 0.9;
// How much of it is here (1 whole, 0 gone into the stone), and how much shows through its middle.
uniform float presence = 1.0;
uniform float sheer = 0.45;
// Its hem's height (world), up to which mist eats it.
uniform float hem = 0.1;
// The hollow: 1 on its face's surface; its oval in the shade's own axes (its middle, its half-sizes
// across and up), round which the shroud darkens softly so the hollow's edge never steps.
uniform float hollow = 0.0;
uniform vec3 face_middle = vec3(0.0, 1.5, 0.0);
uniform vec2 face_half = vec2(0.1, 0.12);

varying vec3 world;
varying vec3 local;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	local = VERTEX;
}

void fragment() {
	vec3 p = world * 1.6 + vec3(0.0, -TIME * 0.12, 0.0);
	float n = texture(noise, p).r * 0.7 + texture(noise, p * 2.7 + vec3(3.1)).r * 0.3;
	// Eaten: at its hem into mist, and all over as it goes.
	float at_hem = 1.0 - smoothstep(hem, hem + 0.35, world.y);
	float eat = at_hem * 0.75 + (1.0 - presence) * 1.2;
	if (n < eat * 0.9 + 0.02) {
		discard;
	}
	float facing = clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0);
	float rim = pow(1.0 - facing, 2.0);
	float warmth = clamp(1.0 - distance(world, candle_at) / candle_reach, 0.0, 1.0);
	vec3 colour = mix(pale.rgb * (0.82 + 0.18 * n), rim_colour.rgb * 1.25, rim);
	colour = mix(colour, candle.rgb * 1.3, warmth * warmth * 0.7);
	float alpha = mix(1.0 - sheer, 1.0, rim);
	// Into the hood's shadow round its face: the shroud darkens softly to the hollow's black.
	vec2 off = vec2((local.z - face_middle.z) / face_half.x, (local.y - face_middle.y) / face_half.y);
	float near_face = (1.0 - smoothstep(0.75, 1.35, length(off))) * step(0.0, local.x);
	colour = mix(colour, vec3(0.02, 0.02, 0.03), near_face);
	alpha = mix(alpha, 1.0, near_face);
	if (hollow > 0.5) {
		colour = vec3(0.02, 0.02, 0.03);
		alpha = 1.0;
	}
	ALBEDO = colour;
	ALPHA = alpha * clamp(presence * 1.5, 0.0, 1.0);
}
