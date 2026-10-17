// A spectre (the nahual; docs/superpowers/refs/underground/supernatural_refs.md): Mignola's black,
// one flat shape with nothing drawn inside it, but not quite there. Its silhouette frays into
// tongues of smoke that climb it (cut hard, never a soft fade), the last of each a cold grey; its
// surface billows a little; the light behind it shows faintly through.
shader_type spatial;
render_mode unshaded, cull_back, depth_prepass_alpha, blend_mix, shadows_disabled;

uniform vec4 ink : source_color = vec4(0.043, 0.039, 0.047, 1.0);
// The fraying's last edge, just before it is gone.
uniform vec4 fray_colour : source_color = vec4(0.26, 0.3, 0.32, 1.0);
uniform sampler3D noise : filter_linear, repeat_enable;
// How far in from its silhouette it frays (0 none, 1 to its middle), how fine and how fast it climbs.
uniform float fray = 0.9;
uniform float grain = 1.1;
uniform float rise = 0.18;
// How much it billows (m), and how much of what is behind it shows through its body.
uniform float billow = 0.018;
uniform float sheer = 0.22;
// How much of it is here (1 whole; 0 scattered to smoke, walked into).
uniform float presence = 1.0;

varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float n = texture(noise, world * 1.3 + vec3(0.0, -TIME * rise, 0.0)).r;
	VERTEX += NORMAL * billow * (n - 0.5) * 2.0;
}

void fragment() {
	// 1 where it faces the eye, falling to 0 at its silhouette.
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	// Smoke climbing: the noise drawn up over time, coarser and finer laid together.
	vec3 p = world * grain + vec3(0.0, -TIME * rise * grain, 0.0);
	float n = texture(noise, p).r * 0.8 + texture(noise, p * 2.1 + vec3(5.1)).r * 0.2;
	// How solid it is here: its body solid, its edges eaten by the smoke, more toward its top.
	float lift = clamp(world.y * 0.4, 0.0, 0.25);
	// (The smoke eats in from the silhouette; the body facing the eye stays whole: big shapes.)
	float edge = 1.0 - smoothstep(0.35, 0.85, facing);
	float solid = smoothstep(0.0, fray, facing) + (n - 0.5) * 1.6 * edge - lift * edge;
	// Scattering: the smoke eats it all, edges first, then its body.
	solid -= (1.0 - presence) * (1.4 + (n - 0.5) * 0.8);
	// Cut hard where the smoke has eaten it: Mignola's crisp shapes, not a soft fade.
	if (solid < 0.3) {
		discard;
	}
	// The last of each tongue a cold grey, then the ink.
	float last = 1.0 - smoothstep(0.3, 0.42, solid);
	ALBEDO = mix(ink.rgb, fray_colour.rgb, last);
	ALPHA = mix(1.0 - sheer, 1.0, last);
}
